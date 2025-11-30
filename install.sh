#!/bin/zsh
set -e

MACSPOOF_DIR="$HOME/macspoof"
CONFIG_FILE="$MACSPOOF_DIR/config"
COMMON_FILE="$MACSPOOF_DIR/net-common.sh"

# -------------------------------------------------------------------
#  Colors (basic, always safe — scripts detect if they can use them)
# -------------------------------------------------------------------
C_RESET=$'\033[0m'
C_GREEN=$'\033[32m'
C_CYAN=$'\033[36m'
C_MAGENTA=$'\033[35m'
C_YELLOW=$'\033[33m'
C_RED=$'\033[31m'
C_BOLD=$'\033[1m'

echo ""
echo "${C_CYAN}================ MAC SPOOF HELPER INSTALLER ================${C_RESET}"
echo ""

# -------------------------------------------------------------------
#  1. Sanity checks
# -------------------------------------------------------------------
if [[ "$(uname)" != "Darwin" ]]; then
  echo "${C_RED}[ERROR]${C_RESET} This installer is for macOS only."
  exit 1
fi

# -------------------------------------------------------------------
#  2. Find enX interfaces + current MACs
# -------------------------------------------------------------------
echo "${C_YELLOW}[INFO]${C_RESET} Scanning network interfaces (enX)..."
echo ""

# Gather en* devices from networksetup
INTERFACES=()
while IFS= read -r line; do
  INTERFACES+=("$line")
done < <(networksetup -listallhardwareports 2>/dev/null | awk '/Device: en/{print $2}')

if [[ ${#INTERFACES[@]} -eq 0 ]]; then
  echo "${C_RED}[ERROR]${C_RESET} No enX interfaces found. Cannot continue."
  exit 1
fi

for IF in "${INTERFACES[@]}"; do
  MAC=$(ifconfig "$IF" 2>/dev/null | awk '/ether /{print $2}' | head -n1 | tr '[:lower:]' '[:upper:]')
  [[ -z "$MAC" ]] && MAC="(unknown)"
  echo "  - ${C_GREEN}${IF}${C_RESET}   (MAC: ${MAC})"
done

echo ""
echo "Note: On modern macOS, Wi-Fi (${C_GREEN}en0${C_RESET}) often cannot be spoofed."
echo "      USB / Ethernet adapters (${C_GREEN}en3${C_RESET}, ${C_GREEN}en4${C_RESET}, etc.) usually work better."
echo ""

DEFAULT_IF="${INTERFACES[1]}"

# -------------------------------------------------------------------
#  3. Prompt for interface + fixed MAC
# -------------------------------------------------------------------
read "IFACE?Enter the interface you want to use (default: ${DEFAULT_IF}): "
IFACE="${IFACE:-$DEFAULT_IF}"

if ! printf '%s\n' "${INTERFACES[@]}" | grep -qx "$IFACE"; then
  echo "${C_RED}[ERROR]${C_RESET} '$IFACE' is not a valid enX interface on this system."
  exit 1
fi

ORIGINAL_MAC=$(ifconfig "$IFACE" 2>/dev/null | awk '/ether /{print $2}' | head -n1 | tr '[:lower:]' '[:upper:]')
if [[ -z "$ORIGINAL_MAC" ]]; then
  echo "${C_RED}[ERROR]${C_RESET} Could not read MAC for interface ${IFACE}."
  exit 1
fi

echo ""
echo "Detected current MAC on ${C_GREEN}${IFACE}${C_RESET}: ${C_BOLD}${ORIGINAL_MAC}${C_RESET}"
echo ""
read "FIXED_MAC?Enter the FIXED custom MAC you want (format XX:XX:XX:XX:XX:XX): "
FIXED_MAC="$(echo "$FIXED_MAC" | tr '[:lower:]' '[:upper:]')"

echo ""
echo "Interface      : ${C_GREEN}${IFACE}${C_RESET}"
echo "Original MAC   : ${C_YELLOW}${ORIGINAL_MAC}${C_RESET}"
echo "Fixed spoof MAC: ${C_MAGENTA}${FIXED_MAC}${C_RESET}"
echo ""
read "CONFIRM?Is this correct? (y/n): "

if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo "${C_RED}Canceled.${C_RESET}"
  exit 1
fi

# -------------------------------------------------------------------
#  4. Prepare directory + config
# -------------------------------------------------------------------
mkdir -p "$MACSPOOF_DIR"

cat > "$CONFIG_FILE" <<EOF
# Mac Spoof Helper config
IFACE="$IFACE"
ORIGINAL_MAC="$ORIGINAL_MAC"
FIXED_MAC="$FIXED_MAC"
EOF

# -------------------------------------------------------------------
#  5. Common functions file (shared by all net: commands)
# -------------------------------------------------------------------
cat > "$COMMON_FILE" <<'EOF'
#!/bin/zsh

MACSPOOF_DIR="$HOME/macspoof"
CONFIG_FILE="$MACSPOOF_DIR/config"

# Basic colors (scripts will use them only if terminal supports)
C_RESET=$'\033[0m'
C_GREEN=$'\033[32m'
C_CYAN=$'\033[36m'
C_MAGENTA=$'\033[35m'
C_YELLOW=$'\033[33m'
C_RED=$'\033[31m'
C_BOLD=$'\033[1m'

# Detect color support
supports_color() {
  [[ -t 1 ]] || return 1
  command -v tput >/dev/null 2>&1 || return 1
  local n
  n=$(tput colors 2>/dev/null || echo 0)
  [[ "$n" -ge 8 ]]
}

# Rainbow printer (per-character color; non-animated)
rainbow_text() {
  local text="$1"
  if ! supports_color; then
    printf "%s\n" "$text"
    return
  fi

  local colors=(31 33 32 36 34 35) # red, yellow, green, cyan, blue, magenta
  local i=0 c ch code
  local len=${#text}

  for (( c=1; c<=len; c++ )); do
    ch=${text[$c]}
    code=${colors[$(( (i % ${#colors[@]}) + 1 ))]}
    printf "\033[%sm%s\033[0m" "$code" "$ch"
    ((i++))
  done
  printf "\n"
}

load_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "${C_RED}[ERROR]${C_RESET} Config file not found at $CONFIG_FILE"
    echo "Run the installer again to setup Mac Spoof Helper."
    return 1
  fi
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
  if [[ -z "$IFACE" || -z "$ORIGINAL_MAC" ]]; then
    echo "${C_RED}[ERROR]${C_RESET} Config file is missing required values."
    return 1
  fi
  return 0
}

print_status() {
  load_config || return 1
  local current
  current=$(ifconfig "$IFACE" 2>/dev/null | awk '/ether /{print $2}' | head -n1 | tr '[:lower:]' '[:upper:]')
  [[ -z "$current" ]] && current="(unknown)"

  echo ""
  echo "${C_CYAN}==================== MAC STATUS ====================${C_RESET}"
  echo ""
  echo "  Interface        : ${C_GREEN}${IFACE}${C_RESET}"
  echo "  Current MAC      : ${C_BOLD}${current}${C_RESET}"
  echo "  Original MAC     : ${C_YELLOW}${ORIGINAL_MAC}${C_RESET}"
  echo ""

  if [[ "$current" == "$ORIGINAL_MAC" ]]; then
    echo "  Status: ${C_GREEN}MATCH → Using ORIGINAL hardware MAC${C_RESET}"
  else
    echo "  Status: ${C_MAGENTA}DIFFERENT → Using SPOOFED MAC${C_RESET}"
  fi

  echo ""
  echo "${C_CYAN}=====================================================${C_RESET}"
  echo ""
}

# Generate random locally-administered unicast MAC
generate_random_mac() {
  # 6 random bytes
  local raw first rest
  raw=$(hexdump -n6 -v -e '/1 "%02X:"' /dev/urandom 2>/dev/null | sed 's/:$//')
  first=${raw%%:*}
  rest=${raw#*:}
  # Force first byte to 02 (locally administered, unicast)
  first="02"
  echo "${first}:${rest}"
}

EOF

chmod +x "$COMMON_FILE"

# -------------------------------------------------------------------
#  6. Create command scripts
# -------------------------------------------------------------------

# net-set.sh  → net:set
cat > "$MACSPOOF_DIR/net-set.sh" <<'EOF'
#!/bin/zsh
set -e
source "$HOME/macspoof/net-common.sh"

if ! load_config; then exit 1; fi

echo "Bringing ${C_GREEN}${IFACE}${C_RESET} up..."
sudo ifconfig "$IFACE" up || true

echo "Setting MAC on ${C_GREEN}${IFACE}${C_RESET} to ${C_MAGENTA}${FIXED_MAC}${C_RESET} ..."
sudo ifconfig "$IFACE" ether "$FIXED_MAC"

print_status
EOF
chmod +x "$MACSPOOF_DIR/net-set.sh"

# net-random.sh  → net:random
cat > "$MACSPOOF_DIR/net-random.sh" <<'EOF'
#!/bin/zsh
set -e
source "$HOME/macspoof/net-common.sh"

if ! load_config; then exit 1; fi

RANDOM_MAC=$(generate_random_mac)

echo "Bringing ${C_GREEN}${IFACE}${C_RESET} up..."
sudo ifconfig "$IFACE" up || true

echo "Setting RANDOM MAC on ${C_GREEN}${IFACE}${C_RESET} to ${C_MAGENTA}${RANDOM_MAC}${C_RESET} ..."
sudo ifconfig "$IFACE" ether "$RANDOM_MAC"

print_status
EOF
chmod +x "$MACSPOOF_DIR/net-random.sh"

# net-revert.sh  → net:revert
cat > "$MACSPOOF_DIR/net-revert.sh" <<'EOF'
#!/bin/zsh
set -e
source "$HOME/macspoof/net-common.sh"

if ! load_config; then exit 1; fi

echo "Bringing ${C_GREEN}${IFACE}${C_RESET} up..."
sudo ifconfig "$IFACE" up || true

echo "Reverting MAC on ${C_GREEN}${IFACE}${C_RESET} to ${C_YELLOW}${ORIGINAL_MAC}${C_RESET} ..."
sudo ifconfig "$IFACE" ether "$ORIGINAL_MAC"

print_status
EOF
chmod +x "$MACSPOOF_DIR/net-revert.sh"

# net-show.sh  → net:show
cat > "$MACSPOOF_DIR/net-show.sh" <<'EOF'
#!/bin/zsh
set -e
source "$HOME/macspoof/net-common.sh"
print_status
EOF
chmod +x "$MACSPOOF_DIR/net-show.sh"

# net-config.sh  → net:config (safest: only edits config, no MAC changes)
cat > "$MACSPOOF_DIR/net-config.sh" <<'EOF'
#!/bin/zsh
set -e
source "$HOME/macspoof/net-common.sh"

echo ""
echo "${C_CYAN}======== Reconfigure Mac Spoof Helper (net:config) ========${C_RESET}"
echo ""

# List interfaces again
INTERFACES=()
while IFS= read -r line; do
  INTERFACES+=("$line")
done < <(networksetup -listallhardwareports 2>/dev/null | awk '/Device: en/{print $2}')

if [[ ${#INTERFACES[@]} -eq 0 ]]; then
  echo "${C_RED}[ERROR]${C_RESET} No enX interfaces found."
  exit 1
fi

for IF in "${INTERFACES[@]}"; do
  MAC=$(ifconfig "$IF" 2>/dev/null | awk '/ether /{print $2}' | head -n1 | tr '[:lower:]' '[:upper:]')
  [[ -z "$MAC" ]] && MAC="(unknown)"
  echo "  - ${C_GREEN}${IF}${C_RESET}   (MAC: ${MAC})"
done

DEFAULT_IF="${INTERFACES[1]}"
echo ""
read "NEW_IF?Enter interface to use (default: ${DEFAULT_IF}): "
NEW_IF="${NEW_IF:-$DEFAULT_IF}"

if ! printf '%s\n' "${INTERFACES[@]}" | grep -qx "$NEW_IF"; then
  echo "${C_RED}[ERROR]${C_RESET} '$NEW_IF' is not a valid enX interface."
  exit 1
fi

NEW_ORIG=$(ifconfig "$NEW_IF" 2>/dev/null | awk '/ether /{print $2}' | head -n1 | tr '[:lower:]' '[:upper:]')
if [[ -z "$NEW_ORIG" ]]; then
  echo "${C_RED}[ERROR]${C_RESET} Could not read MAC for ${NEW_IF}."
  exit 1
fi

echo ""
echo "Detected current MAC on ${C_GREEN}${NEW_IF}${C_RESET}: ${C_BOLD}${NEW_ORIG}${C_RESET}"
echo ""
read "NEW_FIXED?Enter NEW fixed MAC (XX:XX:XX:XX:XX:XX): "
NEW_FIXED="$(echo "$NEW_FIXED" | tr '[:lower:]' '[:upper:]')"

echo ""
echo "New Interface  : ${C_GREEN}${NEW_IF}${C_RESET}"
echo "New Original   : ${C_YELLOW}${NEW_ORIG}${C_RESET}"
echo "New Fixed MAC  : ${C_MAGENTA}${NEW_FIXED}${C_RESET}"
echo ""
read "OKAY?Save this to config? (y/n): "

if [[ "$OKAY" != "y" && "$OKAY" != "Y" ]]; then
  echo "${C_RED}Canceled.${C_RESET}"
  exit 1
fi

cat > "$CONFIG_FILE" <<EOF2
# Mac Spoof Helper config
IFACE="$NEW_IF"
ORIGINAL_MAC="$NEW_ORIG"
FIXED_MAC="$NEW_FIXED"
EOF2

echo ""
echo "${C_GREEN}[OK]${C_RESET} Config updated."
echo "Run: net:set   (or)  net:show"
echo ""
EOF
chmod +x "$MACSPOOF_DIR/net-config.sh"

# net-help.sh  → net:help / spoofhelp
cat > "$MACSPOOF_DIR/net-help.sh" <<'EOF'
#!/bin/zsh
set -e
source "$HOME/macspoof/net-common.sh"

echo ""
echo "${C_CYAN}==================== MAC SPOOF COMMANDS ====================${C_RESET}"
echo ""
echo "  ${C_GREEN}net:set${C_RESET}       - Apply your fixed spoof MAC"
echo "  ${C_GREEN}net:random${C_RESET}    - Apply a random spoof MAC"
echo "  ${C_GREEN}net:revert${C_RESET}    - Restore original hardware MAC"
echo "  ${C_GREEN}net:show${C_RESET}      - Show current vs original MAC"
echo "  ${C_GREEN}net:config${C_RESET}    - Reconfigure interface + fixed MAC (no changes applied yet)"
echo "  ${C_GREEN}net:clean${C_RESET}     - Revert MAC and uninstall Mac Spoof Helper"
echo ""
echo "  ${C_GREEN}net:help${C_RESET}      - Show this help menu"
echo "  ${C_GREEN}spoofhelp${C_RESET}     - Same as net:help (shortcut)"
echo ""
echo "${C_CYAN}=============================================================${C_RESET}"
echo ""

echo "  Credits:"
echo -n "    "
rainbow_text "Discord: dimension53"
echo ""
EOF
chmod +x "$MACSPOOF_DIR/net-help.sh"

# net-clean.sh  → net:clean
cat > "$MACSPOOF_DIR/net-clean.sh" <<'EOF'
#!/bin/zsh
set -e
source "$HOME/macspoof/net-common.sh"

echo ""
echo "${C_RED}WARNING:${C_RESET} This will:"
echo "  - Revert MAC (if config exists)"
echo "  - Remove all net:* / spoofhelp commands"
echo "  - Delete $MACSPOOF_DIR and config"
echo ""
read "ANS?Are you sure you want to continue? (y/n): "

if [[ "$ANS" != "y" && "$ANS" != "Y" ]]; then
  echo "${C_YELLOW}Canceled. Nothing removed.${C_RESET}"
  exit 0
fi

# Try to revert MAC if we still have config
if load_config; then
  echo ""
  echo "Reverting MAC on ${C_GREEN}${IFACE}${C_RESET} to ${C_YELLOW}${ORIGINAL_MAC}${C_RESET} ..."
  sudo ifconfig "$IFACE" up || true
  sudo ifconfig "$IFACE" ether "$ORIGINAL_MAC" || true
fi

# Remove alias block from ~/.zshrc
if [[ -f "$HOME/.zshrc" ]]; then
  sed -i '' '/# >>> Mac Spoof Helper (macspoof) >>>/,/# <<< Mac Spoof Helper (macspoof) <<</d' "$HOME/.zshrc"
fi

# Delete dir
rm -rf "$MACSPOOF_DIR"

echo ""
echo "${C_GREEN}[OK]${C_RESET} Mac Spoof Helper removed."
echo "Open a new terminal session or run: ${C_GREEN}source ~/.zshrc${C_RESET}"
echo ""
EOF
chmod +x "$MACSPOOF_DIR/net-clean.sh"

# -------------------------------------------------------------------
#  7. Add aliases to ~/.zshrc (within clear markers)
# -------------------------------------------------------------------
if [[ ! -f "$HOME/.zshrc" ]]; then
  touch "$HOME/.zshrc"
fi

# Remove any old block first
sed -i '' '/# >>> Mac Spoof Helper (macspoof) >>>/,/# <<< Mac Spoof Helper (macspoof) <<</d' "$HOME/.zshrc"

cat >> "$HOME/.zshrc" <<EOF

# >>> Mac Spoof Helper (macspoof) >>>
alias 'net:set'="$MACSPOOF_DIR/net-set.sh"
alias 'net:random'="$MACSPOOF_DIR/net-random.sh"
alias 'net:revert'="$MACSPOOF_DIR/net-revert.sh"
alias 'net:show'="$MACSPOOF_DIR/net-show.sh"
alias 'net:config'="$MACSPOOF_DIR/net-config.sh"
alias 'net:clean'="$MACSPOOF_DIR/net-clean.sh"
alias spoofhelp="$MACSPOOF_DIR/net-help.sh"
alias 'net:help'="$MACSPOOF_DIR/net-help.sh"
# <<< Mac Spoof Helper (macspoof) <<<
EOF

echo ""
echo "${C_GREEN}[OK]${C_RESET} Saved config to: ${CONFIG_FILE}"
echo "${C_GREEN}[OK]${C_RESET} Installed scripts in: ${MACSPOOF_DIR}"
echo ""
echo "Now run:"
echo "  ${C_YELLOW}source ~/.zshrc${C_RESET}"
echo "Then try:"
echo "  ${C_GREEN}net:help${C_RESET}   or   ${C_GREEN}spoofhelp${C_RESET}"
echo ""
echo "${C_CYAN}=============================================================${C_RESET}"
echo ""
