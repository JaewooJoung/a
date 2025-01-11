#!/usr/bin/env bash

# Exit on error
set -e

# Default configuration
declare -x USE_DEFAULT="--noconfirm"
declare -x AUR_HELPER="yay"
declare -x MY_SHELL="zsh"
declare -x GRUB_THEME="Retroboot"
declare -x SDDM_THEME="Candy"
declare -x HYDE_THEME="Nordic Blue"
declare -x HYDE_THEME_REPO="https://github.com/HyDE-Project/hyde-themes/tree/Nordic-Blue"

# Advanced settings
declare -x BACKUP_RETENTION_DAYS=30
declare -x PARALLEL_DOWNLOADS=5
declare -x TIMEOUT_SECONDS=300
declare -x RETRY_ATTEMPTS=3
declare -x ENABLE_DEBUG=false
declare -x LOG_FILE="$HOME/.cache/hyde/install.log"

# Global variables
declare SCRIPT_DIR
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
declare -x CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
declare -x CACHE_DIR="$HOME/.cache/hyde"
declare -x CLONE_DIR
CLONE_DIR="$(dirname "${SCRIPT_DIR}")"
declare -a AUR_LIST=(yay paru)
declare -a SHELL_LIST=(zsh fish)

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
    
    if [ "${ENABLE_DEBUG}" = true ] && [ -n "${LOG_FILE}" ]; then
        echo "[${level}] [${timestamp}] ${message}" >> "${LOG_FILE}"
    fi
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

# Function to check if a package is installed
pkg_installed() {
    declare pkg_name="$1"
    if pacman -Qi "${pkg_name}" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to check if a package is available in the official repos
pkg_available() {
    declare pkg_name="$1"
    if pacman -Si "${pkg_name}" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to check if a package is available in the AUR
aur_available() {
    declare pkg_name="$1"
    if "${AUR_HELPER}" -Si "${pkg_name}" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to install packages from a list
install_packages() {
    declare pkg_list="$1"
    declare -a arch_packages=()
    declare -a aur_packages=()
    declare attempt=1

    [ ! -f "${pkg_list}" ] && error_exit "Package list ${pkg_list} not found"

    while read -r package deps; do
        package="${package// /}"
        [ -z "${package}" ] && continue

        if [ ! -z "${deps}" ]; then
            deps="${deps%"${deps##*[![:space:]]}"}"
            while read -r dependency; do
                if ! pkg_installed "${dependency}"; then
                    log "WARN" "${package} is missing (${deps}) dependency..."
                    continue 2
                fi
            done < <(echo "${deps}" | xargs -n1)
        fi

        if pkg_installed "${package}"; then
            log "WARN" "${package} is already installed..."
        elif pkg_available "${package}"; then
            repo=$(pacman -Si "${package}" | awk -F ': ' '/Repository / {print $2}')
            log "INFO" "queueing ${package} from official arch repo..."
            arch_packages+=("${package}")
        elif aur_available "${package}"; then
            log "INFO" "queueing ${package} from arch user repo..."
            aur_packages+=("${package}")
        else
            log "ERROR" "unknown package ${package}..."
        fi
    done < <(cut -d '#' -f 1 "${pkg_list}")

    if [[ ${#arch_packages[@]} -gt 0 ]]; then
        sudo pacman ${USE_DEFAULT} -S "${arch_packages[@]}" || error_exit "Failed to install arch packages"
    fi

    if [[ ${#aur_packages[@]} -gt 0 ]]; then
        "${AUR_HELPER}" ${USE_DEFAULT} -S "${aur_packages[@]}" || error_exit "Failed to install AUR packages"
    fi
}

# Function to restore configurations
restore_configs() {
    declare cfg_list="$1"
    declare cfg_dir="$2"
    declare theme_override="$3"

    [ ! -f "${cfg_list}" ] && error_exit "Configuration list ${cfg_list} not found"
    [ ! -d "${cfg_dir}" ] && error_exit "Configuration directory ${cfg_dir} not found"

    declare backup_dir="${HOME}/.config/cfg_backups/$(date +'%Y%m%d_%H%M%S')${theme_override}"
    mkdir -p "${backup_dir}" || error_exit "Failed to create backup directory"

    while read -r line; do
        declare overwrite
        declare backup_flag
        declare path
        declare config_file
        declare package
        
        overwrite="$(echo "${line}" | awk -F '|' '{print $1}')"
        backup_flag="$(echo "${line}" | awk -F '|' '{print $2}')"
        path="$(eval echo "$(echo "${line}" | awk -F '|' '{print $3}')")"
        config_file="$(echo "${line}" | awk -F '|' '{print $4}')"
        package="$(echo "${line}" | awk -F '|' '{print $5}')"

        while read -r pkg_check; do
            if ! pkg_installed "${pkg_check}"; then
                log "WARN" "${path}/${config_file} as dependency ${pkg_check} is not installed..."
                continue 2
            fi
        done < <(echo "${package}" | xargs -n 1)

        echo "${config_file}" | xargs -n 1 | while read -r config_name; do
            [ -z "${path}" ] && continue
            declare target_path
            target_path="$(echo "${path}" | sed "s+^${HOME}++g")"

            if { [ -d "${path}/${config_name}" ] || [ -f "${path}/${config_name}" ]; } && [ "${backup_flag}" = "Y" ]; then
                mkdir -p "${backup_dir}${target_path}" || error_exit "Failed to create backup subdirectory"
                if [ "${overwrite}" = "Y" ]; then
                    mv "${path}/${config_name}" "${backup_dir}${target_path}" || error_exit "Failed to move config for backup"
                else
                    cp -r "${path}/${config_name}" "${backup_dir}${target_path}" || error_exit "Failed to copy config for backup"
                fi
                log "INFO" "Backed up ${path}/${config_name} to ${backup_dir}${target_path}"
            fi

            if [ ! -d "${path}" ]; then
                mkdir -p "${path}" || error_exit "Failed to create config directory"
            fi

            if [ ! -f "${path}/${config_name}" ]; then
                cp -r "${cfg_dir}${target_path}/${config_name}" "${path}" || error_exit "Failed to restore config"
                log "INFO" "Restored ${cfg_dir}${target_path}/${config_name} to ${path}"
            elif [ "${overwrite}" = "Y" ]; then
                cp -r "${cfg_dir}${target_path}/${config_name}" "${path}" || error_exit "Failed to overwrite config"
                log "INFO" "Overwrote ${path} with ${cfg_dir}${target_path}/${config_name}"
            else
                log "WARN" "Preserving user setting at ${path}/${config_name}"
            fi
        done
    done < "${cfg_list}"
}

# Function to restore fonts
restore_fonts() {
    log "INFO" "RESTORING FONTS"

    while read -r line; do
        declare font_name
        declare target_dir
        
        font_name="$(echo "${line}" | awk -F '|' '{print $1}')"
        target_dir="$(eval echo "$(echo "${line}" | awk -F '|' '{print $2}')")"

        if [[ "${target_dir}" =~ /usr/share/ && -d /run/current-system/sw/share/ ]]; then
            log "WARN" "Skipping ${target_dir} on NixOS"
            continue
        fi

        if [ ! -d "${target_dir}" ]; then
            if ! mkdir -p "${target_dir}" 2>/dev/null; then
                log "INFO" "Creating the directory as root instead..."
                sudo mkdir -p "${target_dir}" || error_exit "Failed to create font directory"
            fi
            log "INFO" "Created ${target_dir} directory"
        fi

        sudo tar -xzf "${CLONE_DIR}/Source/arcs/${font_name}.tar.gz" -C "${target_dir}/" || error_exit "Failed to extract fonts"
        log "INFO" "Extracted ${font_name}.tar.gz to ${target_dir}"
    done < "${SCRIPT_DIR}/restorefnt.lst"

    log "INFO" "Rebuilding font cache..."
    fc-cache -f || error_exit "Failed to rebuild font cache"
}

# Function to apply the selected theme
apply_theme() {
    declare theme_name="$1"
    declare theme_repo="$2"

    log "INFO" "APPLYING THEME ${theme_name}"

    declare theme_dir="${CACHE_DIR}/themepatcher/${theme_name}"
    if [ -d "${theme_dir}" ]; then
        log "WARN" "Theme directory exists. Updating..."
        cd "${theme_dir}" && git pull || error_exit "Failed to update theme"
    else
        log "INFO" "Cloning theme repository..."
        git clone -b "${theme_name}" "${theme_repo}" "${theme_dir}" || error_exit "Failed to clone theme"
    fi

    if [ -d "${theme_dir}/Configs/.config/hyde/themes/${theme_name}" ]; then
        log "INFO" "Applying theme configurations..."
        mkdir -p "${CONFIG_DIR}/hyde/themes/" || error_exit "Failed to create theme directory"
        cp -r "${theme_dir}/Configs/.config/hyde/themes/${theme_name}" "${CONFIG_DIR}/hyde/themes/" || error_exit "Failed to copy theme"
    else
        error_exit "Theme directory not found in repository"
    fi

    log "INFO" "Theme ${theme_name} applied successfully"
}

# Function to enable system services
enable_services() {
    log "INFO" "ENABLING SERVICES"

    while read -r service_name; do
        if [[ $(systemctl list-units --all -t service --full --no-legend "${service_name}.service" | sed 's/^\s*//g' | cut -f1 -d' ') == "${service_name}.service" ]]; then
            log "WARN" "${service_name} service is already active"
        else
            log "INFO" "Starting ${service_name} system service..."
            sudo systemctl enable "${service_name}.service" || error_exit "Failed to enable ${service_name} service"
            sudo systemctl start "${service_name}.service" || error_exit "Failed to start ${service_name} service"
        fi
    done < "${SCRIPT_DIR}/systemctl.lst"
}

# Main installation process
main() {
    # Initialize debug logging if enabled
    if [ "${ENABLE_DEBUG}" = true ]; then
        mkdir -p "$(dirname "${LOG_FILE}")"
        exec 1> >(tee -a "${LOG_FILE}")
        exec 2> >(tee -a "${LOG_FILE}" >&2)
        log "INFO" "Debug logging enabled to ${LOG_FILE}"
    fi

    log "INFO" "STARTING INSTALLATION"

    # Check for sudo access
    check_sudo

    # Verify required files exist
    [ ! -f "${SCRIPT_DIR}/custom_hypr.lst" ] && error_exit "Required package list not found"
    [ ! -f "${SCRIPT_DIR}/restore_cfg.lst" ] && error_exit "Required config list not found"
    [ ! -f "${SCRIPT_DIR}/restorefnt.lst" ] && error_exit "Required font list not found"
    [ ! -f "${SCRIPT_DIR}/systemctl.lst" ] && error_exit "Required service list not found"

    # Create necessary directories
    mkdir -p "${CONFIG_DIR}" || error_exit "Failed to create config directory"
    mkdir -p "${CACHE_DIR}" || error_exit "Failed to create cache directory"

    # Install packages
    install_packages "${SCRIPT_DIR}/custom_hypr.lst"

    # Restore configurations
    restore_configs "${SCRIPT_DIR}/restore_cfg.lst" "${CLONE_DIR}/Configs" ""

    # Restore fonts
    restore_fonts

    # Apply the selected theme
    apply_theme "${HYDE_THEME}" "${HYDE_THEME_REPO}"

    # Enable system services
    enable_services

    log "INFO" "INSTALLATION COMPLETE"
    return 0
}

# Trap for cleanup on script exit
cleanup() {
    declare exit_code=$?
    
    # Kill any remaining background processes
    jobs -p | xargs -r kill 2>/dev/null
    
    # Cleanup temporary files if they exist
    if [ -n "${CACHE_DIR}" ] && [ -d "${CACHE_DIR}/temp" ]; then
        rm -rf "${CACHE_DIR}/temp"
    fi
    
    if [ ${exit_code} -ne 0 ]; then
        log "ERROR" "Installation failed with exit code ${exit_code}"
    fi
    
    exit ${exit_code}
}

trap cleanup EXIT

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --debug)
            ENABLE_DEBUG=true
            shift
            ;;
        --timeout)
            TIMEOUT_SECONDS="$2"
            shift 2
            ;;
        --retries)
            RETRY_ATTEMPTS="$2"
            shift 2
            ;;
        --parallel-downloads)
            PARALLEL_DOWNLOADS="$2"
            shift 2
            ;;
        --backup-retention)
            BACKUP_RETENTION_DAYS="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --debug                Enable debug logging"
            echo "  --timeout SECONDS      Set timeout in seconds (default: 300)"
            echo "  --retries N           Number of retry attempts (default: 3)"
            echo "  --parallel-downloads N Set number of parallel downloads (default: 5)"
            echo "  --backup-retention N   Days to keep backups (default: 30)"
            echo "  --help                Show this help message"
            exit 0
            ;;
        *)
            error_exit "Unknown option: $1"
            ;;
    esac
done

# Run main function
main
