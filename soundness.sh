#!/usr/bin/env bash
set -e

# Define color codes
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Display logo
echo -e "${BLUE}Loading logo...${NC}"
sleep 2
curl -s https://raw.githubusercontent.com/bangpateng/logo/refs/heads/main/logo.sh | bash
sleep 1

# Function for installation including Rust and key generation
install_soundness() {
  echo -e "${GREEN}🚀 Installing soundnessup...${NC}" && echo

  BASE_DIR=$HOME
  SOUNDNESS_DIR=${SOUNDNESS_DIR-"$BASE_DIR/.soundness"}
  SOUNDNESS_BIN_DIR="$SOUNDNESS_DIR/bin"
  BIN_URL="https://raw.githubusercontent.com/soundnesslabs/soundness-layer/main/soundnessup/soundnessup"
  BIN_PATH="$SOUNDNESS_BIN_DIR/soundnessup"

  # Create the .soundness bin directory and soundnessup binary if it doesn't exist.
  mkdir -p $SOUNDNESS_BIN_DIR
  curl -# -L $BIN_URL -o $BIN_PATH
  chmod +x $BIN_PATH

  # Store the correct profile file (i.e. .profile for bash or .zshenv for ZSH).
  case $SHELL in
    */zsh)
      PROFILE=${ZDOTDIR-"$HOME"}/.zshenv
      PREF_SHELL=zsh
      ;;
    */bash)
      PROFILE=$HOME/.bashrc
      PREF_SHELL=bash
      ;;
    */fish)
      PROFILE=$HOME/.config/fish/config.fish
      PREF_SHELL=fish
      ;;
    */ash)
      PROFILE=$HOME/.profile
      PREF_SHELL=ash
      ;;
    *)
      echo -e "${RED}soundnessup: could not detect shell, manually add ${SOUNDNESS_BIN_DIR} to your PATH.${NC}"
      exit 1
  esac

  # Only add soundnessup if it isn't already in PATH.
  if [[ ":$PATH:" != *":${SOUNDNESS_BIN_DIR}:"* ]]; then
    # Add the soundnessup directory to the path and ensure the old PATH variables remain.
    echo >> $PROFILE && echo "export PATH=\"\$PATH:$SOUNDNESS_BIN_DIR\"" >> $PROFILE
  fi

  echo && echo -e "${GREEN}✅ Installation complete!${NC}"
  echo && echo -e "${BLUE}🔍 Detected shell: ${PREF_SHELL}${NC}"
  echo -e "${BLUE}🔗 Added soundnessup to PATH${NC}"
  echo && echo -e "${YELLOW}To start using soundnessup, please run:${NC}"
  echo && echo -e "${YELLOW}▶ source ${PROFILE}${NC}"
  echo -e "${YELLOW}▶ soundnessup${NC}"
  echo && echo -e "${GREEN}🎉 Enjoy using soundnessup! For help, type 'soundnessup --help'${NC}" 
  
  # Source profile to update PATH
  source "$PROFILE" 2>/dev/null || true
  
  # Manually add the bin directory to PATH for current session
  export PATH="$PATH:$SOUNDNESS_BIN_DIR"
  
  # Install build tools if needed
  echo && echo -e "${BLUE}🔧 Installing required build tools...${NC}"
  if [ $(id -u) -eq 0 ]; then
      apt-get update && apt-get install -y build-essential pkg-config libssl-dev
  else
      echo -e "${RED}You need root privileges to install build tools.${NC}"
      echo -e "${YELLOW}Please run: sudo apt-get update && sudo apt-get install -y build-essential pkg-config libssl-dev${NC}"
      echo -e "${YELLOW}Then run this script again.${NC}"
      exit 1
  fi
  
  # Install Rust if not already installed
  if ! command -v rustc &> /dev/null; then
      echo -e "${BLUE}🔧 Installing Rust and Cargo...${NC}"
      curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
      source "$HOME/.cargo/env"
  else
      echo -e "${GREEN}✅ Rust is already installed${NC}"
  fi
  
  # Install Soundness CLI
  echo -e "${BLUE}🔧 Installing Soundness CLI...${NC}"
  # Use full path to soundnessup
  if [ -x "$BIN_PATH" ]; then
    "$BIN_PATH" install
  else
    echo -e "${RED}Error: Could not find soundnessup at $BIN_PATH${NC}"
    echo -e "${YELLOW}Trying alternative methods...${NC}"
    
    # Try to find soundnessup in the PATH
    if command -v soundnessup &> /dev/null; then
      soundnessup install
    else
      # Last resort: search the filesystem
      FOUND_SOUNDNESSUP=$(find "$HOME" -name "soundnessup" -type f -executable 2>/dev/null | head -1)
      if [ -n "$FOUND_SOUNDNESSUP" ]; then
        echo -e "${GREEN}Found soundnessup at $FOUND_SOUNDNESSUP${NC}"
        "$FOUND_SOUNDNESSUP" install
      else
        echo -e "${RED}❌ Could not find soundnessup. Installation failed.${NC}"
        exit 1
      fi
    fi
  fi
  
  # Wait for installation to complete
  echo -e "${YELLOW}Waiting for installation to complete...${NC}"
  sleep 5
  
  # Update PATH with cargo bin
  export PATH="$PATH:$HOME/.cargo/bin"
  
  # Search for soundness-cli in possible locations
  SOUNDNESS_CLI=""
  for path in "$HOME/.cargo/bin/soundness-cli" "/usr/local/bin/soundness-cli" "$SOUNDNESS_BIN_DIR/soundness-cli"; do
      if [ -x "$path" ]; then
          SOUNDNESS_CLI="$path"
          break
      fi
  done
  
  if [ -z "$SOUNDNESS_CLI" ]; then
      echo -e "${YELLOW}❌ Could not find soundness-cli. Searching filesystem...${NC}"
      FOUND_CLI=$(find "$HOME/.cargo/bin" "$HOME" "/usr/local/bin" -name "soundness-cli" -type f -executable 2>/dev/null | head -1)
      
      if [ -n "$FOUND_CLI" ]; then
          SOUNDNESS_CLI="$FOUND_CLI"
      else
          echo -e "${RED}❌ Could not find soundness-cli. Key generation will be skipped.${NC}"
          exit 1
      fi
  fi
  
  echo -e "${GREEN}✅ Found soundness-cli at: $SOUNDNESS_CLI${NC}"
  
  # Clean any existing keys before generating new ones
  echo -e "${BLUE}🧹 Cleaning any existing keys...${NC}"
  KEY_NAME="my-key"
  KEY_LOCATIONS=(
    "$HOME/.soundness/keys"
    "$HOME/.config/soundness/keys"
    "$HOME/.local/share/soundness/keys"
  )
  
  for loc in "${KEY_LOCATIONS[@]}"; do
    if [ -d "$loc" ]; then
      rm -f "$loc/$KEY_NAME.pub" 2>/dev/null || true
      rm -f "$loc/$KEY_NAME.key" 2>/dev/null || true
    fi
  done
  
  # Also check for any key with same name in common locations
  find "$HOME" -name "$KEY_NAME.pub" -o -name "$KEY_NAME.key" -delete 2>/dev/null || true
  
  # Generate a new key
  echo -e "${GREEN}🔑 Generating fresh key pair...${NC}"
  "$SOUNDNESS_CLI" generate-key --name "$KEY_NAME"
  
  echo && echo -e "${RED}🔐 IMPORTANT: Make sure to save your mnemonic phrase from above!${NC}"
  echo -e "${RED}It's your only way to recover your key if lost.${NC}"
  
  echo && echo -e "${GREEN}🌟 Done! Use your public key to register for testnet with: !access <your-public-key>${NC}"
}

# Function for deep uninstall including keys
uninstall_soundness() {
  echo -e "${BLUE}🧹 Uninstalling Soundness...${NC}"

  # Check if running as root
  if [ $(id -u) -eq 0 ]; then
    BASE_DIR="/root"
  else
    BASE_DIR="$HOME"
  fi

  # Store the correct profile file
  case $SHELL in
    */zsh)
      PROFILE=${ZDOTDIR-"$BASE_DIR"}/.zshenv
      ;;
    */bash)
      PROFILE=$BASE_DIR/.bashrc
      ;;
    */fish)
      PROFILE=$BASE_DIR/.config/fish/config.fish
      ;;
    */ash)
      PROFILE=$BASE_DIR/.profile
      ;;
    *)
      echo -e "${RED}Could not detect shell profile.${NC}"
      exit 1
  esac
  
  # Remove keys first
  echo -e "${BLUE}Removing keys...${NC}"
  KEY_NAME="my-key"
  KEY_LOCATIONS=(
    "$BASE_DIR/.soundness/keys"
    "$BASE_DIR/.config/soundness/keys"
    "$BASE_DIR/.local/share/soundness/keys"
  )
  
  for loc in "${KEY_LOCATIONS[@]}"; do
    if [ -d "$loc" ]; then
      echo -e "${YELLOW}Removing keys from $loc...${NC}"
      rm -f "$loc/$KEY_NAME.pub" 2>/dev/null || true
      rm -f "$loc/$KEY_NAME.key" 2>/dev/null || true
      rm -f "$loc"/*.pub 2>/dev/null || true
      rm -f "$loc"/*.key 2>/dev/null || true
    fi
  done
  
  # Also check for any key files in common locations
  echo -e "${YELLOW}Searching for other key files...${NC}"
  find "$BASE_DIR" -name "*.pub" -o -name "*.key" | grep -i "soundness" | xargs rm -f 2>/dev/null || true
  
  # Stop any running Soundness processes
  echo -e "${BLUE}Stopping any running Soundness processes...${NC}"
  pkill -f soundness 2>/dev/null || true
  
  # Remove Soundness binaries and directories
  echo -e "${BLUE}Removing Soundness directories and files...${NC}"
  rm -rf "$BASE_DIR/.soundness" 2>/dev/null || true
  rm -rf "$BASE_DIR/.config/soundness" 2>/dev/null || true
  rm -rf "$BASE_DIR/.local/share/soundness" 2>/dev/null || true
  
  # Remove any binaries from common locations
  echo -e "${BLUE}Removing Soundness binaries from common locations...${NC}"
  rm -f "/usr/local/bin/soundness-cli" 2>/dev/null || true
  rm -f "/usr/local/bin/soundness" 2>/dev/null || true
  rm -f "/usr/bin/soundness-cli" 2>/dev/null || true
  rm -f "/usr/bin/soundness" 2>/dev/null || true
  rm -f "/root/key_store.json" 2>/dev/null || true
  
  # Remove Soundness CLI from Cargo if installed
  if command -v cargo &> /dev/null; then
    echo -e "${BLUE}Removing Soundness CLI via Cargo...${NC}"
    cargo uninstall soundness-cli 2>/dev/null || true
  fi
  
  # Find and remove any remaining Soundness files
  echo -e "${BLUE}Finding and removing any remaining Soundness files...${NC}"
  find "$BASE_DIR" -name "*soundness*" -not -path "*rust*" -not -path "*cargo*" -exec rm -rf {} \; 2>/dev/null || true
  
  # Remove PATH entry from profile
  echo -e "${BLUE}Removing Soundness from PATH in $PROFILE...${NC}"
  if [ -f "$PROFILE" ]; then
    sed -i '/soundness/d' "$PROFILE"
  fi
  
  # Ask if user wants to remove Rust/Cargo as well
  echo -e "${YELLOW}Do you want to remove Rust and Cargo as well? (y/n):${NC}"
  read -p "" remove_rust
  if [[ "$remove_rust" =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Removing Rust and Cargo...${NC}"
    if command -v rustup &> /dev/null; then
      rustup self uninstall -y
    else
      rm -rf "$BASE_DIR/.cargo" "$BASE_DIR/.rustup" 2>/dev/null || true
    fi
  else
    echo -e "${BLUE}Keeping Rust and Cargo installed.${NC}"
  fi
  
  echo -e "${GREEN}✅ Soundness has been completely uninstalled.${NC}"
  echo -e "${YELLOW}To complete the uninstallation, restart your terminal or run: source $PROFILE${NC}"
}

# Show help
show_help() {
  echo -e "${BLUE}Soundness Installation/Uninstallation Script${NC}"
  echo -e "${YELLOW}Usage: $0 [option]${NC}"
  echo -e "${YELLOW}Options:${NC}"
  echo -e "${GREEN}  1, install     Install Soundness with CLI and generate keys${NC}"
  echo -e "${RED}  2, uninstall   Uninstall Soundness completely${NC}" 
  echo -e "${BLUE}  h, help        Show this help message${NC}"
}

# Process command line arguments
if [ $# -eq 0 ]; then
  # No arguments, show menu
  echo -e "${BLUE}Soundness Manager:${NC}"
  echo -e "${GREEN}1. Install Soundness${NC}"
  echo -e "${RED}2. Uninstall Soundness${NC}"
  read -p "Enter your choice (1 or 2): " choice
else
  # Use command line argument
  case "$1" in
    "1"|"install") choice=1 ;;
    "2"|"uninstall") choice=2 ;;
    "h"|"help") show_help; exit 0 ;;
    *) echo -e "${RED}Invalid option: $1${NC}"; show_help; exit 1 ;;
  esac
fi

# Execute selected option
case "$choice" in
  1)
    install_soundness
    ;;
  2)
    uninstall_soundness
    ;;
  *)
    echo -e "${RED}Invalid choice. Please select 1 or 2.${NC}"
    exit 1
    ;;
esac

exit 0
