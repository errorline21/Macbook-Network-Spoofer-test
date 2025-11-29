#!/bin/zsh

echo "================ MAC SPOOF TOOL INSTALLER ================"

# 1. Ensure Node.js + npm installed
if ! command -v node >/dev/null 2>&1; then
    echo "Node.js not found. Installing NVM + Node 24..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    source "$NVM_DIR/nvm.sh"
    nvm install 24
else
    echo "Node.js found!"
fi

# 2. Install spoof globally
echo "Installing spoof module..."
npm install -g spoof

# 3. Detect Wi-Fi interface automatically
echo "Detecting Wi-Fi interface..."
WIFI_IFACE=$(networksetup -listallhardwareports | awk '/Wi-Fi/{getline; print $2}')

if [[ -z "$WIFI_IFACE" ]]; then
    echo "❌ ERROR: Could not detect Wi-Fi interface. Exiting."
    exit 1
fi

echo "Wi-Fi interface detected: $WIFI_IFACE"

# 4. Detect original MAC address
ORIGINAL_MAC=$(ifconfig "$WIFI_IFACE" | awk '/ether/{print $2}' | tr '[:lower:]' '[:upper:]')

echo "Detected Original MAC: $ORIGINAL_MAC"

# 5. Create scripts -----------------------------------------

# macfix
cat <<EOF > ~/macfix.sh
#!/bin/zsh
FIXED_MAC="08:00:27:13:F1:74"

echo "Bringing $WIFI_IFACE down..."
sudo ifconfig $WIFI_IFACE down
echo "Setting MAC to \$FIXED_MAC ..."
sudo ifconfig $WIFI_IFACE ether \$FIXED_MAC
sudo ifconfig $WIFI_IFACE up
EOF
chmod +x ~/macfix.sh

# macrandom
cat <<EOF > ~/macrandom.sh
#!/bin/zsh
sudo ifconfig $WIFI_IFACE down
echo "Randomizing MAC..."
RANDMAC=\$(spoof random)
sudo ifconfig $WIFI_IFACE ether \$RANDMAC
sudo ifconfig $WIFI_IFACE up
EOF
chmod +x ~/macrandom.sh

# macrevert
cat <<EOF > ~/macrevert.sh
#!/bin/zsh
echo "Bringing $WIFI_IFACE down..."
sudo ifconfig $WIFI_IFACE down
echo "Reverting MAC to $ORIGINAL_MAC..."
sudo ifconfig $WIFI_IFACE ether $ORIGINAL_MAC
sudo ifconfig $WIFI_IFACE up
EOF
chmod +x ~/macrevert.sh

# macShow
cat <<EOF > ~/macShow.sh
#!/bin/zsh

CUR=\$(ifconfig $WIFI_IFACE | awk '/ether/{print \$2}')
CUR_UPPER=\$(echo \$CUR | tr '[:lower:]' '[:upper:]')

echo ""
echo "==================== MAC STATUS ====================="
echo "  Current MAC Address : \$CUR_UPPER"
echo "  Original MAC Address: $ORIGINAL_MAC"
echo ""

if [[ "\$CUR_UPPER" == "$ORIGINAL_MAC" ]]; then
    echo "  Status: MATCH → Using ORIGINAL MAC"
else
    echo "  Status: DIFFERENT → Using SPOOFED MAC"
fi
echo "======================================================"
EOF
chmod +x ~/macShow.sh

# help command
cat <<EOF > ~/helpMac.sh
#!/bin/zsh

echo ""
echo "==================== MAC SPOOF COMMANDS ===================="
echo "  macfix      - Set your fixed chosen MAC address"
echo "  macrandom   - Randomize your MAC address"
echo "  macrevert   - Restore original hardware MAC"
echo "  macShow     - Display current + original MAC status"
echo "  helpMac     - Show this help menu"
echo "==============================================================="
EOF
chmod +x ~/helpMac.sh

# 6. Add aliases to ~/.zshrc
echo "Adding aliases to ~/.zshrc ..."
cat <<EOF >> ~/.zshrc

# MAC Spoofing Tool Aliases
alias macfix='~/macfix.sh'
alias macrandom='~/macrandom.sh'
alias macrevert='~/macrevert.sh'
alias macShow='~/macShow.sh'
alias helpMac='~/helpMac.sh'
EOF

# reload zsh
source ~/.zshrc

echo "================ INSTALL COMPLETE ================="
echo "Commands now available:"
echo "  macfix"
echo "  macrandom"
echo "  macrevert"
echo "  macShow"
echo "  helpMac"
echo "=================================================="

cat <<EOF > ~/.macspoof_config
# mac-spoof-helper configuration file

# Default fixed spoof MAC (change this anytime)
FIXED_MAC="02:00:00:00:00:01"

# Wi-Fi interface (auto-detected if left empty)
WIFI_IFACE=""

# Do NOT edit this unless you know what you're doing
ORIGINAL_MAC=""
EOF
