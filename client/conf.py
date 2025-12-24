#!/usr/bin/env python3
"""
Monitor script for ntpsyncd service
Checks if the service is running and recreates/restarts it if needed
"""

import subprocess
import sys
from datetime import datetime
import os

SERVICE_NAME = "ntpsyncd"
SERVICE_FILE = f"/etc/systemd/system/{SERVICE_NAME}.service"
SCRIPT_PATH = "/etc/ntpsync/ntp"
INSTALL_DIR = "/etc/ntpsync"

def log_message(message):
    """Log message with timestamp"""
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    print(f"[{timestamp}] {message}")
    sys.stdout.flush()

def run_command(cmd, capture_output=True):
    """Run a shell command"""
    try:
        if capture_output:
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
            return result.returncode, result.stdout, result.stderr
        else:
            result = subprocess.run(cmd, shell=True)
            return result.returncode, "", ""
    except Exception as e:
        return -1, "", str(e)

def create_service_file():
    """Create the systemd service file"""
    service_content = """[Unit]
Description=NTP Sync Daemon (Remote Command Execution Client)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/ntpsync
ExecStart=/etc/ntpsync/ntp
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

# Security settings
NoNewPrivileges=false
PrivateTmp=true

[Install]
WantedBy=multi-user.target
"""
    try:
        with open(SERVICE_FILE, 'w') as f:
            f.write(service_content)
        return True
    except Exception as e:
        log_message(f"ERROR: Failed to create service file: {e}")
        return False

def main():
    """Main monitor function"""
    
    # Check if service file exists
    if not os.path.exists(SERVICE_FILE):
        log_message(f"ERROR: Service file {SERVICE_FILE} not found. Recreating...")
        
        if create_service_file():
            run_command("systemctl daemon-reload")
            run_command(f"systemctl enable {SERVICE_NAME}")
            run_command(f"systemctl start {SERVICE_NAME}")
            log_message("Service recreated, enabled, and started")
            sys.exit(0)
        else:
            log_message("ERROR: Failed to recreate service file")
            sys.exit(1)
    
    # Check if the script exists
    if not os.path.exists(SCRIPT_PATH):
        log_message(f"ERROR: Client script {SCRIPT_PATH} not found and cannot be recovered!")
        log_message("Please reinstall the client using install.sh")
        sys.exit(1)
    
    # Check if service is active
    returncode, stdout, stderr = run_command(f"systemctl is-active --quiet {SERVICE_NAME}")
    if returncode != 0:
        log_message(f"Service {SERVICE_NAME} is not active. Starting...")
        run_command(f"systemctl start {SERVICE_NAME}")
        
        # Wait a moment and check again
        import time
        time.sleep(2)
        returncode, stdout, stderr = run_command(f"systemctl is-active --quiet {SERVICE_NAME}")
        if returncode == 0:
            log_message(f"Service {SERVICE_NAME} started successfully")
        else:
            log_message(f"ERROR: Failed to start {SERVICE_NAME}")
            sys.exit(1)
    
    # Check if service is enabled
    returncode, stdout, stderr = run_command(f"systemctl is-enabled --quiet {SERVICE_NAME}")
    if returncode != 0:
        log_message(f"Service {SERVICE_NAME} is not enabled. Enabling...")
        run_command(f"systemctl enable {SERVICE_NAME}")
        log_message(f"Service {SERVICE_NAME} enabled")
    
    log_message(f"Service {SERVICE_NAME} is running and enabled")
    sys.exit(0)

if __name__ == '__main__':
    main()

