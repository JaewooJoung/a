#!/bin/bash

# Update the system
sudo pacman -Syu --noconfirm

# Install kime and necessary dependencies
sudo pacman -S --noconfirm kime git base-devel

# Clone the kime repository (optional, for configuration files or additional setup)
git clone https://github.com/Riey/kime.git ~/kime

# Copy the default configuration file to the appropriate location
mkdir -p ~/.config/kime
cp ~/kime/config/kime.yaml ~/.config/kime/

# Enable kime for X11 (if you're using Xorg)
echo "export GTK_IM_MODULE=kime" >> ~/.xprofile
echo "export QT_IM_MODULE=kime" >> ~/.xprofile
echo "export XMODIFIERS=@im=kime" >> ~/.xprofile

# Enable kime for Wayland (if you're using Wayland)
echo "export GTK_IM_MODULE=kime" >> ~/.bash_profile
echo "export QT_IM_MODULE=kime" >> ~/.bash_profile
echo "export XMODIFIERS=@im=kime" >> ~/.bash_profile

# Add kime to autostart (for both X11 and Wayland)
mkdir -p ~/.config/autostart
echo "[Desktop Entry]
Type=Application
Exec=kime
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name[en_US]=kime
Name=kime
Comment[en_US]=Korean Input Method Editor
Comment=Korean Input Method Editor" > ~/.config/autostart/kime.desktop

# Start kime immediately
kime &

echo "kime installation and configuration complete!"
