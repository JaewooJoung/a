# Arch Linux Installation Guide 

* This was made for Korean Language user who wants to install Arch easily with Korean Language.  
* If you are not Korean, you will want to change the Korean time and language to elsewhere 🥰
### example
```bash
# Set timezone to S.Korea
ln -sf /usr/share/zoneinfo/Asia/Seoul /etc/localtime
hwclock --systohc

# Set locale
echo "ko_KR.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=ko_KR.UTF-8" > /etc/locale.conf
```
⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️
```bash
# Set timezone to Sweden
ln -sf /usr/share/zoneinfo/Europe/Stockholm /etc/localtime
hwclock --systohc

# Set locale
echo "sv_SE.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=sv_SE.UTF-8" > /etc/locale.conf
```

## added Dynamic SWAP size depends on your memory  (2025/01/08)

## First, Download the ISO
Get it here ➡️  [https://archlinux.org/download/](https://archlinux.org/download/)
For Windows users, create a bootable USB ➡️  [https://rufus.ie/](https://rufus.ie/)
Linux users know how, and Mac users... 🤭

## Installation Guide
### 1. Internet Connection
Wired internet connects automatically.
For wireless internet connection:<br>
<img src="https://jaewoojoung.github.io/a/internet.png" alt="No internet cable?" width="600"/> 
```bash
iwctl
station wlan0 connect [WIFI name]
[password][Enter]
[quit][Enter]
```

### 2. Download Installation Script
Execute the following command:
```bash
curl -O https://jaewoojoung.github.io/a/install.sh
```

### 3. Run Script
Grant execution permission and run:
```bash
chmod +x install.sh && bash install.sh
```

---
# 🚀 Automatic Installation Guide
## 📝 Introduction
This guide explains how to easily install Arch Linux using an automatic installation script.

## ⚠️ Before Starting
- Must boot in UEFI mode
- Internet connection required
- Need Arch Linux environment booted from USB
- **Warning**: All data on the selected disk will be deleted!

## 🎮 Installation Process
### Step-by-Step Guide
1. **System Check** 🔍
   - Verify UEFI mode
   - Set keyboard layout (Default: US)

2. **Hard Drive Selection** 💽
   - Shows list of all system hard drives
   - Select installation drive by number
   ```
   Example:
   1. sda      500GB  disk
   2. nvme0n1   1TB  disk
   ```

3. **CPU Selection** 🔧
   ```
   1. Intel
   2. AMD
   ```

4. **Account Setup** 👤
   - Enter username
   - Enter computer name (hostname)
   - Set root password
   - Set user password

5. **Installation Plan Confirmation** 📋
   - Choose desktop environment (KDE recommended)
   - 5-second countdown (Press Ctrl+C to cancel)

### 4️⃣ Automatic Installation Process 🚀
Script performs:
- Disk partitioning
- Base system installation
- Desktop environment setup
- Development tools installation
- Input method (fcitx5) setup

## 🎉 Post-Installation Tasks
### 1️⃣ Pre-First Boot Preparation
1. Complete shutdown
2. Remove USB
3. Change BIOS settings:
   - Load BIOS defaults
   - Disable Secure Boot
   - Set UEFI mode
   - Configure boot order

### 2️⃣ First Boot Configuration
1. Activate Input Method
   - Run `fcitx5-configtool` in terminal<br>
<img src="https://jaewoojoung.github.io/a/fcitxconfig.png" alt="fcitx config" width="660"/>
   - Click **fcitx5** under virtual keyboard settings<br>
<img src="https://jaewoojoung.github.io/a/virtualkey.png" alt="virtual key" width="660"/>
   - Reboot computer

## 🎨 Installed Programs
- 🌐 Firefox, Chromium
- 📝 LibreOffice
- 💻 Development Tools (VSCode, Git, etc.)
- 🎨 Graphics Tools (GIMP, Krita)
- 🔧 System Tools

## 💡 Troubleshooting
If issues occur:
1. Check internet connection
2. Verify UEFI mode
3. Debug with `fcitx5 --debug &`

## 🌈 Congratulations! You're now using **all** the latest Linux🐧 technologies! 🥰
