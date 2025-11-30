# Macbook Network Spoofer — Easy Terminal Commands

This tool works on **macOS only**.  
Wi-Fi (en0) spoofing is **blocked** by Apple on macOS Catalina and later.  
USB/Ethernet adapters **(en3, en4, etc.)** spoof correctly.

This tool provides a simple installer that adds helpful macOS network commands directly into your terminal.  
It is lightweight, beginner-friendly, and requires **no external dependencies**.

Users can spoof the MAC address of:

- **USB Ethernet adapters**
- **USB-C → Ethernet dongles**
- **Thunderbolt Ethernet adapters**
- **(Sometimes) virtual interfaces**

---

------------------------------------------------------------
📌 1. Installation Options
------------------------------------------------------------

You may install this tool in one of three ways depending on how you downloaded it.

------------------------------------------------------------
✅ Option 1 — Automatic Install (Recommended)
------------------------------------------------------------

Paste this into Terminal:

    ```sh
curl -fsSL https://raw.githubusercontent.com/errorline21/Macbook-Network-Spoofer-test/main/install.sh -o install.sh
chmod +x install.sh
./install.sh





------------------------------------------------------------
✅ Option 2 — Installing from ZIP Download
------------------------------------------------------------

If you downloaded the project via “Download ZIP”:

1. Unzip the folder.
2. Open Terminal.
3. Navigate into the unzipped directory.
4. Run:

cd ~/Downloads/Macbook-Network-Spoofer-test      # or the folder you unzipped
chmod +x install.sh
./install.sh

------------------------------------------------------------
✅ Option 3 — Install via Git Clone
------------------------------------------------------------

If you prefer installing through Git:

git clone https://github.com/errorline21/Macbook-Network-Spoofer-test.git
cd Macbook-Network-Spoofer-test
chmod +x install.sh
./install.sh


------------------------------------------------------------
📌 2. After Installation
------------------------------------------------------------

Reload your shell so the new commands become active:

   source ~/.zshrc


Once reloaded, you can run:

 spoofhelp

to view the list of available commands.

SetLoadedAddress     - Apply your custom MAC Address
RandomizeMacAddress  - Apply a random MAC
RevertMacAddress     - Restore original hardware MAC
ShowMacAddress       - Show current vs original MAC
cleanspoofer         - Fully remove the tool
spoofhelp            - Show help


------------------------------------------------------------
📌 3. Requirements
------------------------------------------------------------

• macOS  
• Terminal  
• (Optional) Node.js if using any Node-based utilities  

Node.js download:  
https://nodejs.org/

------------------------------------------------------------
📌 4. Troubleshooting
------------------------------------------------------------

If `install.sh` will not run:

    chmod +x install.sh
    ./install.sh

If the commands are not recognized:

    source ~/.zshrc

If the folder was moved after installation, reinstall using Option 1.


------------------------------------------------------------
📌 5. Want to uninstall?
------------------------------------------------------------

cleanspoofer
source ~/.zshrc

------------------------------------------------------------

SPOOFING YOUR MAC ADDRESS IS NOT PERMITTED, THIS IS FOR RESETTING YOUR MAC ADDRESS ONLY!  

