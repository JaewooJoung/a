# Arch Linux Installation Guide *If you are not Korean, you will want to change the Korean time and language to elsewhere 🥰

## First, Download the ISO
Get it here first ➡️ [https://archlinux.org/download/](https://archlinux.org/download/)
For Windows users, create a bootable USB ➡️ [https://rufus.ie/](https://rufus.ie/)
Linux users should already know, and Mac users... 🤭

## Installation Guide
### 1. Internet Connection
Wired internet connects automatically.
For wireless internet:
```bash
iwctl
station wlan0 connect [WIFI name]
[password][Enter]
[quit][Enter]
```

### 2. Download Installation Script
Execute this command:
```bash
curl -O https://jaewoojoung.github.io/a/install.sh
```

### 3. Run Script
Grant permission and run:
```bash
chmod +x install.sh && bash install.sh
```

---
# 🚀 Automatic Installation Guide

## 📝 Introduction
Easy Arch Linux installation guide

## ⚠️ Prerequisites
- UEFI boot mode required
- Internet connection needed
- Bootable USB required
- **Warning**: All data will be deleted!

## 🎮 Installation Steps

### Step-by-Step
1. **System Check** 🔍
   - UEFI mode check
   - Keyboard layout setup

2. **Drive Selection** 💽
   - Choose installation drive
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
   - Username
   - Hostname
   - Root password
   - User password

5. **Installation Confirmation** 📋
   - Choose desktop (KDE recommended)
   - 5-second countdown

### 4️⃣ Automatic Process 🚀
Script performs:
- Disk setup
- System installation
- Desktop setup
- Tools installation
- Input setup

## 🎉 After Installation

### 1️⃣ Before First Boot
1. Shutdown
2. Remove USB
3. BIOS settings:
   - Load defaults
   - Disable Secure Boot
   - Set UEFI
   - Set boot order

### 2️⃣ First Boot Setup
1. Input Method Setup
   - Run `fcitx5-configtool`
   - Select fcitx5 in settings
   - Reboot

## 🎨 Installed Programs
- 🌐 Firefox, Chromium
- 📝 LibreOffice
- 💻 Development Tools (VSCode, Git)
- 🎨 Graphics Tools (GIMP, Krita)
- 🔧 System Tools

## 💡 Troubleshooting
If issues occur:
1. Check internet
2. Verify UEFI
3. Debug with `fcitx5 --debug &`

## 🌈 Congratulations! You're now using the latest Linux🐧 technologies! 🥰
