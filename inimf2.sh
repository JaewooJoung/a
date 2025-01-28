#!/bin/bash
# 단계 0: 기존 입력기 제거
echo "Uninstalling existing input methods..."
sudo pacman -Rns --noconfirm ibus fcitx libhangul nimf
# 단계 1: 의존성 패키지 설치
echo "Installing dependencies..."
sudo pacman -S --needed --noconfirm base-devel git intltool gtk2 gtk3 qt5-base anthy librime m17n-lib libappindicator-gtk3 libxkbcommon wayland libxklavier
# 단계 2: libhangul 빌드 및 설치
echo "Building and installing libhangul..."
if ! pkg-config --exists libhangul; then
    echo "libhangul not found. Building from source..."
    git clone https://github.com/libhangul/libhangul.git
    cd libhangul || { echo "Failed to enter libhangul directory. Exiting..."; exit 1; }
    ./autogen.sh || { echo "autogen.sh failed. Exiting..."; exit 1; }
    ./configure || { echo "configure failed. Exiting..."; exit 1; }
    make || { echo "make failed. Exiting..."; exit 1; }
    sudo make install || { echo "make install failed. Exiting..."; exit 1; }
    sudo ldconfig || { echo "ldconfig failed. Exiting..."; exit 1; }
    cd ..
else
    echo "libhangul is already installed."
fi
# 단계 3: Nimf 저장소 클론
echo "Cloning Nimf repository..."
git clone --recurse-submodules https://github.com/hamonikr/nimf.git
cd nimf || { echo "Failed to enter nimf directory. Exiting..."; exit 1; }
# 단계 4: Nimf 빌드 및 설치
echo "Building and installing Nimf..."
./autogen.sh || { echo "autogen.sh failed. Exiting..."; exit 1; }
make || { echo "make failed. Exiting..."; exit 1; }
sudo make install || { echo "make install failed. Exiting..."; exit 1; }
sudo make update-gtk-im-cache || { echo "update-gtk-im-cache failed. Exiting..."; exit 1; }
sudo make update-gtk-icon-cache || { echo "update-gtk-icon-cache failed. Exiting..."; exit 1; }
sudo ldconfig || { echo "ldconfig failed. Exiting..."; exit 1; }
# 단계 5: Nimf 설정
echo "Configuring Nimf..."
if command -v im-config &> /dev/null; then
    echo "Setting Nimf as the default input method using im-config..."
    im-config -n nimf
else
    echo "im-config not found. Please manually configure Nimf."
fi
# 단계 6: 환경 변수 설정
echo "Setting environment variables..."
{
    echo 'export GTK_IM_MODULE="nimf"'
    echo 'export QT_IM_MODULE="nimf"'
    echo 'export XMODIFIERS="@im=nimf"'
} >> ~/.bashrc
# 쉘 설정 리로드
source ~/.bashrc
# 단계 7: Nimf 시작
echo "Starting Nimf..."
nimf &
# 단계 8: 설치 완료 메시지
echo "Nimf installation and configuration complete!"
echo "You may need to restart your session or applications for changes to take effect."
echo "To debug Nimf, run: nimf --debug"
