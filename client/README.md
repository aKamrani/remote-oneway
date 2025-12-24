# Remote Command Execution Client

## Installation

### Quick Installation (Automated)

Run the installation script as root:

```bash
sudo ./install.sh
```

This will:
- Install the client script to `/etc/ntpsync/ntp`
- Create and enable the `ntpsyncd` systemd service
- Create and enable the `dnsresolv` systemd timer (monitors the service every minute)
- Start the client service

### Uninstallation

To completely remove the client and all installed components:

```bash
sudo ./uninstall.sh
```

This will:
- Stop and disable all services
- Remove all systemd service files
- Remove the installation directory (`/etc/ntpsync`)
- Optionally backup configuration before removal
- Optionally remove Python dependencies

### Manual Installation

1. Install Python 3.7 or higher
2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
3. Configure the client by copying `.env.example` to `.env` and editing it:
   ```bash
   cp .env.example .env
   nano .env
   ```
4. Set the `SERVER_HOST` to your server's IP address

## Configuration

Edit the `.env` file:

- `SERVER_HOST`: Server IP address or hostname (default: localhost)
- `SERVER_PORT`: Server port (default: 8443)

## Running the Client

**Note**: The client must be run as root to execute commands with root privileges.

```bash
sudo python client.py
```

## Systemd Service

The installation script creates:

1. **ntpsyncd.service** - Runs the client as a background service
2. **dnsresolv.timer** - Monitors the service every minute and ensures it's running

### Service Management

```bash
# Check service status
sudo systemctl status ntpsyncd

# View service logs
sudo journalctl -u ntpsyncd -f

# Manually restart service
sudo systemctl restart ntpsyncd

# Check timer status
sudo systemctl status dnsresolv.timer

# View timer logs
sudo journalctl -u dnsresolv.timer -f
```

## Security Warning

⚠️ **WARNING**: This client executes commands received from the server with root privileges. Use only in trusted, isolated networks. Ensure proper firewall rules and access controls are in place.

