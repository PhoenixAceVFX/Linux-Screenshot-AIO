#!/bin/bash -e

# Main script variables
url="https://guns.lol/api/upload"
temp_file="/tmp/screenshot.png"
response_file="/tmp/upload.json"
settings_file="$HOME/.config/guns/settings.json"

# Helper functions
get_saved_value() {
    [[ -f "$settings_file" ]] && jq -r ".$1" "$settings_file" || echo ""
}

save_value() {
    mkdir -p "$(dirname "$settings_file")"
    [[ -f "$settings_file" ]] && jq ".$1=\"$2\"" "$settings_file" > "$settings_file.tmp" && mv "$settings_file.tmp" "$settings_file" || echo "{\"$1\": \"$2\"}" > "$settings_file"
}

install_dependencies() {
    for package in "$@"; do
        if ! command -v "$package" &> /dev/null; then
            echo "$package is missing. Installing..."
            case "$package_manager" in
                "arch") sudo pacman -S --noconfirm "$package" ;;
                "debian") sudo apt-get install -y "$package" ;;
                "fedora") sudo dnf install -y "$package" ;;
                "nixos") sudo nix-env -iA nixpkgs."$package" ;;
                "gentoo") sudo emerge --ask "$package" ;;
                "opensuse") sudo zypper install -y "$package" ;;
                "void") sudo xbps-install -y "$package" ;;
                "bedrock")
                    if command -v xbps-install &> /dev/null; then
                        sudo xbps-install -y "$package"
                    elif command -v zypper &> /dev/null; then
                        sudo zypper install -y "$package"
                    else
                        echo "Install $package manually."
                        exit 1
                    fi
                    ;;
                *) echo "Unsupported package manager."; exit 1 ;;
            esac
        fi
    done
}

# Detect distro and desktop environment
distro=$(awk -F= '/^NAME/{print $2}' /etc/os-release | tr -d '"')
desktop_env=$(echo "$XDG_CURRENT_DESKTOP" | tr '[:upper:]' '[:lower:]')

case "$distro" in
    *"Arch"*) package_manager="arch" ;;
    *"Debian"*) package_manager="debian" ;;
    *"Fedora"*) package_manager="fedora" ;;
    *"NixOS"*) package_manager="nixos" ;;
    *"Gentoo"*) package_manager="gentoo" ;;
    *"openSUSE"*) package_manager="opensuse" ;;
    *"Void"*) package_manager="void" ;;
    *"Bedrock"*) package_manager="bedrock" ;;
    *) echo "Unsupported distribution: $distro"; exit 1 ;;
esac

# Reset settings if -c flag is passed
while getopts "c" opt; do
    [[ "$opt" == "c" ]] && rm -f "$settings_file"
done

# Ensure Zenity is installed
install_dependencies "zenity"

# Get auth key
auth=$(get_saved_value "auth")
if [[ -z "$auth" ]]; then
    auth=$(zenity --entry --title="Authentication Key" --text="Enter your auth key:" --width=500) || exit 1
    save_value "auth" "$auth"
fi

# Screenshot tool selection for various environments
get_tool_choice() {
    local env_name="$1"
    local tools=(${@:2})
    local saved_choice=$(get_saved_value "${env_name}_screenshot_tool")
    
    if [[ -z "$saved_choice" || ! " ${tools[@]} " =~ " ${saved_choice} " ]]; then
        local tool_options=""
        for tool in "${tools[@]}"; do
            tool_options+="FALSE $tool "
        done
        local chosen_tool=$(zenity --list --radiolist --title="${env_name} Screenshot Tool" --text="Choose your preferred screenshot tool:" --column="" --column="Tool" TRUE ${tool_options} --width=500 --height=316) || exit 1
        save_value "${env_name}_screenshot_tool" "$chosen_tool"
        echo "$chosen_tool"
    else
        echo "$saved_choice"
    fi
}

# Handle screenshots based on the desktop environment
case "$desktop_env" in
    *"kde"*)
        install_dependencies "flameshot" "spectacle"
        tool=$(get_tool_choice "KDE" "Flameshot" "Spectacle")
        if [[ "$tool" == "Flameshot" ]]; then
            flameshot gui -p "$temp_file"
        else
            spectacle --region --background --nonotify --output "$temp_file"
        fi
        ;;
    *"openbox"*)
        install_dependencies "scrot" "flameshot"
        tool=$(get_tool_choice "Openbox" "Flameshot" "Scrot")
        if [[ "$tool" == "Flameshot" ]]; then
            flameshot gui -p "$temp_file"
        else
            scrot "$temp_file"
        fi
        ;;
    *"hyprland"*|*"i3"*)
        install_dependencies "grim" "flameshot"
        tool=$(get_tool_choice "Tiling_WM" "Grim" "Flameshot")
        if [[ "$tool" == "Grim" ]]; then
            grim "$temp_file"
        else
            flameshot gui -p "$temp_file"
        fi
        ;;
    *"xfce"*)
        install_dependencies "xfce4-screenshooter" "flameshot"
        tool=$(get_tool_choice "XFCE" "XFCE4-Screenshooter" "Flameshot")
        if [[ "$tool" == "XFCE4-Screenshooter" ]]; then
            xfce4-screenshooter -r -s "$temp_file"
        else
            flameshot gui -p "$temp_file"
        fi
        ;;
    *"gnome"*)
        install_dependencies "gnome-screenshot" "flameshot"
        tool=$(get_tool_choice "GNOME" "GNOME-Screenshot" "Flameshot")
        if [[ "$tool" == "GNOME-Screenshot" ]]; then
            gnome-screenshot -a -f "$temp_file"
        else
            flameshot gui -p "$temp_file"
        fi
        ;;
    *"cinnamon"*)
        install_dependencies "gnome-screenshot" "flameshot"
        tool=$(get_tool_choice "Cinnamon" "GNOME-Screenshot" "Flameshot")
        if [[ "$tool" == "GNOME-Screenshot" ]]; then
            gnome-screenshot -a -f "$temp_file"
        else
            flameshot gui -p "$temp_file"
        fi
        ;;
    *"deepin"*)
        install_dependencies "deepin-screenshot"
        deepin-screenshot -s "$temp_file"
        ;;
    *"mate"*)
        install_dependencies "mate-screenshot" "flameshot"
        tool=$(get_tool_choice "MATE" "MATE-Screenshot" "Flameshot")
        if [[ "$tool" == "MATE-Screenshot" ]]; then
            mate-screenshot -a -f "$temp_file"
        else
            flameshot gui -p "$temp_file"
        fi
        ;;
    *)
        notify-send "Error" "Unsupported desktop environment: $desktop_env" -a "Screenshot Script"
        exit 1
        ;;
esac

# Verify screenshot
if [[ ! -f "$temp_file" ]]; then
    notify-send "Error" "Failed to take screenshot." -a "Screenshot Script"
    exit 1
fi

# Upload screenshot
response=$(curl -s -X POST -F "file=@$temp_file" -F "key=$auth" "$url")
image_url=$(echo "$response" | jq -r '.link')

if [[ -z "$image_url" || "$image_url" == "null" ]]; then
    notify-send "Error" "Failed to upload screenshot." -a "Screenshot Script"
    rm -f "$temp_file"
    exit 1
fi

# Copy url to clipboard
echo -n "$image_url" | xclip -selection clipboard

# Modify clipboard contents by replacing "guns.lol" with "guns.website.com"
# clipboard_content=$(xclip -selection clipboard -o)
# modified_content=$(echo "$clipboard_content" | sed 's/guns.lol/guns.website.com/g')

# Set the modified content back to the clipboard, uncomment if using custom url
# echo -n "$modified_content" | xclip -selection clipboard

# Final alert, swap these IF you are using a custom url
# notify-send "Image URL copied to clipboard" "$modified_content" -a "Screenshot Script" -i "$temp_file"
notify-send "Image URL copied to clipboard" "$image_url" -a "Screenshot Script" -i "$temp_file"

# Clean up temporary files
rm -f "$temp_file" "$response_file"
