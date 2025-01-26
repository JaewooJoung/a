#!/bin/bash

set -e
trap 'echo "Error occurred. Exiting..."; exit 1' ERR

# Check for root user
if [ "$EUID" = 0 ]; then
   echo "Please run as non-root user (without sudo)."
   exit 1
fi

# System update
echo "Updating system..."
sudo pacman -Syu --noconfirm

# Install dependencies
DEPS=(
   noto-fonts-cjk
   cairo
   cmake
   extra-cmake-modules
   pkg-config
   dbus
   gtk3
   gtk4
   libxcb
   qt5-base
   qt6-base
   base-devel
)

echo "Installing dependencies..."
sudo pacman -S --needed --noconfirm "${DEPS[@]}"

# Install Rust if needed
if ! command -v rustc &> /dev/null; then
   echo "Installing Rust..."
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
   source "$HOME/.cargo/env"
fi

# Install yay if needed
if ! command -v yay &> /dev/null; then
   echo "Installing yay..."
   cd /tmp
   git clone https://aur.archlinux.org/yay.git
   cd yay
   makepkg -si --noconfirm
   cd ..
   rm -rf yay
fi

# Install Julia
echo "Installing Julia..."
curl -fsSL https://install.julialang.org | sh

# Install Naver Whale and Hancom Office
echo "Installing Naver Whale and Hancom Office..."
yay -S naver-whale-stable hoffice --noconfirm

# Remove existing kime
echo "Removing existing kime..."
sudo pacman -Rns kime kime-bin --noconfirm || true
rm -rf ~/.config/kime || true

# Install kime-bin
echo "Installing kime-bin..."
yay -S --noconfirm kime-bin

# Create backup
backup_date=$(date +%Y%m%d_%H%M%S)
for file in ~/.xprofile ~/.bash_profile; do
   [ -f "$file" ] && cp "$file" "${file}.${backup_date}.bak"
done

# Configure kime
mkdir -p ~/.config/kime
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

# Configure X11
touch ~/.xprofile
grep -v "GTK_IM_MODULE\|QT_IM_MODULE\|XMODIFIERS" ~/.xprofile > ~/.xprofile.tmp || true
cat >> ~/.xprofile.tmp << 'EOL'
export GTK_IM_MODULE=kime
export QT_IM_MODULE=kime
export XMODIFIERS=@im=kime
EOL
mv ~/.xprofile.tmp ~/.xprofile

# Configure Wayland
touch ~/.bash_profile
grep -v "GTK_IM_MODULE\|QT_IM_MODULE\|XMODIFIERS" ~/.bash_profile > ~/.bash_profile.tmp || true
cat >> ~/.bash_profile.tmp << 'EOL'
export GTK_IM_MODULE=kime
export QT_IM_MODULE=kime
export XMODIFIERS=@im=kime
EOL
mv ~/.bash_profile.tmp ~/.bash_profile

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
Comment=한글 입력기
EOL

# Start kime
pkill kime || true
kime &

# Verify installations
echo "Verifying installations..."
for cmd in juliaup yay kime; do
   if command -v $cmd &> /dev/null; then
       echo "$cmd installed successfully"
   else
       echo "Warning: $cmd installation may have failed"
   fi
done

for pkg in naver-whale-stable hoffice; do
   if yay -Qi $pkg &> /dev/null; then
       echo "$pkg installed successfully"
   else
       echo "Warning: $pkg installation may have failed"
   fi
done

echo "Installation complete! Please logout and login to apply changes."
echo "Use Right Alt or Hangul key to switch between Korean/English input."
