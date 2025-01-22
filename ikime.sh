#!/bin/bash

# 오류 발생 시 즉시 중단
set -e

# 로그 함수
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# 오류 핸들러
handle_error() {
    log "Error occurred in line $1"
    exit 1
}

trap 'handle_error $LINENO' ERR

# 기본 의존성 설치
log "Installing build dependencies..."
sudo pacman -Syu --needed --noconfirm \
    git \
    base-devel \
    cmake \
    pkg-config \
    clang \
    gtk3 \
    gtk4 \
    qt5-base \
    qt6-base \
    libxcb \
    libdbus \
    fontconfig \
    freetype2 \
    libxkbcommon \
    wayland \
    wayland-protocols \
    libxkbcommon-x11 \
    librime \
    libappindicator-gtk3 \
    rustup

# Rust 툴체인 설정
log "Setting up Rust toolchain..."
if ! command -v rustc &> /dev/null; then
    rustup default stable
    log "Rust stable toolchain installed"
else
    log "Rust is already installed"
fi

# kime 빌드를 위한 임시 디렉토리 생성
BUILD_DIR=$(mktemp -d)
log "Created build directory: $BUILD_DIR"

# 빌드 디렉토리 정리를 위한 트랩 설정
trap 'rm -rf $BUILD_DIR' EXIT

# kime 소스 코드 클론
log "Cloning kime repository..."
cd "$BUILD_DIR"
git clone https://github.com/Riey/kime.git
cd kime

# 빌드 스크립트 실행
log "Building kime..."
./scripts/build.sh -ar

# 설치
log "Installing kime..."
sudo ./scripts/install.sh /usr

# GTK 모듈 캐시 업데이트
log "Updating GTK module cache..."
sudo gtk-query-immodules-3.0 --update-cache
sudo gio-querymodules /usr/lib/gtk-4.0/4.0.0/immodules

# 설정 파일 생성
log "Creating configuration files..."
mkdir -p ~/.config/kime

# kime 설정 파일 생성
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
log "Setting up environment variables..."
mkdir -p ~/.config/plasma-workspace/env/
cat > ~/.config/plasma-workspace/env/kime.sh << 'EOL'
#!/bin/sh
export GTK_IM_MODULE=kime
export QT_IM_MODULE=kime
export XMODIFIERS=@im=kime
EOL
chmod +x ~/.config/plasma-workspace/env/kime.sh

# 자동 시작 설정
log "Setting up autostart..."
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

log "Installation completed successfully!"
echo "===================================="
echo "Please do the following:"
echo "1. Go to System Settings > Hardware > Input Devices > Virtual Keyboard"
echo "2. Select 'kime daemon'"
echo "3. Log out and log back in"
echo "4. Use Shift+Space or Hangul key to toggle Korean input"
echo "===================================="
