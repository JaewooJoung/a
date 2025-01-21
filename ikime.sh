#!/bin/bash

# Update the system
sudo pacman -Syu --noconfirm

# Install necessary dependencies
sudo pacman -S --needed --noconfirm \
git base-devel gcc clang cmake pkg-config gtk3 gtk4 qt5-base qt6-base \
libxcb libdbus fontconfig freetype2 libxkbcommon

# Create a temporary directory and navigate into it
cd /tmp
git clone https://aur.archlinux.org/yay.git
cd yay

# Build and install yay
makepkg -si --noconfirm

# Clean up
cd ..
rm -rf yay

echo "yay installation complete!"

# Create a temporary directory for building
mkdir -p ~/aur_builds
cd ~/aur_builds

# Clone the AUR package
git clone https://aur.archlinux.org/kime.git
cd kime

# Build and install the package
makepkg -si --noconfirm

# Create config directory
mkdir -p ~/.config/kime

# Create default configuration file
cat > ~/.config/kime/kime.yaml << 'EOL'
log:
  version: 1
indicator:
  icon_color: "White"
engine:
  hangul_keys: ["Hangul", "Alt_R"]
  compose_keys: ["Shift-Space"]
  toggle_keys: ["Hangul", "Alt_R"]
  xim_preedit_font: [D2Coding, 15.0]
  latin_mode_on_press_shift: false
  latin_mode_on_press_caps: false
  global_category_mode: true
  global_hotkeys: []
  word_commit: false
  commit_key1: "Shift"
  commit_key2: "Shift"
EOL

# Enable kime for X11
echo "export GTK_IM_MODULE=kime" >> ~/.xprofile
echo "export QT_IM_MODULE=kime" >> ~/.xprofile
echo "export XMODIFIERS=@im=kime" >> ~/.xprofile

# Enable kime for Wayland
echo "export GTK_IM_MODULE=kime" >> ~/.bash_profile
echo "export QT_IM_MODULE=kime" >> ~/.bash_profile
echo "export XMODIFIERS=@im=kime" >> ~/.bash_profile

# Add kime to autostart
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/kime.desktop << 'EOL'
[Desktop Entry]
Type=Application
Exec=kime
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name[en_US]=kime
Name=kime
Comment[en_US]=Korean Input Method Editor
Comment=Korean Input Method Editor
EOL

# Clean up build directory
cd ~
rm -rf ~/aur_builds

# Start kime immediately
kime &

echo "kime installation and configuration complete!"
