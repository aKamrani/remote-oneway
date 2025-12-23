#!/usr/bin/env python3
"""
Remote Command Execution Server
Listens for client connections and allows sending commands to clients.
"""

import socket
import threading
import json
import os
from datetime import datetime
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configuration
HOST = os.getenv('SERVER_HOST', '0.0.0.0')
PORT = int(os.getenv('SERVER_PORT', '8443'))
BUFFER_SIZE = 4096

# Store active clients and pending commands
clients = {}
pending_commands = {}
command_lock = threading.Lock()


class ClientHandler(threading.Thread):
    """Handle individual client connections"""
    
    def __init__(self, conn, addr):
        super().__init__()
        self.conn = conn
        self.addr = addr
        self.client_id = f"{addr[0]}:{addr[1]}"
        self.daemon = True
        
    def run(self):
        """Handle client communication"""
        print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] Client connected: {self.client_id}")
        
        try:
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
                            print(f"Response from {self.client_id}:")
                            print(f"Command: {response.get('command', 'N/A')}")
                            print(f"Exit Code: {response.get('exit_code', 'N/A')}")
                            print(f"\n--- STDOUT ---")
                            print(response.get('stdout', '(empty)'))
                            if response.get('stderr'):
                                print(f"\n--- STDERR ---")
                                print(response.get('stderr'))
                            print(f"{'='*80}\n")
                        except json.JSONDecodeError:
                            print(f"[ERROR] Invalid response from {self.client_id}")
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
            print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] Error with client {self.client_id}: {e}")
        finally:
            self.conn.close()
            print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] Client disconnected: {self.client_id}")
            with command_lock:
                if self.client_id in clients:
                    del clients[self.client_id]


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


def command_input_loop():
    """Accept commands from user input"""
    print("\n" + "="*80)
    print("Remote Command Execution Server")
    print("="*80)
    print("Available commands:")
    print("  - Type any shell command to execute on all connected clients")
    print("  - 'list' or 'clients' - Show connected clients")
    print("  - 'exit' or 'quit' - Shutdown server")
    print("="*80 + "\n")
    
    while True:
        try:
            command = input("server> ").strip()
            
            if not command:
                continue
                
            if command.lower() in ['exit', 'quit']:
                print("Shutting down server...")
                os._exit(0)
                
            if command.lower() in ['list', 'clients']:
                with command_lock:
                    if clients:
                        print(f"\nConnected clients ({len(clients)}):")
                        for client_id in clients:
                            print(f"  - {client_id}")
                    else:
                        print("\nNo clients connected.")
                print()
                continue
            
            # Queue command for all connected clients
            with command_lock:
                if not clients:
                    print("[WARNING] No clients connected. Command will not be executed.\n")
                else:
                    for client_id in clients:
                        pending_commands[client_id] = command
                    print(f"[INFO] Command queued for {len(clients)} client(s)\n")
                    
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

