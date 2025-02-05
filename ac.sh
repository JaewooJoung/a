#!/bin/bash

# 如果命令执行过程中发生错误，立即终止脚本
# set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检查是否为普通用户
if [ "$EUID" = 0 ]; then
    echo -e "${RED}请以普通用户权限运行（不要使用sudo）。${NC}"
    exit 1
fi

# GPU检测与配置
echo -e "${BLUE}正在检测并配置GPU...${NC}"

detect_gpu() {
    local gpu_info=$(lspci | grep -i 'vga\|3d\|display')
    local gpu_types=()
    
    if echo "$gpu_info" | grep -qi "nvidia"; then
        gpu_types+=("nvidia")
    fi
    if echo "$gpu_info" | grep -qi "intel"; then
        gpu_types+=("intel")
    fi
    if echo "$gpu_info" | grep -qi "amd\|ati"; then
        gpu_types+=("amd")
    fi
    
    if [ ${#gpu_types[@]} -eq 0 ]; then
        echo "1"  # 基本/未知
        return
    fi
    
    if [[ " ${gpu_types[@]} " =~ " nvidia " ]]; then
        echo "4"  # NVIDIA
    elif [[ " ${gpu_types[@]} " =~ " amd " ]]; then
        echo "3"  # AMD
    elif [[ " ${gpu_types[@]} " =~ " intel " ]]; then
        echo "2"  # Intel
    else
        echo "1"  # 基本/未知
    fi
}

GPU_CHOICE=$(detect_gpu)
case $GPU_CHOICE in
    1) 
        GPU_FXE="xf86-video-vesa"
        GPU_TYPE="基本显卡"
        GPU_CONFIG=""
        ;;
    2)
        GPU_FXE="xf86-video-intel vulkan-intel intel-media-driver libva-intel-driver intel-gpu-tools"
        GPU_TYPE="Intel显卡"
        GPU_CONFIG="options i915 enable_fbc=1 enable_psr=2 fastboot=1"
        ;;
    3)
        GPU_FXE="xf86-video-amdgpu vulkan-radeon libva-mesa-driver mesa-vdpau"
        GPU_TYPE="AMD显卡"
        GPU_CONFIG="options amdgpu si_support=1 cik_support=1"
        ;;
    4)
        GPU_FXE="nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings"
        GPU_TYPE="NVIDIA显卡"
        GPU_CONFIG="options nvidia-drm modeset=1"
        ;;
esac

# 安装GPU驱动
echo -e "${BLUE}正在安装GPU驱动: ${GPU_TYPE}...${NC}"
sudo pacman -S --noconfirm ${GPU_FXE} ${GPU_COMMON}

# 应用GPU配置
if [ -n "$GPU_CONFIG" ]; then
    case $GPU_TYPE in
        "Intel显卡")
            echo "$GPU_CONFIG" | sudo tee /etc/modprobe.d/i915.conf > /dev/null
            ;;
        "AMD显卡")
            echo "$GPU_CONFIG" | sudo tee /etc/modprobe.d/amdgpu.conf > /dev/null
            ;;
        "NVIDIA显卡")
            echo "$GPU_CONFIG" | sudo tee /etc/modprobe.d/nvidia.conf > /dev/null
            sudo sed -i 's/^MODULES=(.*)/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
            sudo mkinitcpio -P
            ;;
    esac
fi


# 如果未安装Rust，则安装
if ! command -v rustc &> /dev/null; then
    echo -e "${BLUE}正在安装Rust...${NC}"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
fi

# 如果未安装yay，则安装
if ! command -v yay &> /dev/null; then
    echo -e "${BLUE}正在安装yay...${NC}"
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ..
    rm -rf yay
    echo -e "${GREEN}yay安装完成！${NC}"
fi

# 安装Julia（通过juliaup）
clear
echo -e "${BLUE}正在安装Julia...${NC}"
curl -fsSL https://install.julialang.org | sh

# 安装Naver Whale
clear
echo -e "${BLUE}正在安装baidunetdisk ...${NC}"
yay -S baidunetdisk-bin --noconfirm

# 安装WPS Office（中文版）
clear
echo -e "${BLUE}正在安装WPS Office...${NC}"
yay -S wps-office-cn ttf-d2coding --noconfirm

# 安装sublime、visual-studio-code-bin等
clear
echo -e "${BLUE}正在安装常用软件...${NC}"
yay -S sublime-text-4 visual-studio-code-bin teams teams-for-linux realvnc-vnc-server p3x-onenote-bin unciv-bin snes9x-git freetube github-cli \
        whatsapp-for-linux \
        --noconfirm

# 系统更新
echo -e "${BLUE}正在更新系统...${NC}"
sudo pacman -Syu --noconfirm

# 安装必要的依赖包
echo -e "${BLUE}正在安装依赖包...${NC}"
sudo pacman -S --needed --noconfirm \
    noto-fonts-cjk adobe-source-han-sans-cn-fonts adobe-source-han-serif-cn-fonts \
    cairo cmake extra-cmake-modules pkg-config dbus gtk3 gtk4 libxcb qt5-base \
    qt6-base base-devel fontconfig freetype2 gcc-libs glibc glu harfbuzz \
    harfbuzz-icu libcups libcurl-gnutls openssl-1.1 qt5-x11extras zlib \
    xdg-utils libxkbcommon-x11 qt5-tools transmission-remote-gtk \
    ttf-jetbrains-mono ttf-jetbrains-mono-nerd nodejs npm cronie \
    obs-studio v4l2loopback-dkms virtualbox virtualbox-host-modules-arch \
    nano conky samba net-tools bluez bluez-utils bluedevil 

# 安装fcitx及中文输入法
echo -e "${BLUE}正在安装fcitx及中文输入法...${NC}"
# Install fcitx and input methods (if not already installed)
echo -e "${BLUE}Installing/checking fcitx and input methods...${NC}"
sudo pacman -S --needed --noconfirm \
    fcitx \
    fcitx-im \
    fcitx-configtool \
    fcitx-googlepinyin \
    fcitx-rime \
    fcitx-gtk2 \
    fcitx-gtk3 \
    fcitx-qt5

# Check if fcitx-baidupinyin is installed
if ! pacman -Qs fcitx-baidupinyin > /dev/null; then
    echo -e "${BLUE}Installing fcitx-baidupinyin...${NC}"
    yay -S --noconfirm fcitx-baidupinyin
fi

# Configure environment variables (append if not exists)
echo -e "${BLUE}Configuring environment variables...${NC}"

# Function to add environment variables if they don't exist
add_env_vars() {
    local file=$1
    local vars=(
        "export GTK_IM_MODULE=fcitx"
        "export QT_IM_MODULE=fcitx"
        "export XMODIFIERS=@im=fcitx"
    )
    
    for var in "${vars[@]}"; do
        if ! grep -q "^$var" "$file" 2>/dev/null; then
            echo "$var" >> "$file"
        fi
    done
}

# Add to various config files
add_env_vars ~/.xprofile
add_env_vars ~/.bashrc
[ -f ~/.xinitrc ] && add_env_vars ~/.xinitrc

# Add fcitx autostart if not exists
if ! grep -q "fcitx -d" ~/.xprofile; then
    echo "fcitx -d" >> ~/.xprofile
fi

# Create xorg config for fcitx if not exists
if [ ! -f /etc/X11/xorg.conf.d/30-fcitx.conf ]; then
    echo -e "${BLUE}Creating Xorg configuration for fcitx...${NC}"
    sudo mkdir -p /etc/X11/xorg.conf.d
    sudo tee /etc/X11/xorg.conf.d/30-fcitx.conf > /dev/null << 'EOL'
Section "InputClass"
    Identifier "Fcitx"
    MatchIsKeyboard "on"
    Option "DefaultServerLayout" "fcitx"
EndSection
EOL
fi

# Create autostart entry if not exists
mkdir -p ~/.config/autostart
if [ ! -f ~/.config/autostart/fcitx.desktop ]; then
    cat > ~/.config/autostart/fcitx.desktop << 'EOL'
[Desktop Entry]
Name=Fcitx
Comment=Start Input Method
Exec=fcitx
Icon=fcitx
Terminal=false
Type=Application
Categories=System;
X-GNOME-Autostart-Phase=Applications
X-GNOME-AutoRestart=false
X-GNOME-Autostart-Notify=false
X-KDE-autostart-after=panel
EOL
fi

# Restart fcitx
echo -e "${BLUE}Restarting fcitx...${NC}"
killall fcitx 2>/dev/null
fcitx -d

# Set up default configuration if not exists
mkdir -p ~/.config/fcitx
if [ ! -f ~/.config/fcitx/config ]; then
    cat > ~/.config/fcitx/config << 'EOL'
[Hotkey]
TriggerKey=CTRL_SPACE
SwitchKey=Disabled
EOL
fi

pkill fcitx-configtool 2>/dev/null || true
fcitx-configtool &

# Virtualbox初始设置
sudo modprobe vboxdrv
sudo usermod -aG vboxusers $USER

# 启用蓝牙
sudo systemctl start bluetooth
sudo systemctl enable bluetooth

echo -e "${GREEN}安装完成！${NC}"
echo -e "${GREEN}请重启系统或注销后重新登录以应用更改。${NC}"
echo -e "${GREEN}请重启终端或执行 'source ~/.bashrc' 以使用Julia。${NC}"
echo -e "${GREEN}可以使用fcitx进行中文输入。${NC}"
