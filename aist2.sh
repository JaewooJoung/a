#!/bin/bash

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# 일반 사용자 확인
if [ "$EUID" = 0 ]; then
    echo -e "${RED}일반 사용자 권한으로 실행해주세요 (sudo를 사용하지 마세요).${NC}"
    exit 1
fi

# 시스템 업데이트
echo -e "${BLUE}시스템을 업데이트하고 있습니다...${NC}"
sudo pacman -Syu --noconfirm

# 필요한 의존성 패키지들을 설치합니다
echo -e "${BLUE}의존성 패키지들을 설치하고 있습니다...${NC}"
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
    base-devel \
    fontconfig \
    freetype2 \
    gcc-libs \
    glibc \
    glu \
    harfbuzz \
    harfbuzz-icu \
    libcups \
    libcurl-gnutls \
    openssl-1.1 \
    qt5-x11extras \
    zlib

# Rust가 설치되어 있지 않다면 설치합니다
if ! command -v rustc &> /dev/null; then
    echo -e "${BLUE}Rust를 설치하고 있습니다...${NC}"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
fi

# yay가 설치되어 있지 않다면 설치합니다
if ! command -v yay &> /dev/null; then
    echo -e "${BLUE}yay를 설치하고 있습니다...${NC}"
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ..
    rm -rf yay
    echo -e "${GREEN}yay 설치가 완료되었습니다!${NC}"
fi

# Julia 설치 (juliaup을 통해)
echo -e "${BLUE}Julia를 설치하는 중...${NC}"
curl -fsSL https://install.julialang.org | sh

# Naver Whale과 한글 오피스 설치
echo -e "${BLUE}Naver Whale을 설치하는 중...${NC}"
yay -S naver-whale-stable --noconfirm

# Hancom Office 관련 디렉토리 설정
HNCDIR="/opt/hnc"
HNCCONTEXT="/opt/hnc/hoffice11/Bin/qt/plugins/platforminputcontexts"

# kime 설치 및 설정
echo -e "${BLUE}kime 설치 및 설정을 진행합니다...${NC}"
yay -S kime-bin --noconfirm

# kime 설정 파일 생성
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

# Hoffice용 kime 플러그인 설정
echo -e "${BLUE}Hoffice용 입력기 플러그인을 설정합니다...${NC}"
sudo mkdir -p "${HNCCONTEXT}"

# kime Qt 플러그인 다운로드 및 설치
echo -e "${BLUE}kime Qt 플러그인을 다운로드하고 설치합니다...${NC}"
TEMP_DIR=$(mktemp -d)
cd "${TEMP_DIR}"
curl -# -o libkime-qt-5.11.3.so -fL 'https://github.com/Riey/kime/releases/latest/download/libkime-qt-5.11.3.so'
sudo install -Dm755 libkime-qt-5.11.3.so "${HNCCONTEXT}/libkime-qt-5.11.3.so"
cd
rm -rf "${TEMP_DIR}"

# 환경 변수 설정
echo -e "${BLUE}환경 변수를 설정합니다...${NC}"
cat > ~/.xprofile << 'EOL'
export GTK_IM_MODULE=kime
export QT_IM_MODULE=kime
export XMODIFIERS=@im=kime
export OOO_FORCE_DESKTOP=gnome
export XDG_CURRENT_DESKTOP=gnome
export SAL_USE_VCLPLUGIN=gtk3
EOL

# 한글 오피스 설치
echo -e "${BLUE}한글 오피스를 설치하는 중...${NC}"
yay -S hoffice --noconfirm

# 설치 확인
echo -e "${BLUE}설치 확인 중...${NC}"
if command -v juliaup &> /dev/null; then
    echo -e "${GREEN}Julia(juliaup)가 성공적으로 설치되었습니다.${NC}"
else
    echo -e "${RED}Julia 설치에 실패했습니다.${NC}"
fi

if yay -Qi naver-whale-stable &> /dev/null; then
    echo -e "${GREEN}Naver Whale이 성공적으로 설치되었습니다.${NC}"
else
    echo -e "${RED}Naver Whale 설치에 실패했습니다.${NC}"
fi

if yay -Qi hoffice &> /dev/null; then
    echo -e "${GREEN}한글 오피스가 성공적으로 설치되었습니다.${NC}"
else
    echo -e "${RED}한글 오피스 설치에 실패했습니다.${NC}"
fi

# kime 서비스 재시작
echo -e "${BLUE}kime 서비스를 재시작합니다...${NC}"
pkill kime 2>/dev/null || true
kime &

echo -e "${GREEN}설치가 완료되었습니다!${NC}"
echo -e "${GREEN}변경사항을 적용하려면 시스템을 재시작하거나 로그아웃 후 다시 로그인해주세요.${NC}"
echo -e "${GREEN}Julia를 사용하기 위해 터미널을 재시작하거나 'source ~/.bashrc'를 실행해주세요.${NC}"
echo -e "${GREEN}한글 오피스에서 한글 입력이 가능해야 합니다.${NC}"
