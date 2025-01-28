#!/bin/bash

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# 스크립트 실행 중 오류 발생시 즉시 종료
set -e

# 함수: 상태 메시지 출력
print_status() {
    echo -e "${BLUE}[알림]${NC} $1"
}

# 함수: 성공 메시지 출력
print_success() {
    echo -e "${GREEN}[성공]${NC} $1"
}

# 함수: 오류 메시지 출력
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

# 환경 변수 및 LibreOffice 설정
print_status "환경 변수 설정을 진행합니다..."

# XDG_CURRENT_DESKTOP 설정 추가
mkdir -p ~/.config/environment.d
cat > ~/.config/environment.d/99-libreoffice-ime.conf << 'EOL'
GTK_IM_MODULE=kime
QT_IM_MODULE=kime
XMODIFIERS=@im=kime
OOO_FORCE_DESKTOP=gnome
XDG_CURRENT_DESKTOP=gnome
EOL

# X11 설정
print_status "X11 환경 설정을 진행합니다..."
cat > ~/.xprofile << 'EOL'
export GTK_IM_MODULE=kime
export QT_IM_MODULE=kime
export XMODIFIERS=@im=kime
export OOO_FORCE_DESKTOP=gnome
export XDG_CURRENT_DESKTOP=gnome
export SAL_USE_VCLPLUGIN=gtk3
EOL

# Wayland 설정
print_status "Wayland 환경 설정을 진행합니다..."
cat > ~/.bash_profile << 'EOL'
export GTK_IM_MODULE=kime
export QT_IM_MODULE=kime
export XMODIFIERS=@im=kime
export OOO_FORCE_DESKTOP=gnome
export XDG_CURRENT_DESKTOP=gnome
export SAL_USE_VCLPLUGIN=gtk3
EOL

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

# 폰트 설치
print_status "추가 한글 폰트를 설치합니다..."

# 임시 디렉토리 생성
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# fonts.tar.gz 다운로드
print_status "폰트 파일을 다운로드합니다..."
curl -L "https://github.com/JaewooJoung/a/raw/main/1737776534_fonts.tar.gz" -o fonts.tar.gz

# 압축 해제
print_status "폰트 파일의 압축을 해제합니다..."
tar xzf fonts.tar.gz

# 시스템 폰트 디렉토리 생성
sudo mkdir -p /usr/share/fonts/korean-custom

# 폰트 파일 복사
print_status "폰트를 시스템에 설치합니다..."
sudo cp -r ./*.ttf /usr/share/fonts/korean-custom/ 2>/dev/null || true
sudo cp -r ./*.TTF /usr/share/fonts/korean-custom/ 2>/dev/null || true
sudo cp -r ./*.otf /usr/share/fonts/korean-custom/ 2>/dev/null || true
sudo cp -r ./*.OTF /usr/share/fonts/korean-custom/ 2>/dev/null || true

# 폰트 캐시 업데이트
print_status "폰트 캐시를 업데이트합니다..."
sudo fc-cache -f -v

# 임시 디렉토리 정리
cd
rm -rf "$TEMP_DIR"

# LibreOffice 프로필 초기화
print_status "LibreOffice 프로필을 초기화합니다..."
rm -rf ~/.config/libreoffice || true

# kime 재시작
print_status "kime를 재시작합니다..."
pkill kime 2>/dev/null || true
kime &

print_success "모든 설치가 완료되었습니다!"
echo -e "${GREEN}[안내]${NC} 시스템을 재시작하거나 로그아웃 후 다시 로그인해주세요."
echo -e "${GREEN}[안내]${NC} LibreOffice에서 다음을 확인해주세요:"
echo -e "1. 도구 > 옵션 > 언어 설정 > 언어 에서 한국어가 포함되어 있는지 확인"
echo -e "2. 도구 > 옵션 > 고급 에서 'Use system's user interface language' 활성화"
echo -e "${GREEN}[안내]${NC} 오른쪽 Alt키 또는 한/영 키로 한글/영문 전환이 가능합니다."
