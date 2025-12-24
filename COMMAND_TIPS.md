# Command Execution Tips

## Interactive vs Non-Interactive Commands

The remote execution system can run most commands, but some work better than others due to the non-interactive nature of the system.

## ✅ Commands That Work Well

### System Information
```bash
uname -a          # System information
hostname          # Hostname
uptime            # System uptime
df -h             # Disk usage
free -h           # Memory usage
lscpu             # CPU information
lsblk             # Block devices
```

### Process Management
```bash
ps aux            # Process list
pgrep nginx       # Find processes by name
pkill nginx       # Kill processes by name
systemctl status nginx  # Service status
systemctl restart nginx # Restart service
kill -9 PID       # Kill process by PID
```

### File Operations
```bash
ls -la /path      # List files
cat file.txt      # Display file contents
tail -f /var/log/syslog  # Follow log (will run for 60s then timeout)
head -n 20 file.txt      # Show first 20 lines
grep "error" /var/log/*  # Search in files
find /path -name "*.log" # Find files
```

### Network
```bash
ip addr           # Network interfaces
netstat -tulpn    # Network connections
ss -tulpn         # Socket statistics
ping -c 4 8.8.8.8 # Ping (limited count)
curl https://example.com  # HTTP request
wget -O- https://example.com  # Download to stdout
```

### Package Management
```bash
apt update        # Update package lists
apt list --installed  # List installed packages
dpkg -l           # List packages
which python3     # Find command location
```

## ⚠️ Interactive Commands (Limited Support)

These commands need a terminal but can work with the `script` wrapper:

### Process Monitors
```bash
# Instead of: htop
# Use these alternatives:
top -b -n 1       # Top in batch mode (one iteration)
ps aux --sort=-%mem | head -20  # Top memory users
ps aux --sort=-%cpu | head -20  # Top CPU users

# htop now works with pseudo-terminal support
htop              # Works with script wrapper
```

### Text Editors
```bash
# Instead of: nano file.txt or vim file.txt
# Use these alternatives:
cat > file.txt << 'EOF'
content here
EOF

echo "content" > file.txt     # Write to file
echo "more" >> file.txt       # Append to file
sed -i 's/old/new/g' file.txt # Edit in place
```

### Pagers
```bash
# Instead of: less file.txt or more file.txt
# Use these alternatives:
cat file.txt      # Display entire file
head -n 100 file.txt  # First 100 lines
tail -n 100 file.txt  # Last 100 lines
grep "pattern" file.txt  # Search and display matches
```

## ❌ Commands That Won't Work

### Truly Interactive Applications
- **SSH sessions**: `ssh user@host` (no way to enter password or interact)
- **Interactive prompts**: Commands asking for confirmation without `-y` flag
- **TUI applications**: Without the script wrapper (now supported for some)
- **Real-time monitoring**: Commands meant to run indefinitely will timeout after 60s

### Workarounds

1. **For commands needing confirmation:**
   ```bash
   # Instead of: apt install package
   apt install -y package
   
   # Instead of: rm -i file
   rm -f file
   ```

2. **For monitoring commands:**
   ```bash
   # Instead of running top continuously
   # Use single iteration:
   top -b -n 1
   
   # Instead of tail -f (which runs forever)
   # Use with timeout:
   timeout 30 tail -f /var/log/syslog  # Run for 30 seconds
   ```

3. **For SSH and remote commands:**
   ```bash
   # Use SSH with key authentication and non-interactive flags
   ssh -o StrictHostKeyChecking=no -i key.pem user@host 'command'
   
   # Or use sshpass for password auth
   sshpass -p 'password' ssh user@host 'command'
   ```

## 💡 Tips for Best Results

1. **Use non-interactive flags:**
   - Add `-y` for yes
   - Add `-f` for force
   - Add `-q` for quiet
   - Add `-b` for batch mode

2. **Limit output:**
   ```bash
   command | head -n 100     # Limit to first 100 lines
   command 2>&1 | head -n 50 # Limit stdout and stderr
   ```

3. **Use timeouts for long-running commands:**
   ```bash
   timeout 30s long-running-command  # Kill after 30 seconds
   ```

4. **Combine commands:**
   ```bash
   cd /path && ls -la && pwd  # Multiple commands
   command1 || command2        # Run command2 if command1 fails
   command1 && command2        # Run command2 if command1 succeeds
   ```

5. **Capture output properly:**
   ```bash
   command 2>&1              # Combine stderr and stdout
   command 2>/dev/null       # Suppress errors
   command > /tmp/output.log 2>&1  # Save to file
   ```

## 📊 Example: System Health Check

```bash
# Single command that provides system overview
echo "=== System Info ===" && \
uname -a && \
echo "=== Uptime ===" && \
uptime && \
echo "=== Memory ===" && \
free -h && \
echo "=== Disk ===" && \
df -h && \
echo "=== Top Processes ===" && \
ps aux --sort=-%mem | head -10
```

## 🔧 Troubleshooting

If a command fails:

1. **Check if it needs TTY**: Try with `script -q -c "command" /dev/null`
2. **Check permissions**: Ensure the command can run as root
3. **Check timeout**: Long commands will timeout after 60 seconds
4. **Check syntax**: Test the command locally first
5. **Check environment**: Some commands need specific env variables

## 📝 Notes

- All commands run with root privileges (be careful!)
- Commands timeout after 60 seconds
- Output is limited by buffer size (4096 bytes per read)
- Some terminal escape sequences may appear in output from interactive commands
- The `script` command creates a pseudo-terminal for better compatibility

