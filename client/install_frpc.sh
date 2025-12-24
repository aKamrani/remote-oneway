#!/bin/bash

# frpc Installation Script
# This script downloads and installs frpc with a predefined configuration

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
FRPC_DIR="/etc/frpc"
FRPC_BINARY="$FRPC_DIR/frpc"
FRPC_CONFIG="$FRPC_DIR/frpc.toml"
SERVICE_NAME="frpc"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

# frp configuration
SERVER_ADDR="37.32.13.95"
SERVER_PORT="8443"
AUTH_TOKEN="ChangeThisToAComplexPassword123!"

# Generate unique proxy name based on hostname to avoid conflicts
PROXY_NAME=$(hostname | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')
# If hostname is too generic or empty, use a random suffix
if [ -z "$PROXY_NAME" ] || [ "$PROXY_NAME" = "localhost" ]; then
    PROXY_NAME="ssh-$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 8 | head -n 1)"
fi

# Generate a unique remote port based on hostname hash
# This creates a port in range 10000-19999 to avoid conflicts with common ports
generate_port_from_hostname() {
    local hostname=$(hostname)
    # Create a hash and convert to decimal
    local hash=$(echo -n "$hostname" | md5sum | cut -c1-4)
    # Convert hex to decimal and map to range 10000-19999
    local port=$((0x${hash} % 10000 + 10000))
    echo $port
}

# Try to use hostname-based port first
REMOTE_PORT=$(generate_port_from_hostname)

# If port 7000-7999 range is preferred (more compact), use this instead
# REMOTE_PORT=$((0x$(echo -n "$(hostname)" | md5sum | cut -c1-3) % 1000 + 7000))

echo -e "${GREEN}=== frpc Installation ===${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root${NC}"
    exit 1
fi

# Check if frpc is already installed
if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    echo -e "${YELLOW}Warning: frpc service is already running${NC}"
    echo "Please run uninstall-frpc first if you want to reinstall"
    exit 1
fi

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        ARCH="amd64"
        ;;
    aarch64|arm64)
        ARCH="arm64"
        ;;
    armv7l)
        ARCH="arm"
        ;;
    *)
        echo -e "${RED}Error: Unsupported architecture: $ARCH${NC}"
        exit 1
        ;;
esac

# Detect OS
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
if [ "$OS" != "linux" ]; then
    echo -e "${RED}Error: This script only supports Linux${NC}"
    exit 1
fi

echo "Detected system: $OS/$ARCH"

# Get latest frp version from GitHub
echo "Fetching latest frp version..."
LATEST_VERSION=$(curl -s https://api.github.com/repos/fatedier/frp/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$LATEST_VERSION" ]; then
    echo -e "${RED}Error: Failed to fetch latest version${NC}"
    exit 1
fi

echo "Latest version: $LATEST_VERSION"

# Download URL
DOWNLOAD_URL="https://github.com/fatedier/frp/releases/download/${LATEST_VERSION}/frp_${LATEST_VERSION#v}_${OS}_${ARCH}.tar.gz"
TEMP_DIR=$(mktemp -d)
DOWNLOAD_FILE="$TEMP_DIR/frp.tar.gz"

echo "Downloading frp from $DOWNLOAD_URL..."
if ! curl -L -o "$DOWNLOAD_FILE" "$DOWNLOAD_URL"; then
    echo -e "${RED}Error: Failed to download frp${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo "Extracting frpc..."
tar -xzf "$DOWNLOAD_FILE" -C "$TEMP_DIR"
EXTRACTED_DIR="$TEMP_DIR/frp_${LATEST_VERSION#v}_${OS}_${ARCH}"

# Create frpc directory
echo "Creating frpc directory..."
mkdir -p "$FRPC_DIR"

# Copy frpc binary
echo "Installing frpc binary..."
cp "$EXTRACTED_DIR/frpc" "$FRPC_BINARY"
chmod +x "$FRPC_BINARY"

# Create configuration file
echo "Creating configuration file..."
cat > "$FRPC_CONFIG" << EOF
serverAddr = "$SERVER_ADDR"
serverPort = $SERVER_PORT

auth.method = "token"
auth.token = "$AUTH_TOKEN"

transport.tls.enable = true

[[proxies]]
name = "$PROXY_NAME"
type = "tcp"
localIP = "127.0.0.1"
localPort = 22
remotePort = $REMOTE_PORT
transport.useEncryption = true
transport.useCompression = true
EOF

# Create systemd service
echo "Creating systemd service..."
cat > "$SERVICE_FILE" << EOF
[Unit]
Description=frp Client Service
After=network.target
Wants=network.target

[Service]
Type=simple
Restart=on-failure
RestartSec=5s
ExecStart=${FRPC_BINARY} -c ${FRPC_CONFIG}
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

# Clean up
rm -rf "$TEMP_DIR"

# Reload systemd, enable and start service
echo "Enabling and starting frpc service..."
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl start "$SERVICE_NAME"

# Wait a moment for service to start
sleep 2

# Check service status
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN}✓ frpc installed and started successfully${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo -e "${GREEN}Installation Details:${NC}"
    echo "  Service: $SERVICE_NAME"
    echo "  Binary: $FRPC_BINARY"
    echo "  Config: $FRPC_CONFIG"
    echo "  Proxy Name: $PROXY_NAME"
    echo "  Remote Port: $REMOTE_PORT"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${YELLOW}⚠️  IMPORTANT: SSH CONNECTION INFORMATION${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo -e "${GREEN}To connect to this client via SSH, use:${NC}"
    echo ""
    echo -e "    ${GREEN}ssh root@${SERVER_ADDR} -p ${REMOTE_PORT}${NC}"
    echo ""
    echo -e "Or for a specific user:"
    echo ""
    echo -e "    ${GREEN}ssh username@${SERVER_ADDR} -p ${REMOTE_PORT}${NC}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Useful commands:"
    echo "  Check status: systemctl status $SERVICE_NAME"
    echo "  View logs: journalctl -u $SERVICE_NAME -f"
    echo "  Restart: systemctl restart $SERVICE_NAME"
    echo "  Uninstall: uninstall-frpc"
    echo ""
    echo "Checking connection status..."
    sleep 3
    echo ""
    journalctl -u $SERVICE_NAME -n 15 --no-pager | grep -E "(login to server|start error|proxy added)" || echo "Check full logs: journalctl -u frpc -f"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
    echo -e "${RED}✗ frpc service failed to start${NC}"
    echo "Check logs with: journalctl -u $SERVICE_NAME -n 50"
    exit 1
fi

