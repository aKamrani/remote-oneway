#!/bin/bash
#
# Update configuration and restart the client service
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/etc/ntpsync"
SERVICE_NAME="ntpsyncd"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root${NC}"
    echo "Please run: sudo $0"
    exit 1
fi

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}Update Client Configuration${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""

# Check if .env exists in current directory
if [ ! -f ".env" ]; then
    echo -e "${RED}Error: .env file not found in current directory${NC}"
    echo "Please create .env file first or run from the client directory"
    exit 1
fi

# Show current configuration
echo "Current configuration in .env:"
cat .env
echo ""

# Confirm update
read -p "Copy this configuration to $INSTALL_DIR/.env? (y/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Update cancelled"
    exit 0
fi

# Copy .env file
echo -e "${GREEN}[1/2]${NC} Copying configuration..."
cp ".env" "$INSTALL_DIR/.env"
echo "Configuration copied to $INSTALL_DIR/.env"

# Restart service
echo -e "${GREEN}[2/2]${NC} Restarting service..."
systemctl restart "$SERVICE_NAME"

# Wait a moment
sleep 2

# Check status
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo -e "${GREEN}Service restarted successfully!${NC}"
else
    echo -e "${RED}Service failed to restart${NC}"
    exit 1
fi

echo ""
echo "Recent service logs:"
journalctl -u "$SERVICE_NAME" -n 10 --no-pager

echo ""
echo -e "${GREEN}Configuration updated successfully!${NC}"

