#!/bin/bash

# =============================================================================
# Arch Linux ARM Installer for Raspberry Pi 5 with NVMe SSD
# Includes: Hyprland (primary) or KDE Plasma (fallback), kime Korean IME
# User: crux / Password: 1234
# =============================================================================
# 
# IMPORTANT: Since you don't have a micro SD card, you have TWO options:
#
# OPTION A: Use a USB NVMe enclosure (RECOMMENDED)
#   1. Put your NVMe SSD in a USB-to-NVMe enclosure
#   2. Connect to your Linux PC
#   3. Run this script on your Linux PC
#   4. Transfer NVMe to Pi 5's M.2 HAT/base
#   5. Boot Pi 5 directly from NVMe
#
# OPTION B: Use Raspberry Pi Network Boot (more complex)
#   1. Use another Pi or a bootable USB with Raspberry Pi OS
#   2. Configure EEPROM for network boot
#   3. Flash NVMe from there
#
# This script is designed for OPTION A
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
MOUNT_POINT="/mnt/archpi5"
USERNAME="crux"
USER_PASSWORD="1234"
ROOT_PASSWORD="1234"
HOSTNAME="raspberrypi5"

print_header() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║  Arch Linux ARM for Raspberry Pi 5 - NVMe + Hyprland + kime      ║"
    echo "║  User: crux / Password: 1234                                      ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "\n${GREEN}[STEP]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Please run as root (use sudo)"
        exit 1
    fi
}

check_commands() {
    local commands=("wget" "fdisk" "mkfs.vfat" "mkfs.ext4" "bsdtar" "sync" "blkid" "parted")
    local missing=()
    
    for cmd in "${commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        print_error "Missing required commands: ${missing[*]}"
        echo ""
        echo "On Arch Linux: sudo pacman -S wget dosfstools e2fsprogs libarchive parted"
        echo "On Ubuntu/Debian: sudo apt install wget dosfstools e2fsprogs libarchive-tools parted"
        exit 1
    fi
}

show_installation_options() {
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                    INSTALLATION OPTIONS                           ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Since you don't have a micro SD card, here are your options:"
    echo ""
    echo -e "${GREEN}Option A: USB NVMe Enclosure (RECOMMENDED)${NC}"
    echo "  1. Place your NVMe SSD in a USB-to-NVMe enclosure"
    echo "  2. Connect to this Linux machine"
    echo "  3. Run this script to install Arch Linux ARM directly to NVMe"
    echo "  4. Move NVMe to your Pi 5's M.2 HAT/Base"
    echo "  5. Pi 5 will boot directly from NVMe (default boot order supports this)"
    echo ""
    echo -e "${YELLOW}Option B: Another Raspberry Pi or USB Boot${NC}"
    echo "  1. Boot Pi 5 with Raspberry Pi OS from USB stick"
    echo "  2. Connect NVMe via HAT"
    echo "  3. Run installation from there"
    echo ""
    echo -e "${BLUE}Note: Pi 5's default BOOT_ORDER is 0xf461 which tries:${NC}"
    echo "  1. SD card first (if present)"
    echo "  2. NVMe second"
    echo "  3. USB third"
    echo "  4. Network last"
    echo ""
    echo "So with NO SD card, it will automatically try NVMe boot!"
    echo ""
    read -p "Press Enter to continue with the installation..."
}

select_nvme_device() {
    print_step "Available storage devices:"
    echo ""
    lsblk -d -o NAME,SIZE,MODEL,TYPE | grep -E '^(sd|nvme|mmcblk)' || true
    echo ""
    
    # Try to auto-detect NVMe
    NVME_DEVICES=$(lsblk -d -o NAME | grep nvme || true)
    if [ -n "$NVME_DEVICES" ]; then
        print_info "Detected NVMe device(s): $NVME_DEVICES"
    fi
    
    read -p "Enter NVMe device (e.g., /dev/nvme0n1 or /dev/sda for USB enclosure): " NVME_DEVICE
    
    if [ ! -b "$NVME_DEVICE" ]; then
        print_error "Device $NVME_DEVICE does not exist or is not a block device"
        exit 1
    fi
    
    # Get device size
    DEVICE_SIZE=$(lsblk -b -d -o SIZE -n "$NVME_DEVICE")
    DEVICE_SIZE_GB=$((DEVICE_SIZE / 1024 / 1024 / 1024))
    
    echo ""
    print_warning "═══════════════════════════════════════════════════════════"
    print_warning "SELECTED DEVICE: $NVME_DEVICE (${DEVICE_SIZE_GB}GB)"
    print_warning "ALL DATA ON THIS DEVICE WILL BE PERMANENTLY DESTROYED!"
    print_warning "═══════════════════════════════════════════════════════════"
    echo ""
    read -p "Type 'YES' (uppercase) to confirm: " confirm
    
    if [ "$confirm" != "YES" ]; then
        print_error "Operation cancelled"
        exit 1
    fi
}

partition_nvme() {
    print_step "Partitioning NVMe drive..."
    
    # Unmount any mounted partitions
    umount ${NVME_DEVICE}* 2>/dev/null || true
    
    # Wipe existing partition table
    wipefs -a "$NVME_DEVICE" 2>/dev/null || true
    
    # Create GPT partition table with parted
    parted -s "$NVME_DEVICE" mklabel gpt
    
    # Create boot partition (512MB FAT32)
    parted -s "$NVME_DEVICE" mkpart primary fat32 1MiB 513MiB
    parted -s "$NVME_DEVICE" set 1 boot on
    
    # Create root partition (rest of the drive)
    parted -s "$NVME_DEVICE" mkpart primary ext4 513MiB 100%
    
    # Wait for partitions to appear
    sleep 2
    partprobe "$NVME_DEVICE"
    sleep 2
    
    # Determine partition naming
    if [[ "$NVME_DEVICE" == *"nvme"* ]]; then
        BOOT_PART="${NVME_DEVICE}p1"
        ROOT_PART="${NVME_DEVICE}p2"
    else
        BOOT_PART="${NVME_DEVICE}1"
        ROOT_PART="${NVME_DEVICE}2"
    fi
    
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
    
    print_success "Partitions mounted at $MOUNT_POINT"
}

download_and_extract_arch() {
    print_step "Downloading Arch Linux ARM..."
    
    cd /tmp
    
    if [ -f "ArchLinuxARM-rpi-aarch64-latest.tar.gz" ]; then
        read -p "Found existing tarball. Use it? (y/n): " use_existing
        if [ "$use_existing" != "y" ]; then
            wget -c "$ARCH_URL" -O ArchLinuxARM-rpi-aarch64-latest.tar.gz
        fi
    else
        wget -c "$ARCH_URL" -O ArchLinuxARM-rpi-aarch64-latest.tar.gz
    fi
    
    print_step "Extracting Arch Linux ARM to NVMe..."
    bsdtar -xpf ArchLinuxARM-rpi-aarch64-latest.tar.gz -C "$MOUNT_POINT"
    sync
    
    print_success "Arch Linux ARM extracted"
}

configure_boot() {
    print_step "Configuring boot for Raspberry Pi 5..."
    
    # Get PARTUUIDs
    ROOT_PARTUUID=$(blkid -s PARTUUID -o value "$ROOT_PART")
    BOOT_PARTUUID=$(blkid -s PARTUUID -o value "$BOOT_PART")
    ROOT_UUID=$(blkid -s UUID -o value "$ROOT_PART")
    BOOT_UUID=$(blkid -s UUID -o value "$BOOT_PART")
    
    print_info "ROOT PARTUUID: $ROOT_PARTUUID"
    print_info "BOOT PARTUUID: $BOOT_PARTUUID"
    
    # Create config.txt for Pi 5
    cat > "$MOUNT_POINT/boot/config.txt" << 'EOF'
# Raspberry Pi 5 Configuration for Arch Linux ARM

[all]
# 64-bit mode
arm_64bit=1

# Use RPi kernel (not U-Boot)
kernel=Image
initramfs initramfs-linux.img followkernel

# Device tree for Pi 5
dtb=bcm2712-rpi-5-b.dtb

# Enable UART for debugging
enable_uart=1

# Enable PCIe for NVMe SSD
dtparam=pciex1
dtparam=pciex1_gen=3

# Enable DRM VC4 V3D driver
dtoverlay=vc4-kms-v3d
max_framebuffers=2

# Audio
dtparam=audio=on

# Bluetooth
dtparam=krnbt=on

# WiFi (Pi 5 doesn't have built-in WiFi, but enable for USB adapters)
# dtoverlay=disable-wifi

# I2C
dtparam=i2c_arm=on

# SPI
dtparam=spi=on

# GPU Memory
gpu_mem=256

# Disable overscan
disable_overscan=1

# HDMI settings (adjust as needed)
# hdmi_force_hotplug=1
# hdmi_group=2
# hdmi_mode=82

# Fan control (for active cooler)
dtoverlay=pwm-fan,fan0_temp=50000,fan0_speed=75

# Camera (if using)
# dtoverlay=imx708

# Optional: USB power (for peripherals)
usb_max_current_enable=1
EOF

    # Create cmdline.txt
    cat > "$MOUNT_POINT/boot/cmdline.txt" << EOF
root=PARTUUID=${ROOT_PARTUUID} rw rootwait console=ttyAMA10,115200 console=tty1 fsck.repair=yes
EOF

    # Update fstab
    cat > "$MOUNT_POINT/etc/fstab" << EOF
# Static information about the filesystems.
# See fstab(5) for details.

# <file system> <dir> <type> <options> <dump> <pass>
PARTUUID=${ROOT_PARTUUID}   /           ext4    defaults,noatime    0   1
PARTUUID=${BOOT_PARTUUID}   /boot       vfat    defaults,noatime    0   2
EOF

    print_success "Boot configuration completed"
}

create_post_install_script() {
    print_step "Creating post-installation setup scripts..."
    
    # Main setup script
    cat > "$MOUNT_POINT/root/setup-pi5.sh" << 'SETUP_SCRIPT'
#!/bin/bash

# =============================================================================
# Raspberry Pi 5 Post-Installation Setup Script
# Run this after first boot as root
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_step() {
    echo -e "\n${GREEN}[STEP]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Configuration
USERNAME="crux"
USER_PASSWORD="1234"
HOSTNAME="raspberrypi5"

echo -e "${CYAN}"
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║       Raspberry Pi 5 - Post-Installation Setup                    ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Initialize pacman keyring
print_step "Initializing pacman keyring..."
pacman-key --init
pacman-key --populate archlinuxarm

# Update system
print_step "Updating system..."
pacman -Syu --noconfirm

# Install Pi 5 optimized kernel
print_step "Installing Raspberry Pi 5 optimized packages..."
pacman -S --noconfirm --needed linux-rpi linux-rpi-headers raspberrypi-firmware

# Install base packages
print_step "Installing base system packages..."
pacman -S --noconfirm --needed \
    base-devel \
    sudo \
    vim \
    nano \
    git \
    htop \
    curl \
    wget \
    networkmanager \
    bluez \
    bluez-utils \
    openssh \
    zsh \
    tmux \
    tree \
    unzip \
    p7zip \
    rsync \
    man-db \
    man-pages

# Enable essential services
print_step "Enabling essential services..."
systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable sshd
systemctl enable systemd-resolved
systemctl enable systemd-timesyncd

# Create user
print_step "Creating user: $USERNAME..."
if ! id "$USERNAME" &>/dev/null; then
    useradd -m -G wheel,audio,video,storage,optical,network,users -s /bin/zsh "$USERNAME"
    echo "$USERNAME:$USER_PASSWORD" | chpasswd
    print_info "User '$USERNAME' created with password '$USER_PASSWORD'"
else
    print_info "User '$USERNAME' already exists"
fi

# Configure sudo
print_step "Configuring sudo..."
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

# Set hostname
print_step "Setting hostname to $HOSTNAME..."
hostnamectl set-hostname "$HOSTNAME"
echo "127.0.0.1 localhost" > /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts

# Configure locale
print_step "Configuring locale..."
sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
sed -i 's/#ko_KR.UTF-8/ko_KR.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set timezone (change as needed)
print_step "Setting timezone to Europe/Stockholm..."
ln -sf /usr/share/zoneinfo/Europe/Stockholm /etc/localtime
hwclock --systohc

# Setup ZRAM swap
print_step "Setting up ZRAM swap..."
pacman -S --noconfirm --needed zram-generator
cat > /etc/systemd/zram-generator.conf << 'ZRAMEOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
ZRAMEOF
systemctl enable systemd-zram-setup@zram0

# Performance optimizations
print_step "Applying performance optimizations..."
cat > /etc/sysctl.d/99-rpi5-performance.conf << 'SYSCTL'
# Reduce swappiness for better performance
vm.swappiness=10

# Increase inotify watches for development
fs.inotify.max_user_watches=524288

# Network optimizations
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
SYSCTL

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_success "Base system setup complete!"
echo ""
echo "Next steps:"
echo "  1. Reboot the system"
echo "  2. Login as '$USERNAME' with password '$USER_PASSWORD'"
echo "  3. Run: sudo /root/setup-desktop.sh (for Hyprland + kime)"
echo ""
echo "Or run: sudo /root/setup-kde.sh (for KDE Plasma alternative)"
echo ""
read -p "Press Enter to continue..."
SETUP_SCRIPT
    chmod +x "$MOUNT_POINT/root/setup-pi5.sh"
    
    # Hyprland + kime setup script
    cat > "$MOUNT_POINT/root/setup-desktop.sh" << 'DESKTOP_SCRIPT'
#!/bin/bash

# =============================================================================
# Hyprland + kime Desktop Setup for Raspberry Pi 5
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_step() {
    echo -e "\n${GREEN}[STEP]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

USERNAME="crux"

echo -e "${CYAN}"
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║         Hyprland + kime Desktop Setup                             ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Install yay AUR helper
print_step "Installing yay AUR helper..."
if ! command -v yay &> /dev/null; then
    cd /tmp
    rm -rf yay
    sudo -u "$USERNAME" git clone https://aur.archlinux.org/yay.git
    cd yay
    sudo -u "$USERNAME" makepkg -si --noconfirm
    cd ..
    rm -rf yay
fi

# Install Wayland and display server packages
print_step "Installing Wayland packages..."
pacman -S --noconfirm --needed \
    wayland \
    wayland-protocols \
    xorg-xwayland \
    wlroots \
    xdg-desktop-portal \
    xdg-desktop-portal-wlr \
    xdg-utils \
    pipewire \
    pipewire-alsa \
    pipewire-pulse \
    pipewire-jack \
    wireplumber

# Install Hyprland and related packages
print_step "Installing Hyprland..."
pacman -S --noconfirm --needed \
    hyprland \
    xdg-desktop-portal-hyprland \
    hyprpaper \
    hypridle \
    hyprlock \
    hyprpicker \
    waybar \
    wofi \
    rofi-wayland \
    mako \
    kitty \
    foot \
    thunar \
    tumbler \
    gvfs \
    polkit-gnome \
    qt5-wayland \
    qt6-wayland \
    brightnessctl \
    pavucontrol \
    network-manager-applet \
    blueman \
    cliphist \
    wl-clipboard \
    grim \
    slurp \
    swappy

# Install fonts
print_step "Installing fonts (including Korean fonts)..."
pacman -S --noconfirm --needed \
    ttf-dejavu \
    ttf-liberation \
    noto-fonts \
    noto-fonts-cjk \
    noto-fonts-emoji \
    adobe-source-han-sans-kr-fonts \
    adobe-source-han-serif-kr-fonts \
    ttf-jetbrains-mono \
    ttf-jetbrains-mono-nerd \
    ttf-fira-code

# Install kime (Korean Input Method Editor)
print_step "Installing kime Korean input method..."
sudo -u "$USERNAME" yay -S --noconfirm kime-git || {
    print_warning "kime-git installation failed, trying alternative..."
    sudo -u "$USERNAME" yay -S --noconfirm kime-bin || {
        print_warning "Using fcitx5-hangul as fallback..."
        pacman -S --noconfirm --needed \
            fcitx5 \
            fcitx5-gtk \
            fcitx5-qt \
            fcitx5-configtool \
            fcitx5-hangul
    }
}

# Install additional useful applications
print_step "Installing additional applications..."
pacman -S --noconfirm --needed \
    firefox \
    chromium \
    mpv \
    imv \
    zathura \
    zathura-pdf-poppler \
    gimp \
    libreoffice-fresh \
    code \
    neovim \
    python \
    python-pip \
    nodejs \
    npm

# Install Rust for some tools
print_step "Installing Rust..."
if ! command -v rustc &> /dev/null; then
    sudo -u "$USERNAME" bash -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y'
fi

# Create Hyprland configuration for user
print_step "Creating Hyprland configuration..."
USER_HOME="/home/$USERNAME"
mkdir -p "$USER_HOME/.config/hypr"

cat > "$USER_HOME/.config/hypr/hyprland.conf" << 'HYPRCONF'
# =============================================================================
# Hyprland Configuration for Raspberry Pi 5
# =============================================================================

# Monitor configuration (adjust for your display)
monitor=,preferred,auto,1

# Input configuration
input {
    kb_layout = us,kr
    kb_options = grp:alt_shift_toggle
    
    follow_mouse = 1
    
    touchpad {
        natural_scroll = yes
    }
    
    sensitivity = 0
}

# General appearance
general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
    col.inactive_border = rgba(595959aa)
    layout = dwindle
}

# Decoration
decoration {
    rounding = 10
    blur {
        enabled = true
        size = 3
        passes = 1
    }
    drop_shadow = yes
    shadow_range = 4
    shadow_render_power = 3
    col.shadow = rgba(1a1a1aee)
}

# Animations (toned down for Pi 5 performance)
animations {
    enabled = yes
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    animation = windows, 1, 5, myBezier
    animation = windowsOut, 1, 5, default, popin 80%
    animation = border, 1, 8, default
    animation = fade, 1, 5, default
    animation = workspaces, 1, 4, default
}

# Layout
dwindle {
    pseudotile = yes
    preserve_split = yes
}

master {
    new_status = master
}

# Gestures
gestures {
    workspace_swipe = on
}

# Environment variables
env = XCURSOR_SIZE,24
env = QT_QPA_PLATFORMTHEME,qt5ct

# Input Method (kime)
env = GTK_IM_MODULE,kime
env = QT_IM_MODULE,kime
env = XMODIFIERS,@im=kime

# Wayland
env = XDG_CURRENT_DESKTOP,Hyprland
env = XDG_SESSION_TYPE,wayland
env = XDG_SESSION_DESKTOP,Hyprland

# Autostart applications
exec-once = waybar
exec-once = mako
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
exec-once = hyprpaper
exec-once = hypridle
exec-once = nm-applet --indicator
exec-once = blueman-applet
exec-once = wl-paste --type text --watch cliphist store
exec-once = wl-paste --type image --watch cliphist store

# Start kime
exec-once = kime

# Window rules
windowrule = pseudo,fcitx
windowrule = pseudo,kime

# Key bindings
$mainMod = SUPER

bind = $mainMod, Return, exec, kitty
bind = $mainMod, Q, killactive
bind = $mainMod SHIFT, E, exit
bind = $mainMod, E, exec, thunar
bind = $mainMod, V, togglefloating
bind = $mainMod, D, exec, wofi --show drun
bind = $mainMod, P, pseudo
bind = $mainMod, J, togglesplit
bind = $mainMod, F, fullscreen

# Screenshot
bind = , Print, exec, grim -g "$(slurp)" - | swappy -f -
bind = $mainMod, Print, exec, grim - | swappy -f -

# Clipboard history
bind = $mainMod, C, exec, cliphist list | wofi --dmenu | cliphist decode | wl-copy

# Lock screen
bind = $mainMod, L, exec, hyprlock

# Focus movement
bind = $mainMod, left, movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up, movefocus, u
bind = $mainMod, down, movefocus, d

# Workspace switching
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod, 6, workspace, 6
bind = $mainMod, 7, workspace, 7
bind = $mainMod, 8, workspace, 8
bind = $mainMod, 9, workspace, 9
bind = $mainMod, 0, workspace, 10

# Move window to workspace
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5
bind = $mainMod SHIFT, 6, movetoworkspace, 6
bind = $mainMod SHIFT, 7, movetoworkspace, 7
bind = $mainMod SHIFT, 8, movetoworkspace, 8
bind = $mainMod SHIFT, 9, movetoworkspace, 9
bind = $mainMod SHIFT, 0, movetoworkspace, 10

# Mouse bindings
bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow

# Volume control
bind = , XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
bind = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bind = , XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle

# Brightness control
bind = , XF86MonBrightnessUp, exec, brightnessctl set 10%+
bind = , XF86MonBrightnessDown, exec, brightnessctl set 10%-
HYPRCONF

# Create kime configuration
print_step "Creating kime configuration..."
mkdir -p "$USER_HOME/.config/kime"

cat > "$USER_HOME/.config/kime/config.yaml" << 'KIMECONF'
# Kime Configuration for Hyprland

daemon:
  modules:
    - Wayland
    - Xim
    - Indicator

indicator:
  icon_color: Black

log:
  global_level: INFO

engine:
  translation_layer: null
  default_category: Latin
  global_category_state: false
  
  global_hotkeys:
    Hangul:
      behavior: !Toggle
        - Hangul
        - Latin
      result: Consume
    
    Super-Space:
      behavior: !Toggle
        - Hangul
        - Latin
      result: Consume
    
    Shift-Space:
      behavior: !Toggle
        - Hangul
        - Latin
      result: Consume
    
    Esc:
      behavior: !Switch Latin
      result: Bypass

  category_hotkeys:
    Hangul:
      ControlR:
        behavior: !Mode Hanja
        result: Consume
      HangulHanja:
        behavior: !Mode Hanja
        result: Consume
      F9:
        behavior: !Mode Hanja
        result: ConsumeIfProcessed

  mode_hotkeys:
    Hanja:
      Enter:
        behavior: Commit
        result: ConsumeIfProcessed
      Tab:
        behavior: Commit
        result: ConsumeIfProcessed
      Up:
        behavior: !PrevPage
        result: ConsumeIfProcessed
      Down:
        behavior: !NextPage
        result: ConsumeIfProcessed

  candidate_font: "Noto Sans CJK KR 12"
  xim_preedit_font:
    - "Noto Sans CJK KR"
    - 15.0

  latin:
    layout: Qwerty
    preferred_direct: true
    auto_commit: true

  hangul:
    layout: dubeolsik
    word_commit: false
    auto_reorder: true
    preedit_johab: Needed
    
    addons:
      all:
        - ComposeChoseongSsang
        - ComposeJungseongSsang
      
      dubeolsik:
        - TreatJongseongAsChoseong

wayland:
  use_virtual_keyboard: true
  text_input_v1: true
  text_input_v3: true
  input_method_v2: true

gtk:
  im_module: true
  use_system_theme: true

qt:
  input_method: true
  use_system_theme: true
KIMECONF

# Create waybar configuration
print_step "Creating waybar configuration..."
mkdir -p "$USER_HOME/.config/waybar"

cat > "$USER_HOME/.config/waybar/config" << 'WAYBARCONF'
{
    "layer": "top",
    "position": "top",
    "height": 30,
    "modules-left": ["hyprland/workspaces", "hyprland/window"],
    "modules-center": ["clock"],
    "modules-right": ["tray", "network", "bluetooth", "pulseaudio", "battery"],
    
    "hyprland/workspaces": {
        "format": "{icon}",
        "on-click": "activate",
        "format-icons": {
            "1": "1",
            "2": "2",
            "3": "3",
            "4": "4",
            "5": "5",
            "urgent": "",
            "active": "",
            "default": ""
        }
    },
    
    "clock": {
        "format": "{:%Y-%m-%d %H:%M}",
        "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>"
    },
    
    "network": {
        "format-wifi": " {signalStrength}%",
        "format-ethernet": "",
        "format-disconnected": "",
        "tooltip-format": "{ifname}: {ipaddr}"
    },
    
    "bluetooth": {
        "format": "",
        "format-connected": " {device_alias}",
        "format-disabled": "",
        "on-click": "blueman-manager"
    },
    
    "pulseaudio": {
        "format": "{icon} {volume}%",
        "format-muted": "",
        "format-icons": {
            "default": ["", "", ""]
        },
        "on-click": "pavucontrol"
    },
    
    "battery": {
        "format": "{icon} {capacity}%",
        "format-icons": ["", "", "", "", ""]
    },
    
    "tray": {
        "spacing": 10
    }
}
WAYBARCONF

cat > "$USER_HOME/.config/waybar/style.css" << 'WAYBARSTYLE'
* {
    font-family: "JetBrainsMono Nerd Font", "Noto Sans CJK KR", sans-serif;
    font-size: 13px;
}

window#waybar {
    background-color: rgba(30, 30, 46, 0.9);
    color: #cdd6f4;
    border-bottom: 2px solid #45475a;
}

#workspaces button {
    padding: 0 5px;
    color: #cdd6f4;
    border-radius: 5px;
    margin: 3px;
}

#workspaces button.active {
    background-color: #45475a;
    color: #89b4fa;
}

#clock, #battery, #network, #pulseaudio, #bluetooth, #tray {
    padding: 0 10px;
    margin: 3px;
}

#clock {
    color: #f5c2e7;
}

#battery {
    color: #a6e3a1;
}

#network {
    color: #89b4fa;
}

#pulseaudio {
    color: #fab387;
}

#bluetooth {
    color: #74c7ec;
}
WAYBARSTYLE

# Create autostart for kime
print_step "Creating autostart entries..."
mkdir -p "$USER_HOME/.config/autostart"

cat > "$USER_HOME/.config/autostart/kime.desktop" << 'KIMEAUTOSTART'
[Desktop Entry]
Type=Application
Name=Kime Input Method
Comment=Korean Input Method Editor
Exec=/usr/bin/kime
Icon=input-keyboard
Terminal=false
Categories=Utility;
StartupNotify=false
X-GNOME-Autostart-enabled=true
KIMEAUTOSTART

# Create .zprofile for environment variables
cat > "$USER_HOME/.zprofile" << 'ZPROFILE'
# Kime Input Method Settings
export GTK_IM_MODULE=kime
export QT_IM_MODULE=kime
export XMODIFIERS=@im=kime

# Wayland Settings
export XDG_CURRENT_DESKTOP=Hyprland
export XDG_SESSION_TYPE=wayland
export XDG_SESSION_DESKTOP=Hyprland

# Qt Settings
export QT_QPA_PLATFORM=wayland
export QT_QPA_PLATFORMTHEME=qt5ct

# Locale
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Start Hyprland automatically on tty1
if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
    exec Hyprland
fi
ZPROFILE

# Set proper ownership
chown -R "$USERNAME:$USERNAME" "$USER_HOME/.config"
chown "$USERNAME:$USERNAME" "$USER_HOME/.zprofile"

# Enable services
print_step "Enabling services..."
systemctl enable pipewire
systemctl --user --machine=$USERNAME@.host enable pipewire pipewire-pulse wireplumber 2>/dev/null || true

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_success "Hyprland + kime desktop setup complete!"
echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "Desktop environment installed successfully!"
echo ""
echo "To start Hyprland:"
echo "  1. Reboot or log out"
echo "  2. Login as '$USERNAME' on tty1"
echo "  3. Hyprland will start automatically"
echo ""
echo "Key bindings:"
echo "  SUPER + Return    : Open terminal (kitty)"
echo "  SUPER + D         : Application launcher (wofi)"
echo "  SUPER + Q         : Close window"
echo "  SUPER + V         : Toggle floating"
echo "  SUPER + F         : Fullscreen"
echo "  SUPER + L         : Lock screen"
echo "  SUPER + 1-0       : Switch workspaces"
echo "  Alt + Shift       : Toggle Korean/English (kime)"
echo "  Shift + Space     : Toggle Korean/English (kime alternative)"
echo ""
echo "═══════════════════════════════════════════════════════════════════"
DESKTOP_SCRIPT
    chmod +x "$MOUNT_POINT/root/setup-desktop.sh"
    
    # KDE alternative setup script
    cat > "$MOUNT_POINT/root/setup-kde.sh" << 'KDE_SCRIPT'
#!/bin/bash

# =============================================================================
# KDE Plasma Desktop Setup for Raspberry Pi 5 (Alternative to Hyprland)
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_step() {
    echo -e "\n${GREEN}[STEP]${NC} $1"
}

USERNAME="crux"

echo -e "${CYAN}"
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║         KDE Plasma + kime Desktop Setup                           ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Install yay AUR helper
print_step "Installing yay AUR helper..."
if ! command -v yay &> /dev/null; then
    cd /tmp
    rm -rf yay
    sudo -u "$USERNAME" git clone https://aur.archlinux.org/yay.git
    cd yay
    sudo -u "$USERNAME" makepkg -si --noconfirm
    cd ..
    rm -rf yay
fi

# Install KDE Plasma
print_step "Installing KDE Plasma..."
pacman -S --noconfirm --needed \
    plasma-meta \
    kde-applications-meta \
    sddm \
    plasma-wayland-session \
    xdg-desktop-portal-kde \
    pipewire \
    pipewire-alsa \
    pipewire-pulse \
    pipewire-jack \
    wireplumber

# Install fonts
print_step "Installing fonts..."
pacman -S --noconfirm --needed \
    ttf-dejavu \
    ttf-liberation \
    noto-fonts \
    noto-fonts-cjk \
    noto-fonts-emoji \
    adobe-source-han-sans-kr-fonts \
    adobe-source-han-serif-kr-fonts \
    ttf-jetbrains-mono \
    ttf-jetbrains-mono-nerd

# Install kime
print_step "Installing kime Korean input method..."
sudo -u "$USERNAME" yay -S --noconfirm kime-git || {
    pacman -S --noconfirm --needed fcitx5 fcitx5-gtk fcitx5-qt fcitx5-configtool fcitx5-hangul
}

# Enable services
print_step "Enabling services..."
systemctl enable sddm
systemctl enable bluetooth
systemctl enable NetworkManager

# Create kime configuration
USER_HOME="/home/$USERNAME"
mkdir -p "$USER_HOME/.config/kime"

cat > "$USER_HOME/.config/kime/config.yaml" << 'KIMECONF'
daemon:
  modules:
    - Wayland
    - Xim
    - Indicator

indicator:
  icon_color: Black

log:
  global_level: INFO

engine:
  default_category: Latin
  global_category_state: false
  
  global_hotkeys:
    Hangul:
      behavior: !Toggle
        - Hangul
        - Latin
      result: Consume
    
    Super-Space:
      behavior: !Toggle
        - Hangul
        - Latin
      result: Consume

  hangul:
    layout: dubeolsik
    word_commit: false
    auto_reorder: true

wayland:
  use_virtual_keyboard: true
  text_input_v1: true
  text_input_v3: true
KIMECONF

# Environment variables for kime
mkdir -p "$USER_HOME/.config/plasma-workspace/env"
cat > "$USER_HOME/.config/plasma-workspace/env/kime.sh" << 'KIMEENV'
export GTK_IM_MODULE=kime
export QT_IM_MODULE=kime
export XMODIFIERS=@im=kime
KIMEENV
chmod +x "$USER_HOME/.config/plasma-workspace/env/kime.sh"

# Autostart kime
mkdir -p "$USER_HOME/.config/autostart"
cat > "$USER_HOME/.config/autostart/kime.desktop" << 'KIMEAUTO'
[Desktop Entry]
Type=Application
Name=Kime
Exec=/usr/bin/kime
KIMEAUTO

chown -R "$USERNAME:$USERNAME" "$USER_HOME/.config"

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_success "KDE Plasma + kime setup complete!"
echo ""
echo "Reboot to start using KDE Plasma desktop."
echo "Use Alt+Shift or Super+Space to toggle Korean/English input."
KDE_SCRIPT
    chmod +x "$MOUNT_POINT/root/setup-kde.sh"

    # First boot helper
    cat > "$MOUNT_POINT/home/alarm/README-FIRST-BOOT.txt" << 'FIRSTBOOT'
═══════════════════════════════════════════════════════════════════════════════
                    ARCH LINUX ARM - RASPBERRY PI 5
                        FIRST BOOT INSTRUCTIONS
═══════════════════════════════════════════════════════════════════════════════

DEFAULT LOGIN CREDENTIALS:
--------------------------
Username: alarm
Password: alarm

Root password: root

SETUP STEPS:
------------
1. Login as root:
   $ su -
   (enter password: root)

2. Run the base system setup:
   # /root/setup-pi5.sh

3. Reboot:
   # reboot

4. Login as your new user (crux):
   Username: crux
   Password: 1234

5. Install desktop environment:
   $ sudo /root/setup-desktop.sh    (for Hyprland + kime)
   OR
   $ sudo /root/setup-kde.sh        (for KDE Plasma + kime)

6. Reboot and enjoy!

NETWORK SETUP:
--------------
If using WiFi (USB adapter):
   $ sudo nmtui

For Ethernet, it should connect automatically via DHCP.

TROUBLESHOOTING:
----------------
- If boot fails, connect HDMI to see error messages
- Pi 5 requires 5V/5A power supply for stable operation
- Ensure NVMe is properly seated in M.2 HAT/Base

═══════════════════════════════════════════════════════════════════════════════
FIRSTBOOT

    print_success "Post-installation scripts created"
}

cleanup() {
    print_step "Cleaning up..."
    sync
    
    umount "$MOUNT_POINT/boot" 2>/dev/null || true
    umount "$MOUNT_POINT" 2>/dev/null || true
    
    rm -rf "$MOUNT_POINT" 2>/dev/null || true
    
    print_success "Cleanup completed"
}

show_summary() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    INSTALLATION COMPLETE!                         ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "DEVICE INFORMATION:"
    echo "  NVMe Device: $NVME_DEVICE"
    echo "  Boot Partition: $BOOT_PART"
    echo "  Root Partition: $ROOT_PART"
    echo ""
    echo "NEXT STEPS:"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    echo "1. TRANSFER NVMe TO RASPBERRY PI 5"
    echo "   - Remove NVMe from USB enclosure"
    echo "   - Install in Pi 5's M.2 HAT/Base"
    echo ""
    echo "2. POWER ON THE PI 5"
    echo "   - Use 5V/5A USB-C power supply"
    echo "   - Connect HDMI for initial setup (or use SSH)"
    echo "   - Pi will boot directly from NVMe"
    echo ""
    echo "3. FIRST BOOT LOGIN"
    echo "   Username: alarm"
    echo "   Password: alarm"
    echo "   Root password: root"
    echo ""
    echo "4. RUN SETUP SCRIPTS"
    echo "   $ su -"
    echo "   # /root/setup-pi5.sh      (base system)"
    echo "   # reboot"
    echo "   (login as crux with password 1234)"
    echo "   $ sudo /root/setup-desktop.sh  (Hyprland + kime)"
    echo "   OR"
    echo "   $ sudo /root/setup-kde.sh      (KDE Plasma + kime)"
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "YOUR ACCOUNT (after setup):"
    echo "  Username: $USERNAME"
    echo "  Password: $USER_PASSWORD"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    echo -e "${YELLOW}IMPORTANT NOTES:${NC}"
    echo "• Pi 5 default boot order: SD → NVMe → USB (will boot from NVMe)"
    echo "• Use quality 5V/5A USB-C PD power supply"
    echo "• Pi 5 runs hot - ensure adequate cooling"
    echo "• Bluetooth is enabled for peripherals"
    echo "• kime: Press Hangul key, Alt+Shift, or Super+Space for Korean"
    echo ""
}

main() {
    print_header
    check_root
    check_commands
    show_installation_options
    select_nvme_device
    partition_nvme
    mount_partitions
    download_and_extract_arch
    configure_boot
    create_post_install_script
    cleanup
    show_summary
}

# Error handling
trap 'print_error "Script interrupted. Cleaning up..."; cleanup; exit 1' INT TERM

# Run main function
main
