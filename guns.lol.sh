#!/bin/bash -e

# Main script variables
url="https://guns.lol/api/upload"
temp_file="/tmp/screenshot.png"
response_file="/tmp/upload.json"

# Settings file path
settings_file="$HOME/.config/guns/settings.json"

# Function to read the saved value from the JSON file
get_saved_value() {
    local key=$1
    if [[ -f "$settings_file" ]]; then
        # Use jq to read the saved value
        saved_value=$(jq -r ".$key" "$settings_file")
        echo "$saved_value"
    else
        echo ""
    fi
}

# Function to save a key-value pair to the JSON file
save_value() {
    local key=$1
    local value=$2
    mkdir -p "$(dirname "$settings_file")"
    if [[ -f "$settings_file" ]]; then
        # Update the existing JSON file with the new value
        jq ".$key=\"$value\"" "$settings_file" > "$settings_file.tmp" && mv "$settings_file.tmp" "$settings_file"
    else
        # Create a new JSON file if it doesn't exist
        echo "{\"$key\": \"$value\"}" > "$settings_file"
    fi
}

# Function to check and install missing dependencies
install_dependencies() {
    local package_manager=$1
    shift
    local packages=("$@")
    for package in "${packages[@]}"; do
        if ! command -v "$package" &> /dev/null; then
            echo "$package is missing. Installing..."
            case "$package_manager" in
                "arch")
                    sudo pacman -S --noconfirm "$package"
                    ;;
                "debian")
                    sudo apt-get install -y "$package"
                    ;;
                "fedora")
                    sudo dnf install -y "$package"
                    ;;
                "nixos")
                    # NixOS package installation
                    sudo nix-env -iA nixpkgs."$package"
                    ;;
                "gentoo")
                    # Gentoo package installation
                    sudo emerge --ask "$package"
                    ;;
                "opensuse")
                    # openSUSE package installation
                    sudo zypper install -y "$package"
                    ;;
                "void")
                    # Void package installation
                    sudo xbps-install -y "$package"
                    ;;
                "bedrock")
                    # Bedrock: Since it's a multi-distribution system, we don't assume a package manager
                    # Default to Void or openSUSE logic depending on available package managers
                    if command -v xbps-install &> /dev/null; then
                        sudo xbps-install -y "$package"
                    elif command -v zypper &> /dev/null; then
                        sudo zypper install -y "$package"
                    else
                        echo "Package manager for Bedrock is unknown. Please install $package manually."
                        exit 1
                    fi
                    ;;
                *)
                    echo "Unsupported package manager: $package_manager"
                    exit 1
                    ;;
            esac
        fi
    done
}

# Function to check if zenity is installed, and install it if missing
check_zenity() {
    if ! command -v zenity &> /dev/null; then
        echo "Zenity is not installed. Installing..."
        case "$package_manager" in
            "arch")
                sudo pacman -S --noconfirm zenity
                ;;
            "debian")
                sudo apt-get install -y zenity
                ;;
            "fedora")
                sudo dnf install -y zenity
                ;;
            "nixos")
                # NixOS package installation for zenity
                sudo nix-env -iA nixpkgs.zenity
                ;;
            "gentoo")
                # Gentoo package installation for zenity
                sudo emerge --ask zenity
                ;;
            "opensuse")
                # openSUSE package installation for zenity
                sudo zypper install -y zenity
                ;;
            "void")
                # Void package installation for zenity
                sudo xbps-install -y zenity
                ;;
            "bedrock")
                # Bedrock: Use Void or openSUSE logic for zenity
                if command -v xbps-install &> /dev/null; then
                    sudo xbps-install -y zenity
                elif command -v zypper &> /dev/null; then
                    sudo zypper install -y zenity
                else
                    echo "Unable to install zenity on Bedrock Linux. Please install it manually."
                    exit 1
                fi
                ;;
            *)
                echo "Unsupported package manager for zenity installation: $package_manager"
                exit 1
                ;;
        esac
    fi
}

# Function to delete settings.json and reset setup
delete_settings_file() {
    if [[ -f "$settings_file" ]]; then
        echo "Deleting settings.json file..."
        rm -f "$settings_file"
    fi
}

# Function to get the auth key using zenity dialog box
get_auth_key() {
    local saved_auth=$(get_saved_value "auth")
    if [[ -z "$saved_auth" ]]; then
        auth=$(zenity --entry --title="Authentication Key" --text="Enter your auth key:" --width=300)
        if [[ -n "$auth" ]]; then
            save_value "auth" "$auth"
        else
            notify-send "Error" "No auth key entered. Exiting." -a "Screenshot Script"
            exit 1
        fi
    else
        auth=$saved_auth
    fi
}

# Function to get the screenshot tool preference using zenity dialog box
get_screenshot_tool_choice() {
    saved_choice=$(get_saved_value "screenshot_tool")
    if [[ -z "$saved_choice" || ( "$saved_choice" != "Flameshot" && "$saved_choice" != "Spectacle" ) ]]; then
        # Use Zenity to show a dialog for tool choice
        screenshot_tool=$(zenity --list --radiolist --title="KDE Screenshot Tool" --text="Choose your preferred screenshot tool:" --column="" --column="Tool" TRUE "Flameshot" FALSE "Spectacle" --width=500 --height=500)

        if [[ -n "$screenshot_tool" ]]; then
            save_value "screenshot_tool" "$screenshot_tool"
        else
            notify-send "Error" "No screenshot tool selected. Exiting." -a "Screenshot Script"
            exit 1
        fi
    else
        screenshot_tool=$saved_choice
    fi
}

# Detect the Linux distribution
distro=$(awk -F= '/^NAME/{print $2}' /etc/os-release | tr -d '"')

# Detect the desktop environment
desktop_env=$(echo "$XDG_CURRENT_DESKTOP" | tr '[:upper:]' '[:lower:]')

# Ensure required tools are installed based on the distro
case "$distro" in
    *"Arch"*)
        package_manager="arch"
        ;;
    *"Debian"*)
        package_manager="debian"
        ;;
    *"Fedora"*)
        package_manager="fedora"
        ;;
    *"NixOS"*)
        package_manager="nixos"
        ;;
    *"Gentoo"*)
        package_manager="gentoo"
        ;;
    *"openSUSE"*)
        package_manager="opensuse"
        ;;
    *"Void"*)
        package_manager="void"
        ;;
    *"Bedrock"*)
        package_manager="bedrock"
        ;;
    *)
        echo "Unsupported distribution: $distro"
        exit 1
        ;;
esac

# Check command line options
while getopts "c" opt; do
    case "$opt" in
        c)
            # If -c is provided, delete the settings file and reset the setup
            delete_settings_file
            ;;
        *)
            echo "Usage: $0 [-c]"
            exit 1
            ;;
    esac
done

# Ensure Zenity is installed
check_zenity

# Get the auth key
get_auth_key

# Check dependencies for each desktop environment
if [[ "$desktop_env" == *"hyprland"* ]]; then
    # Hyprland: Requires grim and slurp
    install_dependencies "$package_manager" "grim" "slurp"
    grim -g "$(slurp $SLURP_ARGS)" "$temp_file"

elif [[ "$desktop_env" == *"kde"* ]]; then
    # KDE Plasma: Offer choice between flameshot or spectacle
    if ! command -v flameshot &> /dev/null && ! command -v spectacle &> /dev/null; then
        echo "Neither Flameshot nor Spectacle is installed. Installing both."
        install_dependencies "$package_manager" "flameshot" "spectacle"
    fi

    # Get the saved screenshot tool choice from the settings file
    get_screenshot_tool_choice

    # Execute the chosen screenshot tool
    if [[ "$screenshot_tool" == "Flameshot" ]]; then
        flameshot gui -p "$temp_file"
    else
        spectacle --region --background --nonotify --output "$temp_file"
    fi

elif [[ "$desktop_env" == *"gnome"* || "$desktop_env" == *"cinnamon"* ]]; then
    # GNOME and Cinnamon: Requires gnome-screenshot
    install_dependencies "$package_manager" "gnome-screenshot"
    gnome-screenshot -a -f "$temp_file"

elif [[ "$desktop_env" == *"xfce"* ]]; then
    # XFCE: Requires xfce4-screenshooter
    install_dependencies "$package_manager" "xfce4-screenshooter"
    xfce4-screenshooter -r -o "$temp_file"

elif [[ "$desktop_env" == *"i3"* ]]; then
    # i3: Requires scrot
    install_dependencies "$package_manager" "scrot"
    scrot "$temp_file"

elif [[ "$desktop_env" == *"deepin"* ]]; then
    # Deepin: Requires deepin-screenshot
    install_dependencies "$package_manager" "deepin-screenshot"
    deepin-screenshot -o "$temp_file"

elif [[ "$desktop_env" == *"openbox"* ]]; then
    # Openbox: Requires scrot or flameshot
    install_dependencies "$package_manager" "scrot" "flameshot"
    scrot "$temp_file" # Default tool, or replace with flameshot if preferred

elif [[ "$desktop_env" == *"mate"* ]]; then
    # MATE: Requires mate-screenshot
    install_dependencies "$package_manager" "mate-screenshot"
    mate-screenshot -a -f "$temp_file"

else
    notify-send "Error" "Unsupported desktop environment: $desktop_env" -a "Screenshot Script"
    exit 1
fi

# Check if the screenshot was saved successfully
if [[ ! -f "$temp_file" ]]; then
    notify-send "Error" "Failed to take screenshot" -a "Screenshot Script"
    exit 1
fi

# Check if it's a PNG file
if [[ $(file --mime-type -b "$temp_file") != "image/png" ]]; then
    notify-send "Error" "Screenshot is not a valid PNG file" -a "Screenshot Script"
    rm -f "$temp_file"
    exit 1
fi

# Upload the screenshot
response=$(curl -s -X POST -F "file=@$temp_file" -F "key=$auth" "$url")
if [[ $? -ne 0 || -z "$response" ]]; then
    notify-send "Error" "Failed to upload the image" -a "Screenshot Script"
    rm -f "$temp_file"
    exit 1
fi

# Parse the response
echo "$response" > "$response_file"
image_url=$(echo "$response" | jq -r '.link')

# Validate the response URL
if [[ -z "$image_url" || "$image_url" == "null" ]]; then
    notify-send "Error" "Invalid response from the server" -a "Screenshot Script"
    rm -f "$temp_file" "$response_file"
    exit 1
fi

# Copy url to clipboard
echo -n "$image_url" | xclip -selection clipboard

# Modify clipboard contents by replacing "guns.lol" with "guns.website.com"
#clipboard_content=$(xclip -selection clipboard -o)
# Example is s/guns.lol/guns.website.com/g
#modified_content=$(echo "$clipboard_content" | sed 's/guns.lol/guns.website.com/g')

# Set the modified content back to the clipboard
#echo -n "$modified_content" | xclip -selection clipboard

# Final alert, swap these IF you are using a custom url
# notify-send "Image URL copied to clipboard" "$modified_content" -a "Screenshot Script" -i "$temp_file"
notify-send "Image URL copied to clipboard" "$modified_content" -a "Screenshot Script" -i "$temp_file"

# Clean up temporary files
rm -f "$temp_file" "$response_file"
