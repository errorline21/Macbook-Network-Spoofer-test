# Macbook Network Spoofer — Easy Terminal Commands

This tool works on **macOS only**.  
Wi-Fi (en0) spoofing is **blocked** by Apple on macOS Catalina and later.  
USB/Ethernet adapters **(en3, en4, etc.)** spoof correctly.

This tool installs simple, safe, beginner-friendly macOS terminal commands to
manage and modify your network interface MAC addresses.

You can spoof the MAC address of:

- **USB Ethernet adapters**
- **USB-C → Ethernet dongles**
- **Thunderbolt Ethernet adapters**
- *(Sometimes)* virtual interfaces

---

## 📌 1. Installation Options

You may install this tool in one of three ways depending on how you downloaded it.

---

## ✅ Option 1 — Automatic Install (Recommended)

Paste this into Terminal:

```sh
curl -fsSL https://raw.githubusercontent.com/errorline21/Macbook-Network-Spoofer-test/main/install.sh -o install.sh
chmod +x install.sh
./install.sh
```

---

## ✅ Option 2 — Installing from ZIP Download

If you downloaded the project via **Download ZIP**:

1. Unzip the folder.
2. Open Terminal.
3. Navigate into the unzipped directory.
4. Run:

```sh
cd ~/Downloads/Macbook-Network-Spoofer-test
chmod +x install.sh
./install.sh
```

---

## ✅ Option 3 — Install via Git Clone

```sh
git clone https://github.com/errorline21/Macbook-Network-Spoofer-test.git
cd Macbook-Network-Spoofer-test
chmod +x install.sh
./install.sh
```

---

## 📌 2. After Installation

Reload your shell so the new commands become active:

```sh
source ~/.zshrc
```

Now run:

```sh
spoofhelp
```

### Available Commands

| Command              | Description                                |
|---------------------|---------------------------------------------|
| SetLoadedAddress    | Apply your custom MAC address               |
| RandomizeMacAddress | Apply a random locally-administered MAC     |
| RevertMacAddress    | Restore original hardware MAC               |
| ShowMacAddress      | Show current vs original MAC                |
| cleanspoofer        | Fully remove the tool                       |
| spoofhelp           | Show help                                   |

---

## 📌 3. Requirements

- macOS  
- Terminal  
- *(Optional)* Node.js for any Node-based tools  

Download Node.js:  
https://nodejs.org/

---

## 📌 4. Troubleshooting

If `install.sh` won’t run:

```sh
chmod +x install.sh
./install.sh
```

If the commands do not appear:

```sh
source ~/.zshrc
```

If you moved the folder after installation → reinstall using **Option 1**.

---

## 📌 5. Want to uninstall?

```sh
cleanspoofer
source ~/.zshrc
```

---

## ⚠️ Disclaimer

**SPOOFING YOUR MAC ADDRESS MAY NOT BE PERMITTED.  
THIS TOOL IS FOR PRIVACY & SECURITY RESEARCH, OR RESETTING YOUR MAC ADDRESS ONLY.**
