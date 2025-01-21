#!/bin/bash
# Update the system
sudo pacman -Syu --noconfirm

# Install necessary dependencies
sudo pacman -S --needed --noconfirm git base-devel gcc clang cmake pkg-config gtk3 gtk4 qt5-base qt6-base libxcb libdbus fontconfig freetype2 libxkbcommon

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"

# Create a temporary directory and navigate into it
cd /tmp
git clone https://aur.archlinux.org/yay.git
cd yay

# Build and install yay
makepkg -si --noconfirm

# Clean up yay build
cd ..
rm -rf yay
echo "yay installation complete!"

# Clone kime repository
cd ~/다운로드
git clone https://github.com/Riey/kime
cd kime

# Build kime
cargo build --release

# Run build script
./scripts/build.sh -ar

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

# Start kime immediately
kime &
echo "kime installation and configuration complete!"

curl -fsSL https://install.julialang.org | sh


