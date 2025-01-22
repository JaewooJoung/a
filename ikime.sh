#!/bin/bash

# 오류가 발생하면 즉시 종료
set -e

# 시스템 업데이트
echo "Updating system..."
sudo pacman -Syu --noconfirm

# 필요한 종속성 설치
echo "Installing dependencies..."
sudo pacman -S --needed --noconfirm \
    git base-devel gcc clang cmake pkg-config \
    gtk3 gtk4 qt5-base qt6-base libxcb libdbus fontconfig freetype2 libxkbcommon wayland \
    noto-fonts-cjk cairo cargo dbus llvm

# Rust 설치
echo "Installing Rust..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"

# yay 설치
echo "Installing yay..."
cd /tmp
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
cd ..
rm -rf yay
echo "yay installation complete!"

# kime, kime-bin, zoom-libkime 설치
echo "Installing kime, kime-bin, and zoom-libkime using yay..."
yay -S --noconfirm kime kime-bin zoom-libkime

# fcitx5 제거
echo "Uninstalling fcitx5..."
sudo pacman -Rns --noconfirm fcitx5 fcitx5-configtool fcitx5-gtk fcitx5-qt fcitx5-mozc || true

# kime 설정
echo "Configuring kime..."
# 구성 디렉토리 생성
mkdir -p ~/.config/kime

# 기본 구성 파일 생성
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

# X11용 kime 활성화
echo "Configuring kime for X11..."
{
    echo "export GTK_IM_MODULE=kime"
    echo "export QT_IM_MODULE=kime"
    echo "export XMODIFIERS=@im=kime"
} >> ~/.xprofile

# Wayland용 kime 활성화
echo "Configuring kime for Wayland..."
{
    echo "export GTK_IM_MODULE=kime"
    echo "export QT_IM_MODULE=kime"
    echo "export XMODIFIERS=@im=kime"
} >> ~/.bash_profile

# kime를 자동 시작 목록에 추가
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

# kime 즉시 실행
echo "Starting kime..."
pkill kime || true  # 기존의 kime 프로세스 종료
kime &

echo "kime installation and configuration complete!"

# Julia 설치
echo "Installing Julia..."
curl -fsSL https://install.julialang.org | sh
echo "Julia installation complete!"

# Naver Whale 브라우저 설치
yay -S --noconfirm naver-whale-stable

echo "이제 한글로 플루토를 쓸 수 있네요. 🥰"
