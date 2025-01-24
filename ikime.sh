#!/bin/bash
# 명령어 실행 중 오류가 발생하면 즉시 스크립트를 종료합니다
set -e

# 시스템 업데이트
echo "시스템을 업데이트하고 있습니다..."
sudo pacman -Syu --noconfirm

# 필요한 의존성 패키지들을 설치합니다
echo "의존성 패키지들을 설치하고 있습니다..."
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

# Rust가 설치되어 있지 않다면 설치합니다
if ! command -v rustc &> /dev/null; then
   echo "Rust를 설치하고 있습니다..."
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
   source "$HOME/.cargo/env"
fi

# yay가 설치되어 있지 않다면 설치합니다
if ! command -v yay &> /dev/null; then
   echo "yay를 설치하고 있습니다..."
   cd /tmp
   git clone https://aur.archlinux.org/yay.git
   cd yay
   makepkg -si --noconfirm
   cd ..
   rm -rf yay
   echo "yay 설치가 완료되었습니다!"
fi

# 기존 kime 설치를 제거합니다
echo "기존 kime 설치를 제거하고 있습니다..."
sudo pacman -Rns kime kime-bin --noconfirm || true
rm -rf ~/.config/kime || true

# kime-bin을 설치합니다
echo "kime-bin을 설치하고 있습니다..."
yay -S --noconfirm kime-bin

# kime 설정을 시작합니다
echo "kime 설정을 시작합니다..."
# 설정 디렉토리를 생성합니다
mkdir -p ~/.config/kime

# 기본 설정 파일을 생성합니다
echo "kime 설정 파일을 생성하고 있습니다..."
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

# X11용 설정을 합니다
echo "X11용 kime 설정을 하고 있습니다..."
# .xprofile 파일을 생성하거나 수정합니다
touch ~/.xprofile
grep -v "GTK_IM_MODULE\|QT_IM_MODULE\|XMODIFIERS" ~/.xprofile > ~/.xprofile.tmp || true
cat >> ~/.xprofile.tmp << 'EOL'
export GTK_IM_MODULE=kime
export QT_IM_MODULE=kime
export XMODIFIERS=@im=kime
EOL
mv ~/.xprofile.tmp ~/.xprofile

# Wayland용 설정을 합니다
echo "Wayland용 kime 설정을 하고 있습니다..."
# .bash_profile 파일을 생성하거나 수정합니다
touch ~/.bash_profile
grep -v "GTK_IM_MODULE\|QT_IM_MODULE\|XMODIFIERS" ~/.bash_profile > ~/.bash_profile.tmp || true
cat >> ~/.bash_profile.tmp << 'EOL'
export GTK_IM_MODULE=kime
export QT_IM_MODULE=kime
export XMODIFIERS=@im=kime
EOL
mv ~/.bash_profile.tmp ~/.bash_profile

# 자동 시작에 kime를 추가합니다
echo "kime를 자동 시작 목록에 추가하고 있습니다..."
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

# kime를 시작합니다
echo "kime를 시작합니다..."
pkill kime || true  # 실행 중인 kime 프로세스가 있다면 종료합니다
kime &

echo "설치가 완료되었습니다! 변경사항을 적용하려면 로그아웃 후 다시 로그인해주세요."
echo "오른쪽 Alt키나 한/영 키를 사용하여 한글/영문 입력을 전환할 수 있습니다."
