# Remote Command Execution Server

## Installation

1. Install Python 3.7 or higher
2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
   
   **Note for Windows users**: The server uses `pyreadline3` to enable command history and arrow key navigation. This is automatically installed on Windows from requirements.txt.

## Configuration

Edit the `.env` file to configure the server:

- `SERVER_HOST`: Host to bind to (default: 0.0.0.0)
- `SERVER_PORT`: Port to listen on (default: 8443)

## Running the Server

```bash
python server.py
```

## Usage

Once the server is running, you can:

1. Type any shell command to execute it on all connected clients
2. Type `list` or `clients` to see connected clients
3. Type `exit` or `quit` to shutdown the server

The server will display the output (stdout and stderr) from each client after command execution.

### Command Line Features

The server provides bash-like command line editing:
- **Up/Down arrows**: Navigate command history
- **Left/Right arrows**: Move cursor within the line
- **Ctrl+A**: Jump to beginning of line
- **Ctrl+E**: Jump to end of line
- **Backspace/Delete**: Edit commands
- **Tab**: Auto-completion (if available)

## Security Warning

⚠️ **WARNING**: This server allows remote command execution with root privileges on connected clients. Use only in trusted, isolated networks. Ensure proper firewall rules and access controls are in place.

