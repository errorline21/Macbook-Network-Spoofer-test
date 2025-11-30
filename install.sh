#!/bin/zsh

set -e

CONFIG_DIR="$HOME/.macspoof"
SCRIPTS_DIR="$CONFIG_DIR/scripts"
CONFIG_FILE="$CONFIG_DIR/config"

# ---------- Basic colors ----------
RESET="\033[0m"
BOLD="\033[1m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"



# ---------- Gradient credit for Dimension53 ----------
# ---------- Simple rainbow credit (each letter colored) ----------
render_discord_credit() {
  local R1="\033[31m"   # red
  local R2="\033[33m"   # yellow
  local R3="\033[32m"   # green
  local R4="\033[36m"   # cyan
  local R5="\033[34m"   # blue
  local R6="\033[35m"   # magenta
  local RESET="\033[0m"

  # D i m e n s i o n 5 3
  printf "        Created by: "
  printf "%bD%b" "$R1" "$RESET"
  printf "%bi%b" "$R2" "$RESET"
  printf "%bm%b" "$R3" "$RESET"
  printf "%be%b" "$R4" "$RESET"
  printf "%bn%b" "$R5" "$RESET"
  printf "%bs%b" "$R6" "$RESET"
  printf "%bi%b" "$R1" "$RESET"
  printf "%bo%b" "$R2" "$RESET"
  printf "%bn%b" "$R3" "$RESET"
  printf "%b5%b" "$R4" "$RESET"
  printf "%b3%b\n" "$R5" "$RESET"

  printf "        (Discord: dimension53)\n"
}




# ---------- Header ----------
print_header() {
  printf "%b\n" "${CYAN}================= MAC SPOOF HELPER INSTALLER =================${RESET}"
  printf "\n"
  render_discord_credit
  printf "\n%b\n" "${CYAN}==============================================================${RESET}"
  printf "\n"
}

# Detect if interface is Wi-Fi (en0)
is_wifi_iface() {
    [[ "$1" == "en0" ]]
}




# ---------- Get MAC for interface ----------
get_mac_for_iface() {
  local iface="$1"
  ifconfig "$iface" 2>/dev/null | awk '/ether/{print $2; exit}'
}

# ---------- Prompt for interface and MAC ----------
prompt_for_config() {
  echo "${CYAN}[INFO] Scanning network interfaces (enX)...${RESET}"
  echo

  # List en* style interfaces
  for dev in $(ifconfig -l | tr ' ' '\n' | grep '^en'); do
    local mac="$(get_mac_for_iface "$dev")"
    [[ -n "$mac" ]] && printf "  - %s  (MAC: %s)\n" "$dev" "$mac"
  done

  echo
  echo "Note: ${YELLOW}en0 (Wi-Fi) may NOT spoof on modern macOS.${RESET}"
  echo "      USB / Ethernet (e.g., en3, en4…) usually work better."
  echo

  local default_iface="en3"
  printf "\nEnter the interface you want to use (default: %s): " "$default_iface"
  read -r IFACE
  [[ -z "$IFACE" ]] && IFACE="$default_iface"

  local current_mac
  current_mac="$(get_mac_for_iface "$IFACE")"

  if [[ -z "$current_mac" ]]; then
    printf "%b[ERROR]%b Could not read MAC for interface %s.\n" "$RED" "$RESET" "$IFACE"
    exit 1
  fi

  current_mac_upper="${(U)current_mac}"

  echo
  printf "Detected current MAC on %s: %s\n" "$IFACE" "$current_mac_upper"
  echo
  printf "Enter the FIXED custom MAC you want (format XX:XX:XX:XX:XX:XX): "
  read -r fixed_mac_raw

  # Normalize
  fixed_mac_upper="${(U)fixed_mac_raw}"

  echo
  echo "Interface      : $IFACE"
  echo "Original MAC   : $current_mac_upper"
  echo "Fixed spoof MAC: $fixed_mac_upper"
  echo
  printf "Is this correct? (y/n): "
  read -r confirm

  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
  fi

  IFACE_CHOSEN="$IFACE"
  ORIGINAL_MAC="$current_mac_upper"
  FIXED_MAC="$fixed_mac_upper"
}

# ---------- Write config ----------
write_config() {
  mkdir -p "$CONFIG_DIR"
  cat > "$CONFIG_FILE" <<EOF
# macspoof config
IFACE="$IFACE_CHOSEN"
ORIGINAL_MAC="$ORIGINAL_MAC"
FIXED_MAC="$FIXED_MAC"
EOF

  printf "\n%b[OK]%b Config saved to: %s\n" "$GREEN" "$RESET" "$CONFIG_FILE"
}

# ---------- Generate helper scripts ----------
write_scripts() {
  mkdir -p "$SCRIPTS_DIR"

  # Common header used by all helper scripts
  local COMMON='#!/bin/zsh
CONFIG_FILE="$HOME/.macspoof/config"
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "[ERROR] Config not found at $CONFIG_FILE"
  exit 1
fi
source "$CONFIG_FILE"
if [[ -z "$IFACE" || -z "$ORIGINAL_MAC" || -z "$FIXED_MAC" ]]; then
  echo "[ERROR] Config missing IFACE/ORIGINAL_MAC/FIXED_MAC"
  exit 1
fi
CURRENT_MAC_RAW=$(ifconfig "$IFACE" 2>/dev/null | awk '\''/ether/{print $2; exit}'\'')
CURRENT_MAC=${CURRENT_MAC_RAW:u}
ORIG=${ORIGINAL_MAC:u}
FIX=${FIXED_MAC:u}
RESET="\033[0m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RED="\033[31m"
'

# SetLoadedAddress (apply fixed MAC)
  cat > "$SCRIPTS_DIR/SetLoadedAddress.sh" <<'EOF'
#!/bin/zsh
CONFIG_FILE="$HOME/.macspoof/config"
source "$CONFIG_FILE"

RESET="\033[0m"
YELLOW="\033[33m"
GREEN="\033[32m"
RED="\033[31m"
CYAN="\033[36m"

echo "Bringing $IFACE up..."
sudo ifconfig "$IFACE" up 2>/dev/null || true

echo "Attempting to set MAC on $IFACE to $FIX ..."
if ! sudo ifconfig "$IFACE" ether "$FIX" 2>/dev/null; then
    if [[ "$IFACE" == "en0" ]]; then
        echo "${YELLOW}[WARNING] macOS blocked Wi-Fi MAC spoofing on en0.${RESET}"
        echo "         Apple prevents changing the Wi-Fi adapter MAC."
    else
        echo "${RED}[ERROR] Failed to modify MAC on $IFACE${RESET}"
    fi
fi

"$HOME/.macspoof/scripts/ShowMacAddress.sh"
EOF



  # SetLoadedAddress (apply fixed MAC)
  cat > "$SCRIPTS_DIR/SetLoadedAddress.sh" <<EOF
$COMMON
echo "Bringing \$IFACE up..."
sudo ifconfig "\$IFACE" up 2>/dev/null || true
echo "Setting MAC on \$IFACE to \$FIX ..."
sudo ifconfig "\$IFACE" ether "\$FIX" || {
  echo "[ERROR] Failed to set MAC on \$IFACE"
  exit 1
}
"\$HOME/.macspoof/scripts/ShowMacAddress.sh"
EOF

  # RandomizeMacAddress (random, locally-administered MAC)
  cat > "$SCRIPTS_DIR/RandomizeMacAddress.sh" <<'EOF'
#!/bin/zsh
CONFIG_FILE="$HOME/.macspoof/config"
source "$CONFIG_FILE"

RESET="\033[0m"
YELLOW="\033[33m"

rand() { printf "%02X" $(( RANDOM % 256 )); }

b1=$(rand); b2=$(rand); b3=$(rand); b4=$(rand); b5=$(rand); b6=$(rand)

first_dec=$(( 0x$b1 ))
first_dec=$(( (first_dec | 0x02) & 0xFE ))
printf -v b1 "%02X" "$first_dec"

RAND_MAC="$b1:$b2:$b3:$b4:$b5:$b6"

echo "Bringing $IFACE up..."
sudo ifconfig "$IFACE" up 2>/dev/null || true

echo "Setting RANDOM MAC on $IFACE to $RAND_MAC ..."
if ! sudo ifconfig "$IFACE" ether "$RAND_MAC" 2>/dev/null; then
    if [[ "$IFACE" == "en0" ]]; then
        echo "${YELLOW}[WARNING] macOS blocked Wi-Fi MAC spoofing on en0.${RESET}"
        echo "         Wi-Fi MAC cannot be randomized on modern macOS."
    else
        echo "[ERROR] Failed to set random MAC on $IFACE"
    fi
fi

"$HOME/.macspoof/scripts/ShowMacAddress.sh"
EOF


  # RevertMacAddress (restore hardware MAC)
  cat > "$SCRIPTS_DIR/RevertMacAddress.sh" <<'EOF'
#!/bin/zsh
CONFIG_FILE="$HOME/.macspoof/config"
source "$CONFIG_FILE"

RESET="\033[0m"
YELLOW="\033[33m"
RED="\033[31m"

echo "Bringing $IFACE up..."
sudo ifconfig "$IFACE" up 2>/dev/null || true

echo "Reverting MAC on $IFACE to $ORIGINAL_MAC ..."
if ! sudo ifconfig "$IFACE" ether "$ORIGINAL_MAC" 2>/dev/null; then
    if [[ "$IFACE" == "en0" ]]; then
        echo "${YELLOW}[WARNING] macOS blocked Wi-Fi MAC restore on en0.${RESET}"
        echo "         This adapter always forces its true hardware MAC."
    else
        echo "${RED}[ERROR] Could not revert MAC on $IFACE${RESET}"
    fi
fi

"$HOME/.macspoof/scripts/ShowMacAddress.sh"
EOF


  # spoofhelp (pretty UI)
  cat > "$SCRIPTS_DIR/spoofhelp.sh" <<'EOF'
#!/bin/zsh
CONFIG_FILE="$HOME/.macspoof/config"
if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
fi
RESET="\033[0m"
CYAN="\033[36m"
GREEN="\033[32m"
MAGENTA="\033[35m"
YELLOW="\033[33m"

echo
printf "%b\n" "${CYAN}==================== SPOOF HELPER =====================${RESET}"
echo
printf "  Active interface : %b%s%b\n" "$GREEN" "${IFACE:-unknown}" "$RESET"
echo
printf "%b" "${MAGENTA}  Created by: ${RESET}"
echo "Dimension53 (Discord: dimension53)"
echo
printf "%b\n" "${CYAN}  Commands:${RESET}"
echo
printf "    %bSetLoadedAddress%b     - Apply your fixed MAC\n" "$GREEN" "$RESET"
printf "    %bRandomizeMacAddress%b  - Apply random locally-administered MAC\n" "$GREEN" "$RESET"
printf "    %bRevertMacAddress%b     - Restore hardware MAC\n" "$GREEN" "$RESET"
printf "    %bShowMacAddress%b       - Show current vs original MAC\n" "$GREEN" "$RESET"
echo
printf "    %bspoofhelp%b            - Show this help menu\n" "$YELLOW" "$RESET"
printf "    %bcleanspoofer%b         - Remove all spoof helper files\n" "$YELLOW" "$RESET"
echo
echo "  Note: Some macOS versions block Wi-Fi MAC changes."
echo "        USB / Ethernet adapters usually work better than en0."
echo
printf "%b\n" "${CYAN}==========================================================${RESET}"
echo
EOF

  # cleanspoofer
  cat > "$SCRIPTS_DIR/cleanspoofer.sh" <<'EOF'
#!/bin/zsh
CONFIG_DIR="$HOME/.macspoof"
CONFIG_FILE="$CONFIG_DIR/config"
RESET="\033[0m"
CYAN="\033[36m"
YELLOW="\033[33m"
GREEN="\033[32m"
RED="\033[31m"

echo
printf "%b\n" "${CYAN}============ CLEAN SPOOFER UTILITY ============${RESET}"
echo
echo "  This will attempt to:"
echo "    - Revert MAC to original (if config exists)"
echo "    - Remove ~/.macspoof"
echo "    - Remove spoof helper aliases from ~/.zshrc"
echo
printf "Are you sure? (y/N): "
read -r ans

if [[ ! "$ans" =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

IFACE=""
ORIGINAL_MAC=""

if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
fi

if [[ -n "$IFACE" && -n "$ORIGINAL_MAC" ]]; then
  echo "Reverting MAC on $IFACE to $ORIGINAL_MAC (best effort)..."
  sudo ifconfig "$IFACE" up 2>/dev/null || true
  sudo ifconfig "$IFACE" ether "$ORIGINAL_MAC" 2>/dev/null || true
fi

# Remove block from ~/.zshrc
if [[ -f "$HOME/.zshrc" ]]; then
  tmpfile="$HOME/.zshrc.macspoof-cleaned.$$"
  sed '/# >>> Mac Spoof Helper (macspoof) >>>/,/# <<< Mac Spoof Helper (macspoof) <<</d' "$HOME/.zshrc" > "$tmpfile" && mv "$tmpfile" "$HOME/.zshrc"
  sed '/# >>> Mac Spoof Helper Prompt (macspoof) >>>/,/# <<< Mac Spoof Helper Prompt (macspoof) <<</d' "$HOME/.zshrc" > "$tmpfile" && mv "$tmpfile" "$HOME/.zshrc"
fi

rm -rf "$CONFIG_DIR"

echo
printf "%b[OK]%b Spoof helper removed.\n" "$GREEN" "$RESET"
echo "Run: source ~/.zshrc"
echo
EOF

  chmod +x "$SCRIPTS_DIR"/*.sh
}

# ---------- Install aliases and Minecraft-style prompt into ~/.zshrc ----------
install_zshrc_block() {
  # Remove any previous helper block
  if [[ -f "$HOME/.zshrc" ]]; then
    sed -i '' '/# >>> Mac Spoof Helper (macspoof) >>>/,/# <<< Mac Spoof Helper (macspoof) <<</d' "$HOME/.zshrc"
    sed -i '' '/# >>> Mac Spoof Helper Prompt (macspoof) >>>/,/# <<< Mac Spoof Helper Prompt (macspoof) <<</d' "$HOME/.zshrc"
  fi

  {
    echo '# >>> Mac Spoof Helper (macspoof) >>>'
    echo "alias SetLoadedAddress=\"$SCRIPTS_DIR/SetLoadedAddress.sh\""
    echo "alias RandomizeMacAddress=\"$SCRIPTS_DIR/RandomizeMacAddress.sh\""
    echo "alias RevertMacAddress=\"$SCRIPTS_DIR/RevertMacAddress.sh\""
    echo "alias ShowMacAddress=\"$SCRIPTS_DIR/ShowMacAddress.sh\""
    echo "alias spoofhelp=\"$SCRIPTS_DIR/spoofhelp.sh\""
    echo "alias cleanspoofer=\"$SCRIPTS_DIR/cleanspoofer.sh\""
    echo '# <<< Mac Spoof Helper (macspoof) <<<'
    echo
    echo '# >>> Mac Spoof Helper Prompt (macspoof) >>>'
    echo 'autoload -U colors && colors'
    echo 'setopt PROMPT_SUBST'
    # Minecraft-style-ish prompt: green path, yellow user@host
    echo "PROMPT=\$'%F{green}⛏ %F{yellow}%n@%m %F{green}%~%f\n%F{green}➜ %f'"
    echo '# <<< Mac Spoof Helper Prompt (macspoof) <<<'
  } >> "$HOME/.zshrc"
}

# ---------- MAIN ----------
print_header
prompt_for_config
write_config
write_scripts
install_zshrc_block

echo
printf "%b[OK]%b Installation complete!\n" "$GREEN" "$RESET"
echo "Run the following:"
echo
echo "  source ~/.zshrc"
echo "  spoofhelp"
echo
printf "%b\n" "${CYAN}==============================================================${RESET}"
