#!/bin/bash

# Install libhangul-git
echo "Installing libhangul-git..."
git clone https://aur.archlinux.org/libhangul-git.git
cd libhangul-git
makepkg -si
cd ..
rm -rf libhangul-git

# Install nimf
echo "Installing nimf..."
git clone https://github.com/hamonikr/nimf.git
cd nimf
makepkg -si
cd ..
rm -rf nimf

# Configure input method
echo "Configuring input method..."
echo 'export GTK_IM_MODULE=nimf' >> ~/.xprofile
echo 'export QT4_IM_MODULE="nimf"' >> ~/.xprofile
echo 'export QT_IM_MODULE=nimf' >> ~/.xprofile
echo 'export XMODIFIERS="@im=nimf"' >> ~/.xprofile

echo "Setup complete! Please restart your session to apply changes."
