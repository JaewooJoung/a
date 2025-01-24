#!/bin/bash

# root 권한으로 실행되었는지 확인
if [ "$EUID" -ne 0 ]; then
    echo "root 권한으로 실행해주세요."
    exit 1
fi

# 시스템 업데이트
echo "시스템을 업데이트하는 중..."
pacman -Syu --noconfirm

# Julia 설치
echo "Julia를 설치하는 중..."
pacman -S --noconfirm julia

# Naver Whale 의존성 패키지 설치
echo "Naver Whale 의존성 패키지를 설치하는 중..."
pacman -S --noconfirm alsa-lib gtk3 libcups libxss libxtst nss ttf-liberation xdg-utils

# 일반 사용자 확인
SUDO_USER="${SUDO_USER:-$USER}"
if [ "$SUDO_USER" = "root" ]; then
    echo "일반 사용자 권한으로 실행해주세요 (sudo 사용)"
    exit 1
fi

# yay 설치 (일반 사용자 권한으로)
if ! command -v yay &> /dev/null; then
    echo "yay를 설치하는 중..."
    pacman -S --needed git base-devel --noconfirm
    
    # 임시 디렉토리 생성
    TMP_DIR=$(sudo -u "$SUDO_USER" mktemp -d)
    
    # yay 설치 (일반 사용자 권한으로)
    sudo -u "$SUDO_USER" bash << EOF
        cd "$TMP_DIR"
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si --noconfirm
EOF
    
    # 임시 디렉토리 삭제
    rm -rf "$TMP_DIR"
fi

# Naver Whale 설치 (일반 사용자 권한으로)
echo "Naver Whale을 설치하는 중..."
sudo -u "$SUDO_USER" yay -S naver-whale-stable --noconfirm

# 설치 확인
echo "설치 확인 중..."
if command -v julia &> /dev/null; then
    echo "Julia가 성공적으로 설치되었습니다."
else
    echo "Julia 설치에 실패했습니다."
fi

if command -v whale &> /dev/null; then
    echo "Naver Whale이 성공적으로 설치되었습니다."
else
    echo "Naver Whale 설치에 실패했습니다."
fi

echo "설치가 완료되었습니다!"
