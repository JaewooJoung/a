#!/bin/bash

# JSON 파일 생성 함수
create_myarch_json() {
    cat <<EOF > myarch.json
{
    "__separator__": null,
    "config_version": "2.8.6",
    "additional-repositories": [],
    "archinstall-language": "$LANGUAGE",
    "audio_config": {"audio": "pipewire"},
    "bootloader": "Systemd-boot",
    "debug": false,
    "disk_config": {
        "config_type": "default_layout",
        "device_modifications": [
            {
                "device": "$DEVICE",
                "partitions": [
                    {
                        "btrfs": [],
                        "flags": ["boot"],
                        "fs_type": "fat32",
                        "size": {"unit": "MiB", "value": 512},
                        "mount_options": [],
                        "mountpoint": "/boot",
                        "obj_id": "2c3fa2d5-2c79-4fab-86ec-22d0ea1543c0",
                        "start": {"unit": "MiB", "value": 1, "sector_size": {"unit": "B", "value": 512}},
                        "status": "create",
                        "type": "primary"
                    },
                    {
                        "btrfs": [],
                        "flags": [],
                        "fs_type": "ext4",
                        "size": {"unit": "GiB", "value": 20},
                        "mount_options": [],
                        "mountpoint": "/",
                        "obj_id": "3e7018a0-363b-4d05-ab83-8e82d13db208",
                        "start": {"unit": "MiB", "value": 513, "sector_size": {"unit": "B", "value": 512}},
                        "status": "create",
                        "type": "primary"
                    },
                    {
                        "btrfs": [],
                        "flags": [],
                        "fs_type": "ext4",
                        "size": {"unit": "Percent", "value": 100},
                        "mount_options": [],
                        "mountpoint": "/home",
                        "obj_id": "ce58b139-f041-4a06-94da-1f8bad775d3f",
                        "start": {"unit": "GiB", "value": 20, "sector_size": {"unit": "B", "value": 512}},
                        "status": "create",
                        "type": "primary"
                    }
                ],
                "wipe": true
            }
        ]
    },
    "hostname": "$HOSTNAME",
    "kernels": ["linux"],
    "locale_config": {
        "kb_layout": "us",
        "kb_variants": ["kr", "es", "cn", "se"],
        "sys_enc": "UTF-8",
        "sys_lang": "$LOCALE"
    },
    "mirror_config": {
        "mirror-regions": {
            "Australia": ["http://archlinux.mirror.digitalpacific.com.au/\$repo/os/\$arch"]
        }
    },
    "network_config": {
        "type": "manual",
        "nics": [
            {
                "iface": "$SELECTED_INTERFACE",
                "ip": "192.168.1.15/24",
                "dhcp": true,
                "gateway": "192.168.1.1",
                "dns": ["192.168.1.1", "9.9.9.9"]
            }
        ]
    },
    "no_pkg_lookups": false,
    "ntp": true,
    "offline": false,
    "packages": [],
    "parallel downloads": 0,
    "profile_config": {
        "gfx_driver": "All open-source (default)",
        "greeter": "$GREETER",
        "profile": {
            "details": ["$DESKTOP_ENVIRONMENT"],
            "main": "Desktop"
        }
    },
    "script": "guided",
    "silent": false,
    "swap": true,
    "timezone": "$TIMEZONE",
    "version": "2.8.6"
}
EOF
}

# 언어 선택
clear
echo "Select your language:"
echo "1. Korean"
echo "2. English"
echo "3. Spanish"
echo "4. Chinese"
echo "5. Swedish"
read -p "Enter your choice (1-5): " lang_choice

case $lang_choice in
    1)
        LANGUAGE="Korean"
        LOCALE="ko_KR"
        ;;
    2)
        LANGUAGE="English"
        LOCALE="en_US"
        ;;
    3)
        LANGUAGE="Spanish"
        LOCALE="es_ES"
        ;;
    4)
        LANGUAGE="Chinese"
        LOCALE="zh_CN"
        ;;
    5)
        LANGUAGE="Swedish"
        LOCALE="sv_SE"
        ;;
    *)
        echo "Invalid choice. Defaulting to English."
        LANGUAGE="English"
        LOCALE="en_US"
        ;;
esac

# 로케일 선택
clear
echo "Select your locale:"
echo "1. Sweden, Stockholm"
echo "2. South Korea, Seoul"
echo "3. China, Shanghai"
read -p "Enter your choice (1-3): " locale_choice

case $locale_choice in
    1)
        TIMEZONE="Europe/Stockholm"
        ;;
    2)
        TIMEZONE="Asia/Seoul"
        ;;
    3)
        TIMEZONE="Asia/Shanghai"
        ;;
    *)
        echo "Invalid choice. Defaulting to Asia/Seoul."
        TIMEZONE="Asia/Seoul"
        ;;
esac

# 키보드 레이아웃 설정
# 기본값은 영어(us)로 설정하고, 추가로 한국어(kr), 스페인어(es), 중국어(cn), 스웨덴어(se)를 추가합니다.
KEYBOARD_LAYOUT="us"
KEYBOARD_VARIANTS=("kr" "es" "cn" "se")

# 데스크톱 환경 선택
clear
echo "Select your desktop environment:"
echo "1. awesome"
echo "2. bspwm"
echo "3. budgie"
echo "4. cinnamon"
echo "5. cosmic"
echo "6. cutefish"
echo "7. deepin"
echo "8. enlightenment"
echo "9. gnome"
echo "10. hyprland"
echo "11. i3"
echo "12. lxqt"
echo "13. mate"
echo "14. plasma"
echo "15. qtile"
echo "16. sway"
echo "17. wayfire"
echo "18. xfce4"
read -p "Enter your choice (1-18): " de_choice

case $de_choice in
    1)
        DESKTOP_ENVIRONMENT="awesome"
        GREETER="lightdm"
        ;;
    2)
        DESKTOP_ENVIRONMENT="bspwm"
        GREETER="lightdm"
        ;;
    3)
        DESKTOP_ENVIRONMENT="budgie"
        GREETER="gdm"
        ;;
    4)
        DESKTOP_ENVIRONMENT="cinnamon"
        GREETER="lightdm"
        ;;
    5)
        DESKTOP_ENVIRONMENT="cosmic"
        GREETER="gdm"
        ;;
    6)
        DESKTOP_ENVIRONMENT="cutefish"
        GREETER="sddm"
        ;;
    7)
        DESKTOP_ENVIRONMENT="deepin"
        GREETER="lightdm"
        ;;
    8)
        DESKTOP_ENVIRONMENT="enlightenment"
        GREETER="lightdm"
        ;;
    9)
        DESKTOP_ENVIRONMENT="gnome"
        GREETER="gdm"
        ;;
    10)
        DESKTOP_ENVIRONMENT="hyprland"
        GREETER="sddm"
        ;;
    11)
        DESKTOP_ENVIRONMENT="i3"
        GREETER="lightdm"
        ;;
    12)
        DESKTOP_ENVIRONMENT="lxqt"
        GREETER="sddm"
        ;;
    13)
        DESKTOP_ENVIRONMENT="mate"
        GREETER="lightdm"
        ;;
    14)
        DESKTOP_ENVIRONMENT="plasma"
        GREETER="sddm"
        ;;
    15)
        DESKTOP_ENVIRONMENT="qtile"
        GREETER="lightdm"
        ;;
    16)
        DESKTOP_ENVIRONMENT="sway"
        GREETER="sddm"
        ;;
    17)
        DESKTOP_ENVIRONMENT="wayfire"
        GREETER="sddm"
        ;;
    18)
        DESKTOP_ENVIRONMENT="xfce4"
        GREETER="lightdm"
        ;;
    *)
        echo "Invalid choice. Defaulting to KDE Plasma."
        DESKTOP_ENVIRONMENT="plasma"
        GREETER="sddm"
        ;;
esac

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

# 이더넷 인터페이스 선택
clear
echo "Detecting network interfaces..."
INTERFACES=($(ls /sys/class/net | grep -v lo))  # lo (루프백 인터페이스) 제외
if [ ${#INTERFACES[@]} -eq 0 ]; then
    echo "No network interfaces found. Exiting..."
    exit 1
fi

echo "Available network interfaces:"
for i in "${!INTERFACES[@]}"; do
    echo "$((i+1)). ${INTERFACES[$i]}"
done

read -p "Please enter the number of the desired network interface (e.g., 1, 2, etc.): " iface_choice

# 선택 유효성 검사
if [[ $iface_choice -gt 0 && $iface_choice -le ${#INTERFACES[@]} ]]; then
    SELECTED_INTERFACE="${INTERFACES[$iface_choice-1]}"
    echo "Selected network interface: $SELECTED_INTERFACE"
else
    echo "Invalid number. Exiting..."
    exit 1
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
echo "Language: ${LANGUAGE}"
echo "Locale: ${LOCALE}"
echo "Keyboard Layout: ${KEYBOARD_LAYOUT} (with variants: ${KEYBOARD_VARIANTS[@]})"
echo "Desktop Environment: ${DESKTOP_ENVIRONMENT}"
echo "Greeter: ${GREETER}"
echo "Timezone: ${TIMEZONE}"
echo "Network Interface: ${SELECTED_INTERFACE}"
echo "==========================="
echo "WARNING: This will COMPLETELY ERASE the selected drive!"
echo "Press Ctrl+C within 3 seconds to cancel..."
sleep 3

# JSON 파일 생성
create_myarch_json

# archinstall 실행
echo "Running archinstall with myarch.json..."
archinstall --config myarch.json

# 설치 완료 메시지
echo "Installation complete! Please reboot your system."
