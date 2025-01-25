#!/bin/bash

# root 권한으로 실행되었는지 확인
if [ "$EUID" -ne 0 ]; then
    echo "root 권한으로 실행해주세요."
    exit 1
fi

# 시스템 업데이트
echo "시스템을 업데이트하는 중..."
pacman -Syu --noconfirm

# 일반 사용자 확인
SUDO_USER="${SUDO_USER:-$USER}"
if [ "$SUDO_USER" = "root" ]; then
    echo "일반 사용자 권한으로 실행해주세요 (sudo 사용)"
    exit 1
fi

# Julia 설치 (juliaup을 통해)
echo "Julia를 설치하는 중..."
sudo -u "$SUDO_USER" bash -c 'curl -fsSL https://install.julialang.org | sh'

# Naver Whale 설치 (일반 사용자 권한으로)
echo "Naver Whale을 설치하는 중..."
sudo -u "$SUDO_USER" yay -S naver-whale-stable --noconfirm

echo "한글 office 을 설치하는 중..."
sudo -u "$SUDO_USER" yay -S hoffice --noconfirm

# 설치 확인
echo "설치 확인 중..."
if command -v juliaup &> /dev/null; then
    echo "Julia(juliaup)가 성공적으로 설치되었습니다."
else
    echo "Julia 설치에 실패했습니다."
fi

if pacman -Qi naver-whale-stable &> /dev/null; then
    echo "Naver Whale 이 성공적으로 설치되었습니다."
else
    echo "Naver Whale 설치에 실패했습니다."
fi

if pacman -Qi hoffice &> /dev/null; then
    echo "한글 office 가 성공적으로 설치되었습니다."
else
    echo "한글 office 설치에 실패했습니다."
fi

echo "설치가 완료되었습니다!"
echo "Julia를 사용하기 위해 터미널을 재시작하거나 'source ~/.bashrc'를 실행해주세요."
