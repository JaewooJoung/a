#!/bin/bash

if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

# 1. Show all hard drives
echo "Here are all the hard drives in the system:"
drives=($(lsblk -d -o NAME,SIZE,TYPE | grep disk | nl -w2 -s'. ' | awk '{print $2}'))
lsblk -d -o NAME,SIZE,TYPE | grep disk | nl -w2 -s'. '

# 2. Drive selection
read -p "Please enter the number of the desired hard drive (e.g., 1, 2, etc.): " choice

# 3. Validate selection
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
sgdisk -n 2:0:+8G -t 2:8200 -c 2:"Linux swap" ${DEVICE}
sgdisk -n 3:0:0 -t 3:8300 -c 3:"Linux root" ${DEVICE}

# Wait for kernel to update partition table
sleep 3
partprobe ${DEVICE}
sleep 3

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
    xorg plasma plasma-desktop sddm \
    firefox konsole dolphin dosfstools mtools os-prober --noconfirm
    
# Generate fstab
echo "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

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

# Install and configure bootloader
bootctl install

# Create bootloader configuration
mkdir -p /boot/loader/entries
cat > /boot/loader/loader.conf <<EOF
default arch.conf
timeout 0
console-mode max
editor no
EOF

# Create arch boot entry
cat > /boot/loader/entries/arch.conf <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /${CPU_UCODE}.img
initrd  /initramfs-linux.img
options root=PARTUUID=$(blkid -s PARTUUID -o value ${ROOT_PART}) rw quiet
EOF

# ----------------------------------------------------------------------------
# 데스크탑 및 필수 패키지 설치
pacman -Sy --noconfirm

# 데스크탑 환경
pacman -S --noconfirm \
    xorg xorg-xwayland \
    plasma plasma-desktop plasma-wayland-protocols \
    kde-applications sddm

# 글꼴 및 한국어 지원
pacman -S --noconfirm \
    noto-fonts-cjk noto-fonts-emoji \
    adobe-source-han-sans-kr-fonts adobe-source-han-serif-kr-fonts ttf-baekmuk \
    powerline-fonts nerd-fonts \
    ttf-lato

# 한국어 입력 및 개발 도구
pacman -S --noconfirm \
    libhangul fcitx5 fcitx5-configtool fcitx5-hangul fcitx5-gtk fcitx5-qt

# 시스템 도구
pacman -S --noconfirm \
    efibootmgr dosfstools mtools os-prober \
    zsh zsh-autosuggestions zsh-completions zsh-doc zsh-history-substring-search zsh-lovers zsh-syntax-highlighting zshdb \
    rsync inotify-tools btop tmux kitty

# 개발 및 그래픽 도구
pacman -S --noconfirm \
    vim git autoconf pkg-config \
    imagemagick krita gimp gimp-help-ko \
    tectonic texlive-basic texlive-bibtexextra texlive-bin \
    texlive-binextra texlive-context texlive-doc texlive-fontsextra \
    texlive-fontsrecommended texlive-fontutils texlive-formatsextra \
    texlive-games texlive-humanities texlive-langchinese \
    texlive-langcjk texlive-langkorean texstudio

# Qt6 관련 패키지
pacman -S --noconfirm \
    qgpgme-qt6 appstream-qt qt6-doc qt6-examples qt6-translations qt6-5compat qt6-base qt6-declarative qt6-quick3d qt6-quicktimeline \
    qt6-shadertools qt6-svg qt6-tools qt6-wayland qt6-imageformats qt6-3d qt6-networkauth pyside6 poppler-qt6 \
    python-pyqt6 python-pyqt6-networkauth python-pyqt6-3d python-pyqt6-sip python-qscintilla-qt6 qscintilla-qt6 \
    qtkeychain-qt6 qt6-charts qt6-datavis3d qt6-lottie qt6-scxml qt6-virtualkeyboard python-pyqt6-charts \
    python-pyqt6-datavisualization qca-qt6 qt6-connectivity qt6-multimedia qt6-remoteobjects qt6-sensors \
    qt6-serialbus qt6-serialport qt6-webchannel qt6-webengine qt6-websockets qt6-webview python-pyqt6-webengine \
    qt6-positioning quazip-qt6 qt6-languageserver qt6-httpserver qt6-multimedia-ffmpeg qt6-multimedia-gstreamer \
    qt6-quick3dphysics qt6-speech qt6-grpc qt6-location qt6-quickeffectmaker fcitx-qt6 fcitx5-qt \
    kvantum libfm-qt libqtxdg packagekit-qt6 qt6ct qxlsx-qt6 qxmpp-qt6 polkit-qt6 qt6-graphs phonon-qt6 \
    phonon-qt6-vlc libqaccessibilityclient-qt6 kdsoap-qt6 qtpbfimageplugin-qt6 doublecmd-qt6 lazarus-qt6 \
    qt6pas deepin-qt6platform-plugins deepin-qt6integration qt6-xcb-private-headers plasma5support futuresql \
    libportal-qt6 qcoro python-pyqt6-graphs qt6-connectivity pulseaudio-bluetooth

# 프로그래밍 언어 및 도구
pacman -S --noconfirm \
    julia llvm-julia llvm-julia-libs \
    kotlin lua-stdlib \
    ruby neko \
    go go-tools \
    perl latex2html \
    nodejs nodejs-emojione nodejs-lts-hydrogen nodejs-lts-iron nodejs-material-design-icons nodejs-nopt \
    nodejs-source-map nodejs-yaml npm npm-check-updates \
    rust rust-analyzer rust-bindgen rust-kanban rust-musl rust-script rust-wasm rustic rustlings rustscan rustup \
    rustypaste rustypaste-cli \
    gcc gcc-libs gcc-ada gcc-fortran gcc-objc gcc-go lib32-gcc-libs libgccjit gcc-d gcc-m2 gcc-rust \
    code vscode-css-languageserver vscode-html-languageserver vscode-json-languageserver

# 데이터베이스 관련 패키지
pacman -S --noconfirm \
	mariadb mariadb-clients mariadb-libs mariadb-lts mariadb-lts-clients mariadb-lts-libs \
	sqlite sqlite-analyzer sqlite-doc sqlite-tcl sqlitebrowser vsqlite++ wxsqlite3 ruby-sqlite3 php-sqlite \
	cowsql

# 응용 프로그램
pacman -S --noconfirm \
    firefox thunderbird thunderbird-i18n-ko \
    libreoffice-fresh libreoffice-fresh-ko \
    flatpak remmina opentofu chromium \
    describeimage fortunecraft llm-manager ollama ollama-docs

# 시스템 설정
pacman -S --noconfirm \
    xdg-user-dirs xdg-utils \
    cups cups-pdf nss-mdns \
    gtk3 gtk2 qt5-base qt5-tools qt5-connectivity qt5-sensors\
    sddm sddm-kcm \
    hwloc hwdata lshw ethtool jitterentropy \
    blendr blueberry bluedevil blueman bluetui bluez \
    zsh zsh-autosuggestions zsh-completions zsh-doc zsh-history-substring-search zsh-lovers zsh-syntax-highlighting 

# ----------------------------------------------------------------------------
# Enable basic services
systemctl enable NetworkManager
systemctl enable sddm

# Configure Korean fonts and input method
cd /tmp
sudo -u ${USERNAME} bash <<EOF
# Install AUR fonts
git clone https://aur.archlinux.org/spoqa-han-sans.git
cd spoqa-han-sans
yes | makepkg -si --noconfirm
cd ..

for font in ttf-d2coding ttf-nanum ttf-nanumgothic_coding ttf-kopub ttf-kopubworld; do
    git clone https://aur.archlinux.org/\${font}.git
    cd \${font}
    yes | makepkg -si --noconfirm
    cd ..
done
EOF

# Configure fcitx5
mkdir -p /home/${USERNAME}/.config/fcitx5/conf
mkdir -p /home/${USERNAME}/.config/autostart
mkdir -p /home/${USERNAME}/.local/share/fcitx5/themes

# Create fcitx5 autostart entry
cat > /home/${USERNAME}/.config/autostart/fcitx5.desktop <<EOL
[Desktop Entry]
Name=Fcitx 5
GenericName=Input Method
Comment=Start Input Method
Exec=fcitx5
Icon=fcitx
Terminal=false
Type=Application
Categories=System;Utility;
X-GNOME-Autostart-Phase=Applications
X-GNOME-AutoRestart=false
X-GNOME-Autostart-Notify=false
X-KDE-autostart-after=panel
EOL

# Configure environment variables
cat > /home/${USERNAME}/.pam_environment <<EOL
GTK_IM_MODULE DEFAULT=fcitx5
QT_IM_MODULE  DEFAULT=fcitx5
XMODIFIERS    DEFAULT=\@im=fcitx5
EOL

# Set ownership
chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.config
chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.local
chown ${USERNAME}:${USERNAME} /home/${USERNAME}/.pam_environment

# Generate initramfs
mkinitcpio -P
CHROOT_COMMANDS

# Unmount all partitions
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
