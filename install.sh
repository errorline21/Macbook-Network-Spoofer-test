#!/bin/zsh
set -e

# ---------------- COLORS ----------------
RED=$'%{\e[31m%}'
GREEN=$'%{\e[32m%}'
YELLOW=$'%{\e[33m%}'
BLUE=$'%{\e[34m%}'
CYAN=$'%{\e[36m%}'
BOLD=$'%{\e[1m%}'
RESET=$'%{\e[0m%}'

plain_red="\033[31m"
plain_green="\033[32m"
plain_yellow="\033[33m"
plain_blue="\033[34m"
plain_cyan="\033[36m"
plain_bold="\033[1m"
plain_reset="\033[0m"

echo ""
echo "${plain_cyan}${plain_bold}================ MAC SPOOF HELPER INSTALLER ================${plain_reset}"
echo ""

# ---------------- SAFETY CHECKS ----------------
if [ "$(uname)" != "Darwin" ]; then
  echo "${plain_red}[ERROR]${plain_reset} This installer is for macOS only."
  exit 1
fi

CONFIG_DIR="$HOME/.macspoof"
SCRIPTS_DIR="$CONFIG_DIR/scripts"
CONF_FILE="$CONFIG_DIR/config.conf"

mkdir -p "$SCRIPTS_DIR"

echo "${plain_blue}[INFO]${plain_reset} Scanning network interfaces (enX)..."
echo ""

# List enX interfaces with MAC addresses
ifconfig | awk '
  BEGIN { OFS=""; }
  /^en[0-9]:/ {
    gsub(":", "", $1);
    iface=$1;
  }
  /ether/ && iface != "" {
    mac=toupper($2);
    printf("  - %s   (MAC: %s)\n", iface, mac);
    iface="";
  }
'

DEFAULT_IFACE=$(ifconfig | awk '/^en[0-9]:/ {gsub(":", "", $1); print $1; exit}')

if [ -z "$DEFAULT_IFACE" ]; then
  echo ""
  echo "${plain_red}[ERROR]${plain_reset} No enX interfaces found. Aborting."
  exit 1
fi

echo ""
echo "${plain_yellow}Note:${plain_reset} On modern macOS, Wi-Fi (en0) often ${plain_bold}cannot${plain_reset} be spoofed."
echo "      USB / Ethernet adapters (en3, en4, etc.) usually work better."
echo ""

read "IFACE?Enter the interface you want to use (default: $DEFAULT_IFACE): "
IFACE=${IFACE:-$DEFAULT_IFACE}

# Get current MAC for that interface
ORIGINAL_MAC=$(ifconfig "$IFACE" 2>/dev/null | awk '/ether/{print toupper($2); exit}')

if [ -z "$ORIGINAL_MAC" ]; then
  echo ""
  echo "${plain_red}[ERROR]${plain_reset} Could not read MAC for interface ${plain_bold}$IFACE${plain_reset}."
  exit 1
fi

echo ""
echo "${plain_blue}[INFO]${plain_reset} Detected current MAC on ${plain_bold}$IFACE${plain_reset}: ${plain_green}$ORIGINAL_MAC${plain_reset}"
echo ""

read "FIXED?Enter the FIXED custom MAC you want (format XX:XX:XX:XX:XX:XX): "
FIXED=$(echo "$FIXED" | tr '[:lower:]' '[:upper:]')

echo ""
echo "Interface      : $IFACE"
echo "Original MAC   : $ORIGINAL_MAC"
echo "Fixed spoof MAC: $FIXED"
echo ""
read "CONFIRM?Is this correct? (y/n): "

if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo ""
  echo "${plain_yellow}[ABORT]${plain_reset} User canceled. Nothing installed."
  exit 0
fi

echo ""
echo "${plain_blue}[TEST]${plain_reset} Checking if ${plain_bold}$IFACE${plain_reset} accepts MAC changes..."
echo "       You may be asked for your password."
echo ""

# Build a temporary random MAC starting with 02
RAND_HEX=$(openssl rand -hex 5 | tr '[:lower:]' '[:upper:]')  # 10 hex chars
TEMP_MAC="02:${RAND_HEX:0:2}:${RAND_HEX:2:2}:${RAND_HEX:4:2}:${RAND_HEX:6:2}:${RAND_HEX:8:2}"

SPOOFABLE="yes"

# Try changing MAC and reverting
if sudo ifconfig "$IFACE" up 2>/dev/null && \
   sudo ifconfig "$IFACE" ether "$TEMP_MAC" 2>/dev/null; then
  # Now revert
  sudo ifconfig "$IFACE" ether "$ORIGINAL_MAC" 2>/dev/null || true
  echo "${plain_green}[OK]${plain_reset} Interface ${plain_bold}$IFACE${plain_reset} appears spoofable."
else
  echo "${plain_yellow}[WARN]${plain_reset} macOS refused to change MAC on ${plain_bold}$IFACE${plain_reset}."
  echo "      Commands will still be installed, but MAC changes may fail at runtime."
  SPOOFABLE="no"
fi

# ---------------- WRITE CONFIG ----------------
cat > "$CONF_FILE" <<EOF
# Real MAC Spoof Helper Config
IFACE="$IFACE"
ORIGINAL_MAC="$ORIGINAL_MAC"
FIXED_MAC="$FIXED"
SPOOFABLE="$SPOOFABLE"
EOF

echo ""
echo "${plain_green}[OK]${plain_reset} Saved configuration to ${plain_bold}$CONF_FILE${plain_reset}"
echo ""

# ---------------- CREATE SCRIPTS ----------------

# macshow.sh
cat > "$SCRIPTS_DIR/macshow.sh" <<'EOF'
#!/bin/zsh

plain_red="\033[31m"
plain_green="\033[32m"
plain_yellow="\033[33m"
plain_cyan="\033[36m"
plain_bold="\033[1m"
plain_reset="\033[0m"

CONF_FILE="$HOME/.macspoof/config.conf"

if [ ! -f "$CONF_FILE" ]; then
  echo "${plain_red}[ERROR]${plain_reset} Config file not found at $CONF_FILE"
  exit 1
fi

source "$CONF_FILE"

CURRENT_MAC=$(ifconfig "$IFACE" 2>/dev/null | awk '/ether/{print toupper($2); exit}')

echo ""
echo "${plain_cyan}${plain_bold}==================== MAC STATUS ====================${plain_reset}"
echo ""
echo "  Interface        : $IFACE"
echo "  Current MAC      : ${plain_green}${CURRENT_MAC:-UNKNOWN}${plain_reset}"
echo "  Original MAC     : ${plain_green}${ORIGINAL_MAC:-UNKNOWN}${plain_reset}"
echo ""

if [ -z "$CURRENT_MAC" ]; then
  echo "  Status: ${plain_red}UNKNOWN → interface not found or down${plain_reset}"
elif [ "$CURRENT_MAC" = "$ORIGINAL_MAC" ]; then
  echo "  Status: ${plain_green}MATCH → Using ORIGINAL hardware MAC${plain_reset}"
else
  echo "  Status: ${plain_yellow}DIFFERENT → Using SPOOFED MAC${plain_reset}"
fi

echo ""
echo "====================================================="
echo ""
EOF
chmod +x "$SCRIPTS_DIR/macshow.sh"

# macfix.sh
cat > "$SCRIPTS_DIR/macfix.sh" <<'EOF'
#!/bin/zsh

plain_red="\033[31m"
plain_green="\033[32m"
plain_yellow="\033[33m"
plain_cyan="\033[36m"
plain_bold="\033[1m"
plain_reset="\033[0m"

CONF_FILE="$HOME/.macspoof/config.conf"

if [ ! -f "$CONF_FILE" ]; then
  echo "${plain_red}[ERROR]${plain_reset} Config file not found at $CONF_FILE"
  exit 1
fi

source "$CONF_FILE"

echo "${plain_cyan}Bringing $IFACE up...${plain_reset}"
sudo ifconfig "$IFACE" up 2>/dev/null || true

echo "${plain_cyan}Setting MAC on $IFACE to ${plain_bold}$FIXED_MAC${plain_reset} ..."
if sudo ifconfig "$IFACE" ether "$FIXED_MAC" 2>/dev/null; then
  "$HOME/.macspoof/scripts/macshow.sh"
else
  echo "${plain_red}[ERROR]${plain_reset} macOS refused to set MAC on $IFACE."
  echo "        This interface or OS version may block MAC spoofing."
fi
EOF
chmod +x "$SCRIPTS_DIR/macfix.sh"

# macrandom.sh
cat > "$SCRIPTS_DIR/macrandom.sh" <<'EOF'
#!/bin/zsh

plain_red="\033[31m"
plain_green="\033[32m"
plain_yellow="\033[33m"
plain_cyan="\033[36m"
plain_bold="\033[1m"
plain_reset="\033[0m"

CONF_FILE="$HOME/.macspoof/config.conf"

if [ ! -f "$CONF_FILE" ]; then
  echo "${plain_red}[ERROR]${plain_reset} Config file not found at $CONF_FILE"
  exit 1
fi

source "$CONF_FILE"

# Generate random locally-administered MAC (02:xx:xx:xx:xx:xx)
RAND_HEX=$(openssl rand -hex 5 | tr '[:lower:]' '[:upper:]')
RAND_MAC="02:${RAND_HEX:0:2}:${RAND_HEX:2:2}:${RAND_HEX:4:2}:${RAND_HEX:6:2}:${RAND_HEX:8:2}"

echo "${plain_cyan}Bringing $IFACE up...${plain_reset}"
sudo ifconfig "$IFACE" up 2>/dev/null || true

echo "${plain_cyan}Setting RANDOM MAC on $IFACE to ${plain_bold}$RAND_MAC${plain_reset} ..."
if sudo ifconfig "$IFACE" ether "$RAND_MAC" 2>/dev/null; then
  "$HOME/.macspoof/scripts/macshow.sh"
else
  echo "${plain_red}[ERROR]${plain_reset} macOS refused to set random MAC on $IFACE."
fi
EOF
chmod +x "$SCRIPTS_DIR/macrandom.sh"

# macrevert.sh
cat > "$SCRIPTS_DIR/macrevert.sh" <<'EOF'
#!/bin/zsh

plain_red="\033[31m"
plain_green="\033[32m"
plain_yellow="\033[33m"
plain_cyan="\033[36m"
plain_bold="\033[1m"
plain_reset="\033[0m"

CONF_FILE="$HOME/.macspoof/config.conf"

if [ ! -f "$CONF_FILE" ]; then
  echo "${plain_red}[ERROR]${plain_reset} Config file not found at $CONF_FILE"
  exit 1
fi

source "$CONF_FILE"

echo "${plain_cyan}Bringing $IFACE up...${plain_reset}"
sudo ifconfig "$IFACE" up 2>/dev/null || true

echo "${plain_cyan}Reverting MAC on $IFACE to ${plain_bold}$ORIGINAL_MAC${plain_reset} ..."
if sudo ifconfig "$IFACE" ether "$ORIGINAL_MAC" 2>/dev/null; then
  "$HOME/.macspoof/scripts/macshow.sh"
else
  echo "${plain_red}[ERROR]${plain_reset} macOS refused to revert MAC on $IFACE."
fi
EOF
chmod +x "$SCRIPTS_DIR/macrevert.sh"

# spoofhelp.sh
cat > "$SCRIPTS_DIR/spoofhelp.sh" <<'EOF'
#!/bin/zsh

plain_cyan="\033[36m"
plain_green="\033[32m"
plain_yellow="\033[33m"
plain_bold="\033[1m"
plain_reset="\033[0m"

CONF_FILE="$HOME/.macspoof/config.conf"
IFACE="unknown"

if [ -f "$CONF_FILE" ]; then
  source "$CONF_FILE"
fi

echo ""
echo "${plain_cyan}${plain_bold}==================== SPOOF HELPER ====================${plain_reset}"
echo ""
echo "  Active interface : ${plain_green}$IFACE${plain_reset}"
echo ""
echo "  ${plain_bold}Available commands:${plain_reset}"
echo ""
echo "    ${plain_green}macfix${plain_reset}       - Apply your fixed MAC from config"
echo "    ${plain_green}macrandom${plain_reset}    - Apply a random MAC (locally-administered)"
echo "    ${plain_green}macrevert${plain_reset}    - Restore original hardware MAC"
echo "    ${plain_green}macshow${plain_reset}      - Show current vs original MAC"
echo ""
echo "    ${plain_green}spoofhelp${plain_reset}    - Show this help menu"
echo "    ${plain_green}cleanspoofer${plain_reset} - Revert MAC (if possible) and remove all spoof helper files"
echo ""
echo "${plain_yellow}  Note:${plain_reset} Some macOS versions block Wi-Fi MAC changes."
echo "        USB / Ethernet adapters usually work better than en0."
echo ""
echo "=========================================================="
echo ""
EOF
chmod +x "$SCRIPTS_DIR/spoofhelp.sh"

# cleanspoofer.sh
cat > "$SCRIPTS_DIR/cleanspoofer.sh" <<'EOF'
#!/bin/zsh

plain_red="\033[31m"
plain_green="\033[32m"
plain_yellow="\033[33m"
plain_cyan="\033[36m"
plain_bold="\033[1m"
plain_reset="\033[0m"

CONFIG_DIR="$HOME/.macspoof"
SCRIPTS_DIR="$CONFIG_DIR/scripts"
CONF_FILE="$CONFIG_DIR/config.conf"

IFACE=""
ORIGINAL_MAC=""

if [ -f "$CONF_FILE" ]; then
  source "$CONF_FILE"
fi

echo ""
echo "${plain_cyan}${plain_bold}============ CLEAN SPOOFER UTILITY ============${plain_reset}"
echo ""
echo "  This will attempt to:"
echo "    - Revert MAC to original (if config is present)"
echo "    - Remove ${CONFIG_DIR}"
echo "    - Remove spoof helper aliases from ~/.zshrc"
echo ""
read "ANS?Are you sure you want to remove everything? (y/N): "

if [[ "$ANS" != "y" && "$ANS" != "Y" ]]; then
  echo ""
  echo "${plain_yellow}[ABORT]${plain_reset} Nothing was removed."
  echo ""
  exit 0
fi

# Try revert
if [ -n "$IFACE" ] && [ -n "$ORIGINAL_MAC" ]; then
  echo ""
  echo "${plain_cyan}Reverting MAC on $IFACE to $ORIGINAL_MAC (best effort)...${plain_reset}"
  sudo ifconfig "$IFACE" up 2>/dev/null || true
  sudo ifconfig "$IFACE" ether "$ORIGINAL_MAC" 2>/dev/null || true
fi

# Clean aliases from ~/.zshrc
if [ -f "$HOME/.zshrc" ]; then
  sed -i '' '/alias macfix=/d'       "$HOME/.zshrc" 2>/dev/null
  sed -i '' '/alias macrandom=/d'    "$HOME/.zshrc" 2>/dev/null
  sed -i '' '/alias macrevert=/d'    "$HOME/.zshrc" 2>/dev/null
  sed -i '' '/alias macshow=/d'      "$HOME/.zshrc" 2>/dev/null
  sed -i '' '/alias macShow=/d'      "$HOME/.zshrc" 2>/dev/null
  sed -i '' '/alias spoofhelp=/d'    "$HOME/.zshrc" 2>/dev/null
  sed -i '' '/alias cleanspoofer=/d' "$HOME/.zshrc" 2>/dev/null
  sed -i '' '/Real MAC Spoof Helper Commands/d' "$HOME/.zshrc" 2>/dev/null
fi

# Remove directory
rm -rf "$CONFIG_DIR"

echo ""
echo "${plain_green}[OK]${plain_reset} Spoof helper files removed."
echo "    Open a new terminal, or run: source ~/.zshrc"
echo ""
EOF
chmod +x "$SCRIPTS_DIR/cleanspoofer.sh"

# ---------------- ADD ALIASES ----------------
add_alias() {
  local LINE="$1"
  if [ -f "$HOME/.zshrc" ]; then
    if ! grep -Fqx "$LINE" "$HOME/.zshrc" 2>/dev/null; then
      echo "$LINE" >> "$HOME/.zshrc"
    fi
  else
    echo "$LINE" >> "$HOME/.zshrc"
  fi
}

echo "" >> "$HOME/.zshrc"
echo "# Real MAC Spoof Helper Commands" >> "$HOME/.zshrc"
add_alias "alias macfix='$SCRIPTS_DIR/macfix.sh'"
add_alias "alias macrandom='$SCRIPTS_DIR/macrandom.sh'"
add_alias "alias macrevert='$SCRIPTS_DIR/macrevert.sh'"
add_alias "alias macshow='$SCRIPTS_DIR/macshow.sh'"
add_alias "alias macShow='$SCRIPTS_DIR/macshow.sh'"
add_alias "alias spoofhelp='$SCRIPTS_DIR/spoofhelp.sh'"
add_alias "alias cleanspoofer='$SCRIPTS_DIR/cleanspoofer.sh'"

echo ""
echo "${plain_green}================ INSTALL COMPLETE ================${plain_reset}"
echo "Now run:"
echo "  ${plain_bold}source ~/.zshrc${plain_reset}"
echo ""
echo "Then try:"
echo "  ${plain_green}spoofhelp${plain_reset}"
echo ""
echo "If you ever want to uninstall:"
echo "  ${plain_green}cleanspoofer${plain_reset}"
echo "=================================================="
echo ""
