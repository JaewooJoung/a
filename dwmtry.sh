#!/bin/bash

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

# Get credentials
while true; do
   read -p "Enter username: " input_username
   if [ -n "$input_username" ]; then
       USERNAME="$input_username"
       break
   fi
done

while true; do
   read -p "Enter hostname: " input_hostname
   if [ -n "$input_hostname" ]; then
       HOSTNAME="$input_hostname"
       break
   fi
done

# Get passwords
while true; do
   read -s -p "Enter root password: " input_root_pass
   echo
   read -s -p "Confirm root password: " input_root_pass2
   echo
   if [ "$input_root_pass" = "$input_root_pass2" ]; then
       ROOT_PASSWORD="$input_root_pass"
       break
   fi
done

while true; do
   read -s -p "Enter user password: " input_user_pass
   echo
   read -s -p "Confirm user password: " input_user_pass2
   echo
   if [ "$input_user_pass" = "$input_user_pass2" ]; then
       USER_PASSWORD="$input_user_pass"
       break
   fi
done

# Set partition variables
if [[ ${DEVICE} == *"nvme"* ]]; then
    EFI_PART="${DEVICE}p1"
    SWAP_PART="${DEVICE}p2"
    ROOT_PART="${DEVICE}p3"
else
    EFI_PART="${DEVICE}1"
    SWAP_PART="${DEVICE}2"
    ROOT_PART="${DEVICE}3"
fi

# Calculate swap size
TOTAL_RAM=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_GB=$((TOTAL_RAM / 1024 / 1024))
SWAP_SIZE=8  # Default to 8GB

# Show installation plan
echo "==========================="
echo "Installation Plan:"
echo "Device: ${DEVICE}"
echo "EFI: ${EFI_PART}"
echo "Swap: ${SWAP_PART} (${SWAP_SIZE}GB)"
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

# Prepare disk
dd if=/dev/zero of=${DEVICE} bs=1M count=100
wipefs -af ${DEVICE}
sgdisk -Z ${DEVICE}
sgdisk -o ${DEVICE}

# Create partitions
sgdisk -n 1:0:+1G -t 1:ef00 -c 1:"EFI System" ${DEVICE}
sgdisk -n 2:0:+${SWAP_SIZE}G -t 2:8200 -c 2:"Linux swap" ${DEVICE}
sgdisk -n 3:0:0 -t 3:8300 -c 3:"Linux root" ${DEVICE}

sleep 3
partprobe ${DEVICE}
sleep 3

# Format and mount
mkfs.fat -F 32 ${EFI_PART}
mkswap ${SWAP_PART}
mkfs.ext4 ${ROOT_PART}

mount ${ROOT_PART} /mnt
mkdir -p /mnt/boot
mount ${EFI_PART} /mnt/boot
swapon ${SWAP_PART}

# Install base system with minimal X11 dependencies
pacstrap -K /mnt base linux linux-firmware base-devel ${CPU_UCODE} \
    networkmanager vim nano git wget curl \
    sudo xorg xorg-server xorg-xinit libx11 libxft libxinerama \
    terminus-font ttf-dejavu ttf-liberation noto-fonts \
    noto-fonts-cjk noto-fonts-emoji adobe-source-han-sans-kr-fonts \
    adobe-source-han-serif-kr-fonts ttf-baekmuk \
    fcitx5 fcitx5-configtool fcitx5-hangul fcitx5-gtk fcitx5-qt \
    base-devel gcc make pkg-config

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# System configuration
arch-chroot /mnt /bin/bash <<CHROOT_COMMANDS
# Set timezone
ln -sf /usr/share/zoneinfo/Asia/Seoul /etc/localtime
hwclock --systohc

# Set locale
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "ko_KR.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set hostname
echo "${HOSTNAME}" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
EOF

# Set passwords
echo "root:${ROOT_PASSWORD}" | chpasswd
useradd -m -G wheel,audio,video,optical,storage -s /bin/bash ${USERNAME}
echo "${USERNAME}:${USER_PASSWORD}" | chpasswd
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel

# Configure bootloader
bootctl install
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

# Setup fcitx5 configuration
mkdir -p /home/${USERNAME}/.config/fcitx5/conf
mkdir -p /home/${USERNAME}/.config/environment.d

# Configure fcitx5 environment variables
cat > /home/${USERNAME}/.config/environment.d/fcitx5.conf <<EOF
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
EOF

# Configure fcitx5 profile
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

# Setup .xinitrc for the user
cat > /home/${USERNAME}/.xinitrc <<EOF
#!/bin/sh

# Start some basic X programs
xrdb ~/.Xresources
xsetroot -cursor_name left_ptr

# Clone and install suckless software from official repositories
cd /home/${USERNAME}
mkdir -p suckless && cd suckless

# Install DWM from latest stable release
wget https://dl.suckless.org/dwm/dwm-6.5.tar.gz
tar xvf dwm-6.5.tar.gz
cd dwm-6.5 && make clean && sudo make install
cd ..

# Install ST terminal from latest stable release
wget https://dl.suckless.org/st/st-0.9.2.tar.gz
tar xvf st-0.9.2.tar.gz
cd st-0.9.2 && make clean && sudo make install
cd ..

# Install dmenu from latest stable release
wget https://dl.suckless.org/tools/dmenu-5.3.tar.gz
tar xvf dmenu-5.3.tar.gz
cd dmenu-5.3 && make clean && sudo make install
cd ..

# Install dwmblocks
git clone https://github.com/torrinfail/dwmblocks.git
cd dwmblocks && make clean && sudo make install
cd ..

# Clean up tarballs
rm dwm-6.5.tar.gz st-0.9.2.tar.gz dmenu-5.3.tar.gz

# Set permissions
chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/suckless

# Start input method
fcitx5 -d &

# Start dwm
dwmblocks &
exec dwm
EOF

chown ${USERNAME}:${USERNAME} /home/${USERNAME}/.xinitrc
chmod +x /home/${USERNAME}/.xinitrc

# Enable NetworkManager
systemctl enable NetworkManager

# Generate initramfs
mkinitcpio -P
CHROOT_COMMANDS

# Unmount
umount -R /mnt

echo "Installation complete!"
echo ""
echo "Post-installation steps:"
echo "1. Power off the computer (not reboot)"
echo "2. Remove the installation media"
echo "3. Boot into the system"
echo "4. Log in as your user"
echo "5. Start X server with 'startx'"
