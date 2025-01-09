#!/bin/bash

# 루트 권한 확인
if [ "$EUID" -ne 0 ]; then 
    echo "이 스크립트는 루트 권한으로 실행되어야 합니다."
    exit 1
fi

# 디스크 공간 확인
echo "디스크 공간을 확인합니다..."
FREE_SPACE=$(df / | tail -1 | awk '{print $4}')
REQUIRED_SPACE=70000  # 70MB 이상 필요

if [ "$FREE_SPACE" -lt "$REQUIRED_SPACE" ]; then
    echo "오류: 루트 파티션에 충분한 공간이 없습니다. 최소 70MB 이상 필요합니다."
    echo "현재 사용 가능한 공간: $FREE_SPACE blocks"
    exit 1
fi

# 한국어 지원 설정
echo "한국어 지원을 설정 중입니다..."

# 한국어 폰트 설치
echo "한국어 폰트를 설치합니다..."
pacman -Sy --noconfirm noto-fonts-cjk adobe-source-han-sans-kr-fonts adobe-source-han-serif-kr-fonts ttf-baekmuk

# 폰트 캐시 업데이트
echo "폰트 캐시를 업데이트합니다..."
fc-cache -fv

# 로케일 설정
echo "로케일을 한국어로 설정합니다..."
sed -i '/ko_KR.UTF-8/s/^#//g' /etc/locale.gen
locale-gen
echo "LANG=ko_KR.UTF-8" > /etc/locale.conf
export LANG=ko_KR.UTF-8

# 시간대 설정
echo "시간대를 서울로 설정합니다..."
ln -sf /usr/share/zoneinfo/Asia/Seoul /etc/localtime
hwclock --systohc

# 입력기 설치 (fcitx5)
echo "한국어 입력기를 설치합니다..."
pacman -Sy --noconfirm fcitx5 fcitx5-hangul fcitx5-gtk fcitx5-qt fcitx5-configtool

# 입력기 환경 변수 설정
echo "입력기 환경 변수를 설정합니다..."
mkdir -p /etc/environment.d
cat > /etc/environment.d/fcitx5.conf <<EOF
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
EOF

# 입력기 프로필 설정
mkdir -p /etc/skel/.config/fcitx5
cat > /etc/skel/.config/fcitx5/profile <<EOF
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=hangul

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=hangul
Layout=

[GroupOrder]
0=Default
EOF

# 환경 변수 적용
echo "환경 변수를 적용합니다..."
source /etc/environment.d/fcitx5.conf

# 한국어 입력기 자동 시작 설정
echo "한국어 입력기를 자동 시작으로 설정합니다..."
mkdir -p /etc/xdg/autostart
cat > /etc/xdg/autostart/fcitx5.desktop <<EOF
[Desktop Entry]
Type=Application
Name=fcitx5
Exec=fcitx5
Comment=Korean Input Method
EOF

# 한국어 지원 테스트
echo "한국어 지원 테스트:"
echo "안녕하세요, Arch Linux!"
sleep 2

echo "한국어 지원 설정이 완료되었습니다."
