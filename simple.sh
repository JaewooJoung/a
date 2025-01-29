#!/bin/bash

# Function to detect GPU
detect_gpu() {
    local gpu_info=$(lspci | grep -i 'vga\|3d\|display')
    if echo "$gpu_info" | grep -qi "nvidia"; then
        echo "4"  # NVIDIA
    elif echo "$gpu_info" | grep -qi "intel"; then
        echo "2"  # Intel
    elif echo "$gpu_info" | grep -qi "amd\|ati"; then
        echo "3"  # AMD
    else
        echo "1"  # Basic/Unknown
    fi
}

# Function to detect CPU
detect_cpu() {
    if lscpu | grep -qi "intel"; then
        echo "1"  # Intel
    elif lscpu | grep -qi "amd"; then
        echo "2"  # AMD
    else
        echo "1"  # Default to Intel if unknown
    fi
}

# Function to get system memory and calculate swap size
calculate_swap() {
    local total_ram=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_ram_gb=$((total_ram / 1024 / 1024))
    
    if [ ${total_ram_gb} -le 8 ]; then
        echo ${total_ram_gb}
    elif [ ${total_ram_gb} -le 64 ]; then
        echo $((total_ram_gb / 2))
    else
        echo 32
    fi
}

# Function to set swappiness based on RAM
set_swappiness() {
    local total_ram_gb=$(($(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 / 1024))
    if [ ${total_ram_gb} -gt 32 ]; then
        echo 10
    else
        echo 60
    fi
}

# Root check
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

# Display available drives
clear
echo "Available drives:"
drives=($(lsblk -d -o NAME,SIZE,TYPE | grep disk | nl -w2 -s'. ' | awk '{print $2}'))
lsblk -d -o NAME,SIZE,TYPE | grep disk | nl -w2 -s'. '

# Drive selection
read -p "Select drive number: " choice
if [[ $choice -gt 0 && $choice -le ${#drives[@]} ]]; then
    DEVICE="/dev/${drives[$choice-1]}"
    echo "Selected: $DEVICE"
else
    echo "Invalid selection. Exiting..."
    exit 1
fi

# Auto-detect CPU and GPU
CPU_CHOICE=$(detect_cpu)
case $CPU_CHOICE in
    1) CPU_UCODE="intel-ucode";;
    2) CPU_UCODE="amd-ucode";;
esac

GPU_CHOICE=$(detect_gpu)
GPU_COMMON="mesa vulkan-icd-loader lib32-mesa libva libvdpau mesa-utils"
case $GPU_CHOICE in
    1) 
        GPU_FXE="xf86-video-vesa"
        GPU_TYPE="Basic Graphics"
        ;;
    2)
        GPU_FXE="xf86-video-intel vulkan-intel intel-media-driver libva-intel-driver intel-gpu-tools"
        GPU_TYPE="Intel Graphics"
        ;;
    3)
        GPU_FXE="xf86-video-amdgpu vulkan-radeon libva-mesa-driver mesa-vdpau"
        GPU_TYPE="AMD Graphics"
        ;;
    4)
        GPU_FXE="nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings"
        GPU_TYPE="NVIDIA Graphics"
        ;;
esac

# Simplified user setup
read -p "Enter username [default: user]: " USERNAME
USERNAME=${USERNAME:-user}

if [ "$USERNAME" = "crux" ]; then
    HOSTNAME="lia"
    ROOT_PASSWORD="1234"
    USER_PASSWORD="1234"
    echo "Default values set for code owner installation."
else
    read -p "Enter hostname [default: archlinux]: " HOSTNAME
    HOSTNAME=${HOSTNAME:-archlinux}
    
    # Password setup with verification
    while true; do
        read -s -p "Enter root password: " ROOT_PASSWORD
        echo
        read -s -p "Confirm root password: " ROOT_PASSWORD2
        echo
        
        [ "$ROOT_PASSWORD" = "$ROOT_PASSWORD2" ] && [ -n "$ROOT_PASSWORD" ] && break
        echo "Passwords don't match or empty. Try again."
    done

    while true; do
        read -s -p "Enter user password: " USER_PASSWORD
        echo
        read -s -p "Confirm user password: " USER_PASSWORD2
        echo
        
        [ "$USER_PASSWORD" = "$USER_PASSWORD2" ] && [ -n "$USER_PASSWORD" ] && break
        echo "Passwords don't match or empty. Try again."
    done
fi

# Partition setup
if [[ ${DEVICE} == *"nvme"* ]]; then
    EFI_PART="${DEVICE}p1"
    SWAP_PART="${DEVICE}p2"
    ROOT_PART="${DEVICE}p3"
else
    EFI_PART="${DEVICE}1"
    SWAP_PART="${DEVICE}2"
    ROOT_PART="${DEVICE}3"
fi

# Calculate swap size and swappiness
SWAP_SIZE=$(calculate_swap)
SWAPPINESS=$(set_swappiness)

# Simplified timezone selection
PS3="Select timezone: "
select TIMEZONE in "Europe/Stockholm" "Asia/Seoul" "Asia/Shanghai" "America/New_York"; do
    if [ -n "$TIMEZONE" ]; then
        break
    fi
done

# Simplified language selection
PS3="Select language: "
select LANG_CHOICE in "Korean" "Swedish" "Chinese" "English US"; do
    if [ -n "$LANG_CHOICE" ]; then
        case $LANG_CHOICE in
            "Korean")
                locale="ko_KR.UTF-8"
                lang_packages="libhangul noto-fonts-cjk noto-fonts-emoji"
                ;;
            "Swedish")
                locale="sv_SE.UTF-8"
                lang_packages="libreoffice-fresh-sv"
                ;;
            "Chinese")
                locale="zh_CN.UTF-8"
                lang_packages="adobe-source-han-sans-cn-fonts"
                ;;
            "English US")
                locale="en_US.UTF-8"
                lang_packages="ttf-liberation"
                ;;
        esac
        break
    fi
done

# Simplified DE selection with automatic display manager
PS3="Select desktop environment: "
select DE_CHOICE in "KDE Plasma" "GNOME" "XFCE" "Cinnamon" "MATE"; do
    if [ -n "$DE_CHOICE" ]; then
        case $DE_CHOICE in
            "KDE Plasma")
                DE_PACKAGES="plasma-meta konsole dolphin ark sddm"
                DM_SERVICE="sddm"
                ;;
            "GNOME")
                DE_PACKAGES="gnome gnome-tweaks gdm"
                DM_SERVICE="gdm"
                ;;
            "XFCE")
                DE_PACKAGES="xfce4 xfce4-goodies lightdm lightdm-gtk-greeter"
                DM_SERVICE="lightdm"
                ;;
            "Cinnamon")
                DE_PACKAGES="cinnamon lightdm lightdm-gtk-greeter"
                DM_SERVICE="lightdm"
                ;;
            "MATE")
                DE_PACKAGES="mate mate-extra lightdm lightdm-gtk-greeter"
                DM_SERVICE="lightdm"
                ;;
        esac
        break
    fi
done

# Installation summary
clear
echo "=== Installation Summary ==="
echo "Device: ${DEVICE}"
echo "Username: ${USERNAME}"
echo "Hostname: ${HOSTNAME}"
echo "CPU Type: ${CPU_UCODE}"
echo "GPU Type: ${GPU_TYPE}"
echo "Desktop: ${DE_CHOICE}"
echo "Timezone: ${TIMEZONE}"
echo "Language: ${locale}"
echo "=========================="
echo "Press Enter to continue or Ctrl+C to cancel..."
read

# Begin installation
echo "Preparing disk..."
wipefs -af ${DEVICE}
sgdisk -Z ${DEVICE}
sgdisk -o ${DEVICE}

# Create partitions
sgdisk -n 1:0:+1G -t 1:ef00 ${DEVICE}
sgdisk -n 2:0:+${SWAP_SIZE}G -t 2:8200 ${DEVICE}
sgdisk -n 3:0:0 -t 3:8300 ${DEVICE}

sleep 3
partprobe ${DEVICE}
sleep 3

# Format partitions
mkfs.fat -F 32 ${EFI_PART}
mkswap ${SWAP_PART}
mkfs.ext4 ${ROOT_PART}

# Mount partitions
mount ${ROOT_PART} /mnt
mkdir -p /mnt/boot
mount ${EFI_PART} /mnt/boot
swapon ${SWAP_PART}

# Install base system
pacstrap -K /mnt base linux linux-firmware base-devel ${CPU_UCODE} \
    networkmanager vim sudo ${DE_PACKAGES} ${GPU_FXE} ${GPU_COMMON} \
    ${lang_packages}

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Configure system
arch-chroot /mnt /bin/bash <<EOF
# Set timezone
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
hwclock --systohc

# Set locale
echo "${locale} UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=${locale}" > /etc/locale.conf

# Set hostname
echo "${HOSTNAME}" > /etc/hostname
echo "127.0.0.1 localhost" > /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 ${HOSTNAME}.localdomain ${HOSTNAME}" >> /etc/hosts

# Set passwords
echo "root:${ROOT_PASSWORD}" | chpasswd
useradd -m -G wheel,audio,video,optical,storage -s /bin/bash ${USERNAME}
echo "${USERNAME}:${USER_PASSWORD}" | chpasswd
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel

# Enable services
systemctl enable NetworkManager
systemctl enable ${DM_SERVICE}

# Install bootloader
bootctl install
echo "default arch.conf" > /boot/loader/loader.conf
echo "timeout 0" >> /boot/loader/loader.conf
echo "editor no" >> /boot/loader/loader.conf

cat > /boot/loader/entries/arch.conf <<BOOT
title Arch Linux
linux /vmlinuz-linux
initrd /${CPU_UCODE}.img
initrd /initramfs-linux.img
options root=PARTUUID=$(blkid -s PARTUUID -o value ${ROOT_PART}) rw quiet
BOOT

# Set swappiness
echo "vm.swappiness=${SWAPPINESS}" > /etc/sysctl.d/99-swappiness.conf

# Configure GPU-specific settings
case ${GPU_TYPE} in
    "Intel Graphics")
        echo "options i915 enable_fbc=1 enable_psr=2 fastboot=1" > /etc/modprobe.d/i915.conf
        ;;
    "AMD Graphics")
        echo "options amdgpu si_support=1 cik_support=1" > /etc/modprobe.d/amdgpu.conf
        ;;
    "NVIDIA Graphics")
        sed -i 's/^MODULES=(.*)/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
        mkinitcpio -P
        ;;
esac
EOF

# Unmount and finish
umount -R /mnt
echo "Installation complete! Please remove installation media and reboot."
