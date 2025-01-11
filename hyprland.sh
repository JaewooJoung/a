#!/usr/bin/env bash

# Exit on error
set -e

# Default configuration
declare -x use_default="--noconfirm"
declare -x getAur="yay"
declare -x myShell="zsh"
declare -x grubtheme="Retroboot"
declare -x sddmtheme="Candy"
declare -x hydeTheme="Nordic Blue"
declare -x hydeThemeRepo="https://github.com/HyDE-Project/hyde-themes/tree/Nordic-Blue"

# Advanced settings
declare -x BACKUP_RETENTION_DAYS=30
declare -x PARALLEL_DOWNLOADS=5
declare -x TIMEOUT_SECONDS=300
declare -x RETRY_ATTEMPTS=3
declare -x ENABLE_DEBUG=false
declare -x LOG_FILE="$HOME/.cache/hyde/install.log"

# Global variables
declare scrDir
scrDir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
declare -x confDir="${XDG_CONFIG_HOME:-$HOME/.config}"
declare -x cacheDir="$HOME/.cache/hyde"
declare -x cloneDir
cloneDir="$(dirname "${scrDir}")"
declare -a aurList=(yay paru)
declare -a shlList=(zsh fish)

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

# Cleanup function for old backups
cleanup_old_backups() {
    log "INFO" "Cleaning up old backups older than ${BACKUP_RETENTION_DAYS} days"
    local backup_dir="${HOME}/.config/cfg_backups"
    
    if [ ! -d "${backup_dir}" ]; then
        log "WARN" "Backup directory does not exist, skipping cleanup"
        return 0
    fi
    
    find "${backup_dir}" -type d -mtime "+${BACKUP_RETENTION_DAYS}" -exec rm -rf {} \; 2>/dev/null || 
        log "WARN" "Some backups could not be removed"
}

# Check for sudo access
check_sudo() {
    if ! sudo -v; then
        error_exit "This script requires sudo privileges"
    fi
}

# Function to check if a package is installed
pkg_installed() {
    local PkgIn="$1"
    if pacman -Qi "${PkgIn}" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to check if a package is available in the official repos
pkg_available() {
    local PkgIn="$1"
    if pacman -Si "${PkgIn}" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to check if a package is available in the AUR
aur_available() {
    local PkgIn="$1"
    if "${getAur}" -Si "${PkgIn}" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to detect NVIDIA GPU
nvidia_detect() {
    local -a dGPU
    readarray -t dGPU < <(lspci -k | grep -E "(VGA|3D)" | awk -F ': ' '{print $NF}')
    if grep -iq nvidia <<< "${dGPU[@]}"; then
        return 0
    else
        return 1
    fi
}

# Function to install packages from a list
install_packages() {
    local listPkg="$1"
    local -a archPkg=()
    local -a aurhPkg=()
    local attempt=1

    [ ! -f "${listPkg}" ] && error_exit "Package list ${listPkg} not found"

    # Set parallel downloads
    if [ -f "/etc/pacman.conf" ]; then
        sudo sed -i "s/^#ParallelDownloads = .*$/ParallelDownloads = ${PARALLEL_DOWNLOADS}/" /etc/pacman.conf
    fi

    while read -r pkg deps; do
        pkg="${pkg// /}"
        [ -z "${pkg}" ] && continue

        if [ ! -z "${deps}" ]; then
            deps="${deps%"${deps##*[![:space:]]}"}"
            while read -r cdep; do
                if ! pkg_installed "${cdep}"; then
                    log "WARN" "${pkg} is missing (${deps}) dependency..."
                    continue 2
                fi
            done < <(echo "${deps}" | xargs -n1)
        fi

        if pkg_installed "${pkg}"; then
            log "WARN" "${pkg} is already installed..."
        elif pkg_available "${pkg}"; then
            repo=$(pacman -Si "${pkg}" | awk -F ': ' '/Repository / {print $2}')
            log "INFO" "queueing ${pkg} from official arch repo..."
            archPkg+=("${pkg}")
        elif aur_available "${pkg}"; then
            log "INFO" "queueing ${pkg} from arch user repo..."
            aurhPkg+=("${pkg}")
        else
            log "ERROR" "unknown package ${pkg}..."
        fi
    done < <(cut -d '#' -f 1 "${listPkg}")

    while [ ${attempt} -le ${RETRY_ATTEMPTS} ]; do
        if [[ ${#archPkg[@]} -gt 0 ]]; then
            if sudo pacman ${use_default} -S "${archPkg[@]}"; then
                break
            else
                log "WARN" "Package installation attempt ${attempt} failed, retrying..."
                attempt=$((attempt + 1))
                sleep 5
            fi
        fi
    done
    [ ${attempt} -gt ${RETRY_ATTEMPTS} ] && error_exit "Failed to install official packages after ${RETRY_ATTEMPTS} attempts"

    attempt=1
    while [ ${attempt} -le ${RETRY_ATTEMPTS} ]; do
        if [[ ${#aurhPkg[@]} -gt 0 ]]; then
            if "${getAur}" ${use_default} -S "${aurhPkg[@]}"; then
                break
            else
                log "WARN" "AUR package installation attempt ${attempt} failed, retrying..."
                attempt=$((attempt + 1))
                sleep 5
            fi
        fi
    done
    [ ${attempt} -gt ${RETRY_ATTEMPTS} ] && error_exit "Failed to install AUR packages after ${RETRY_ATTEMPTS} attempts"
}

# Function to restore configurations
restore_configs() {
    local CfgLst="$1"
    local CfgDir="$2"
    local ThemeOverride="$3"

    [ ! -f "${CfgLst}" ] && error_exit "Configuration list ${CfgLst} not found"
    [ ! -d "${CfgDir}" ] && error_exit "Configuration directory ${CfgDir} not found"

    local BkpDir="${HOME}/.config/cfg_backups/$(date +'%Y%m%d_%H%M%S')${ThemeOverride}"
    mkdir -p "${BkpDir}" || error_exit "Failed to create backup directory"

    while read -r lst; do
        local ovrWrte
        local bkpFlag
        local pth
        local cfg
        local pkg
        
        ovrWrte="$(echo "${lst}" | awk -F '|' '{print $1}')"
        bkpFlag="$(echo "${lst}" | awk -F '|' '{print $2}')"
        pth="$(eval echo "$(echo "${lst}" | awk -F '|' '{print $3}')")"
        cfg="$(echo "${lst}" | awk -F '|' '{print $4}')"
        pkg="$(echo "${lst}" | awk -F '|' '{print $5}')"

        while read -r pkg_chk; do
            if ! pkg_installed "${pkg_chk}"; then
                log "WARN" "${pth}/${cfg} as dependency ${pkg_chk} is not installed..."
                continue 2
            fi
        done < <(echo "${pkg}" | xargs -n 1)

        echo "${cfg}" | xargs -n 1 | while read -r cfg_chk; do
            [ -z "${pth}" ] && continue
            local tgt
            tgt="$(echo "${pth}" | sed "s+^${HOME}++g")"

            if { [ -d "${pth}/${cfg_chk}" ] || [ -f "${pth}/${cfg_chk}" ]; } && [ "${bkpFlag}" = "Y" ]; then
                mkdir -p "${BkpDir}${tgt}" || error_exit "Failed to create backup subdirectory"
                if [ "${ovrWrte}" = "Y" ]; then
                    mv "${pth}/${cfg_chk}" "${BkpDir}${tgt}" || error_exit "Failed to move config for backup"
                else
                    cp -r "${pth}/${cfg_chk}" "${BkpDir}${tgt}" || error_exit "Failed to copy config for backup"
                fi
                log "INFO" "Backed up ${pth}/${cfg_chk} to ${BkpDir}${tgt}"
            fi

            if [ ! -d "${pth}" ]; then
                mkdir -p "${pth}" || error_exit "Failed to create config directory"
            fi

            if [ ! -f "${pth}/${cfg_chk}" ]; then
                cp -r "${CfgDir}${tgt}/${cfg_chk}" "${pth}" || error_exit "Failed to restore config"
                log "INFO" "Restored ${CfgDir}${tgt}/${cfg_chk} to ${pth}"
            elif [ "${ovrWrte}" = "Y" ]; then
                cp -r "${CfgDir}${tgt}/${cfg_chk}" "${pth}" || error_exit "Failed to overwrite config"
                log "INFO" "Overwrote ${pth} with ${CfgDir}${tgt}/${cfg_chk}"
            else
                log "WARN" "Preserving user setting at ${pth}/${cfg_chk}"
            fi
        done
    done < "${CfgLst}"
}

# Function to restore fonts
restore_fonts() {
    log "INFO" "RESTORING FONTS"

    while read -r lst; do
        local fnt
        local tgt
        
        fnt="$(echo "$lst" | awk -F '|' '{print $1}')"
        tgt="$(eval echo "$(echo "$lst" | awk -F '|' '{print $2}')")"

        if [[ "${tgt}" =~ /usr/share/ && -d /run/current-system/sw/share/ ]]; then
            log "WARN" "Skipping ${tgt} on NixOS"
            continue
        fi

        if [ ! -d "${tgt}" ]; then
            if ! mkdir -p "${tgt}" 2>/dev/null; then
                log "INFO" "Creating the directory as root instead..."
                sudo mkdir -p "${tgt}" || error_exit "Failed to create font directory"
            fi
            log "INFO" "Created ${tgt} directory"
        fi

        sudo tar -xzf "${cloneDir}/Source/arcs/${fnt}.tar.gz" -C "${tgt}/" || error_exit "Failed to extract fonts"
        log "INFO" "Extracted ${fnt}.tar.gz to ${tgt}"
    done < "${scrDir}/restorefnt.lst"

    log "INFO" "Rebuilding font cache..."
    fc-cache -f || error_exit "Failed to rebuild font cache"
}

# Function to apply the selected theme
apply_theme() {
    local themeName="$1"
    local themeRepo="$2"

    log "INFO" "APPLYING THEME ${themeName}"

    local themeDir="${cacheDir}/themepatcher/${themeName}"
    if [ -d "${themeDir}" ]; then
        log "WARN" "Theme directory exists. Updating..."
        cd "${themeDir}" && git pull || error_exit "Failed to update theme"
    else
        log "INFO" "Cloning theme repository..."
        git clone -b "${themeName}" "${themeRepo}" "${themeDir}" || error_exit "Failed to clone theme"
    fi

    if [ -d "${themeDir}/Configs/.config/hyde/themes/${themeName}" ]; then
        log "INFO" "Applying theme configurations..."
        mkdir -p "${confDir}/hyde/themes/" || error_exit "Failed to create theme directory"
        cp -r "${themeDir}/Configs/.config/hyde/themes/${themeName}" "${confDir}/hyde/themes/" || error_exit "Failed to copy theme"
    else
        error_exit "Theme directory not found in repository"
    fi

    log "INFO" "Theme ${themeName} applied successfully"
}

# Function to enable system services
enable_services() {
    log "INFO" "ENABLING SERVICES"

    while read -r servChk; do
        if [[ $(systemctl list-units --all -t service --full --no-legend "${servChk}.service" | sed 's/^\s*//g' | cut -f1 -d' ') == "${servChk}.service" ]]; then
            log "WARN" "${servChk} service is already active"
        else
            log "INFO" "Starting ${servChk} system service..."
            sudo systemctl enable "${servChk}.service" || error_exit "Failed to enable ${servChk} service"
            sudo systemctl start "${servChk}.service" || error_exit "Failed to start ${servChk} service"
        fi
    done < "${scrDir}/systemctl.lst"
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
    [ ! -f "${scrDir}/custom_hypr.lst" ] && error_exit "Required package list not found"
    [ ! -f "${scrDir}/restore_cfg.lst" ] && error_exit "Required config list not found"
    [ ! -f "${scrDir}/restorefnt.lst" ] && error_exit "Required font list not found"
    [ ! -f "${scrDir}/systemctl.lst" ] && error_exit "Required service list not found"

    # Create necessary directories
    mkdir -p "${confDir}" || error_exit "Failed to create config directory"
    mkdir -p "${cacheDir}" || error_exit "Failed to create cache directory"

    # Cleanup old backups before starting
    cleanup_old_backups

    # Handle timeout for the entire process
    (
        sleep "${TIMEOUT_SECONDS}"
        kill -0 $ 2>/dev/null && {
            log "ERROR" "Installation timed out after ${TIMEOUT_SECONDS} seconds"
            kill -15 $ 2>/dev/null || kill -9 $ 2>/dev/null
        }
    ) &
    timeout_pid=$!

    # Install packages
    local attempt=1
    while [ ${attempt} -le ${RETRY_ATTEMPTS} ]; do
        if install_packages "${scrDir}/custom_hypr.lst"; then
            break
        else
            log "WARN" "Installation attempt ${attempt} failed, retrying..."
            attempt=$((attempt + 1))
            sleep 5
        fi
    done

    if [ ${attempt} -gt ${RETRY_ATTEMPTS} ]; then
        log "ERROR" "Installation failed after ${RETRY_ATTEMPTS} attempts"
        exit 1
    fi

    # Restore configurations
    restore_configs "${scrDir}/restore_cfg.lst" "${cloneDir}/Configs" ""

    # Restore fonts
    restore_fonts

    # Apply the selected theme
    apply_theme "${hydeTheme}" "${hydeThemeRepo}"

    # Enable system services
    enable_services

    # Cleanup timeout monitor
    kill "${timeout_pid}" 2>/dev/null

    log "INFO" "INSTALLATION COMPLETE"
    return 0
}

# Trap for cleanup on script exit
cleanup() {
    local exit_code=$?
    
    # Kill any remaining background processes
    jobs -p | xargs -r kill 2>/dev/null
    
    # Cleanup temporary files if they exist
    if [ -n "${cacheDir}" ] && [ -d "${cacheDir}/temp" ]; then
        rm -rf "${cacheDir}/temp"
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
