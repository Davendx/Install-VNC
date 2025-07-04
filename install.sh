#!/bin/bash

# Define constants
VNC_CONFIG_DIR="$HOME/.vnc"
VNC_PORT_FILE="$VNC_CONFIG_DIR/vnc_port.conf"
VNC_SERVICE_FILE="/etc/systemd/system/vncserver@.service" # Template service file
VNC_GEOMETRY="1920x1080"
VNC_DEPTH="24"
CURRENT_USER=$(whoami) # The user running this script, who will own the VNC session

# --- Helper Functions ---

# Function to read the current VNC port from configuration file
get_current_vnc_port() {
    if [ -f "$VNC_PORT_FILE" ]; then
        cat "$VNC_PORT_FILE"
    else
        echo "5901" # Default if file doesn't exist
    fi
}

# Function to get the display number from a port
get_display_from_port() {
    local port=$1
    echo $((port - 5900))
}

# Function to validate port input
validate_port() {
    local port=$1
    if [[ "$port" =~ ^[0-9]+$ ]] && (( port >= 5901 && port <= 5920 )); then
        return 0 # Valid
    else
        echo "Invalid port. Please enter a number between 5901 and 5920."
        return 1 # Invalid
    fi
}

# --- Main Menu Options ---

install_vnc_xfce() {
    echo "--- Starting XFCE and VNC Installation ---"
    echo "This will install necessary packages, XFCE, and TightVNC server."
    echo ""
    echo "Note: This setup is for a single VNC desktop session for the current user ($CURRENT_USER)."
    echo "The VNC server will be bound to localhost for security, requiring an SSH tunnel to connect."
    echo ""

    # 1. Install packages
    echo "Updating package lists and installing required packages..."
    sudo apt update
    if [ $? -ne 0 ]; then
        echo "Error: apt update failed. Exiting."
        return 1
    fi
    sudo apt install curl iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip autocutsel xfce4 xfce4-goodies tightvncserver -y

    if [ $? -ne 0 ]; then
        echo "Error: Package installation failed. Please check your internet connection and try again."
        return 1
    fi
    echo "All required packages installed successfully."

    # 2. Initial VNC server run to set password
    echo ""
    echo "--- VNC Password Setup ---"
    echo "You will now be prompted to set a password for your VNC connection."
    echo "This is a one-time setup. Remember this password!"
    vncserver

    if [ $? -ne 0 ]; then
        echo "Error: Failed to run vncserver for password setup. Please check TightVNC installation."
        return 1
    fi
    echo "VNC password set."

    # 3. Ask for desired VNC port
    local selected_port
    while true; do
        read -p "Enter your desired VNC port (e.g., 5901 for display :1, 5902 for :2, up to 5920 for :20): " selected_port
        if validate_port "$selected_port"; then
            break
        fi
    done

    local selected_display=$(get_display_from_port "$selected_port")

    # 4. Configure ~/.vnc/xstartup
    echo "Configuring VNC startup script ($VNC_CONFIG_DIR/xstartup)..."
    mkdir -p "$VNC_CONFIG_DIR"
    cat << EOF > "$VNC_CONFIG_DIR/xstartup"
#!/bin/bash
xrdb \$HOME/.Xresources
startxfce4 &
xfce4-terminal &
autocutsel &
EOF

    if [ $? -ne 0 ]; then
        echo "Error: Failed to write to $VNC_CONFIG_DIR/xstartup."
        return 1
    fi

    # 5. Make xstartup executable
    echo "Making VNC startup script executable..."
    chmod +x "$VNC_CONFIG_DIR/xstartup"

    if [ $? -ne 0 ]; then
        echo "Error: Failed to make $VNC_CONFIG_DIR/xstartup executable."
        return 1
    fi

    # 6. Save selected port
    echo "$selected_port" > "$VNC_PORT_FILE"
    echo "VNC port $selected_port saved for future use."

    # 7. Create Systemd Service File
    echo "Creating systemd service file for VNC server..."
    sudo tee "$VNC_SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=TightVNC remote desktop service for $CURRENT_USER on display %i
After=network.target

[Service]
Type=forking
User=$CURRENT_USER
PIDFile=/home/$CURRENT_USER/.vnc/%H:%i.pid
ExecStartPre=-/usr/bin/vncserver -kill :%i
ExecStart=/usr/bin/vncserver :%i -geometry $VNC_GEOMETRY -depth $VNC_DEPTH -localhost
ExecStop=/usr/bin/vncserver -kill :%i

[Install]
WantedBy=multi-user.target
EOF

    if [ $? -ne 0 ]; then
        echo "Error: Failed to create systemd service file. Exiting."
        return 1
    fi
    echo "Systemd service file created at $VNC_SERVICE_FILE."

    # 8. Reload systemd and enable/start service
    echo "Reloading systemd daemon..."
    sudo systemctl daemon-reload
    if [ $? -ne 0 ]; then echo "Error: Failed to reload systemd daemon."; return 1; fi

    echo "Enabling VNC systemd service for display :$selected_display..."
    sudo systemctl enable "vncserver@$selected_display.service"
    if [ $? -ne 0 ]; then echo "Error: Failed to enable VNC service."; return 1; fi

    echo "Starting VNC server service on display :$selected_display (port $selected_port)..."
    sudo systemctl start "vncserver@$selected_display.service"
    if [ $? -ne 0 ]; then echo "Error: Failed to start VNC service."; return 1; fi

    echo ""
    echo "--- Installation Complete! ---"
    echo "XFCE and TightVNC server are installed and configured as a systemd service."
    echo "VNC server is running on display :$selected_display (port $selected_port) and is bound to localhost."
    echo ""
    echo "IMPORTANT: The VNC port ($selected_port) is NOT open to the public internet."
    echo "You do NOT need to open this port in your firewall (e.g., UFW)."
    echo ""
    echo "To connect from your local machine, you MUST use an SSH tunnel:"
    echo "Example: ssh -L YOUR_LOCAL_PORT:localhost:$selected_port -N -f $CURRENT_USER@your_server_ip"
    echo "(Replace YOUR_LOCAL_PORT with a free port on your local machine, e.g., 6000)"
    echo "Then, connect your VNC client to localhost:YOUR_LOCAL_PORT"
    echo ""
    echo "To check the service status: sudo systemctl status vncserver@$selected_display.service"
}

uninstall_vnc_xfce() {
    echo "--- Starting XFCE and VNC Uninstallation ---"
    read -p "Are you sure you want to uninstall XFCE and TightVNC? This will remove all related packages and configuration files. (y/N): " confirm_uninstall
    if [[ ! "$confirm_uninstall" =~ ^[Yy]$ ]]; then
        echo "Uninstallation cancelled."
        return 0
    fi

    local current_port=$(get_current_vnc_port)
    local current_display=$(get_display_from_port "$current_port")

    # Stop and disable systemd service
    echo "Stopping and disabling VNC systemd service for display :$current_display..."
    sudo systemctl stop "vncserver@$current_display.service" > /dev/null 2>&1 || true
    sudo systemctl disable "vncserver@$current_display.service" > /dev/null 2>&1 || true

    # Remove systemd service file
    if [ -f "$VNC_SERVICE_FILE" ]; then
        echo "Removing VNC systemd service file ($VNC_SERVICE_FILE)..."
        sudo rm -f "$VNC_SERVICE_FILE"
        sudo systemctl daemon-reload # Reload daemon after removing service file
    fi
    echo "Systemd service removed/disabled."

    # Purge packages
    echo "Removing XFCE and TightVNC packages..."
    sudo apt purge --autoremove xfce4 xfce4-goodies tightvncserver -y

    if [ $? -ne 0 ]; then
        echo "Error: Package uninstallation failed. Some packages might remain."
    else
        echo "Packages uninstalled successfully."
    fi

    # Remove VNC configuration directory
    echo "Removing VNC configuration directory ($VNC_CONFIG_DIR)..."
    rm -rf "$VNC_CONFIG_DIR"
    echo "VNC configuration removed."

    echo "--- Uninstallation Complete! ---"
}

change_vnc_port() {
    echo "--- Change VNC Port ---"
    local current_port=$(get_current_vnc_port)
    local current_display=$(get_display_from_port "$current_port")
    
    if [ ! -f "$VNC_SERVICE_FILE" ]; then
        echo "VNC service not set up via this script. Cannot change port without systemd service file."
        echo "Please run 'Install VNC/XFCE Desktop' first."
        return 1
    fi

    echo "Current VNC server is configured on port $current_port (display :$current_display)."

    read -p "Do you want to change the VNC port? (y/N): " confirm_change
    if [[ ! "$confirm_change" =~ ^[Yy]$ ]]; then
        echo "Port change cancelled."
        return 0
    fi

    local new_port
    while true; do
        read -p "Enter the NEW desired VNC port (5901-5920): " new_port
        if validate_port "$new_port"; then
            break
        fi
    done

    local new_display=$(get_display_from_port "$new_port")

    if [ "$new_display" -eq "$current_display" ]; then
        echo "New port is the same as the old port. No change needed."
        return 0
    fi

    echo "Stopping and disabling VNC service for old display :$current_display..."
    sudo systemctl stop "vncserver@$current_display.service" > /dev/null 2>&1 || true
    sudo systemctl disable "vncserver@$current_display.service" > /dev/null 2>&1 || true

    # Save new port
    echo "$new_port" > "$VNC_PORT_FILE"
    echo "New VNC port $new_port saved."

    # Enable and start VNC service on new port
    echo "Enabling VNC systemd service for new display :$new_display..."
    sudo systemctl enable "vncserver@$new_display.service"
    if [ $? -ne 0 ]; then echo "Error: Failed to enable VNC service for new display."; return 1; fi

    echo "Starting VNC server service on new display :$new_display (port $new_port)..."
    sudo systemctl start "vncserver@$new_display.service"
    if [ $? -ne 0 ]; then echo "Error: Failed to start VNC service for new display."; return 1; fi

    echo "VNC port successfully changed to $new_port."
    echo "Remember to update your SSH tunnel on your local machine if you use one."
    echo "Example: ssh -L YOUR_LOCAL_PORT:localhost:$new_port -N -f $CURRENT_USER@your_server_ip"
    echo "Check the service status: sudo systemctl status vncserver@$new_display.service"
}

restart_vnc_server() {
    echo "--- Restart VNC Server ---"
    local current_port=$(get_current_vnc_port)
    local current_display=$(get_display_from_port "$current_port")

    if [ ! -f "$VNC_SERVICE_FILE" ] || ! sudo systemctl is-enabled "vncserver@$current_display.service" > /dev/null 2>&1; then
        echo "VNC server not configured or systemd service not found/enabled for display :$current_display."
        echo "Please run 'Install VNC/XFCE Desktop' first."
        return 1
    fi

    echo "Attempting to restart VNC server service on display :$current_display (port $current_port)..."
    sudo systemctl restart "vncserver@$current_display.service"

    if [ $? -ne 0 ]; then
        echo "Error: Failed to restart VNC server service on display :$current_display."
        return 1
    fi

    echo "VNC server on display :$current_display (port $current_port) restarted successfully."
    echo "Check the service status: sudo systemctl status vncserver@$current_display.service"
}

# --- Main Menu Loop ---

while true; do
    echo ""
    echo "--- VNC/XFCE Management Menu (User: $CURRENT_USER) ---"
    echo "1. Install VNC/XFCE Desktop"
    echo "2. Uninstall VNC/XFCE Desktop"
    echo "3. Change VNC Port"
    echo "4. Restart VNC Server"
    echo "5. Exit"
    echo "----------------------------------------------------"
    read -p "Enter your choice [1-5]: " choice

    case $choice in
        1) install_vnc_xfce ;;
        2) uninstall_vnc_xfce ;;
        3) change_vnc_port ;;
        4) restart_vnc_server ;;
        5) echo "Exiting script. Goodbye!"; break ;;
        *) echo "Invalid option. Please enter a number between 1 and 5." ;;
    esac
    echo ""
    read -p "Press Enter to continue..."
done
