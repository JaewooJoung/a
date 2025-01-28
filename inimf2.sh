#!/bin/bash

# Install Nimf on Arch Linux - Automated Script

# Step 1: Install Dependencies
echo "Installing dependencies..."
sudo pacman -S --needed --noconfirm base-devel git intltool gtk2 gtk3 qt5-base anthy librime m17n-lib libappindicator-gtk3 libxkbcommon wayland libxklavier

# Step 2: Build and Install libhangul
echo "Building and installing libhangul..."
if ! pkg-config --exists libhangul; then
    echo "libhangul not found. Building from source..."
    git clone https://github.com/libhangul/libhangul.git
    cd libhangul || { echo "Failed to enter libhangul directory. Exiting..."; exit 1; }
    ./autogen.sh || { echo "autogen.sh failed. Exiting..."; exit 1; }
    ./configure || { echo "configure failed. Exiting..."; exit 1; }
    make || { echo "make failed. Exiting..."; exit 1; }
    sudo make install || { echo "make install failed. Exiting..."; exit 1; }
    sudo ldconfig || { echo "ldconfig failed. Exiting..."; exit 1; }
    cd ..
else
    echo "libhangul is already installed."
fi

# Step 3: Clone the Nimf Repository
echo "Cloning Nimf repository..."
git clone --recurse-submodules https://github.com/hamonikr/nimf.git
cd nimf || { echo "Failed to enter nimf directory. Exiting..."; exit 1; }

# Step 4: Build and Install Nimf
echo "Building and installing Nimf..."
./autogen.sh || { echo "autogen.sh failed. Exiting..."; exit 1; }
make || { echo "make failed. Exiting..."; exit 1; }
sudo make install || { echo "make install failed. Exiting..."; exit 1; }
sudo make update-gtk-im-cache || { echo "update-gtk-im-cache failed. Exiting..."; exit 1; }
sudo make update-gtk-icon-cache || { echo "update-gtk-icon-cache failed. Exiting..."; exit 1; }
sudo ldconfig || { echo "ldconfig failed. Exiting..."; exit 1; }

# Step 5: Configure Nimf
echo "Configuring Nimf..."
if command -v im-config &> /dev/null; then
    echo "Setting Nimf as the default input method using im-config..."
    im-config -n nimf
else
    echo "im-config not found. Please manually configure Nimf."
fi

# Step 6: Set Environment Variables
echo "Setting environment variables..."
{
    echo 'export GTK_IM_MODULE="nimf"'
    echo 'export QT_IM_MODULE="nimf"'
    echo 'export XMODIFIERS="@im=nimf"'
} >> ~/.bashrc

# Reload shell configuration
source ~/.bashrc

# Step 7: Start Nimf
echo "Starting Nimf..."
nimf &

# Step 8: Final Message
echo "Nimf installation and configuration complete!"
echo "You may need to restart your session or applications for changes to take effect."
echo "To debug Nimf, run: nimf --debug"
