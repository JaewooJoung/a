#!/bin/bash

# =============================================================================
# Arch Linux ARM Installer - Run directly from Raspberry Pi 5
# Installs to NVMe SSD connected via M.2 HAT
# User: crux / Password: 1234
# =============================================================================

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
ARCH_URL="http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-aarch64-latest.tar.gz"
MOUNT_POINT="/mnt/arch"
USERNAME="crux"
USER_PASSWORD="1234"
HOSTNAME="raspberrypi5"

print_header() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║  Arch Linux ARM Installer for Raspberry Pi 5 - NVMe Edition      ║"
    echo "║  Running directly from Pi - Installing to NVMe                    ║"
    echo "║  User: crux / Password: 1234                                      ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() { echo -e "\n${GREEN}[STEP]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_info() { echo -e "${BLUE}[i]${NC} $1"; }

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Please run as root: sudo $0"
        exit 1
    fi
}

check_dependencies() {
    print_step "Checking and installing dependencies..."
    
    # Check if we're on Raspberry Pi OS (Debian-based)
    if command -v apt &> /dev/null; then
        apt update
        apt install -y libarchive-tools parted dosfstools curl wget
    # Or if somehow already on Arch
    elif command -v pacman &> /dev/null; then
        pacman -Sy --noconfirm libarchive parted dosfstools curl wget
    fi
    
    # Verify bsdtar exists
    if ! command -v bsdtar &> /dev/null; then
        print_error "bsdtar not found. Please install libarchive-tools"
        exit 1
    fi
    
    print_success "Dependencies ready"
}

detect_nvme() {
    print_step "Detecting NVMe drive..."
    
    # Check if NVMe exists
    if [ ! -b /dev/nvme0n1 ]; then
        print_error "No NVMe drive detected at /dev/nvme0n1"
        echo ""
        echo "Troubleshooting:"
        echo "1. Check if NVMe is properly seated in M.2 HAT"
        echo "2. Add these lines to /boot/firmware/config.txt and reboot:"
        echo "   dtparam=pciex1"
        echo "   dtparam=pciex1_gen=3"
        echo ""
        echo "Current block devices:"
        lsblk
        exit 1
    fi
    
    NVME_DEVICE="/dev/nvme0n1"
    
    # Show NVMe info
    echo ""
    print_info "Found NVMe device:"
    lsblk "$NVME_DEVICE" -o NAME,SIZE,MODEL
    echo ""
    
    # Get size
    NVME_SIZE=$(lsblk -b -d -o SIZE -n "$NVME_DEVICE")
    NVME_SIZE_GB=$((NVME_SIZE / 1024 / 1024 / 1024))
    
    print_warning "═══════════════════════════════════════════════════════════"
    print_warning "TARGET: $NVME_DEVICE (${NVME_SIZE_GB}GB)"
    print_warning "ALL DATA ON THIS NVME WILL BE PERMANENTLY DESTROYED!"
    print_warning "═══════════════════════════════════════════════════════════"
    echo ""
    read -p "Type 'YES' to confirm installation to NVMe: " confirm
    
    if [ "$confirm" != "YES" ]; then
        print_error "Installation cancelled"
        exit 1
    fi
}

update_eeprom_boot_order() {
    print_step "Checking EEPROM boot order..."
    
    if command -v rpi-eeprom-config &> /dev/null; then
        CURRENT_BOOT_ORDER=$(rpi-eeprom-config | grep BOOT_ORDER || echo "")
        print_info "Current boot config: $CURRENT_BOOT_ORDER"
        
        echo ""
        echo "Recommended boot order: BOOT_ORDER=0xf416"
        echo "  6 = NVMe first"
        echo "  1 = SD card second"  
        echo "  4 = USB third"
        echo "  f = loop/retry"
        echo ""
        read -p "Update EEPROM boot order to prioritize NVMe? (y/n): " update_eeprom
        
        if [ "$update_eeprom" = "y" ]; then
            print_step "Updating EEPROM..."
            
            # Create temp config
            TEMP_CONFIG=$(mktemp)
            rpi-eeprom-config > "$TEMP_CONFIG"
            
            # Update or add BOOT_ORDER
            if grep -q "BOOT_ORDER" "$TEMP_CONFIG"; then
                sed -i 's/BOOT_ORDER=.*/BOOT_ORDER=0xf416/' "$TEMP_CONFIG"
            else
                echo "BOOT_ORDER=0xf416" >> "$TEMP_CONFIG"
            fi
            
            # Ensure PCIE_PROBE is set
            if ! grep -q "PCIE_PROBE" "$TEMP_CONFIG"; then
                echo "PCIE_PROBE=1" >> "$TEMP_CONFIG"
            fi
            
            rpi-eeprom-config --apply "$TEMP_CONFIG"
            rm "$TEMP_CONFIG"
            
            print_success "EEPROM updated - NVMe will be primary boot device"
        fi
    else
        print_warning "rpi-eeprom-config not available"
        print_info "You may need to manually set boot order after installation"
    fi
}

partition_nvme() {
    print_step "Partitioning NVMe drive..."
    
    # Unmount any existing partitions
    umount /dev/nvme0n1* 2>/dev/null || true
    
    # Wipe partition table
    wipefs -a "$NVME_DEVICE" 2>/dev/null || true
    
    # Create GPT partition table
    parted -s "$NVME_DEVICE" mklabel gpt
    
    # Create boot partition (512MB FAT32)
    parted -s "$NVME_DEVICE" mkpart primary fat32 1MiB 513MiB
    parted -s "$NVME_DEVICE" set 1 boot on
    
    # Create root partition (rest of drive)
    parted -s "$NVME_DEVICE" mkpart primary ext4 513MiB 100%
    
    # Wait for kernel to recognize partitions
    sleep 2
    partprobe "$NVME_DEVICE"
    sleep 2
    
    BOOT_PART="${NVME_DEVICE}p1"
    ROOT_PART="${NVME_DEVICE}p2"
    
    # Format partitions
    print_step "Formatting partitions..."
    mkfs.vfat -F 32 -n BOOT "$BOOT_PART"
    mkfs.ext4 -F -L ROOT "$ROOT_PART"
    
    print_success "Partitions created: $BOOT_PART (boot), $ROOT_PART (root)"
}

mount_partitions() {
    print_step "Mounting partitions..."
    
    mkdir -p "$MOUNT_POINT"
    mount "$ROOT_PART" "$MOUNT_POINT"
    mkdir -p "$MOUNT_POINT/boot"
    mount "$BOOT_PART" "$MOUNT_POINT/boot"
    
    print_success "Mounted at $MOUNT_POINT"
}

download_arch() {
    print_step "Downloading Arch Linux ARM..."
    
    cd /tmp
    
    if [ -f "ArchLinuxARM-rpi-aarch64-latest.tar.gz" ]; then
        print_info "Found existing download"
        read -p "Use existing file? (y/n): " use_existing
        if [ "$use_existing" != "y" ]; then
            rm -f ArchLinuxARM-rpi-aarch64-latest.tar.gz
            wget "$ARCH_URL" -O ArchLinuxARM-rpi-aarch64-latest.tar.gz
        fi
    else
        wget "$ARCH_URL" -O ArchLinuxARM-rpi-aarch64-latest.tar.gz
    fi
    
    print_success "Download complete"
}

extract_arch() {
    print_step "Extracting Arch Linux ARM to NVMe (this takes a few minutes)..."
    
    cd /tmp
    bsdtar -xpf ArchLinuxARM-rpi-aarch64-latest.tar.gz -C "$MOUNT_POINT"
    sync
    
    print_success "Extraction complete"
}

configure_boot() {
    print_step "Configuring boot for Raspberry Pi 5..."
    
    # Get PARTUUIDs
    ROOT_PARTUUID=$(blkid -s PARTUUID -o value "$ROOT_PART")
    BOOT_PARTUUID=$(blkid -s PARTUUID -o value "$BOOT_PART")
    
    print_info "ROOT PARTUUID: $ROOT_PARTUUID"
    print_info "BOOT PARTUUID: $BOOT_PARTUUID"
    
    # Create config.txt for Pi 5
    cat > "$MOUNT_POINT/boot/config.txt" << 'EOF'
# Raspberry Pi 5 Configuration for Arch Linux ARM

[all]
arm_64bit=1
kernel=Image
initramfs initramfs-linux.img followkernel
dtb=bcm2712-rpi-5-b.dtb

# UART for debugging
enable_uart=1

# PCIe/NVMe
dtparam=pciex1
dtparam=pciex1_gen=3

# Display
dtoverlay=vc4-kms-v3d
max_framebuffers=2

# Audio
dtparam=audio=on

# Bluetooth
dtparam=krnbt=on

# I2C & SPI
dtparam=i2c_arm=on
dtparam=spi=on

# GPU Memory
gpu_mem=256

# Overscan
disable_overscan=1

# Fan control
dtoverlay=pwm-fan,fan0_temp=50000,fan0_speed=75

# USB power for peripherals
usb_max_current_enable=1
EOF

    # Create cmdline.txt
    cat > "$MOUNT_POINT/boot/cmdline.txt" << EOF
root=PARTUUID=${ROOT_PARTUUID} rw rootwait console=ttyAMA10,115200 console=tty1 fsck.repair=yes
EOF

    # Update fstab
    cat > "$MOUNT_POINT/etc/fstab" << EOF
# Arch Linux ARM fstab
PARTUUID=${ROOT_PARTUUID}   /           ext4    defaults,noatime    0   1
PARTUUID=${BOOT_PARTUUID}   /boot       vfat    defaults,noatime    0   2
EOF

    print_success "Boot configuration complete"
}

create_setup_scripts() {
    print_step "Creating post-boot setup scripts..."

    # =========================================================================
    # MAIN SETUP SCRIPT
    # =========================================================================
    cat > "$MOUNT_POINT/root/setup-pi5.sh" << 'SETUPSCRIPT'
#!/bin/bash
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}       Raspberry Pi 5 - Base System Setup                  ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"

USERNAME="crux"
USER_PASSWORD="1234"

echo -e "\n${BLUE}[1/8]${NC} Initializing pacman keyring..."
pacman-key --init
pacman-key --populate archlinuxarm

echo -e "\n${BLUE}[2/8]${NC} Updating system..."
pacman -Syu --noconfirm

echo -e "\n${BLUE}[3/8]${NC} Installing Pi 5 kernel..."
pacman -S --noconfirm --needed linux-rpi linux-rpi-headers raspberrypi-firmware

echo -e "\n${BLUE}[4/8]${NC} Installing base packages..."
pacman -S --noconfirm --needed \
    base-devel sudo vim nano git htop curl wget \
    networkmanager bluez bluez-utils openssh zsh \
    tmux unzip rsync man-db man-pages

echo -e "\n${BLUE}[5/8]${NC} Enabling services..."
systemctl enable NetworkManager bluetooth sshd systemd-timesyncd

echo -e "\n${BLUE}[6/8]${NC} Creating user: $USERNAME..."
if ! id "$USERNAME" &>/dev/null; then
    useradd -m -G wheel,audio,video,storage,network,users -s /bin/zsh "$USERNAME"
    echo "$USERNAME:$USER_PASSWORD" | chpasswd
fi

echo -e "\n${BLUE}[7/8]${NC} Configuring sudo..."
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel

echo -e "\n${BLUE}[8/8]${NC} Setting locale and timezone..."
sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
sed -i 's/#ko_KR.UTF-8/ko_KR.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
ln -sf /usr/share/zoneinfo/Europe/Stockholm /etc/localtime

# Setup ZRAM
pacman -S --noconfirm --needed zram-generator
cat > /etc/systemd/zram-generator.conf << 'ZRAM'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
ZRAM

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Base setup complete!${NC}"
echo ""
echo "  Next steps:"
echo "  1. Reboot: reboot"
echo "  2. Login as: $USERNAME (password: $USER_PASSWORD)"
echo "  3. Run: sudo /root/setup-hyprland.sh"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
SETUPSCRIPT
    chmod +x "$MOUNT_POINT/root/setup-pi5.sh"

    # =========================================================================
    # HYPRLAND + KIME SETUP SCRIPT  
    # =========================================================================
    cat > "$MOUNT_POINT/root/setup-hyprland.sh" << 'HYPRSCRIPT'
#!/bin/bash
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

USERNAME="crux"
USER_HOME="/home/$USERNAME"

echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}       Hyprland + kime Desktop Setup                       ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"

# Install yay
echo -e "\n${BLUE}[1/6]${NC} Installing yay AUR helper..."
if ! command -v yay &> /dev/null; then
    cd /tmp
    rm -rf yay
    sudo -u "$USERNAME" git clone https://aur.archlinux.org/yay.git
    cd yay
    sudo -u "$USERNAME" makepkg -si --noconfirm
    cd /tmp && rm -rf yay
fi

# Install Wayland/Hyprland packages
echo -e "\n${BLUE}[2/6]${NC} Installing Hyprland and Wayland packages..."
pacman -S --noconfirm --needed \
    wayland wayland-protocols xorg-xwayland \
    hyprland xdg-desktop-portal-hyprland xdg-desktop-portal-wlr \
    hyprpaper hypridle hyprlock waybar wofi rofi-wayland \
    mako kitty foot thunar gvfs polkit-gnome \
    qt5-wayland qt6-wayland pipewire pipewire-pulse wireplumber \
    brightnessctl pavucontrol network-manager-applet blueman \
    wl-clipboard grim slurp cliphist

# Install fonts
echo -e "\n${BLUE}[3/6]${NC} Installing fonts..."
pacman -S --noconfirm --needed \
    ttf-dejavu noto-fonts noto-fonts-cjk noto-fonts-emoji \
    adobe-source-han-sans-kr-fonts adobe-source-han-serif-kr-fonts \
    ttf-jetbrains-mono-nerd

# Install kime
echo -e "\n${BLUE}[4/6]${NC} Installing kime Korean input method..."
sudo -u "$USERNAME" yay -S --noconfirm kime-git 2>/dev/null || {
    echo -e "${YELLOW}kime-git failed, trying kime-bin...${NC}"
    sudo -u "$USERNAME" yay -S --noconfirm kime-bin 2>/dev/null || {
        echo -e "${YELLOW}Using fcitx5-hangul as fallback...${NC}"
        pacman -S --noconfirm fcitx5 fcitx5-gtk fcitx5-qt fcitx5-hangul fcitx5-configtool
    }
}

# Install extra apps
echo -e "\n${BLUE}[5/6]${NC} Installing applications..."
pacman -S --noconfirm --needed firefox chromium mpv neovim

# Create configurations
echo -e "\n${BLUE}[6/6]${NC} Creating configuration files..."

mkdir -p "$USER_HOME/.config/hypr"
cat > "$USER_HOME/.config/hypr/hyprland.conf" << 'HYPRCONF'
# Hyprland config for Pi 5

monitor=,preferred,auto,1

input {
    kb_layout = us,kr
    kb_options = grp:alt_shift_toggle
    follow_mouse = 1
    sensitivity = 0
}

general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(33ccffee)
    col.inactive_border = rgba(595959aa)
    layout = dwindle
}

decoration {
    rounding = 8
    blur { enabled = false }
    drop_shadow = no
}

animations {
    enabled = yes
    animation = windows, 1, 3, default
    animation = fade, 1, 3, default
    animation = workspaces, 1, 2, default
}

# Environment
env = GTK_IM_MODULE,kime
env = QT_IM_MODULE,kime
env = XMODIFIERS,@im=kime
env = XDG_CURRENT_DESKTOP,Hyprland
env = XDG_SESSION_TYPE,wayland

# Autostart
exec-once = waybar
exec-once = mako
exec-once = nm-applet --indicator
exec-once = blueman-applet
exec-once = kime
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1

windowrule = pseudo,fcitx
windowrule = pseudo,kime

# Keybinds
$mainMod = SUPER

bind = $mainMod, Return, exec, kitty
bind = $mainMod, Q, killactive
bind = $mainMod SHIFT, E, exit
bind = $mainMod, E, exec, thunar
bind = $mainMod, D, exec, wofi --show drun
bind = $mainMod, V, togglefloating
bind = $mainMod, F, fullscreen
bind = $mainMod, L, exec, hyprlock

bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5

bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5

bind = $mainMod, left, movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up, movefocus, u
bind = $mainMod, down, movefocus, d

bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow

bind = , XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
bind = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bind = , XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
HYPRCONF

# kime config
mkdir -p "$USER_HOME/.config/kime"
cat > "$USER_HOME/.config/kime/config.yaml" << 'KIMECONF'
daemon:
  modules: [Wayland, Xim, Indicator]

indicator:
  icon_color: Black

engine:
  default_category: Latin
  
  global_hotkeys:
    Hangul:
      behavior: !Toggle [Hangul, Latin]
      result: Consume
    Super-Space:
      behavior: !Toggle [Hangul, Latin]
      result: Consume
    Shift-Space:
      behavior: !Toggle [Hangul, Latin]
      result: Consume

  hangul:
    layout: dubeolsik
    word_commit: false

wayland:
  text_input_v3: true
KIMECONF

# Waybar config
mkdir -p "$USER_HOME/.config/waybar"
cat > "$USER_HOME/.config/waybar/config" << 'WAYBAR'
{
    "layer": "top",
    "height": 28,
    "modules-left": ["hyprland/workspaces"],
    "modules-center": ["clock"],
    "modules-right": ["tray", "network", "bluetooth", "pulseaudio"],
    "clock": { "format": "{:%Y-%m-%d %H:%M}" },
    "network": { "format-wifi": " {signalStrength}%", "format-disconnected": "" },
    "bluetooth": { "format": "", "on-click": "blueman-manager" },
    "pulseaudio": { "format": " {volume}%", "on-click": "pavucontrol" },
    "tray": { "spacing": 10 }
}
WAYBAR

# .zprofile for auto-start
cat > "$USER_HOME/.zprofile" << 'ZPROFILE'
export GTK_IM_MODULE=kime
export QT_IM_MODULE=kime  
export XMODIFIERS=@im=kime
export XDG_CURRENT_DESKTOP=Hyprland
export XDG_SESSION_TYPE=wayland

if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
    exec Hyprland
fi
ZPROFILE

chown -R "$USERNAME:$USERNAME" "$USER_HOME/.config" "$USER_HOME/.zprofile"

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Hyprland + kime setup complete!${NC}"
echo ""
echo "  Reboot and login as crux on tty1"
echo "  Hyprland will start automatically"
echo ""
echo "  Key bindings:"
echo "    SUPER + Return  : Terminal"
echo "    SUPER + D       : App launcher"
echo "    SUPER + Q       : Close window"
echo "    Alt + Shift     : Toggle 한/영"
echo "    Shift + Space   : Toggle 한/영"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
HYPRSCRIPT
    chmod +x "$MOUNT_POINT/root/setup-hyprland.sh"

    # =========================================================================
    # KDE PLASMA ALTERNATIVE
    # =========================================================================
    cat > "$MOUNT_POINT/root/setup-kde.sh" << 'KDESCRIPT'
#!/bin/bash
set -e

USERNAME="crux"

echo "Installing KDE Plasma..."

# Install yay if needed
if ! command -v yay &> /dev/null; then
    cd /tmp && rm -rf yay
    sudo -u "$USERNAME" git clone https://aur.archlinux.org/yay.git
    cd yay && sudo -u "$USERNAME" makepkg -si --noconfirm
    cd /tmp && rm -rf yay
fi

pacman -S --noconfirm --needed \
    plasma-meta kde-applications-meta sddm \
    pipewire pipewire-pulse wireplumber \
    noto-fonts noto-fonts-cjk adobe-source-han-sans-kr-fonts

# Install kime
sudo -u "$USERNAME" yay -S --noconfirm kime-git || \
    pacman -S --noconfirm fcitx5 fcitx5-hangul fcitx5-gtk fcitx5-qt fcitx5-configtool

systemctl enable sddm

# kime env
mkdir -p "/home/$USERNAME/.config/plasma-workspace/env"
cat > "/home/$USERNAME/.config/plasma-workspace/env/kime.sh" << 'ENV'
export GTK_IM_MODULE=kime
export QT_IM_MODULE=kime
export XMODIFIERS=@im=kime
ENV
chmod +x "/home/$USERNAME/.config/plasma-workspace/env/kime.sh"
chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.config"

echo "KDE Plasma installed! Reboot to use."
KDESCRIPT
    chmod +x "$MOUNT_POINT/root/setup-kde.sh"

    print_success "Setup scripts created"
}

cleanup() {
    print_step "Finalizing installation..."
    sync
    umount "$MOUNT_POINT/boot" 2>/dev/null || true
    umount "$MOUNT_POINT" 2>/dev/null || true
    print_success "Done"
}

show_completion() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              INSTALLATION COMPLETE!                               ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    echo "  NEXT STEPS:"
    echo ""
    echo "  1. Reboot into Arch Linux:"
    echo "     sudo reboot"
    echo ""
    echo "  2. Login with default credentials:"
    echo "     Username: alarm"
    echo "     Password: alarm"
    echo "     (Root password: root)"
    echo ""
    echo "  3. Run base setup as root:"
    echo "     su -"
    echo "     /root/setup-pi5.sh"
    echo "     reboot"
    echo ""
    echo "  4. Login as your user:"
    echo "     Username: crux"
    echo "     Password: 1234"
    echo ""
    echo "  5. Install desktop (choose one):"
    echo "     sudo /root/setup-hyprland.sh   # Hyprland + kime"
    echo "     sudo /root/setup-kde.sh        # KDE Plasma + kime"
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    echo -e "${YELLOW}NOTE: Remove any SD card before rebooting to ensure NVMe boot${NC}"
    echo ""
}

# Main
main() {
    print_header
    check_root
    check_dependencies
    detect_nvme
    update_eeprom_boot_order
    partition_nvme
    mount_partitions
    download_arch
    extract_arch
    configure_boot
    create_setup_scripts
    cleanup
    show_completion
}

trap 'print_error "Interrupted"; cleanup; exit 1' INT TERM
main
