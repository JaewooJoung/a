#!/bin/bash

# 오류가 발생하면 즉시 종료
set -e

# 시스템 업데이트
sudo pacman -Syu --noconfirm

# 필요한 종속성 설치
sudo pacman -S --needed --noconfirm git base-devel gcc clang cmake pkg-config gtk3 gtk4 qt5-base qt6-base libxcb libdbus fontconfig freetype2 libxkbcommon

# Rust 설치
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"

# 임시 디렉토리 생성 및 이동
cd /tmp
git clone 
cd yay

# yay 빌드 및 설치
makepkg -si --noconfirm

# yay 빌드 정리
cd ..
rm -rf yay
echo "yay 설치 완료!"

# kime 저장소 클론
cd ~/다운로드 || cd ~/Downloads # 먼저 한글 이름을 시도하고, 그 다음 영어 이름을 시도
git clone https://github.com/Riey/kime
cd kime

# kime 빌드
cargo build --release

# 빌드 스크립트 실행
./scripts/build.sh -ar

# 구성 디렉토리 생성
mkdir -p ~/.config/kime

# 기본 구성 파일 생성
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

# X11용 kime 활성화 (만약 .xprofile에 이미 이러한 항목이 없다면)
grep -q "GTK_IM_MODULE=kime" ~/.xprofile || echo "export GTK_IM_MODULE=kime" >> ~/.xprofile
grep -q "QT_IM_MODULE=kime" ~/.xprofile || echo "export QT_IM_MODULE=kime" >> ~/.xprofile
grep -q "XMODIFIERS=@im=kime" ~/.xprofile || echo "export XMODIFIERS=@im=kime" >> ~/.xprofile

# Wayland용 kime 활성화 (만약 .bash_profile에 이미 이러한 항목이 없다면)
grep -q "GTK_IM_MODULE=kime" ~/.bash_profile || echo "export GTK_IM_MODULE=kime" >> ~/.bash_profile
grep -q "QT_IM_MODULE=kime" ~/.bash_profile || echo "export QT_IM_MODULE=kime" >> ~/.bash_profile
grep -q "XMODIFIERS=@im=kime" ~/.bash_profile || echo "export XMODIFIERS=@im=kime" >> ~/.bash_profile

# kime를 자동 시작 목록에 추가
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
Comment[en_US]=한국어 입력기 편집기
Comment=한국어 입력기 편집기
EOL

# kime 즉시 실행
pkill kime || true  # 기존의 kime 프로세스 종료
kime &

echo "kime 설치 및 설정 완료!"

# Julia 설치를 위한 임시 디렉토리 생성
curl -fsSL https://install.julialang.org | sh

echo "julia 설치 및 설정 완료!"
