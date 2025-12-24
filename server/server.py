#!/usr/bin/env python3
"""
Remote Command Execution Server
Listens for client connections and allows sending commands to clients.
"""

import socket
import threading
import json
import os
import sys
from datetime import datetime
from dotenv import load_dotenv

# Import readline for command history and line editing
try:
    import readline
    # Enable tab completion (optional)
    readline.parse_and_bind('tab: complete')
    # Set history length
    readline.set_history_length(1000)
except ImportError:
    # readline not available on Windows by default
    # You can install pyreadline3 on Windows: pip install pyreadline3
    print("Warning: readline module not available. Command history and arrow keys won't work.")
    print("On Windows, install: pip install pyreadline3")
    readline = None

# Load environment variables
load_dotenv()

# Configuration
HOST = os.getenv('SERVER_HOST', '0.0.0.0')
PORT = int(os.getenv('SERVER_PORT', '8443'))
BUFFER_SIZE = 4096

# Store active clients and pending commands
clients = {}
client_names = {}  # Maps client_name -> client_id (addr:port)
pending_commands = {}
command_lock = threading.Lock()


class ClientHandler(threading.Thread):
    """Handle individual client connections"""
    
    def __init__(self, conn, addr):
        super().__init__()
        self.conn = conn
        self.addr = addr
        self.client_id = f"{addr[0]}:{addr[1]}"
        self.client_name = None
        self.daemon = True
        
    def run(self):
        """Handle client communication"""
        print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] Client connected: {self.client_id}")
        
        try:
            # First, wait for client identification
            self.conn.settimeout(10)
            try:
                data = self.conn.recv(BUFFER_SIZE)
                if data:
                    try:
                        ident_msg = json.loads(data.decode('utf-8').strip())
                        if ident_msg.get('type') == 'identify':
                            self.client_name = ident_msg.get('client_name', self.client_id)
                            with command_lock:
                                client_names[self.client_name] = self.client_id
                            print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] Client identified as: {self.client_name}")
                    except json.JSONDecodeError:
                        pass
            except socket.timeout:
                print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] Client identification timeout")
            finally:
                self.conn.settimeout(None)
            
            # If no identification received, use IP-based ID
            if not self.client_name:
                self.client_name = self.client_id
                with command_lock:
                    client_names[self.client_name] = self.client_id
            
            while True:
                # Check if there's a pending command for this client
                with command_lock:
                    if self.client_id in pending_commands:
                        command = pending_commands.pop(self.client_id)
                        
                        # Send command to client
                        message = json.dumps({
                            'type': 'command',
                            'command': command
                        })
                        self.conn.sendall(message.encode('utf-8') + b'\n')
                        print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] Command sent to {self.client_id}: {command}")
                        
                        # Wait for response
                        data = self.conn.recv(BUFFER_SIZE)
                        if not data:
                            break
                            
                        try:
                            response = json.loads(data.decode('utf-8'))
                            print(f"\n{'='*80}")
                            print(f"Response from {self.client_name} ({self.client_id}):")
                            print(f"Command: {response.get('command', 'N/A')}")
                            print(f"Exit Code: {response.get('exit_code', 'N/A')}")
                            print(f"\n--- STDOUT ---")
                            print(response.get('stdout', '(empty)'))
                            if response.get('stderr'):
                                print(f"\n--- STDERR ---")
                                print(response.get('stderr'))
                            print(f"{'='*80}\n")
                        except json.JSONDecodeError:
                            print(f"[ERROR] Invalid response from {self.client_name}")
                    else:
                        # Send heartbeat
                        message = json.dumps({'type': 'heartbeat'})
                        self.conn.sendall(message.encode('utf-8') + b'\n')
                        
                        # Wait for acknowledgment (with timeout)
                        self.conn.settimeout(2)
                        try:
                            data = self.conn.recv(BUFFER_SIZE)
                            if not data:
                                break
                        except socket.timeout:
                            pass
                        finally:
                            self.conn.settimeout(None)
                            
        except Exception as e:
            print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] Error with client {self.client_name}: {e}")
        finally:
            self.conn.close()
            print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] Client disconnected: {self.client_name}")
            with command_lock:
                if self.client_id in clients:
                    del clients[self.client_id]
                if self.client_name and self.client_name in client_names:
                    del client_names[self.client_name]


def accept_connections(server_socket):
    """Accept incoming client connections"""
    while True:
        try:
            conn, addr = server_socket.accept()
            client_id = f"{addr[0]}:{addr[1]}"
            
            handler = ClientHandler(conn, addr)
            clients[client_id] = handler
            handler.start()
        except Exception as e:
            print(f"[ERROR] Failed to accept connection: {e}")


def parse_command_input(user_input):
    """
    Parse command input to determine target clients and command.
    
    Formats:
        - "command" -> all clients
        - "@client_name command" -> specific client
        - "@all command" -> all clients
        
    Returns:
        tuple: (target_clients, command) where target_clients is list of client_ids or None for all
    """
    user_input = user_input.strip()
    
    if user_input.startswith('@'):
        # Extract target and command
        parts = user_input.split(None, 1)
        if len(parts) < 2:
            return None, None
        
        target = parts[0][1:]  # Remove @ symbol
        command = parts[1]
        
        if target.lower() == 'all':
            return None, command  # None means all clients
        else:
            return [target], command
    else:
        # No target specified, execute on all clients
        return None, user_input


def command_input_loop():
    """Accept commands from user input"""
    print("\n" + "="*80)
    print("Remote Command Execution Server")
    print("="*80)
    print("Available commands:")
    print("  - Type any shell command to execute on all connected clients")
    print("  - '@client_name command' - Execute command on specific client")
    print("  - '@all command' - Execute command on all clients")
    print("  - 'list' or 'clients' - Show connected clients")
    print("  - 'exit' or 'quit' - Shutdown server")
    print("="*80)
    
    if readline:
        print("Info: Command history enabled. Use arrow keys to navigate.")
    else:
        print("Warning: Command history disabled. Install pyreadline3 (Windows) or readline.")
    
    print("="*80 + "\n")
    
    while True:
        try:
            # Using input() with readline module enabled provides:
            # - Up/Down arrows for command history
            # - Left/Right arrows for cursor movement
            # - Ctrl+A/E for beginning/end of line
            # - Backspace/Delete for editing
            user_input = input("server> ").strip()
            
            if not user_input:
                continue
                
            if user_input.lower() in ['exit', 'quit']:
                print("Shutting down server...")
                os._exit(0)
                
            if user_input.lower() in ['list', 'clients']:
                with command_lock:
                    if clients:
                        print(f"\nConnected clients ({len(clients)}):")
                        for client_id, handler in clients.items():
                            client_name = handler.client_name if handler.client_name else client_id
                            print(f"  - {client_name} ({client_id})")
                    else:
                        print("\nNo clients connected.")
                print()
                continue
            
            # Parse command input
            target_clients, command = parse_command_input(user_input)
            
            if command is None:
                print("[ERROR] Invalid command format. Use '@client_name command' or just 'command'\n")
                continue
            
            # Queue command for specified clients
            with command_lock:
                if not clients:
                    print("[WARNING] No clients connected. Command will not be executed.\n")
                    continue
                
                if target_clients is None:
                    # Execute on all clients
                    for client_id in clients:
                        pending_commands[client_id] = command
                    print(f"[INFO] Command queued for {len(clients)} client(s)\n")
                else:
                    # Execute on specific client(s)
                    queued = 0
                    for target in target_clients:
                        # Check if target is a client name or client_id
                        client_id = client_names.get(target)
                        if not client_id:
                            # Try direct client_id match
                            if target in clients:
                                client_id = target
                        
                        if client_id and client_id in clients:
                            pending_commands[client_id] = command
                            queued += 1
                        else:
                            print(f"[WARNING] Client '{target}' not found or not connected")
                    
                    if queued > 0:
                        print(f"[INFO] Command queued for {queued} client(s)\n")
                    else:
                        print("[ERROR] No valid clients found for command execution\n")
                    
        except KeyboardInterrupt:
            print("\n\nShutting down server...")
            os._exit(0)
        except Exception as e:
            print(f"[ERROR] {e}\n")


def main():
    """Main server function"""
    # Create socket
    server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    
    try:
        server_socket.bind((HOST, PORT))
        server_socket.listen(5)
        print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] Server listening on {HOST}:{PORT}")
        
        # Start connection acceptor thread
        accept_thread = threading.Thread(target=accept_connections, args=(server_socket,), daemon=True)
        accept_thread.start()
        
        # Start command input loop (main thread)
        command_input_loop()
        
    except Exception as e:
        print(f"[ERROR] Server error: {e}")
    finally:
        server_socket.close()


if __name__ == '__main__':
    main()

