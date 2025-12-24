# frpc Setup Guide

## Overview

The frpc (Fast Reverse Proxy Client) integration allows you to establish SSH tunnels to your remote clients through a central frps server, even when clients are behind NAT or firewalls.

## How It Works

### Unique Port Assignment

Each client automatically gets a **unique remote port** calculated from its hostname:
- Port range: **10000-19999**
- Calculation: MD5 hash of hostname → mapped to port range
- Same hostname = same port (consistent across reinstalls)
- Different hostnames = different ports (avoids conflicts)

### Unique Proxy Names

Each client gets a unique proxy name:
- Based on hostname (lowercase, alphanumeric)
- Example: hostname `web-server-1` → proxy name `web-server-1`
- Generic/empty hostnames get random names like `ssh-a1b2c3d4`

## Installation from Server

### Install frpc on a client:

```bash
server> @client-name install-frpc
```

The output will show:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ frpc installed and started successfully
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Installation Details:
  Service: frpc
  Binary: /etc/frpc/frpc
  Config: /etc/frpc/frpc.toml
  Proxy Name: client-hostname
  Remote Port: 12345

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️  IMPORTANT: SSH CONNECTION INFORMATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

To connect to this client via SSH, use:

    ssh root@37.32.13.95 -p 12345

Or for a specific user:

    ssh username@37.32.13.95 -p 12345

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Port Assignment Examples

| Hostname | Proxy Name | Remote Port (approx) |
|----------|------------|---------------------|
| web-server-1 | web-server-1 | 14523 |
| db-server | db-server | 11789 |
| pc | pc | 16234 |
| localhost | ssh-a1b2c3d4 | 13456 |

*Note: Actual ports depend on MD5 hash calculation*

## Configuration

### Server Configuration (frps)

You need an frps server running on `37.32.13.95:8443` with the following configuration:

```toml
# /etc/frps/frps.toml
bindPort = 8443

auth.method = "token"
auth.token = "ChangeThisToAComplexPassword123!"

transport.tls.enable = true
transport.tls.certFile = "/path/to/cert.pem"
transport.tls.keyFile = "/path/to/key.pem"

# Allow wide port range for SSH tunnels
allowPorts = [
  { start = 10000, end = 19999 }
]
```

### Generate SSL Certificate

```bash
mkdir -p /etc/frps
openssl req -newkey rsa:2048 -nodes -keyout /etc/frps/key.pem \
  -x509 -days 365 -out /etc/frps/cert.pem \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=37.32.13.95"
```

### Start frps Server

```bash
# Download frps
wget https://github.com/fatedier/frp/releases/latest/download/frp_*_linux_amd64.tar.gz
tar -xzf frp_*_linux_amd64.tar.gz
cd frp_*_linux_amd64

# Start server
./frps -c /etc/frps/frps.toml
```

Or create a systemd service:

```bash
cat > /etc/systemd/system/frps.service << 'EOF'
[Unit]
Description=frp Server Service
After=network.target
Wants=network.target

[Service]
Type=simple
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/bin/frps -c /etc/frps/frps.toml
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable frps
systemctl start frps
```

## Troubleshooting

### "proxy already exists" Error

**Problem**: Multiple clients with the same hostname or reinstalling without cleaning up.

**Solution**:
1. Uninstall first: `uninstall-frpc`
2. Then reinstall: `install-frpc`
3. Or restart the frps server to clear all proxies

### Cannot SSH to the Remote Port

**Check 1: Client Connection**
```bash
systemctl status frpc
journalctl -u frpc -f
```

Look for: `login to server success` and `proxy added: [name]`

**Check 2: Server Firewall**
```bash
# On frps server
ufw allow 10000:19999/tcp
# Or for specific port
ufw allow 12345/tcp
```

**Check 3: Port Range in frps Config**
Make sure `allowPorts` includes your port range (10000-19999)

**Check 4: frps Server Running**
```bash
# On frps server
systemctl status frps
# or
ps aux | grep frps
```

### Find Your Client's Port

If you forgot the port number:

```bash
# On the client
cat /etc/frpc/frpc.toml | grep remotePort

# Or check the logs
journalctl -u frpc | grep "proxy added"
```

### Change Port After Installation

If you need a different port:

```bash
# Edit the config
nano /etc/frpc/frpc.toml
# Change: remotePort = 12345

# Restart the service
systemctl restart frpc
```

## Uninstallation

From the server, send:

```bash
server> @client-name uninstall-frpc
```

Or manually on the client:

```bash
uninstall-frpc
```

This will:
- Stop and disable the frpc service
- Remove all frpc files and configuration
- Clean up systemd

## Security Notes

1. **Authentication**: Uses token-based authentication with TLS encryption
2. **Port Range**: Uses high ports (10000-19999) to avoid conflicts
3. **SSH Keys**: Recommend using SSH keys instead of passwords for SSH access
4. **Firewall**: Ensure frps server firewall only allows necessary ports
5. **Token**: Change the default token in `install_frpc.sh` before deployment

## Port Calculation Details

The port is calculated as:
```bash
MD5_HASH=$(echo -n "hostname" | md5sum | cut -c1-4)
PORT=$((0x${MD5_HASH} % 10000 + 10000))
```

This ensures:
- **Deterministic**: Same hostname always gets the same port
- **Distributed**: Ports are spread across the range
- **Collision-resistant**: Hash-based distribution reduces conflicts
- **Range-bound**: Always between 10000-19999

## Multiple Clients Example

```bash
# Install on multiple clients
server> @web-server install-frpc
# Output: ssh root@37.32.13.95 -p 14523

server> @db-server install-frpc
# Output: ssh root@37.32.13.95 -p 11789

server> @app-server install-frpc
# Output: ssh root@37.32.13.95 -p 16842

# Now you can SSH to any client
ssh root@37.32.13.95 -p 14523  # web-server
ssh root@37.32.13.95 -p 11789  # db-server
ssh root@37.32.13.95 -p 16842  # app-server
```

## References

- frp GitHub: https://github.com/fatedier/frp
- frp Documentation: https://gofrp.org/docs/

