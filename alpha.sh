#!/bin/bash

# 루트 권한 확인
if [ "$EUID" -ne 0 ]; then 
    echo "이 스크립트는 루트 권한으로 실행되어야 합니다."
    exit 1
fi

# 한국어 지원 설정
echo "한국어 지원을 설정 중입니다..."

# 한국어 폰트 설치
echo "한국어 폰트를 설치합니다..."
pacman -Sy --noconfirm noto-fonts-cjk adobe-source-han-sans-kr-fonts adobe-source-han-serif-kr-fonts ttf-baekmuk

# 로케일 설정
echo "로케일을 한국어로 설정합니다..."
sed -i '/ko_KR.UTF-8/s/^#//g' /etc/locale.gen
locale-gen
echo "LANG=ko_KR.UTF-8" > /etc/locale.conf
export LANG=ko_KR.UTF-8

# 시간대 설정
echo "시간대를 서울로 설정합니다..."
ln -sf /usr/share/zoneinfo/Asia/Seoul /etc/localtime
hwclock --systohc

# 입력기 설치 (fcitx5)
echo "한국어 입력기를 설치합니다..."
pacman -Sy --noconfirm fcitx5 fcitx5-hangul fcitx5-gtk fcitx5-qt fcitx5-configtool

# 입력기 환경 변수 설정
echo "입력기 환경 변수를 설정합니다..."
mkdir -p /etc/environment.d
cat > /etc/environment.d/fcitx5.conf <<EOF
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
EOF

# 입력기 프로필 설정
mkdir -p /etc/skel/.config/fcitx5
cat > /etc/skel/.config/fcitx5/profile <<EOF
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=hangul

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=hangul
Layout=

[GroupOrder]
0=Default
EOF

# 환경 변수 적용
echo "환경 변수를 적용합니다..."
source /etc/environment.d/fcitx5.conf

# 한국어 지원 테스트
echo "한국어 지원 테스트:"
echo "안녕하세요, Arch Linux!"
sleep 2

# 한국어 입력기 자동 시작 설정
echo "한국어 입력기를 자동 시작으로 설정합니다..."
mkdir -p /etc/xdg/autostart
cat > /etc/xdg/autostart/fcitx5.desktop <<EOF
[Desktop Entry]
Type=Application
Name=fcitx5
Exec=fcitx5
Comment=Korean Input Method
EOF

echo "한국어 지원 설정이 완료되었습니다."
echo "이제 스크립트를 계속 실행합니다..."
sleep 2
clear

# ====================================================
# 여기서부터 원래 스크립트 시작
# ====================================================

# Check root privileges
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

# Show all hard drives
echo "Here are all the hard drives in the system:"
drives=($(lsblk -d -o NAME,SIZE,TYPE | grep disk | nl -w2 -s'. ' | awk '{print $2}'))
lsblk -d -o NAME,SIZE,TYPE | grep disk | nl -w2 -s'. '

# Drive selection
read -p "Please enter the number of the desired hard drive (e.g., 1, 2, etc.): " choice

# Validate selection
if [[ $choice -gt 0 && $choice -le ${#drives[@]} ]]; then
    DEVICE="/dev/${drives[$choice-1]}"
    echo "Selected hard drive: $DEVICE"
else
    echo "Invalid number. Exiting..."
    exit 1
fi

# Show CPU type selection
echo "Select your CPU type:"
echo "1. Intel"
echo "2. AMD"
read -p "Enter your choice (1 or 2): " cpu_choice

case $cpu_choice in
    1)
        CPU_UCODE="intel-ucode"
        ;;
    2)
        CPU_UCODE="amd-ucode"
        ;;
    *)
        echo "Invalid choice. Exiting..."
        exit 1
        ;;
esac

# Credentials check 
# Get username
while true; do
   read -p "Enter username: " input_username
   if [ -n "$input_username" ]; then
       USERNAME="$input_username"
       break
   else
       echo "Username cannot be empty. Please try again."
   fi
done

# Get hostname
while true; do
   read -p "Enter hostname: " input_hostname
   if [ -n "$input_hostname" ]; then
       HOSTNAME="$input_hostname"
       break
   else
       echo "Hostname cannot be empty. Please try again."
   fi
done

# Get root password
while true; do
   read -s -p "Enter root password: " input_root_pass
   echo
   read -s -p "Confirm root password: " input_root_pass2
   echo
   
   if [ -z "$input_root_pass" ]; then
       echo "Password cannot be empty. Please try again."
       continue
   fi
   
   if [ "$input_root_pass" = "$input_root_pass2" ]; then
       ROOT_PASSWORD="$input_root_pass"
       break
   else
       echo "Passwords do not match. Please try again."
   fi
done

# Get user password
while true; do
   read -s -p "Enter user password: " input_user_pass
   echo
   read -s -p "Confirm user password: " input_user_pass2
   echo
   
   if [ -z "$input_user_pass" ]; then
       echo "Password cannot be empty. Please try again."
       continue
   fi
   
   if [ "$input_user_pass" = "$input_user_pass2" ]; then
       USER_PASSWORD="$input_user_pass"
       break
   else
       echo "Passwords do not match. Please try again."
   fi
done

# Set partition variables based on device type
if [[ ${DEVICE} == *"nvme"* ]]; then
    EFI_PART="${DEVICE}p1"
    SWAP_PART="${DEVICE}p2"
    ROOT_PART="${DEVICE}p3"
else
    EFI_PART="${DEVICE}1"
    SWAP_PART="${DEVICE}2"
    ROOT_PART="${DEVICE}3"
fi

# Get total RAM and calculate recommended swap size
TOTAL_RAM=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_GB=$((TOTAL_RAM / 1024 / 1024))

# Calculate swap size based on RAM
if [ $TOTAL_RAM_GB -le 2 ]; then
    SWAP_SIZE=4
elif [ $TOTAL_RAM_GB -le 8 ]; then
    SWAP_SIZE=8
elif [ $TOTAL_RAM_GB -le 16 ]; then
    SWAP_SIZE=16
elif [ $TOTAL_RAM_GB -le 64 ]; then
    SWAP_SIZE=16
else
    SWAP_SIZE=32
fi

# Ask user if they want to modify swap size
echo "Recommended swap size based on your RAM (${TOTAL_RAM_GB}GB) is ${SWAP_SIZE}GB"
read -p "Enter desired swap size in GB (press Enter for recommended size): " input_swap_size
if [ -n "$input_swap_size" ]; then
    SWAP_SIZE=$input_swap_size
fi

# Ask for swappiness value
echo "Recommended swappiness:"
echo "- For desktop/laptop with high RAM (>16GB): 10"
echo "- For server or low RAM system: 60"
read -p "Enter desired swappiness value (10-60, default: 10): " input_swappiness
SWAPPINESS=${input_swappiness:-10}

# Show installation plan
echo "==========================="
echo "Installation Plan:"
echo "Device: ${DEVICE}"
echo "EFI: ${EFI_PART}"
echo "Swap: ${SWAP_PART}"
echo "Root: ${ROOT_PART}"
echo "Username: ${USERNAME}"
echo "Hostname: ${HOSTNAME}"
echo "CPU Type: ${CPU_UCODE}"
echo "==========================="
echo "WARNING: This will COMPLETELY ERASE the selected drive!"
echo "Press Ctrl+C within 5 seconds to cancel..."
sleep 5

# Initialize pacman
pacman-key --init
pacman-key --populate archlinux
pacman -Sy archlinux-keyring

# Clean disk
echo "Cleaning disk..."
dd if=/dev/zero of=${DEVICE} bs=1M count=100
dd if=/dev/zero of=${DEVICE} bs=1M seek=$(( $(blockdev --getsz ${DEVICE}) / 2048 - 100)) count=100
wipefs -af ${DEVICE}
sgdisk -Z ${DEVICE}

# Create new GPT
sgdisk -o ${DEVICE}

# Create partitions
sgdisk -n 1:0:+1G -t 1:ef00 -c 1:"EFI System Partition" ${DEVICE}
sgdisk -n 2:0:+${SWAP_SIZE}G -t 2:8200 -c 2:"Linux swap" ${DEVICE}
sgdisk -n 3:0:0 -t 3:8300 -c 3:"Linux root" ${DEVICE}

# Wait for kernel to update partition table
sleep 3
partprobe ${DEVICE}
sleep 3

clear
# Desktop environment selection
echo "Select your desktop environment:"
echo "1) KDE Plasma"
echo "2) GNOME"
echo "3) XFCE"
echo "4) Awesome WM"
echo "5) DWM"
echo "6) Cinnamon"
echo "7) Hyprland"
read -p "Enter your choice (1-7): " de_choice

case $de_choice in
    1)  # KDE Plasma
        DE_PACKAGES="plasma plasma-desktop plasma-wayland-protocols kde-applications sddm"
        DM_SERVICE="sddm"
        ;;
    2)  # GNOME
        DE_PACKAGES="gnome gnome-extra gdm"
        DM_SERVICE="gdm"
        ;;
    3)  # XFCE
        DE_PACKAGES="xfce4 xfce4-goodies lightdm lightdm-gtk-greeter thunar lxsession rxvt-unicode"
        DM_SERVICE="lightdm"
        ;;
    4)  # Awesome WM
        DE_PACKAGES="awesome lightdm lightdm-gtk-greeter thunar"
        DM_SERVICE="lightdm"
        ;;
    5)  # DWM
        DE_PACKAGES="dwm st dmenu ghostty thunar"
        DM_SERVICE="none"
        ;;
    6)  # Cinnamon
        DE_PACKAGES="cinnamon lightdm lightdm-gtk-greeter"
        DM_SERVICE="lightdm"
        ;;
    7)  # Hyprland
        DE_PACKAGES="hyprcursor hyprutils aquamarine hypridle hyprlock hyprland pyprland hyprland-qtutils waybar swaybg swaylock swayidle wlogout mako grim slurp wl-clipboard thunar"
        DM_SERVICE="sddm"
        ;;
    *)
        echo "Invalid choice. Exiting..."
        exit 1
        ;;
esac

# Format partitions
echo "Formatting partitions..."
mkfs.fat -F 32 ${EFI_PART}
mkswap ${SWAP_PART}
mkfs.ext4 ${ROOT_PART}

# Mount partitions
echo "Mounting partitions..."
mount ${ROOT_PART} /mnt
mkdir -p /mnt/boot
mount ${EFI_PART} /mnt/boot
swapon ${SWAP_PART}

# Install base system
echo "Installing base system..."
pacstrap -K /mnt base linux linux-firmware base-devel ${CPU_UCODE} \
    networkmanager terminus-font vim efibootmgr \
    pipewire pipewire-alsa pipewire-pulse pipewire-jack \
    reflector dhcpcd bash-completion \
    sudo btrfs-progs htop pacman-contrib pkgfile less \
    git curl wget zsh openssh man-db \
    xorg xorg-server xorg-apps xorg-drivers xorg-xkill xorg-xinit xterm \
    mesa libx11 libxft libxinerama freetype2 noto-fonts-emoji usbutils xdg-user-dirs \
    konsole bluez bluez-utils blueman --noconfirm

# Generate fstab
echo "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# Install selected desktop environment
echo "Installing selected desktop environment..."
arch-chroot /mnt pacman -S --noconfirm ${DE_PACKAGES}

# Enable display manager if applicable
if [[ $DM_SERVICE != "none" ]]; then
    arch-chroot /mnt systemctl enable ${DM_SERVICE}
fi

# System configuration
arch-chroot /mnt /bin/bash <<CHROOT_COMMANDS
# Set timezone to S.Korea
ln -sf /usr/share/zoneinfo/Asia/Seoul /etc/localtime
hwclock --systohc

# Enable time sync
systemctl enable systemd-timesyncd

# Set locale
echo "ko_KR.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=ko_KR.UTF-8" > /etc/locale.conf
export LANG=ko_KR.UTF-8

# Set hostname
echo "${HOSTNAME}" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
EOF

# Create user and set passwords
echo "root:${ROOT_PASSWORD}" | chpasswd
useradd -m -G wheel,audio,video,optical,storage -s /bin/bash ${USERNAME}
echo "${USERNAME}:${USER_PASSWORD}" | chpasswd
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel

# Install and configure bootloader
bootctl install

mkdir -p /boot/loader/entries
cat > /boot/loader/loader.conf <<EOF
default arch.conf
timeout 0
console-mode max
editor no
EOF

cat > /boot/loader/entries/arch.conf <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /${CPU_UCODE}.img
initrd  /initramfs-linux.img
options root=PARTUUID=$(blkid -s PARTUUID -o value ${ROOT_PART}) rw quiet
EOF

# Install additional packages
pacman -Sy --noconfirm

# Install Korean fonts and input method
pacman -S --noconfirm \
    noto-fonts-cjk noto-fonts-emoji \
    adobe-source-han-sans-kr-fonts adobe-source-han-serif-kr-fonts ttf-baekmuk \
    powerline-fonts nerd-fonts ttf-lato \
    libhangul fcitx5 fcitx5-configtool fcitx5-hangul fcitx5-gtk fcitx5-qt

# 프로그래밍 언어 및 도구
pacman -S --noconfirm \
    firefox thunderbird thunderbird-i18n-ko \
    libreoffice-fresh libreoffice-fresh-ko \
    flatpak remmina opentofu chromium \
    describeimage fortunecraft llm-manager ollama ollama-docs ghostty

# Configure fcitx5
mkdir -p /home/${USERNAME}/.config/fcitx5/conf
mkdir -p /home/${USERNAME}/.config/environment.d

cat > /home/${USERNAME}/.config/environment.d/fcitx5.conf <<EOF
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
EOF

cat > /home/${USERNAME}/.config/fcitx5/profile <<EOF
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=hangul

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=hangul
Layout=

[GroupOrder]
0=Default
EOF

chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.config
echo "vm.swappiness=${SWAPPINESS}" > /etc/sysctl.d/99-swappiness.conf
# Generate initramfs
mkinitcpio -P
CHROOT_COMMANDS

# Unmount partitions
umount -R /mnt

echo "Installation complete!"
echo ""
echo "IMPORTANT POST-INSTALLATION STEPS:"
echo "1. Power off the computer completely (not reboot)"
echo "2. Remove the USB drive"
echo "3. Enter BIOS setup and make these changes:"
echo "   a. Load BIOS defaults first"
echo "   b. Disable Secure Boot"
echo "   c. Set UEFI boot mode (disable CSM/Legacy completely)"
echo "   d. Set Boot Device Priority to ${DEVICE}"
echo ""
echo "After first boot:"
echo "1. Korean input can be toggled with Shift+Space"
echo "2. Run 'fcitx5-configtool' to configure input method"
echo "3. Use 'fcitx5 --debug &' if you need to troubleshoot"
