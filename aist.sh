#!/bin/bash

# 오류 발생시 즉시 종료
set -e
trap '오류가 발생했습니다. 종료합니다...' ERR

# root 사용자 체크
if [ "$EUID" = 0 ]; then
   echo "일반 사용자 권한으로 실행해주세요 (sudo 사용하지 마세요)."
   exit 1
fi

# 시스템 업데이트
echo "시스템을 업데이트하고 있습니다..."
sudo pacman -Syu --noconfirm

# 기본 의존성 패키지 설치
DEPS=(
   noto-fonts-cjk    # 한글 폰트
   cairo             # 그래픽 라이브러리
   cmake             # 빌드 도구
   extra-cmake-modules
   pkg-config
   dbus             # IPC 시스템
   gtk3 gtk4        # GUI 툴킷
   libxcb           # X11 클라이언트
   qt5-base qt6-base # Qt 프레임워크
   base-devel       # 개발 도구
)

echo "필요한 패키지들을 설치하고 있습니다..."
sudo pacman -S --needed --noconfirm "${DEPS[@]}"

# 1. Julia 설치
echo "Julia를 설치하고 있습니다..."
curl -fsSL https://install.julialang.org | sh

# Julia 설치 확인
if command -v juliaup &> /dev/null; then
   echo "Julia가 성공적으로 설치되었습니다"
else
   echo "Julia 설치에 실패했습니다"
   exit 1
fi

# 2. Naver Whale과 한글 오피스 설치
echo "Naver Whale과 한글 오피스를 설치합니다..."
if ! command -v yay &> /dev/null; then
   echo "yay를 먼저 설치합니다..."
   cd /tmp
   git clone https://aur.archlinux.org/yay.git
   cd yay
   makepkg -si --noconfirm
   cd ..
   rm -rf yay
fi

# Whale과 한글 오피스 설치
yay -S naver-whale-stable hoffice --noconfirm

# 설치 확인
for pkg in naver-whale-stable hoffice; do
   if yay -Qi $pkg &> /dev/null; then
       echo "$pkg 설치가 완료되었습니다"
   else
       echo "$pkg 설치에 실패했습니다"
       exit 1
   fi
done

# 3. kime 설치 및 설정
echo "kime 설정을 시작합니다..."
# 기존 kime 제거
sudo pacman -Rns kime kime-bin --noconfirm || true
rm -rf ~/.config/kime || true
yay -S --noconfirm kime-bin

# 설정 파일 백업
backup_date=$(date +%Y%m%d_%H%M%S)
for file in ~/.xprofile ~/.bash_profile; do
   [ -f "$file" ] && cp "$file" "${file}.${backup_date}.bak"
done

# kime 설정
mkdir -p ~/.config/kime
cat > ~/.config/kime/kime.yaml << 'EOL'
log:
version: 1
indicator:
icon_color: "White"
engine:
hangul_keys: ["Hangul", "Alt_R"]    # 한/영 전환키 설정
compose_keys: ["Shift-Space"]
toggle_keys: ["Hangul", "Alt_R"]
xim_preedit_font: [D2Coding, 15.0]  # 입력 폰트
latin_mode_on_press_shift: false
latin_mode_on_press_caps: false
global_category_mode: true
global_hotkeys: []
word_commit: false
commit_key1: "Shift"
commit_key2: "Shift"
EOL

# X11 환경 설정
touch ~/.xprofile
grep -v "GTK_IM_MODULE\|QT_IM_MODULE\|XMODIFIERS" ~/.xprofile > ~/.xprofile.tmp || true
cat >> ~/.xprofile.tmp << 'EOL'
export GTK_IM_MODULE=kime
export QT_IM_MODULE=kime
export XMODIFIERS=@im=kime
EOL
mv ~/.xprofile.tmp ~/.xprofile

# Wayland 환경 설정
touch ~/.bash_profile
grep -v "GTK_IM_MODULE\|QT_IM_MODULE\|XMODIFIERS" ~/.bash_profile > ~/.bash_profile.tmp || true
cat >> ~/.bash_profile.tmp << 'EOL'
export GTK_IM_MODULE=kime
export QT_IM_MODULE=kime
export XMODIFIERS=@im=kime
EOL
mv ~/.bash_profile.tmp ~/.bash_profile

# kime 자동 시작 설정
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

# kime 시작
pkill kime || true
kime &

echo "설치가 완료되었습니다!"
echo "kime 설정을 적용하려면 로그아웃 후 다시 로그인해주세요."
echo "오른쪽 Alt키나 한/영 키로 한글/영문 전환이 가능합니다."
