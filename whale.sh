#!/bin/bash

# 일반 사용자 확인
if [ "$EUID" = 0 ]; then
    echo "일반 사용자 권한으로 실행해주세요 (sudo를 사용하지 마세요)."
    exit 1
fi

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

# Julia 설치 (juliaup을 통해)
echo "Julia를 설치하는 중..."
curl -fsSL https://install.julialang.org | sh

# Naver Whale과 한글 오피스 설치
echo "Naver Whale을 설치하는 중..."
yay -S naver-whale-stable --noconfirm

echo "한글 오피스를 설치하는 중..."
yay -S hoffice --noconfirm

# 설치 확인
echo "설치 확인 중..."
if command -v juliaup &> /dev/null; then
    echo "Julia(juliaup)가 성공적으로 설치되었습니다."
else
    echo "Julia 설치에 실패했습니다."
fi

if yay -Qi naver-whale-stable &> /dev/null; then
    echo "Naver Whale이 성공적으로 설치되었습니다."
else
    echo "Naver Whale 설치에 실패했습니다."
fi

if yay -Qi hoffice &> /dev/null; then
    echo "한글 오피스가 성공적으로 설치되었습니다."
else
    echo "한글 오피스 설치에 실패했습니다."
fi

echo "설치가 완료되었습니다!"
echo "Julia를 사용하기 위해 터미널을 재시작하거나 'source ~/.bashrc'를 실행해주세요."
