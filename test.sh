#!/bin/bash

if [ "$EUID" -ne 0 ]; then 
    echo "root 권한으로 실행해주세요"
    exit 1
fi

# 라이브 환경에서 한글 설정을 위한 패키지 설치
pacman -Sy --noconfirm terminus-font

# 한글 폰트 및 로케일 설정
echo "한글 환경을 설정합니다..."
echo "ko_KR.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
export LANG=ko_KR.UTF-8

# 콘솔 폰트 설정
setfont ter-132n

# 한글 표시 확인
echo "한글 표시 테스트 메시지입니다."
echo "제대로 보이면 계속 진행합니다..."
sleep 3
