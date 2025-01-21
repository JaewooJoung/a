#!/bin/bash

# 루트 권한 확인
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

# 모든 하드 드라이브 표시
clear
echo "Here are all the hard drives in the system:"
drives=($(lsblk -d -o NAME,SIZE,TYPE | grep disk | nl -w2 -s'. ' | awk '{print $2}'))
lsblk -d -o NAME,SIZE,TYPE | grep disk | nl -w2 -s'. '

# 드라이브 선택
read -p "Please enter the number of the desired hard drive (e.g., 1, 2, etc.): " choice

# 선택 유효성 검사
if [[ $choice -gt 0 && $choice -le ${#drives[@]} ]]; then
    DEVICE="/dev/${drives[$choice-1]}"
    echo "Selected hard drive: $DEVICE"
else
    echo "Invalid number. Exiting..."
    exit 1
fi

# CPU 유형 선택 표시
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

# 사용자 정보 확인
# 사용자 이름 받기
while true; do
   read -p "Enter username: " input_username
   if [ -n "$input_username" ]; then
       USERNAME="$input_username"
       # 사용자 이름이 "crux"인 경우 기본값 설정 및 다른 프롬프트 건너뛰기
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

# 사용자 이름이 "crux"가 아닌 경우에만 계속 진행
if [ "$USERNAME" != "crux" ]; then
    # 호스트명 받기
    while true; do
       read -p "Enter hostname: " input_hostname
       if [ -n "$input_hostname" ]; then
           HOSTNAME="$input_hostname"
           break
       else
           echo "Hostname cannot be empty. Please try again."
       fi
    done

    # 루트 비밀번호 받기
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

    # 사용자 비밀번호 받기
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

# 장치 유형에 따른 파티션 변수 설정
if [[ ${DEVICE} == *"nvme"* ]]; then
    EFI_PART="${DEVICE}p1"
    SWAP_PART="${DEVICE}p2"
    ROOT_PART="${DEVICE}p3"
else
    EFI_PART="${DEVICE}1"
    SWAP_PART="${DEVICE}2"
    ROOT_PART="${DEVICE}3"
fi

# 총 RAM 확인 및 권장 스왑 크기 계산
TOTAL_RAM=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_GB=$((TOTAL_RAM / 1024 / 1024))

# RAM 기반 권장 스왑 크기 계산
if [ ${TOTAL_RAM_GB} -le 8 ]; then
    # RAM ≤ 8GB인 경우, 동일한 스왑 크기 사용
    SWAP_SIZE=${TOTAL_RAM_GB}
elif [ ${TOTAL_RAM_GB} -le 64 ]; then
    # RAM이 8GB에서 64GB 사이인 경우, RAM 크기의 절반 사용
    SWAP_SIZE=$((TOTAL_RAM_GB / 2))
else
    # RAM > 64GB인 경우, 32GB 스왑으로 제한
    SWAP_SIZE=32
fi

# RAM 크기에 따른 스왑성 설정
if [ ${TOTAL_RAM_GB} -gt 32 ]; then
    SWAPPINESS=10  # 높은 RAM 시스템의 경우 낮은 스왑성
else
    SWAPPINESS=60  # 낮은 RAM 시스템의 경우 높은 스왑성
fi

# 설치 계획 표시
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

# pacman 초기화
pacman-key --init
pacman-key --populate archlinux
pacman -Sy archlinux-keyring

# 디스크 정리
echo "Cleaning disk..."
dd if=/dev/zero of=${DEVICE} bs=1M count=100
dd if=/dev/zero of=${DEVICE} bs=1M seek=$(( $(blockdev --getsz ${DEVICE}) / 2048 - 100)) count=100
wipefs -af ${DEVICE}
sgdisk -Z ${DEVICE}

# 새 GPT 생성
sgdisk -o ${DEVICE}

# 파티션 생성
sgdisk -n 1:0:+1G -t 1:ef00 -c 1:"EFI System Partition" ${DEVICE}
sgdisk -n 2:0:+${SWAP_SIZE}G -t 2:8200 -c 2:"Linux swap" ${DEVICE}
sgdisk -n 3:0:0 -t 3:8300 -c 3:"Linux root" ${DEVICE}

# 커널이 파티션 테이블을 업데이트할 때까지 대기
sleep 3
partprobe ${DEVICE}
sleep 3

clear
# 데스크톱 환경 선택
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

# 파티션 포맷
clear
echo "Formatting partitions..."
mkfs.fat -F 32 ${EFI_PART}
mkswap ${SWAP_PART}
mkfs.ext4 ${ROOT_PART}

# 파티션 마운트
clear
echo "Mounting partitions..."
mount ${ROOT_PART} /mnt
mkdir -p /mnt/boot
mount ${EFI_PART} /mnt/boot
swapon ${SWAP_PART}

# 기본 시스템 설치
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

# fstab 생성
clear
echo "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# 선택한 데스크톱 환경 설치
clear
echo "Installing selected desktop environment..."
arch-chroot /mnt pacman -S --noconfirm ${DE_PACKAGES}

# 해당되는 경우 디스플레이 매니저 활성화
if [[ $DM_SERVICE != "none" ]]; then
    arch-chroot /mnt systemctl enable ${DM_SERVICE}
fi

# 네트워크 활성화
arch-chroot /mnt systemctl enable NetworkManager

# 시스템 구성
arch-chroot /mnt /bin/bash <<CHROOT_COMMANDS
# 시간대를 대한민국으로 설정
ln -sf /usr/share/zoneinfo/Asia/Seoul /etc/localtime
hwclock --systohc

# 시간 동기화 활성화
systemctl enable systemd-timesyncd

# 로케일 설정
echo "ko_KR.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=ko_KR.UTF-8" > /etc/locale.conf

# 호스트명 설정
echo "${HOSTNAME}" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
EOF

# 사용자 생성 및 비밀번호 설정
echo "root:${ROOT_PASSWORD}" | chpasswd
useradd -m -G wheel,audio,video,optical,storage -s /bin/bash ${USERNAME}
echo "${USERNAME}:${USER_PASSWORD}" | chpasswd
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel

# 데스크톱 환경 선택에 따른 자동 로그인 구성
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
        
    *)  # 다른 모든 DE - 자동 로그인 구성 없음
        # 기본 로그인 동작 사용
        ;;
esac

# 부트로더 설치 및 구성
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

# 추가 패키지 설치
clear
pacman -Sy --noconfirm

# 한글 폰트 및 입력기 설치
pacman -S --noconfirm \
    noto-fonts-cjk noto-fonts-emoji \
    adobe-source-han-sans-kr-fonts adobe-source-han-serif-kr-fonts ttf-baekmuk \
    powerline
