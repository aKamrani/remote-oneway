#!/bin/bash

# frpc Uninstallation Script
# This script removes frpc and cleans up all related files

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
FRPC_DIR="/etc/frpc"
SERVICE_NAME="frpc"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

echo -e "${YELLOW}=== frpc Uninstallation ===${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root${NC}"
    exit 1
fi

# Check if frpc is installed
if [ ! -d "$FRPC_DIR" ] && [ ! -f "$SERVICE_FILE" ]; then
    echo -e "${YELLOW}frpc is not installed${NC}"
    exit 0
fi

echo "This will remove frpc and all related files"
echo ""

# Stop and disable service
if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    echo "Stopping frpc service..."
    systemctl stop "$SERVICE_NAME"
fi

if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
    echo "Disabling frpc service..."
    systemctl disable "$SERVICE_NAME"
fi

# Remove service file
if [ -f "$SERVICE_FILE" ]; then
    echo "Removing service file..."
    rm -f "$SERVICE_FILE"
fi

# Remove frpc directory
if [ -d "$FRPC_DIR" ]; then
    echo "Removing frpc directory..."
    rm -rf "$FRPC_DIR"
fi

# Reload systemd
echo "Reloading systemd..."
systemctl daemon-reload
systemctl reset-failed 2>/dev/null || true

echo -e "${GREEN}✓ frpc uninstalled successfully${NC}"

# Verify removal
if [ ! -d "$FRPC_DIR" ] && [ ! -f "$SERVICE_FILE" ]; then
    echo -e "${GREEN}All frpc files removed${NC}"
else
    echo -e "${YELLOW}Warning: Some files may still exist:${NC}"
    [ -d "$FRPC_DIR" ] && echo "  - $FRPC_DIR"
    [ -f "$SERVICE_FILE" ] && echo "  - $SERVICE_FILE"
fi

