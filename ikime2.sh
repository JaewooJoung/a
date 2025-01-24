#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# System update
echo "Updating system..."
sudo pacman -Syu --noconfirm

# Install required dependencies
echo "Installing dependencies..."
sudo pacman -S --needed --noconfirm \
    noto-fonts-cjk \
    cairo \
    cmake \
    extra-cmake-modules \
    pkg-config \
    dbus \
    gtk3 \
    gtk4 \
    libxcb \
    qt5-base \
    qt6-base \
    base-devel

# Install Rust if not already installed
if ! command -v rustc &> /dev/null; then
    echo "Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
fi

# Install yay if not already installed
if ! command -v yay &> /dev/null; then
    echo "Installing yay..."
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ..
    rm -rf yay
    echo "yay installation complete!"
fi

# Remove any existing kime installations
echo "Removing any existing kime installations..."
sudo pacman -Rns kime kime-bin --noconfirm || true
rm -rf ~/.config/kime || true

# Install kime-bin
echo "Installing kime-bin..."
yay -S --noconfirm kime-bin

# Configure kime
echo "Configuring kime..."
# Create configuration directory
mkdir -p ~/.config/kime

# Create default configuration file
echo "Creating kime configuration file..."
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

# Configure for X11
echo "Configuring kime for X11..."
# Create or modify .xprofile
touch ~/.xprofile
grep -v "GTK_IM_MODULE\|QT_IM_MODULE\|XMODIFIERS" ~/.xprofile > ~/.xprofile.tmp || true
cat >> ~/.xprofile.tmp << 'EOL'
export GTK_IM_MODULE=kime
export QT_IM_MODULE=kime
export XMODIFIERS=@im=kime
EOL
mv ~/.xprofile.tmp ~/.xprofile

# Configure for Wayland
echo "Configuring kime for Wayland..."
# Create or modify .bash_profile
touch ~/.bash_profile
grep -v "GTK_IM_MODULE\|QT_IM_MODULE\|XMODIFIERS" ~/.bash_profile > ~/.bash_profile.tmp || true
cat >> ~/.bash_profile.tmp << 'EOL'
export GTK_IM_MODULE=kime
export QT_IM_MODULE=kime
export XMODIFIERS=@im=kime
EOL
mv ~/.bash_profile.tmp ~/.bash_profile

# Add kime to autostart
echo "Adding kime to autostart..."
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

# Start kime
echo "Starting kime..."
pkill kime || true  # Kill existing kime process if any
kime &

echo "Installation complete! Please log out and log back in for all changes to take effect."
echo "You can switch between Korean and English input using the Alt_R (Right Alt) key or Hangul key."
