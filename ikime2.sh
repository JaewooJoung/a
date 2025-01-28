#!/bin/bash

# 스크립트 실행 중 오류 발생시 즉시 종료
set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 진행상태 출력 함수
print_status() {
    echo -e "${BLUE}[알림]${NC} $1"
}

# 성공 메시지 출력 함수
print_success() {
    echo -e "${GREEN}[성공]${NC} $1"
}

# 오류 메시지 출력 함수
print_error() {
    echo -e "${RED}[오류]${NC} $1"
}

# 시스템 업데이트
print_status "시스템 업데이트를 진행합니다..."
sudo pacman -Syu --noconfirm

# 의존성 패키지 설치
print_status "필요한 패키지들을 설치합니다..."
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

# Rust 설치 확인 및 설치
if ! command -v rustc &> /dev/null; then
    print_status "Rust를 설치합니다..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    print_success "Rust 설치가 완료되었습니다."
fi

# yay 설치 확인 및 설치
if ! command -v yay &> /dev/null; then
    print_status "yay를 설치합니다..."
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ..
    rm -rf yay
    print_success "yay 설치가 완료되었습니다."
fi

# 기존 kime 제거
print_status "기존 kime 설치를 제거합니다..."
sudo pacman -Rns kime kime-bin --noconfirm 2>/dev/null || true
rm -rf ~/.config/kime 2>/dev/null || true

# kime-bin 설치
print_status "kime-bin을 설치합니다..."
yay -S --noconfirm kime-bin

# kime 설정
print_status "kime 설정을 시작합니다..."
mkdir -p ~/.config/kime

# kime.yaml 설정 파일 생성
print_status "kime 설정 파일을 생성합니다..."
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

# X11 환경 설정
print_status "X11 환경 설정을 진행합니다..."
touch ~/.xprofile
grep -v "GTK_IM_MODULE\|QT_IM_MODULE\|XMODIFIERS\|OOO_FORCE_DESKTOP" ~/.xprofile > ~/.xprofile.tmp || true
cat >> ~/.xprofile.tmp << 'EOL'
export GTK_IM_MODULE=kime
export QT_IM_MODULE=kime
export XMODIFIERS=@im=kime
export OOO_FORCE_DESKTOP="gnome"
EOL
mv ~/.xprofile.tmp ~/.xprofile

# Wayland 환경 설정
print_status "Wayland 환경 설정을 진행합니다..."
touch ~/.bash_profile
grep -v "GTK_IM_MODULE\|QT_IM_MODULE\|XMODIFIERS\|OOO_FORCE_DESKTOP" ~/.bash_profile > ~/.bash_profile.tmp || true
cat >> ~/.bash_profile.tmp << 'EOL'
export GTK_IM_MODULE=kime
export QT_IM_MODULE=kime
export XMODIFIERS=@im=kime
export OOO_FORCE_DESKTOP="gnome"
EOL
mv ~/.bash_profile.tmp ~/.bash_profile

# 자동 시작 설정
print_status "자동 시작 설정을 추가합니다..."
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

# kime 프로세스 재시작
print_status "kime를 재시작합니다..."
pkill kime 2>/dev/null || true
kime &

print_success "설치가 완료되었습니다!"
echo -e "${GREEN}[안내]${NC} 변경사항을 적용하려면 로그아웃 후 다시 로그인해주세요."
echo -e "${GREEN}[안내]${NC} 오른쪽 Alt키 또는 한/영 키로 한글/영문 전환이 가능합니다."
echo -e "${GREEN}[안내]${NC} LibreOffice 한글 입력을 위한 설정도 완료되었습니다."
