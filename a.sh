#!/bin/bash

# 명령어 실행 중 오류가 발생하면 즉시 스크립트를 종료합니다
set -e

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
    adobe-source-han-sans-kr-fonts \
    adobe-source-han-serif-kr-fonts \
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
    zlib \
    xdg-utils \
    libxkbcommon-x11 \
    qt5-tools 
    # ibus \

# 폰트 설치
echo -e "${BLUE}추가 한글 폰트를 설치합니다...${NC}"

# 임시 디렉토리 생성
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# fonts.tar.gz 다운로드
echo -e "${BLUE}폰트 파일을 다운로드합니다...${NC}"
curl -L "https://github.com/JaewooJoung/a/raw/main/1737776534_fonts.tar.gz" -o fonts.tar.gz

# 압축 해제
echo -e "${BLUE}폰트 파일의 압축을 해제합니다...${NC}"
tar xzf fonts.tar.gz

# 시스템 폰트 디렉토리 생성
sudo mkdir -p /usr/share/fonts/korean-custom

# 폰트 파일 복사
echo -e "${BLUE}폰트를 시스템에 설치합니다...${NC}"
sudo cp -r ./*.ttf /usr/share/fonts/korean-custom/ 2>/dev/null || true
sudo cp -r ./*.TTF /usr/share/fonts/korean-custom/ 2>/dev/null || true
sudo cp -r ./*.otf /usr/share/fonts/korean-custom/ 2>/dev/null || true
sudo cp -r ./*.OTF /usr/share/fonts/korean-custom/ 2>/dev/null || true

# 폰트 캐시 업데이트
echo -e "${BLUE}폰트 캐시를 업데이트합니다...${NC}"
sudo fc-cache -f -v

# 임시 디렉토리 정리
cd
rm -rf "$TEMP_DIR"

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
clear
echo -e "${BLUE}Julia를 설치하는 중...${NC}"
curl -fsSL https://install.julialang.org | sh

# Naver Whale 설치
clear
echo -e "${BLUE}Naver Whale을 설치하는 중...${NC}"
yay -S naver-whale-stable --noconfirm

# 한글 오피스 설치 
clear
echo -e "${BLUE}한글 오피스를 설치하는 중...${NC}"
yay -S hoffice ttf-d2coding --noconfirm

# sublime visual-studio-code-bin 오피스 설치 
clear
echo -e "${BLUE}내가 잘쓰는 여러가지 설치하는 중...${NC}"
yay -S sublime-text-4 visual-studio-code-bin teams teams-for-linux realvnc-vnc-server virtualbox-bin virtualbox-bin-guest-iso p3x-onenote-bin p3x-onenote unciv-bin snes9x-git --noconfirm

# 기존 kime 설치를 제거합니다
echo -e "${BLUE}기존 kime 설치를 제거하고 있습니다...${NC}"
sudo pacman -Rns kime kime-bin --noconfirm || true
rm -rf ~/.config/kime || true

# kime-bin을 설치합니다
echo -e "${BLUE}kime-bin을 설치하고 있습니다...${NC}"
yay -S --noconfirm kime-bin
#nimf 보다 깔끔하게 설치됨.. 

# Hancom Office 관련 디렉토리 설정
HNCDIR="/opt/hnc"
HNCCONTEXT="/opt/hnc/hoffice11/Bin/qt/plugins/platforminputcontexts"

# kime 설정 파일 생성
mkdir -p ~/.config/kime
echo -e "${BLUE}kime 설정 파일을 생성합니다...${NC}"
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

# X11용 설정을 합니다
echo -e "${BLUE}X11용 kime 설정을 하고 있습니다...${NC}"
touch ~/.xprofile
grep -v "GTK_IM_MODULE\|QT_IM_MODULE\|XMODIFIERS\|OOO_FORCE_DESKTOP\|XDG_CURRENT_DESKTOP\|SAL_USE_VCLPLUGIN" ~/.xprofile > ~/.xprofile.tmp || true
cat >> ~/.xprofile.tmp << 'EOL'
export GTK_IM_MODULE=kime
export QT_IM_MODULE=kime
export XMODIFIERS=@im=kime
export OOO_FORCE_DESKTOP=gnome
export XDG_CURRENT_DESKTOP=gnome
export SAL_USE_VCLPLUGIN=gtk3
EOL
mv ~/.xprofile.tmp ~/.xprofile

# Wayland용 설정을 합니다
echo -e "${BLUE}Wayland용 kime 설정을 하고 있습니다...${NC}"
touch ~/.bash_profile
grep -v "GTK_IM_MODULE\|QT_IM_MODULE\|XMODIFIERS\|OOO_FORCE_DESKTOP\|XDG_CURRENT_DESKTOP\|SAL_USE_VCLPLUGIN" ~/.bash_profile > ~/.bash_profile.tmp || true
cat >> ~/.bash_profile.tmp << 'EOL'
export GTK_IM_MODULE=kime
export QT_IM_MODULE=kime
export XMODIFIERS=@im=kime
export OOO_FORCE_DESKTOP=gnome
export XDG_CURRENT_DESKTOP=gnome
export SAL_USE_VCLPLUGIN=gtk3
EOL
mv ~/.bash_profile.tmp ~/.bash_profile

# 자동 시작에 kime를 추가합니다
echo -e "${BLUE}kime를 자동 시작 목록에 추가하고 있습니다...${NC}"
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

if yay -Qi sublime-text-4 &> /dev/null; then
    echo -e "${GREEN}아마 다르것들도 성공적으로 설치되었습니다.${NC}"
else
    echo -e "${RED}뭔진 모르지만 몇가지 설치를 실패했습니다.${NC}"
fi

# kime 서비스 재시작
echo -e "${BLUE}kime 서비스를 재시작합니다...${NC}"
pkill kime 2>/dev/null || true
kime &

echo -e "${GREEN}설치가 완료되었습니다!${NC}"
echo -e "${GREEN}변경사항을 적용하려면 시스템을 재시작하거나 로그아웃 후 다시 로그인해주세요.${NC}"
echo -e "${GREEN}Julia를 사용하기 위해 터미널을 재시작하거나 'source ~/.bashrc'를 실행해주세요.${NC}"
echo -e "${GREEN}한글 오피스에서 한글 입력이 가능해야 합니다.${NC}"
echo -e "${GREEN}오른쪽 Alt키나 한/영 키를 사용하여 한글/영문 입력을 전환할 수 있습니다.${NC}"
