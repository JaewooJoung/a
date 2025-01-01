#!/bin/bash

if [ "$EUID" -ne 0 ]; then 
    echo "루트 권한으로 실행해주세요."
    exit 1
fi

# 한국어 지원 패키지 설치
echo "한국어 지원 패키지 설치 중..."
pacman -Sy --noconfirm \
    terminus-font \
    noto-fonts-cjk \
    adobe-source-han-sans-kr-fonts

# 한국어 로케일 설정
echo "ko_KR.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen

# 환경 변수 설정
echo "환경 변수 설정 중..."
{
    echo "export LANG=ko_KR.UTF-8"
    echo "export LC_ALL=ko_KR.UTF-8"
} >> /etc/profile

# 콘솔 폰트 설정
setfont ter-132n

# 확인 메시지
echo "한글 로케일 설정이 완료되었습니다."
echo "한글 출력 테스트 중..."
echo "한글이 제대로 보이면 Enter를 누르세요..."
read -p "계속하려면 Enter를 누르세요..."

# 한국어 출력 테스트
clear
echo "한글 테스트 - Korean Test"
