#!/usr/bin/env bash

# Predefined choices
export use_default="--noconfirm"
export getAur="yay"  # Default AUR helper
export myShell="zsh" # Default shell
export grubtheme="Retroboot" # Default GRUB theme
export sddmtheme="Candy" # Default SDDM theme
export hydeTheme="Nordic Blue" # Default Hyprland theme
export hydeThemeRepo="https://github.com/HyDE-Project/hyde-themes/tree/Nordic-Blue" # Theme repository

# Global variables
scrDir=$(dirname "$(realpath "$0")")
confDir="${XDG_CONFIG_HOME:-$HOME/.config}"
cacheDir="$HOME/.cache/hyde"
cloneDir="$(dirname "${scrDir}")"
aurList=(yay paru)
shlList=(zsh fish)

# Function to check if a package is installed
pkg_installed() {
    local PkgIn=$1
    if pacman -Qi "${PkgIn}" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to check if a package is available in the official repos
pkg_available() {
    local PkgIn=$1
    if pacman -Si "${PkgIn}" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to check if a package is available in the AUR
aur_available() {
    local PkgIn=$1
    if ${getAur} -Si "${PkgIn}" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to detect NVIDIA GPU
nvidia_detect() {
    readarray -t dGPU < <(lspci -k | grep -E "(VGA|3D)" | awk -F ': ' '{print $NF}')
    if grep -iq nvidia <<< "${dGPU[@]}"; then
        return 0
    else
        return 1
    fi
}

# Function to install packages from a list
install_packages() {
    local listPkg="${1}"
    local archPkg=()
    local aurhPkg=()

    while read -r pkg deps; do
        pkg="${pkg// /}"
        if [ -z "${pkg}" ]; then
            continue
        fi

        if [ ! -z "${deps}" ]; then
            deps="${deps%"${deps##*[![:space:]]}"}"
            while read -r cdep; do
                if ! pkg_installed "${cdep}"; then
                    echo -e "\033[0;33m[skip]\033[0m ${pkg} is missing (${deps}) dependency..."
                    continue 2
                fi
            done < <(echo "${deps}" | xargs -n1)
        fi

        if pkg_installed "${pkg}"; then
            echo -e "\033[0;33m[skip]\033[0m ${pkg} is already installed..."
        elif pkg_available "${pkg}"; then
            repo=$(pacman -Si "${pkg}" | awk -F ': ' '/Repository / {print $2}')
            echo -e "\033[0;32m[${repo}]\033[0m queueing ${pkg} from official arch repo..."
            archPkg+=("${pkg}")
        elif aur_available "${pkg}"; then
            echo -e "\033[0;34m[aur]\033[0m queueing ${pkg} from arch user repo..."
            aurhPkg+=("${pkg}")
        else
            echo "Error: unknown package ${pkg}..."
        fi
    done < <(cut -d '#' -f 1 "${listPkg}")

    if [[ ${#archPkg[@]} -gt 0 ]]; then
        sudo pacman ${use_default} -S "${archPkg[@]}"
    fi

    if [[ ${#aurhPkg[@]} -gt 0 ]]; then
        "${getAur}" ${use_default} -S "${aurhPkg[@]}"
    fi
}

# Function to restore configurations
restore_configs() {
    local CfgLst="${1}"
    local CfgDir="${2}"
    local ThemeOverride="${3}"

    if [ ! -f "${CfgLst}" ] || [ ! -d "${CfgDir}" ]; then
        echo "ERROR: '${CfgLst}' or '${CfgDir}' does not exist..."
        exit 1
    fi

    BkpDir="${HOME}/.config/cfg_backups/$(date +'%y%m%d_%Hh%Mm%Ss')${ThemeOverride}"
    mkdir -p "${BkpDir}"

    cat "${CfgLst}" | while read lst; do
        ovrWrte=$(echo "${lst}" | awk -F '|' '{print $1}')
        bkpFlag=$(echo "${lst}" | awk -F '|' '{print $2}')
        pth=$(echo "${lst}" | awk -F '|' '{print $3}')
        pth=$(eval echo "${pth}")
        cfg=$(echo "${lst}" | awk -F '|' '{print $4}')
        pkg=$(echo "${lst}" | awk -F '|' '{print $5}")

        while read -r pkg_chk; do
            if ! pkg_installed "${pkg_chk}"; then
                echo -e "\033[0;33m[skip]\033[0m ${pth}/${cfg} as dependency ${pkg_chk} is not installed..."
                continue 2
            fi
        done < <(echo "${pkg}" | xargs -n 1)

        echo "${cfg}" | xargs -n 1 | while read -r cfg_chk; do
            if [[ -z "${pth}" ]]; then continue; fi
            tgt=$(echo "${pth}" | sed "s+^${HOME}++g")

            if ( [ -d "${pth}/${cfg_chk}" ] || [ -f "${pth}/${cfg_chk}" ] ) && [ "${bkpFlag}" == "Y" ]; then
                mkdir -p "${BkpDir}${tgt}"
                [ "${ovrWrte}" == "Y" ] && mv "${pth}/${cfg_chk}" "${BkpDir}${tgt}" || cp -r "${pth}/${cfg_chk}" "${BkpDir}${tgt}"
                echo -e "\033[0;34m[backup]\033[0m ${pth}/${cfg_chk} --> ${BkpDir}${tgt}..."
            fi

            if [ ! -d "${pth}" ]; then
                mkdir -p "${pth}"
            fi

            if [ ! -f "${pth}/${cfg_chk}" ]; then
                cp -r "${CfgDir}${tgt}/${cfg_chk}" "${pth}"
                echo -e "\033[0;32m[restore]\033[0m ${pth} <-- ${CfgDir}${tgt}/${cfg_chk}..."
            elif [ "${ovrWrte}" == "Y" ]; then
                cp -r "${CfgDir}$tgt/${cfg_chk}" "${pth}"
                echo -e "\033[0;33m[overwrite]\033[0m ${pth} <-- ${CfgDir}${tgt}/${cfg_chk}..."
            else
                echo -e "\033[0;33m[preserve]\033[0m Skipping ${pth}/${cfg_chk} to preserve user setting..."
            fi
        done
    done
}

# Function to restore fonts
restore_fonts() {
    echo -e "\n\033[0;32m[RESTORING FONTS]\033[0m"

    while read -r lst; do
        fnt=$(echo "$lst" | awk -F '|' '{print $1}')
        tgt=$(echo "$lst" | awk -F '|' '{print $2}')
        tgt=$(eval "echo $tgt")

        if [[ "${tgt}" =~ /usr/share/ && -d /run/current-system/sw/share/ ]]; then
            echo -e "\033[0;33m[SKIP]\033[0m ${tgt} on NixOS"
            continue
        fi

        if [ ! -d "${tgt}" ]; then
            mkdir -p "${tgt}" || echo "creating the directory as root instead..." && sudo mkdir -p "${tgt}"
            echo -e "\033[0;32m[extract]\033[0m ${tgt} directory created..."
        fi

        sudo tar -xzf "${cloneDir}/Source/arcs/${fnt}.tar.gz" -C "${tgt}/"
        echo -e "\033[0;32m[extract]\033[0m ${fnt}.tar.gz --> ${tgt}..."
    done < "${scrDir}/restorefnt.lst"

    echo -e "\033[0;32m[FONTS]\033[0m rebuilding font cache..."
    fc-cache -f
}

# Function to apply the selected theme
apply_theme() {
    local themeName="${1}"
    local themeRepo="${2}"

    echo -e "\n\033[0;32m[APPLYING THEME]\033[0m ${themeName}"

    # Clone the theme repository
    themeDir="${cacheDir}/themepatcher/${themeName}"
    if [ -d "${themeDir}" ]; then
        echo -e "\033[0;33m[SKIP]\033[0m Theme directory already exists. Updating..."
        cd "${themeDir}" && git pull
    else
        echo -e "\033[0;32m[CLONING]\033[0m Cloning theme repository..."
        git clone -b "${themeName}" "${themeRepo}" "${themeDir}"
    fi

    # Apply the theme
    if [ -d "${themeDir}/Configs/.config/hyde/themes/${themeName}" ]; then
        echo -e "\033[0;32m[APPLYING]\033[0m Applying theme configurations..."
        cp -r "${themeDir}/Configs/.config/hyde/themes/${themeName}" "${confDir}/hyde/themes/"
    else
        echo -e "\033[0;31m[ERROR]\033[0m Theme directory not found in repository."
        exit 1
    fi

    echo -e "\033[0;32m[THEME APPLIED]\033[0m ${themeName}"
}

# Function to enable system services
enable_services() {
    echo -e "\n\033[0;32m[ENABLING SERVICES]\033[0m"

    while read servChk; do
        if [[ $(systemctl list-units --all -t service --full --no-legend "${servChk}.service" | sed 's/^\s*//g' | cut -f1 -d' ') == "${servChk}.service" ]]; then
            echo -e "\033[0;33m[SKIP]\033[0m ${servChk} service is active..."
        else
            echo -e "\033[0;32m[systemctl]\033[0m starting ${servChk} system service..."
            sudo systemctl enable "${servChk}.service"
            sudo systemctl start "${servChk}.service"
        fi
    done < "${scrDir}/systemctl.lst"
}

# Main installation process
echo -e "\n\033[0;32m[STARTING INSTALLATION]\033[0m"

# Install packages
install_packages "${scrDir}/custom_hypr.lst"

# Restore configurations
restore_configs "${scrDir}/restore_cfg.lst" "${cloneDir}/Configs" ""

# Restore fonts
restore_fonts

# Apply the selected theme
apply_theme "${hydeTheme}" "${hydeThemeRepo}"

# Enable system services
enable_services

echo -e "\n\033[0;32m[INSTALLATION COMPLETE]\033[0m"
