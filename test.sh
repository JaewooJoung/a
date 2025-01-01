#!/bin/bash

if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

# Install Korean language support in live environment
echo "Installing Korean language support..."
pacman -Sy --noconfirm \
    terminus-font \
    noto-fonts-cjk \
    adobe-source-han-sans-kr-fonts

# Set up Korean locale
echo "ko_KR.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
export LANG=ko_KR.UTF-8

# Set console font that supports Korean
setfont noto-fonts-cjk

# Test Korean display
echo "한글 테스트 - Korean Test"
echo "제대로 보이면 Enter를 누르세요..."
read -p "Press Enter to continue..."
