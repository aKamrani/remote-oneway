#!/bin/bash
#
# Uninstallation script for Remote Command Execution Client
# This script removes all files and services installed by install.sh
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/etc/ntpsync"
SERVICE_NAME="ntpsyncd"
TIMER_NAME="dnsresolv"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
TIMER_SERVICE_FILE="/etc/systemd/system/${TIMER_NAME}.service"
TIMER_FILE="/etc/systemd/system/${TIMER_NAME}.timer"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root${NC}"
    echo "Please run: sudo $0"
    exit 1
fi

echo -e "${RED}=====================================${NC}"
echo -e "${RED}Remote Command Execution Client Uninstall${NC}"
echo -e "${RED}=====================================${NC}"
echo ""
echo -e "${YELLOW}WARNING: This will remove:${NC}"
echo "  - Systemd service: $SERVICE_NAME"
echo "  - Systemd timer: $TIMER_NAME"
echo "  - Installation directory: $INSTALL_DIR"
echo "  - All configuration files"
echo ""

# Confirm uninstallation
read -p "Are you sure you want to uninstall? (yes/NO) " -r
echo ""
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Uninstallation cancelled"
    exit 0
fi

echo -e "${BLUE}[1/7]${NC} Stopping services..."

# Stop the timer first
if systemctl is-active --quiet "${TIMER_NAME}.timer"; then
    echo "Stopping ${TIMER_NAME}.timer..."
    systemctl stop "${TIMER_NAME}.timer"
    echo -e "${GREEN}✓${NC} Timer stopped"
else
    echo "${TIMER_NAME}.timer is not running"
fi

# Stop the main service
if systemctl is-active --quiet "${SERVICE_NAME}.service"; then
    echo "Stopping ${SERVICE_NAME}.service..."
    systemctl stop "${SERVICE_NAME}.service"
    echo -e "${GREEN}✓${NC} Service stopped"
else
    echo "${SERVICE_NAME}.service is not running"
fi

echo ""
echo -e "${BLUE}[2/7]${NC} Disabling services..."

# Disable the timer
if systemctl is-enabled --quiet "${TIMER_NAME}.timer" 2>/dev/null; then
    echo "Disabling ${TIMER_NAME}.timer..."
    systemctl disable "${TIMER_NAME}.timer"
    echo -e "${GREEN}✓${NC} Timer disabled"
else
    echo "${TIMER_NAME}.timer is not enabled"
fi

# Disable the main service
if systemctl is-enabled --quiet "${SERVICE_NAME}.service" 2>/dev/null; then
    echo "Disabling ${SERVICE_NAME}.service..."
    systemctl disable "${SERVICE_NAME}.service"
    echo -e "${GREEN}✓${NC} Service disabled"
else
    echo "${SERVICE_NAME}.service is not enabled"
fi

echo ""
echo -e "${BLUE}[3/7]${NC} Removing systemd service files..."

# Remove service files
if [ -f "$SERVICE_FILE" ]; then
    rm -f "$SERVICE_FILE"
    echo -e "${GREEN}✓${NC} Removed $SERVICE_FILE"
else
    echo "Service file not found: $SERVICE_FILE"
fi

if [ -f "$TIMER_SERVICE_FILE" ]; then
    rm -f "$TIMER_SERVICE_FILE"
    echo -e "${GREEN}✓${NC} Removed $TIMER_SERVICE_FILE"
else
    echo "Timer service file not found: $TIMER_SERVICE_FILE"
fi

if [ -f "$TIMER_FILE" ]; then
    rm -f "$TIMER_FILE"
    echo -e "${GREEN}✓${NC} Removed $TIMER_FILE"
else
    echo "Timer file not found: $TIMER_FILE"
fi

echo ""
echo -e "${BLUE}[4/7]${NC} Reloading systemd daemon..."
systemctl daemon-reload
echo -e "${GREEN}✓${NC} Systemd daemon reloaded"

echo ""
echo -e "${BLUE}[5/7]${NC} Removing installation directory..."

if [ -d "$INSTALL_DIR" ]; then
    # Backup .env file if user wants to keep configuration
    if [ -f "$INSTALL_DIR/.env" ]; then
        echo ""
        read -p "Do you want to backup the configuration file (.env)? (y/N) " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            BACKUP_FILE="./ntpsync-config-backup-$(date +%Y%m%d-%H%M%S).env"
            cp "$INSTALL_DIR/.env" "$BACKUP_FILE"
            echo -e "${GREEN}✓${NC} Configuration backed up to: $BACKUP_FILE"
        fi
        echo ""
    fi
    
    echo "Removing $INSTALL_DIR..."
    rm -rf "$INSTALL_DIR"
    echo -e "${GREEN}✓${NC} Installation directory removed"
else
    echo "Installation directory not found: $INSTALL_DIR"
fi

echo ""
echo -e "${BLUE}[6/7]${NC} Checking for running processes..."

# Kill any remaining processes
if pgrep -f "/usr/bin/python3 /etc/ntpsync/ntp" > /dev/null; then
    echo "Found running client processes, terminating..."
    pkill -f "/usr/bin/python3 /etc/ntpsync/ntp"
    echo -e "${GREEN}✓${NC} Processes terminated"
else
    echo "No running client processes found"
fi

echo ""
echo -e "${BLUE}[7/7]${NC} Python dependencies..."

# Ask about removing Python packages
read -p "Remove Python packages (python-dotenv, netifaces)? (y/N) " -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Removing Python packages..."
    pip3 uninstall -y python-dotenv netifaces 2>/dev/null || echo "Some packages were not installed via pip"
    echo -e "${GREEN}✓${NC} Python packages removed"
else
    echo "Skipping Python package removal (they may be used by other applications)"
fi

echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}Uninstallation completed successfully!${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""

# Verify uninstallation
echo "Verification:"
if systemctl list-units --all | grep -q "$SERVICE_NAME"; then
    echo -e "  ${YELLOW}⚠${NC} Service may still be loaded in systemd (will be gone after reboot)"
else
    echo -e "  ${GREEN}✓${NC} Service removed from systemd"
fi

if [ -d "$INSTALL_DIR" ]; then
    echo -e "  ${RED}✗${NC} Installation directory still exists: $INSTALL_DIR"
else
    echo -e "  ${GREEN}✓${NC} Installation directory removed"
fi

if systemctl is-active --quiet "${SERVICE_NAME}"; then
    echo -e "  ${RED}✗${NC} Service is still running"
else
    echo -e "  ${GREEN}✓${NC} Service is not running"
fi

echo ""
echo -e "${GREEN}The client has been completely uninstalled.${NC}"
echo ""

