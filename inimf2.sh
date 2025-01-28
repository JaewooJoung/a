#!/bin/bash
# 단계 0: 기존 입력기 제거
echo "기존 입력기를 제거하는 중..."
sudo pacman -Rns --noconfirm ibus fcitx libhangul nimf
# 단계 1: 의존성 패키지 설치
echo "의존성 패키지 설치 중..."
sudo pacman -S --needed --noconfirm base-devel git intltool gtk2 gtk3 qt5-base anthy librime m17n-lib libappindicator-gtk3 libxkbcommon wayland libxklavier
# 단계 2: libhangul 빌드 및 설치
echo "libhangul 빌드 및 설치 중..."
if ! pkg-config --exists libhangul; then
    echo "libhangul을 찾을 수 없습니다. 소스에서 빌드합니다..."
    git clone https://github.com/libhangul/libhangul.git
    cd libhangul || { echo "libhangul 디렉토리 진입 실패. 종료합니다..."; exit 1; }
    ./autogen.sh || { echo "autogen.sh 실패. 종료합니다..."; exit 1; }
    ./configure || { echo "configure 실패. 종료합니다..."; exit 1; }
    make || { echo "make 실패. 종료합니다..."; exit 1; }
    sudo make install || { echo "make install 실패. 종료합니다..."; exit 1; }
    sudo ldconfig || { echo "ldconfig 실패. 종료합니다..."; exit 1; }
    cd ..
else
    echo "libhangul이 이미 설치되어 있습니다."
fi
# 단계 3: Nimf 저장소 클론
echo "Nimf 저장소 클론 중..."
git clone --recurse-submodules https://github.com/hamonikr/nimf.git
cd nimf || { echo "Nimf 디렉토리 진입 실패. 종료합니다..."; exit 1; }
# 단계 4: Nimf 빌드 및 설치
echo "Nimf 빌드 및 설치 중..."
./autogen.sh || { echo "autogen.sh 실패. 종료합니다..."; exit 1; }
make || { echo "make 실패. 종료합니다..."; exit 1; }
sudo make install || { echo "make install 실패. 종료합니다..."; exit 1; }
sudo make update-gtk-im-cache || { echo "update-gtk-im-cache 실패. 종료합니다..."; exit 1; }
sudo make update-gtk-icon-cache || { echo "update-gtk-icon-cache 실패. 종료합니다..."; exit 1; }
sudo ldconfig || { echo "ldconfig 실패. 종료합니다..."; exit 1; }
# 단계 5: Nimf 설정
echo "Nimf 설정 중..."
if command -v im-config &> /dev/null; then
    echo "im-config를 사용하여 Nimf를 기본 입력기로 설정 중..."
    im-config -n nimf
else
    echo "im-config를 찾을 수 없습니다. 자동으로 환경 변수를 설정합니다..."
    {
        echo 'export GTK_IM_MODULE="nimf"'
        echo 'export QT_IM_MODULE="nimf"'
        echo 'export XMODIFIERS="@im=nimf"'
    } >> ~/.bashrc
fi
# 단계 6: 환경 변수 설정
echo "환경 변수 설정 중..."
{
    echo 'export GTK_IM_MODULE="nimf"'
    echo 'export QT_IM_MODULE="nimf"'
    echo 'export XMODIFIERS="@im=nimf"'
} >> ~/.bashrc
# 쉘 설정 새로고침
source ~/.bashrc
# 단계 7: Nimf 시작
echo "Nimf 시작 중..."
nimf &
# 단계 8: 한글 폰트 설치
echo "한글 폰트 설치 중..."
# wget 설치 (미설치 시)
echo "wget 설치 중..."
sudo pacman -S --noconfirm wget
# 폰트 다운로드
echo "폰트 다운로드 중..."
wget https://github.com/JaewooJoung/a/1737776534_fonts.tar.gz
# 폰트 압축 해제
echo "폰트 압축 해제 중..."
tar -xvzf 1737776534_fonts.tar.gz
# 시스템 폰트 디렉토리로 폰트 이동
echo "폰트를 /usr/share/fonts/로 이동 중..."
sudo mv fonts/* /usr/share/fonts/
# 폰트 캐시 업데이트
echo "폰트 캐시 업데이트 중..."
sudo fc-cache -fv
# 설치 확인
echo "설치 확인 중..."
fc-list | grep -i "korean"
# 정리
echo "임시 파일 정리 중..."
rm -rf 1737776534_fonts.tar.gz fonts
# 단계 9: 최종 메시지
echo "Nimf 설치 및 설정이 완료되었습니다!"
echo "한글 폰트가 설치되었습니다."
echo "변경 사항을 적용하려면 세션이나 애플리케이션을 다시 시작해야 할 수 있습니다."
echo "Nimf 디버깅을 하려면 다음 명령어를 실행하세요: nimf --debug"
