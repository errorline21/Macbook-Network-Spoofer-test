#!/bin/zsh

# ============================================================
#   MAC SPOOFER – HYBRID NETWORK SUITE
#   Created by: dimension53  (Discord)
#   Installer Version: 2.0
# ============================================================

INSTALL_DIR="$HOME/macspoof"
SCRIPT_DIR="$INSTALL_DIR/scripts"
CONFIG_FILE="$INSTALL_DIR/config"

mkdir -p "$SCRIPT_DIR"


# ------------------------------------------------------------
# *** CHECK TERMINAL COLOR SUPPORT ***
# ------------------------------------------------------------
supports_256_colors() {
  if command -v tput >/dev/null 2>&1; then
    cols=$(tput colors 2>/dev/null || echo 0)
    [ "$cols" -ge 256 ]
  else
    return 1
  fi
}

# Discord credit render function
render_discord_credit() {
  if supports_256_colors; then
    # rainbow
    local text="dimension53"
    local colors=(196 202 208 214 220 154 82 46 51 33 27 93)
    local out=""
    local i=1
    for (( idx=1; idx<=${#text}; idx++ )); do
      local ch="${text:idx-1:1}"
      local color="${colors[$i]}"
      out+="%{\e[38;5;${color}m%}${ch}%{\e[0m%}"
      (( i++ ))
      if (( i > ${#colors[@]} )); then i=1; fi
    done
    echo "$out"
  else
    # fallback static green
    echo "%{\e[32m%}dimension53%{\e[0m%}"
  fi
}

DISCORD_CREDIT=$(render_discord_credit)


# ------------------------------------------------------------
# *** TITLE BANNER ***
# ------------------------------------------------------------
print_banner() {
  print ""
  print "================= MAC SPOOF HELPER INSTALLER ================="
  print ""
  print "        Created by: $DISCORD_CREDIT"
  print ""
  print "=============================================================="
  print ""
}


print_banner


# ------------------------------------------------------------
# *** FIND NETWORK INTERFACES ***
# ------------------------------------------------------------
echo "[INFO] Scanning network interfaces (enX)..."
echo ""

for iface in $(networksetup -listallhardwareports | awk '/Device/ {print $2}'); do
    mac=$(ifconfig "$iface" 2>/dev/null | awk '/ether/ {print $2}')
    if [ -n "$mac" ]; then
        printf "  - %-4s (MAC: %s)\n" "$iface" "$mac"
    fi
done

echo ""
echo "Note: en0 (Wi-Fi) may NOT spoof on modern macOS."
echo "      USB / Ethernet (en3, en4…) work best."
echo ""

read "INTERFACE?Enter the interface you want to use (default: en3): "
INTERFACE=${INTERFACE:-en3}

ORIG=$(ifconfig "$INTERFACE" | awk '/ether/ {print $2}')

if [ -z "$ORIG" ]; then
    echo "[ERROR] Could not read MAC for interface $INTERFACE."
    exit 1
fi

echo ""
echo "Detected current MAC on $INTERFACE: $ORIG"
echo ""

# ------------------------------------------------------------
# *** ENTER FIXED MAC ***
# ------------------------------------------------------------
read "FIXED?Enter the FIXED custom MAC you want (format XX:XX:XX:XX:XX:XX): "

FIXED=$(echo "$FIXED" | tr '[:lower:]' '[:upper:]')

echo ""
echo "Interface      : $INTERFACE"
echo "Original MAC   : $ORIG"
echo "Fixed spoof MAC: $FIXED"
echo ""

read "CONFIRM?Is this correct? (y/n): "
[[ "$CONFIRM" != "y" ]] && { echo "Aborted."; exit 1; }

# Save config
mkdir -p "$INSTALL_DIR"
cat <<EOF > "$CONFIG_FILE"
INTERFACE="$INTERFACE"
ORIGINAL="$ORIG"
FIXED="$FIXED"
EOF

echo ""
echo "[OK] Config saved to: $CONFIG_FILE"
echo ""


# ------------------------------------------------------------
# *** CREATE COMMAND SCRIPTS ***
# ------------------------------------------------------------

# SetLoadedAddress
cat <<'EOF' > "$SCRIPT_DIR/SetLoadedAddress.sh"
#!/bin/zsh
source "$HOME/macspoof/config"
echo "Bringing ${INTERFACE} up..."
sudo ifconfig "$INTERFACE" down
sudo ifconfig "$INTERFACE" ether "$FIXED"
sudo ifconfig "$INTERFACE" up
"$HOME/macspoof/scripts/ShowMacAddress.sh"
EOF
chmod +x "$SCRIPT_DIR/SetLoadedAddress.sh"



# RandomizeMacAddress
cat <<'EOF' > "$SCRIPT_DIR/RandomizeMacAddress.sh"
#!/bin/zsh
source "$HOME/macspoof/config"

# Generate locally-administered MAC
OUI=$(printf '%02X:%02X:%02X' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
LAST=$(printf '%02X:%02X:%02X' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))

RAND="$OUI:$LAST"

echo "Bringing ${INTERFACE} up..."
sudo ifconfig "$INTERFACE" down
sudo ifconfig "$INTERFACE" ether "$RAND"
sudo ifconfig "$INTERFACE" up
"$HOME/macspoof/scripts/ShowMacAddress.sh"
EOF
chmod +x "$SCRIPT_DIR/RandomizeMacAddress.sh"



# RevertMacAddress
cat <<'EOF' > "$SCRIPT_DIR/RevertMacAddress.sh"
#!/bin/zsh
source "$HOME/macspoof/config"
echo "Reverting MAC on ${INTERFACE} to ${ORIGINAL}..."
sudo ifconfig "$INTERFACE" down
sudo ifconfig "$INTERFACE" ether "$ORIGINAL"
sudo ifconfig "$INTERFACE" up
"$HOME/macspoof/scripts/ShowMacAddress.sh"
EOF
chmod +x "$SCRIPT_DIR/RevertMacAddress.sh"



# ShowMacAddress
cat <<'EOF' > "$SCRIPT_DIR/ShowMacAddress.sh"
#!/bin/zsh
source "$HOME/macspoof/config"
CUR=$(ifconfig "$INTERFACE" | awk '/ether/ {print $2}')
echo "
==================== MAC STATUS =====================

  Interface        : $INTERFACE
  Current MAC      : $CUR
  Original MAC     : $ORIGINAL

"
if [[ "$CUR" == "$ORIGINAL" ]]; then
    echo "  Status: MATCH → Using ORIGINAL hardware MAC"
else
    echo "  Status: DIFFERENT → Using SPOOFED MAC"
fi
echo "
======================================================
"
EOF
chmod +x "$SCRIPT_DIR/ShowMacAddress.sh"



# spoofhelp
cat <<EOF > "$SCRIPT_DIR/spoofhelp.sh"
#!/bin/zsh
echo ""
echo "==================== SPOOF HELPER ====================="
echo ""
echo "  Active interface : $INTERFACE"
echo ""
echo "  Created by: $DISCORD_CREDIT"
echo ""
echo "  Available commands:"
echo ""
echo "    SetLoadedAddress     - Apply your fixed MAC"
echo "    RandomizeMacAddress  - Apply random locally-administered MAC"
echo "    RevertMacAddress     - Restore hardware MAC"
echo "    ShowMacAddress       - Show current vs original MAC"
echo ""
echo "    spoofhelp            - Show this help menu"
echo "    cleanspoofer         - Remove all spoof helper files"
echo ""
echo "=========================================================="
EOF
chmod +x "$SCRIPT_DIR/spoofhelp.sh"



# cleanspoofer
cat <<'EOF' > "$SCRIPT_DIR/cleanspoofer.sh"
#!/bin/zsh
source "$HOME/macspoof/config"

echo "
============ CLEAN SPOOFER UTILITY ============
"
echo "  This will attempt to:"
echo "    - Revert MAC to original"
echo "    - Remove ~/.macspoof"
echo "    - Remove spoof aliases"
echo ""

read "ANS?Are you sure? (y/N): "
[[ "$ANS" != "y" ]] && exit 0

sudo ifconfig "$INTERFACE" ether "$ORIGINAL" >/dev/null 2>&1

rm -rf "$HOME/macspoof"

sed -i '' '/SetLoadedAddress/d' ~/.zshrc
sed -i '' '/RandomizeMacAddress/d' ~/.zshrc
sed -i '' '/RevertMacAddress/d' ~/.zshrc
sed -i '' '/ShowMacAddress/d' ~/.zshrc
sed -i '' '/spoofhelp/d' ~/.zshrc
sed -i '' '/cleanspoofer/d' ~/.zshrc

echo "[OK] Removed spoof helper."
echo "Run: source ~/.zshrc"
EOF
chmod +x "$SCRIPT_DIR/cleanspoofer.sh"



# ------------------------------------------------------------
# *** ADD ALIASES TO ~/.zshrc ***
# ------------------------------------------------------------

{
  echo "# >>> MAC SPOOFER (dimension53) >>>"
  echo "alias SetLoadedAddress='$SCRIPT_DIR/SetLoadedAddress.sh'"
  echo "alias RandomizeMacAddress='$SCRIPT_DIR/RandomizeMacAddress.sh'"
  echo "alias RevertMacAddress='$SCRIPT_DIR/RevertMacAddress.sh'"
  echo "alias ShowMacAddress='$SCRIPT_DIR/ShowMacAddress.sh'"
  echo "alias spoofhelp='$SCRIPT_DIR/spoofhelp.sh'"
  echo "alias cleanspoofer='$SCRIPT_DIR/cleanspoofer.sh'"
  echo "# <<< MAC SPOOFER <<<"
} >> ~/.zshrc


echo ""
echo "[OK] Installation complete!"
echo "Run the following:"
echo ""
echo "  source ~/.zshrc"
echo "  spoofhelp"
echo ""
echo "=============================================================="
