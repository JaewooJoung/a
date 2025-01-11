#!/usr/bin/env bash

# Exit on error
set -e

# Default configuration
declare -x AUR_HELPER="yay"
declare -x HYDE_THEME="Nordic Blue"
declare -x HYDE_THEME_REPO="https://github.com/HyDE-Project/hyde-themes/tree/Nordic-Blue"

# Logging function
log() {
    local level="$1"
    local message="$2"
    local color
    case "$level" in 
        "INFO") color="32";; # Green
        "WARN") color="33";; # Yellow
        "ERROR") color="31";; # Red 
        *) color="0";;
    esac
    
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "\033[0;${color}m[${level}]\033[0m [${timestamp}] ${message}"
}

# Error handling function
error_exit() {
    log "ERROR" "$1"
    exit 1
}

# Check for sudo access
check_sudo() {
    if ! sudo -v; then
        error_exit "This script requires sudo privileges"
    fi
}

# Function to install Hyprland
install_hyprland() {
    log "INFO" "Installing Hyprland..."
    sudo pacman --noconfirm -S hyprland || error_exit "Failed to install Hyprland"
}

# Function to apply the selected theme
apply_theme() {
    declare theme_name="$1"
    declare theme_repo="$2"

    log "INFO" "Applying theme ${theme_name}"

    declare theme_dir="${HOME}/.cache/hyde/themes/${theme_name}"
    if [ -d "${theme_dir}" ]; then
        log "WARN" "Theme directory exists. Updating..."
        cd "${theme_dir}" && git pull || error_exit "Failed to update theme"
    else
        log "INFO" "Cloning theme repository..."
        git clone -b "${theme_name}" "${theme_repo}" "${theme_dir}" || error_exit "Failed to clone theme"
    fi

    if [ -d "${theme_dir}/Configs/.config/hyde/themes/${theme_name}" ]; then
        log "INFO" "Applying theme configurations..."
        mkdir -p "${HOME}/.config/hyde/themes/" || error_exit "Failed to create theme directory"
        cp -r "${theme_dir}/Configs/.config/hyde/themes/${theme_name}" "${HOME}/.config/hyde/themes/" || error_exit "Failed to copy theme"
    else
        error_exit "Theme directory not found in repository"
    fi

    log "INFO" "Theme ${theme_name} applied successfully"
}

# Main installation process
main() {
    log "INFO" "Starting installation"

    # Check for sudo access
    check_sudo

    # Install Hyprland
    install_hyprland

    # Apply the selected theme
    apply_theme "${HYDE_THEME}" "${HYDE_THEME_REPO}"

    log "INFO" "Installation complete"
}

# Run main function
main
