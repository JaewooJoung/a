#!/bin/bash

# 오류가 발생하면 즉시 종료
set -e

# 시스템 업데이트
echo "Updating system..."
sudo pacman -Syu --noconfirm

# 필요한 종속성 설치 (Plasma Wayland 환경에 맞춤)
echo "Installing dependencies..."
sudo pacman -S --needed --noconfirm \
    git base-devel cmake pkg-config \
    gtk3 gtk4 qt5-base qt6-base \
    libxcb libdbus fontconfig freetype2 \
    libxkbcommon wayland clang \
    noto-fonts-cjk cargo icu

# yay가 없는 경우 설치
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

# fcitx5 설정 백업 (나중을 위해)
if [ -d ~/.config/fcitx5 ]; then
    echo "Backing up fcitx5 configuration..."
    cp -r ~/.config/fcitx5 ~/.config/fcitx5.backup
fi

# fcitx5 비활성화 (제거하지 않고 비활성화)
echo "Disabling fcitx5 autostart..."
mkdir -p ~/.config/autostart
if [ -f /etc/xdg/autostart/fcitx5.desktop ]; then
    cp /etc/xdg/autostart/fcitx5.desktop ~/.config/autostart/
    echo "Hidden=true" >> ~/.config/autostart/fcitx5.desktop
fi

# kime 설치 시도 (yay를 통해)
echo "Attempting to install kime using yay..."
if yay -S --noconfirm kime; then
    echo "kime installed successfully using yay."
else
    echo "yay installation failed. Attempting manual build..."

    # Clone the official kime repository
    cd /tmp
    git clone https://github.com/Riey/kime.git
    cd kime

    # Build and install kime
    echo "Building kime from source..."
    cargo build --release
    sudo cp target/release/kime /usr/bin/
    sudo cp target/release/kime_engine /usr/lib/

    echo "kime installed successfully from source."
fi

# kime 설정 디렉토리 생성
echo "Configuring kime..."
mkdir -p ~/.config/kime

# kime 설정 파일 생성 (Plasma Wayland에 최적화)
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

# Plasma Wayland 환경변수 설정
echo "Configuring environment variables..."
mkdir -p ~/.config/plasma-workspace/env/
cat > ~/.config/plasma-workspace/env/kime.sh << 'EOL'
#!/bin/sh
export GTK_IM_MODULE=kime
export QT_IM_MODULE=kime
export XMODIFIERS=@im=kime
EOL
chmod +x ~/.config/plasma-workspace/env/kime.sh

# kime 자동시작 설정
echo "Setting up kime autostart..."
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

# GTK 모듈 캐시 업데이트
echo "Updating GTK module cache..."
sudo gtk-query-immodules-3.0 --update-cache
sudo gio-querymodules /usr/lib/gtk-4.0/4.0.0/immodules

echo "Installation complete! Please follow these steps:"
echo "1. Go to System Settings > Hardware > Input Devices > Virtual Keyboard"
echo "2. Select 'kime daemon'"
echo "3. Log out and log back in to apply changes"
echo ""
echo "Note: Your previous fcitx5 configuration has been backed up to ~/.config/fcitx5.backup"
echo "To toggle Korean input after logging back in, use Shift+Space or the Hangul key"
