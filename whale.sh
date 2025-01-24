#!/bin/bash

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root."
  exit 1
fi

# Update the system
echo "Updating the system..."
pacman -Syu --noconfirm

# Install Julia
echo "Installing Julia..."
curl -fsSL https://install.julialang.org | sh

# Install Naver Whale dependencies using pacman
echo "Installing Naver Whale dependencies..."
pacman -S --noconfirm alsa-lib gtk3 libcups libxss libxtst nss ttf-liberation xdg-utils

# Install yay (AUR helper) if not already installed
if ! command -v yay &> /dev/null; then
  echo "Installing yay..."
  pacman -S --needed git base-devel --noconfirm
  git clone https://aur.archlinux.org/yay.git /tmp/yay
  cd /tmp/yay
  makepkg -si --noconfirm
  cd ~
  rm -rf /tmp/yay
fi

# Install Naver Whale from AUR using yay
echo "Installing Naver Whale..."
yay -S naver-whale-stable smile --noconfirm

# Verify installation
echo "Verifying installations..."
if command -v julia &> /dev/null; then
  echo "Julia installed successfully."
else
  echo "Julia installation failed."
fi

if command -v whale &> /dev/null; then
  echo "Naver Whale installed successfully."
else
  echo "Naver Whale installation failed."
fi

echo "Installation complete!"
