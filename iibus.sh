#!/bin/bash

# Check root privileges
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

# Show all hard drives
clear
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
clear
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
       # If username is "crux", set default values and skip other prompts
       if [ "$USERNAME" = "crux" ]; then
           HOSTNAME="lia"
           ROOT_PASSWORD="1234"
           USER_PASSWORD="1234"
           echo "Default values set for code owner installation 😘."
           break
       fi
       break
   else
       echo "Username cannot be empty. Please try again."
   fi
done

# Only continue with other prompts if username is not "crux"
if [ "$USERNAME" != "crux" ]; then
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
fi

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

# Calculate recommended swap size based on RAM
if [ ${TOTAL_RAM_GB} -le 8 ]; then
    # For RAM ≤ 8GB, use equal swap size
    SWAP_SIZE=${TOTAL_RAM_GB}
elif [ ${TOTAL_RAM_GB} -le 64 ]; then
    # For RAM between 8GB and 64GB, use half the RAM size
    SWAP_SIZE=$((TOTAL_RAM_GB / 2))
else
    # For RAM > 64GB, cap at 32GB swap
    SWAP_SIZE=32
fi

# Set swappiness based on RAM size
if [ ${TOTAL_RAM_GB} -gt 32 ]; then
    SWAPPINESS=10  # Low swappiness for high RAM systems
else
    SWAPPINESS=60  # Higher swappiness for systems with less RAM
fi

# Show installation plan
echo "==========================="
echo "Installation Plan:"
echo "Device: ${DEVICE}"
echo "EFI: ${EFI_PART}"
echo "Swap: ${SWAP_PART}"
echo "Swappiness: ${SWAPPINESS}"
echo "Root: ${ROOT_PART}"
echo "Username: ${USERNAME}"
echo "Hostname: ${HOSTNAME}"
echo "CPU Type: ${CPU_UCODE}"
echo "==========================="
echo "WARNING: This will COMPLETELY ERASE the selected drive!"
echo "Press Ctrl+C within 3 seconds to cancel..."
sleep 3

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
echo "1) KDE Plasma (verified)"
echo "2) GNOME (verified)"
echo "3) XFCE (verified)"
echo "4) Awesome WM (for experts only)"
echo "5) DWM (for experts only)"
echo "6) Cinnamon (verified)"
echo "7) Hyprland (for experts only)"
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
clear
echo "Formatting partitions..."
mkfs.fat -F 32 ${EFI_PART}
mkswap ${SWAP_PART}
mkfs.ext4 ${ROOT_PART}

# Mount partitions
clear
echo "Mounting partitions..."
mount ${ROOT_PART} /mnt
mkdir -p /mnt/boot
mount ${EFI_PART} /mnt/boot
swapon ${SWAP_PART}

# Install base system
clear
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
clear
echo "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# Install selected desktop environment
clear
echo "Installing selected desktop environment..."
arch-chroot /mnt pacman -S --noconfirm ${DE_PACKAGES}

# Enable display manager if applicable
if [[ $DM_SERVICE != "none" ]]; then
    arch-chroot /mnt systemctl enable ${DM_SERVICE}
fi

# Network enabled
arch-chroot /mnt systemctl enable NetworkManager

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

# Configure autologin based on desktop environment selection
case $de_choice in
    1)  # KDE Plasma (SDDM)
        mkdir -p /etc/sddm.conf.d
        cat > /etc/sddm.conf.d/autologin.conf <<EOF
[Autologin]
User=${USERNAME}
Session=plasma.desktop
Relogin=false
EOF
        ;;
        
    2)  # GNOME (GDM)
        mkdir -p /etc/gdm
        cat > /etc/gdm/custom.conf <<EOF
[daemon]
AutomaticLoginEnable=True
AutomaticLogin=${USERNAME}

[security]

[xdmcp]

[chooser]

[debug]
EOF
        ;;
        
    *)  # All other DEs - no autologin configuration
        # They will use default login behavior
        ;;
esac

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
clear
pacman -Sy --noconfirm

# Install Korean fonts and input method
pacman -S --noconfirm \
    noto-fonts-cjk noto-fonts-emoji \
    adobe-source-han-sans-kr-fonts adobe-source-han-serif-kr-fonts ttf-baekmuk \
    powerline-fonts nerd-fonts ttf-lato \
    libhangul fcitx5 fcitx5-configtool fcitx5-hangul fcitx5-gtk fcitx5-qt \
    libreoffice-fresh libreoffice-fresh-ko

# 프로그래밍 언어 및 도구
pacman -S --noconfirm \
    firefox thunderbird thunderbird-i18n-ko \
    flatpak remmina opentofu chromium code \
    describeimage fortunecraft llm-manager ollama ollama-docs ghostty \
    7zip blas64-openblas fftw libblastrampoline libgit2 libunwind libutf8proc lld llvm-julia-libs mbedtls2 openlibm pcre2 suitesparse \
    gnuplot \
    cmake gcc-fortran libwhich llvm-julia patchelf python

# Configure ibus for Korean input
mkdir -p /home/${USERNAME}/.config/ibusd
mkdir -p /home/${USERNAME}/.config/autostart

# Create ibus autostart entry
cat > /home/${USERNAME}/.config/autostart/ibus.desktop <<EOF
[Desktop Entry]
Type=Application
Name=IBus
Comment=Start IBus input method
Exec=ibus-daemon -drx
EOF

# Set environment variables for ibus
mkdir -p /home/${USERNAME}/.config/environment.d
cat > /home/${USERNAME}/.config/environment.d/ibus.conf <<EOF
GTK_IM_MODULE=ibus
QT_IM_MODULE=ibus
XMODIFIERS=@im=ibus
EOF

# Configure ibus preferences
mkdir -p /home/${USERNAME}/.config/ibus/hangul
cat > /home/${USERNAME}/.config/ibus/hangul/config.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<config>
  <engine>
    <name>hangul</name>
    <symbol>ko</symbol>
    <longname>Korean</longname>
    <layout>us</layout>
    <trigger>Shift+Space</trigger>
  </engine>
</config>
EOF

# Set ownership of the config files to the user
chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.config

# Generate initramfs
mkinitcpio -P
CHROOT_COMMANDS

# [Rest of the script remains the same, but update the final echo messages]

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
echo "2. Run 'ibus-setup' to configure input method"
echo "3. Use 'ibus-daemon -drx' to start ibus if not already running"
