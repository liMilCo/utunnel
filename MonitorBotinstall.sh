#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Paths
INSTALL_DIR="/opt/monitorbot"
CONFIG_FILE="$INSTALL_DIR/config.conf"
SERVICE_FILE="/etc/systemd/system/monitorbot.service"
TEMP_ARCHIVE="/tmp/monitorbot.tar.gz"

show_menu() {
    clear
    echo -e "${BLUE}==============================${NC}"
    echo -e "${BLUE}    MonitorBot Manager        ${NC}"
    echo -e "${BLUE}==============================${NC}"
    echo -e "1. ${GREEN}Install MonitorBot${NC}"
    echo -e "2. ${RED}Remove MonitorBot${NC}"
    echo -e "3. ${YELLOW}Exit${NC}"
    echo -e "${BLUE}==============================${NC}"
    read -p "Select option [1-3]: " choice
}

install_monitorbot() {
    # Check root
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}Error: This script requires root privileges${NC}"
        exit 1
    fi

    echo -e "${GREEN}Starting MonitorBot installation...${NC}"

    # Clean existing
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}Removing previous installation...${NC}"
        rm -rf "$INSTALL_DIR"
    fi

    # Create directory
    echo -e "${YELLOW}Creating installation directory...${NC}"
    mkdir -p "$INSTALL_DIR"

    # Download
    echo -e "${YELLOW}Downloading MonitorBot package...${NC}"
    if ! wget -O "$TEMP_ARCHIVE" "https://raw.githubusercontent.com/liMilCo/utunnel/refs/heads/main/monitorbot.tar.gz"; then
        echo -e "${RED}Error: Download failed${NC}"
        exit 1
    fi

    # Extract
    echo -e "${YELLOW}Extracting files...${NC}"
    if ! tar -xzf "$TEMP_ARCHIVE" -C "$INSTALL_DIR"; then
        echo -e "${RED}Error: Extraction failed${NC}"
        exit 1
    fi

    # Set permissions
    echo -e "${YELLOW}Setting executable permissions...${NC}"
    chmod +x "$INSTALL_DIR"/*.sh

    # Get configuration
    echo -e "${YELLOW}Please enter configuration details:${NC}"
    
    while true; do
        read -p "TELEGRAM_BOT_TOKEN: " TELEGRAM_BOT_TOKEN
        if [ -z "$TELEGRAM_BOT_TOKEN" ]; then
            echo -e "${RED}Error: Token cannot be empty${NC}"
        else
            break
        fi
    done

    while true; do
        read -p "TELEGRAM_CHAT_ID: " TELEGRAM_CHAT_ID
        if [ -z "$TELEGRAM_CHAT_ID" ]; then
            echo -e "${RED}Error: Chat ID cannot be empty${NC}"
        else
            break
        fi
    done

    while true; do
        read -p "CHECK_INTERVAL (seconds): " CHECK_INTERVAL
        if [[ ! "$CHECK_INTERVAL" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}Error: Interval must be a number${NC}"
        else
            break
        fi
    done

    # Create config file with exact field names
    echo -e "${YELLOW}Creating configuration file...${NC}"
    cat > "$CONFIG_FILE" <<EOL
TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN
TELEGRAM_CHAT_ID=$TELEGRAM_CHAT_ID
CHECK_INTERVAL=$CHECK_INTERVAL
EOL

    # Create systemd service
    echo -e "${YELLOW}Creating systemd service...${NC}"
    cat > "$SERVICE_FILE" <<EOL
[Unit]
Description=MonitorBot Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/monitorbot.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOL

    # Enable service
    echo -e "${YELLOW}Enabling service...${NC}"
    systemctl daemon-reload
    systemctl enable monitorbot
    systemctl start monitorbot

    # Clean up
    rm -f "$TEMP_ARCHIVE"

    echo -e "${GREEN}Installation completed successfully!${NC}"
    echo -e "Configuration file created at: $CONFIG_FILE"
    echo -e "Service status: systemctl status monitorbot"
    read -p "Press Enter to continue..."
}

remove_monitorbot() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}Error: This script requires root privileges${NC}"
        exit 1
    fi

    echo -e "${GREEN}Starting MonitorBot removal...${NC}"

    if [ ! -d "$INSTALL_DIR" ]; then
        echo -e "${RED}Error: MonitorBot is not installed${NC}"
        exit 1
    fi

    read -p "Are you sure you want to remove MonitorBot? [y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Removal canceled${NC}"
        exit 0
    fi

    # Stop service
    echo -e "${YELLOW}Stopping service...${NC}"
    systemctl stop monitorbot
    systemctl disable monitorbot

    # Remove files
    echo -e "${YELLOW}Removing files...${NC}"
    [ -f "$SERVICE_FILE" ] && rm -f "$SERVICE_FILE"
    [ -d "$INSTALL_DIR" ] && rm -rf "$INSTALL_DIR"
    
    systemctl daemon-reload

    echo -e "${GREEN}MonitorBot removed successfully!${NC}"
    read -p "Press Enter to continue..."
}

while true; do
    show_menu
    case $choice in
        1) install_monitorbot ;;
        2) remove_monitorbot ;;
        3) echo -e "${BLUE}Exiting...${NC}"; exit 0 ;;
        *) echo -e "${RED}Invalid option! Please select 1-3${NC}"; sleep 1 ;;
    esac
done
