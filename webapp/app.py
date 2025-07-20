#!/usr/bin/env python3
"""
Proxy Farm System - Phase 1
Simple web dashboard for DCOM and 3proxy management
"""

import os
import json
import subprocess
import time
from datetime import datetime
from flask import Flask, render_template, jsonify, request, redirect, url_for
import threading

app = Flask(__name__)
app.secret_key = 'proxy-farm-system-secret-key'

# Paths
PROJECT_ROOT = '/home/proxy-farm-system'
SCRIPTS_PATH = f'{PROJECT_ROOT}/scripts/system'
CONFIGS_PATH = f'{PROJECT_ROOT}/configs'
LOGS_PATH = f'{PROJECT_ROOT}/logs'

# Ensure directories exist
os.makedirs(LOGS_PATH, exist_ok=True)
os.makedirs(f'{CONFIGS_PATH}/dcom', exist_ok=True)

class DCOMManager:
    """Enhanced DCOM management with multi-device support"""
    
    def __init__(self):
        self.modem_ip = "192.168.8.1"
        self.devices = {}  # Store multiple DCOM devices
        self.user_assignments = {}  # User -> DCOM mapping
        self.dcom_assignments = {}  # DCOM -> Users mapping
        self.load_dcom_devices()
        self.load_assignments()
        self.ip_history = {}  # Track IP changes
        self.load_ip_history()
    
    def load_dcom_devices(self):
        """Detect and load available DCOM devices"""
        try:
            # Run detection script
            result = subprocess.run(
                [f'{SCRIPTS_PATH}/detect-dcom-devices.sh'],
                capture_output=True, text=True, timeout=10
            )
            
            if result.returncode == 0:
                # Parse detected devices (mock for now)
                self.devices = {
                    'dcom1': {
                        'id': 'dcom1',
                        'name': 'DCOM Device 1',
                        'interface': 'enx0c5b8f279a64',
                        'ip': '192.168.8.1',
                        'status': 'active',
                        'signal': '-65 dBm',
                        'network': 'LTE',
                        'public_ip': '103.21.244.15',
                        'assigned_users': [],
                        'max_users': 50,
                        'current_load': 0
                    },
                    'dcom2': {
                        'id': 'dcom2', 
                        'name': 'DCOM Device 2',
                        'interface': 'enx0c5b8f279a65',
                        'ip': '192.168.9.1',
                        'status': 'active',
                        'signal': '-72 dBm',
                        'network': 'LTE',
                        'public_ip': '103.21.244.16',
                        'assigned_users': [],
                        'max_users': 50,
                        'current_load': 0
                    },
                    'dcom3': {
                        'id': 'dcom3',
                        'name': 'DCOM Device 3', 
                        'interface': 'enx0c5b8f279a66',
                        'ip': '192.168.10.1',
                        'status': 'inactive',
                        'signal': 'N/A',
                        'network': 'N/A',
                        'public_ip': 'N/A',
                        'assigned_users': [],
                        'max_users': 50,
                        'current_load': 0
                    }
                }
        except Exception as e:
            print(f"Error detecting DCOM devices: {e}")
            # Fallback to single device
            self.devices = {
                'dcom1': {
                    'id': 'dcom1',
                    'name': 'Primary DCOM',
                    'interface': 'enx0c5b8f279a64',
                    'ip': '192.168.8.1', 
                    'status': 'active',
                    'signal': '-65 dBm',
                    'network': 'LTE',
                    'public_ip': '103.21.244.15',
                    'assigned_users': [],
                    'max_users': 100,
                    'current_load': 0
                }
            }
    
    def load_assignments(self):
        """Load user-DCOM assignments from config"""
        try:
            assignment_file = f'{CONFIGS_PATH}/dcom/user_assignments.json'
            if os.path.exists(assignment_file):
                with open(assignment_file, 'r') as f:
                    data = json.load(f)
                    self.user_assignments = data.get('user_assignments', {})
                    self.dcom_assignments = data.get('dcom_assignments', {})
            else:
                # Default assignments
                self.user_assignments = {}
                self.dcom_assignments = {device_id: [] for device_id in self.devices.keys()}
        except Exception as e:
            print(f"Error loading assignments: {e}")
            self.user_assignments = {}
            self.dcom_assignments = {device_id: [] for device_id in self.devices.keys()}
    
    def save_assignments(self):
        """Save assignments to config file"""
        try:
            assignment_file = f'{CONFIGS_PATH}/dcom/user_assignments.json'
            data = {
                'user_assignments': self.user_assignments,
                'dcom_assignments': self.dcom_assignments,
                'last_updated': datetime.now().isoformat()
            }
            with open(assignment_file, 'w') as f:
                json.dump(data, f, indent=2)
            return True
        except Exception as e:
            print(f"Error saving assignments: {e}")
            return False
    
    def get_all_devices(self):
        """Get all DCOM devices with status"""
        devices_status = {}
        for device_id, device in self.devices.items():
            devices_status[device_id] = {
                **device,
                'assigned_users': self.dcom_assignments.get(device_id, []),
                'user_count': len(self.dcom_assignments.get(device_id, [])),
                'load_percentage': min(100, (len(self.dcom_assignments.get(device_id, [])) / device['max_users']) * 100)
            }
        return devices_status
    
    def assign_user_to_dcom(self, username, dcom_id):
        """Assign user to specific DCOM device"""
        if dcom_id not in self.devices:
            return {'success': False, 'message': f'DCOM device {dcom_id} not found'}
        
        # Remove user from any existing assignment
        for device_id in self.dcom_assignments:
            if username in self.dcom_assignments[device_id]:
                self.dcom_assignments[device_id].remove(username)
        
        # Add to new assignment
        if dcom_id not in self.dcom_assignments:
            self.dcom_assignments[dcom_id] = []
        
        if username not in self.dcom_assignments[dcom_id]:
            self.dcom_assignments[dcom_id].append(username)
        
        self.user_assignments[username] = dcom_id
        
        if self.save_assignments():
            return {'success': True, 'message': f'User {username} assigned to {dcom_id}'}
        else:
            return {'success': False, 'message': 'Failed to save assignment'}
    
    def remove_user_from_dcom(self, username):
        """Remove user from DCOM assignment"""
        if username in self.user_assignments:
            dcom_id = self.user_assignments[username]
            if dcom_id in self.dcom_assignments and username in self.dcom_assignments[dcom_id]:
                self.dcom_assignments[dcom_id].remove(username)
            del self.user_assignments[username]
            
            if self.save_assignments():
                return {'success': True, 'message': f'User {username} removed from DCOM assignment'}
            else:
                return {'success': False, 'message': 'Failed to save changes'}
        else:
            return {'success': False, 'message': 'User not assigned to any DCOM'}
    
    def get_user_dcom(self, username):
        """Get DCOM assigned to user"""
        return self.user_assignments.get(username)
    
    def auto_assign_users(self, usernames, mode='round_robin'):
        """Auto assign multiple users to DCOMs"""
        active_dcoms = [d_id for d_id, device in self.devices.items() if device['status'] == 'active']
        if not active_dcoms:
            return {'success': False, 'message': 'No active DCOM devices available'}
        
        assigned = []
        for i, username in enumerate(usernames):
            if mode == 'round_robin':
                dcom_id = active_dcoms[i % len(active_dcoms)]
            elif mode == 'least_loaded':
                # Find DCOM with least users
                dcom_loads = {d_id: len(self.dcom_assignments.get(d_id, [])) for d_id in active_dcoms}
                dcom_id = min(dcom_loads, key=dcom_loads.get)
            else:  # random
                import random
                dcom_id = random.choice(active_dcoms)
            
            result = self.assign_user_to_dcom(username, dcom_id)
            if result['success']:
                assigned.append({'username': username, 'dcom': dcom_id})
        
        return {
            'success': True,
            'message': f'Assigned {len(assigned)} users',
            'assignments': assigned
        }
    
    def load_ip_history(self):
        """Load IP change history"""
        try:
            history_file = f'{CONFIGS_PATH}/dcom/ip_history.json'
            if os.path.exists(history_file):
                with open(history_file, 'r') as f:
                    self.ip_history = json.load(f)
            else:
                self.ip_history = {}
        except Exception as e:
            print(f"Error loading IP history: {e}")
            self.ip_history = {}
    
    def save_ip_history(self):
        """Save IP change history"""
        try:
            history_file = f'{CONFIGS_PATH}/dcom/ip_history.json'
            with open(history_file, 'w') as f:
                json.dump(self.ip_history, f, indent=2)
        except Exception as e:
            print(f"Error saving IP history: {e}")
    
    def track_ip_change(self, dcom_id, old_ip, new_ip):
        """Track IP change for notifications"""
        if dcom_id not in self.ip_history:
            self.ip_history[dcom_id] = []
        
        change_record = {
            'timestamp': datetime.now().isoformat(),
            'old_ip': old_ip,
            'new_ip': new_ip,
            'affected_users': self.dcom_assignments.get(dcom_id, [])
        }
        
        self.ip_history[dcom_id].append(change_record)
        
        # Keep only last 10 changes
        if len(self.ip_history[dcom_id]) > 10:
            self.ip_history[dcom_id] = self.ip_history[dcom_id][-10:]
        
        self.save_ip_history()
        return change_record
    
    def get_ip_changes(self, dcom_id=None, hours=24):
        """Get recent IP changes"""
        from datetime import datetime, timedelta
        
        cutoff_time = datetime.now() - timedelta(hours=hours)
        recent_changes = []
        
        history_to_check = {dcom_id: self.ip_history[dcom_id]} if dcom_id else self.ip_history
        
        for device_id, changes in history_to_check.items():
            for change in changes:
                change_time = datetime.fromisoformat(change['timestamp'])
                if change_time > cutoff_time:
                    recent_changes.append({
                        'dcom_id': device_id,
                        'device_name': self.devices.get(device_id, {}).get('name', device_id),
                        **change
                    })
        
        return sorted(recent_changes, key=lambda x: x['timestamp'], reverse=True)
    
    def notify_users_ip_change(self, dcom_id, old_ip, new_ip):
        """Generate notification for users about IP change"""
        affected_users = self.dcom_assignments.get(dcom_id, [])
        device_name = self.devices.get(dcom_id, {}).get('name', dcom_id)
        
        notification = {
            'type': 'ip_change',
            'dcom_id': dcom_id,
            'device_name': device_name,
            'old_ip': old_ip,
            'new_ip': new_ip,
            'affected_users': affected_users,
            'timestamp': datetime.now().isoformat(),
            'message': f"DCOM {device_name} IP changed from {old_ip} to {new_ip}",
            'action_required': len(affected_users) > 0,
            'recommended_action': 'Users should use gateway IP for seamless connection'
        }
        
        return notification
        
    def get_status(self):
        """Get DCOM status using our existing scripts"""
        try:
            # Use hilink-advanced.sh to get status
            result = subprocess.run(
                [f'{SCRIPTS_PATH}/hilink-advanced.sh', 'status'],
                capture_output=True, text=True, timeout=10
            )
            
            if result.returncode == 0:
                return {
                    'connected': True,
                    'status': 'Connected',
                    'signal': self._extract_signal(),
                    'ip': self._extract_ip(),
                    'network': self._extract_network_type(),
                    'last_update': datetime.now().strftime('%H:%M:%S')
                }
            else:
                return {
                    'connected': False,
                    'status': 'Disconnected',
                    'signal': 'N/A',
                    'ip': 'N/A',
                    'network': 'N/A',
                    'last_update': datetime.now().strftime('%H:%M:%S')
                }
        except Exception as e:
            return {
                'connected': False,
                'status': f'Error: {str(e)}',
                'signal': 'N/A',
                'ip': 'N/A', 
                'network': 'N/A',
                'last_update': datetime.now().strftime('%H:%M:%S')
            }
    
    def _extract_signal(self):
        """Extract signal strength"""
        try:
            result = subprocess.run(
                [f'{SCRIPTS_PATH}/hilink-advanced.sh', 'signal'],
                capture_output=True, text=True, timeout=5
            )
            if 'rssi' in result.stdout:
                # Extract RSSI value
                lines = result.stdout.split('\n')
                for line in lines:
                    if 'rssi' in line.lower():
                        return line.split('>')[-1].split('<')[0]
            return 'N/A'
        except:
            return 'N/A'
    
    def _extract_ip(self):
        """Extract current IP"""
        try:
            result = subprocess.run(
                [f'{SCRIPTS_PATH}/check-wan-ip.sh'],
                capture_output=True, text=True, timeout=10
            )
            if result.returncode == 0:
                lines = result.stdout.split('\n')
                for line in lines:
                    if 'Public IP' in line and 'Failed' not in line:
                        return line.split(':')[-1].strip()
            return 'N/A'
        except:
            return 'N/A'
    
    def _extract_network_type(self):
        """Extract network type"""
        try:
            result = subprocess.run(
                [f'{SCRIPTS_PATH}/hilink-advanced.sh', 'status'],
                capture_output=True, text=True, timeout=5
            )
            if 'Network: LTE' in result.stdout:
                return 'LTE'
            return 'Unknown'
        except:
            return 'Unknown'
    
    def restart_connection(self):
        """Restart DCOM connection"""
        try:
            result = subprocess.run(
                [f'{SCRIPTS_PATH}/connection-control.sh', 'restart'],
                capture_output=True, text=True, timeout=30
            )
            return {
                'success': result.returncode == 0,
                'message': 'Connection restarted successfully' if result.returncode == 0 else 'Failed to restart connection',
                'output': result.stdout
            }
        except Exception as e:
            return {
                'success': False,
                'message': f'Error: {str(e)}',
                'output': ''
            }
    
    def get_current_apn(self):
        """Get current APN profile"""
        try:
            result = subprocess.run(
                [f'{SCRIPTS_PATH}/apn-manager.sh', 'show'],
                capture_output=True, text=True, timeout=10
            )
            
            if result.returncode == 0:
                lines = result.stdout.split('\n')
                apn_info = {}
                for line in lines:
                    if '│ Profile Name' in line:
                        apn_info['name'] = line.split('│')[-2].strip()
                    elif '│ APN' in line and 'Profile' not in line:
                        apn_info['apn'] = line.split('│')[-2].strip()
                    elif '│ Username' in line:
                        apn_info['username'] = line.split('│')[-2].strip()
                
                return apn_info
            return {'name': 'Unknown', 'apn': 'Unknown', 'username': 'Unknown'}
        except:
            return {'name': 'Error', 'apn': 'Error', 'username': 'Error'}

import random
import string
import secrets

class ProxyManager:
    """3Proxy management class with full functionality"""
    
    def __init__(self):
        self.config_file = '/etc/3proxy/3proxy.cfg'
        self.users_file = f'{CONFIGS_PATH}/3proxy/users.conf'
        self.user_manager_script = f'{SCRIPTS_PATH}/user-manager.sh'
        
    def generate_random_credentials(self):
        """Generate random username and password"""
        # Random username: 6-8 characters, alphanumeric
        username_length = random.randint(6, 8)
        username = ''.join(secrets.choice(string.ascii_lowercase + string.digits) for _ in range(username_length))
        
        # Random password: 10-12 characters, mixed case + numbers + symbols
        password_length = random.randint(10, 12)
        password_chars = string.ascii_letters + string.digits + "!@#$%^&*"
        password = ''.join(secrets.choice(password_chars) for _ in range(password_length))
        
        return username, password
    
    def get_random_available_port(self, port_type='http'):
        """Get random available port based on type"""
        port_ranges = {
            'http': [3330, 3331, 3332, 3333, 3334],
            'socks5': [3330, 3335, 3336],  # 3330 is multi-protocol
            'socks4': [3337],
            'no_auth': [3338, 3339]
        }
        
        available_ports = port_ranges.get(port_type, port_ranges['http'])
        return random.choice(available_ports)
    
    def generate_proxy_config(self, username=None, password=None, port_type='http', connection_mode='direct'):
        """Generate complete proxy configuration with DCOM-aware routing"""
        if not username or not password:
            username, password = self.generate_random_credentials()
        
        port = self.get_random_available_port(port_type)
        
        # Get server IP based on connection mode and user's DCOM assignment
        if connection_mode == 'direct':
            server_ip = self._get_direct_dcom_ip(username)
        else:
            server_ip = self._get_server_ip_for_user(username)
        
        config = {
            'username': username,
            'password': password,
            'server_ip': server_ip,
            'port': port,
            'type': port_type,
            'connection_mode': connection_mode,
            'proxy_string': f"{server_ip}:{port}:{username}:{password}",
            'curl_example': self._generate_curl_example(server_ip, port, username, password, port_type),
            'assigned_dcom': dcom.get_user_dcom(username),
            'routing_info': self._get_routing_info(username),
            'direct_connection': connection_mode == 'direct'
        }
        
        return config
    
    def _get_server_ip(self):
        """Get best server IP for proxy config"""
        try:
            # Try to get DCOM public IP first
            result = subprocess.run([
                'curl', '--interface', 'enx0c5b8f279a64', '--connect-timeout', '5', '-s',
                'http://httpbin.org/ip'
            ], capture_output=True, text=True)
            
            if result.returncode == 0:
                ip_info = json.loads(result.stdout)
                return ip_info.get('origin', '').split(',')[0].strip()
        except:
            pass
        
        # Fallback to eth0 IP
        try:
            result = subprocess.run(['hostname', '-I'], capture_output=True, text=True)
            if result.returncode == 0:
                return result.stdout.strip().split()[0]
        except:
            pass
        
        return '10.21.0.107'  # Default fallback
    
    def _get_server_ip_for_user(self, username):
        """Get server IP based on user's DCOM assignment"""
        assigned_dcom = dcom.get_user_dcom(username)
        
        if assigned_dcom:
            devices = dcom.get_all_devices()
            if assigned_dcom in devices:
                device = devices[assigned_dcom]
                if device['status'] == 'active' and device['public_ip'] != 'N/A':
                    return device['public_ip']
        
        # Fallback to general server IP
        return self._get_server_ip()
    
    def _get_routing_info(self, username):
        """Get routing information for user"""
        assigned_dcom = dcom.get_user_dcom(username)
        
        if assigned_dcom:
            devices = dcom.get_all_devices()
            if assigned_dcom in devices:
                device = devices[assigned_dcom]
                return {
                    'dcom_id': assigned_dcom,
                    'dcom_name': device['name'],
                    'interface': device['interface'],
                    'public_ip': device['public_ip'],
                    'status': device['status'],
                    'routing_mode': 'dedicated'
                }
        
        return {
            'dcom_id': None,
            'dcom_name': 'Auto-assigned',
            'interface': 'default',
            'public_ip': self._get_server_ip(),
            'status': 'shared',
            'routing_mode': 'shared'
        }
    
    def _get_direct_dcom_ip(self, username):
        """Get direct DCOM public IP for user with dynamic resolution"""
        assigned_dcom = dcom.get_user_dcom(username)
        
        if assigned_dcom:
            devices = dcom.get_all_devices()
            if assigned_dcom in devices:
                device = devices[assigned_dcom]
                if device['status'] == 'active' and device['public_ip'] != 'N/A':
                    return device['public_ip']
        
        # If no DCOM assigned, assign to least loaded active DCOM
        devices = dcom.get_all_devices()
        active_devices = {k: v for k, v in devices.items() if v['status'] == 'active'}
        
        if active_devices:
            # Find least loaded DCOM
            least_loaded = min(active_devices.items(), key=lambda x: x[1]['load_percentage'])
            dcom_id, device = least_loaded
            
            # Auto-assign user to this DCOM
            dcom.assign_user_to_dcom(username, dcom_id)
            
            return device['public_ip']
        
        # Fallback to server IP if no active DCOM
        return self._get_server_ip()
    
    def _get_gateway_ip(self, username):
        """Get gateway IP for dynamic routing - users always connect to this"""
        # Return fixed gateway IP that routes to current DCOM
        return self._get_server_ip()  # Use server as gateway
    
    def generate_dynamic_proxy_config(self, username=None, password=None, port_type='http'):
        """Generate proxy config with dynamic IP resolution"""
        if not username or not password:
            username, password = self.generate_random_credentials()
        
        port = self.get_random_available_port(port_type)
        
        # Use gateway IP instead of direct DCOM IP
        gateway_ip = self._get_gateway_ip(username)
        
        # Get current DCOM assignment for info
        assigned_dcom = dcom.get_user_dcom(username)
        current_dcom_ip = self._get_direct_dcom_ip(username) if assigned_dcom else 'Auto-assigned'
        
        config = {
            'username': username,
            'password': password,
            'gateway_ip': gateway_ip,  # Fixed IP users connect to
            'current_dcom_ip': current_dcom_ip,  # Current DCOM IP (for info)
            'port': port,
            'type': port_type,
            'connection_mode': 'dynamic_gateway',
            'proxy_string': f"{gateway_ip}:{port}:{username}:{password}",
            'curl_example': self._generate_curl_example(gateway_ip, port, username, password, port_type),
            'assigned_dcom': assigned_dcom,
            'routing_info': {
                'gateway_ip': gateway_ip,
                'current_dcom_ip': current_dcom_ip,
                'assigned_dcom': assigned_dcom,
                'routing_mode': 'dynamic_gateway',
                'benefits': [
                    'Fixed IP for users - no need to change config',
                    'Automatic routing to current DCOM IP',
                    'Seamless IP rotation handling',
                    'Auto-failover when DCOM restarts'
                ]
            }
        }
        
        return config
    
    def _generate_curl_example(self, server_ip, port, username, password, port_type):
        """Generate example curl commands"""
        examples = []
        
        if port_type in ['http', 'https']:
            examples.append(f"curl --proxy-user {username}:{password} -x {server_ip}:{port} http://httpbin.org/ip")
        
        if port_type == 'socks5' or port == 3330:  # 3330 is multi-protocol
            examples.append(f"curl --socks5 {username}:{password}@{server_ip}:{port} http://httpbin.org/ip")
        
        if port_type == 'socks4':
            examples.append(f"curl --socks4 {username}:{password}@{server_ip}:{port} http://httpbin.org/ip")
        
        return examples
    
    def create_random_user(self, port_type='http', custom_username=None):
        """Create user with random credentials"""
        username, password = self.generate_random_credentials()
        if custom_username:
            username = custom_username
        
        # Add user to system
        add_result = self.add_user(username, password)
        if add_result['success']:
            # Generate full config
            config = self.generate_proxy_config(username, password, port_type)
            config['add_result'] = add_result
            return {
                'success': True,
                'config': config,
                'message': f'Random user {username} created successfully'
            }
        else:
            return {
                'success': False,
                'message': add_result['message']
            }
    
    def get_user_connections(self, username=None):
        """Get active connections for user(s)"""
        try:
            # Get current connections from netstat
            result = subprocess.run(['netstat', '-tn'], capture_output=True, text=True)
            connections = []
            
            if result.returncode == 0:
                for line in result.stdout.split('\n'):
                    if 'ESTABLISHED' in line and ':333' in line:
                        parts = line.split()
                        if len(parts) >= 4:
                            local_addr = parts[3]
                            foreign_addr = parts[4]
                            connections.append({
                                'local': local_addr,
                                'foreign': foreign_addr,
                                'user': username if username else 'unknown'
                            })
            
            return {
                'success': True,
                'connections': connections,
                'total': len(connections)
            }
        except Exception as e:
            return {
                'success': False,
                'message': f'Error getting connections: {str(e)}',
                'connections': [],
                'total': 0
            }
        
    def get_status(self):
        """Get detailed 3proxy status"""
        try:
            # Check if running
            result = subprocess.run(['pgrep', '3proxy'], capture_output=True)
            if result.returncode == 0:
                pid = result.stdout.decode().strip()
                
                # Get listening ports
                ports_result = subprocess.run(['netstat', '-tlnp'], capture_output=True, text=True)
                ports = []
                if ports_result.returncode == 0:
                    for line in ports_result.stdout.split('\n'):
                        if '3proxy' in line and ':333' in line:
                            port = line.split(':')[1].split()[0]
                            ports.append(port)
                
                # Get active connections
                conn_result = subprocess.run(['netstat', '-tn'], capture_output=True, text=True)
                active_connections = 0
                if conn_result.returncode == 0:
                    for line in conn_result.stdout.split('\n'):
                        if 'ESTABLISHED' in line and ':333' in line:
                            active_connections += 1
                
                return {
                    'running': True,
                    'status': 'Running',
                    'pid': pid,
                    'ports': sorted(ports),
                    'active_connections': active_connections,
                    'total_users': self._count_users(),
                    'last_update': datetime.now().strftime('%H:%M:%S')
                }
            else:
                return {
                    'running': False,
                    'status': 'Stopped',
                    'pid': 'N/A',
                    'ports': [],
                    'active_connections': 0,
                    'total_users': self._count_users(),
                    'last_update': datetime.now().strftime('%H:%M:%S')
                }
        except Exception as e:
            return {
                'running': False,
                'status': f'Error: {str(e)}',
                'pid': 'N/A',
                'ports': [],
                'active_connections': 0,
                'total_users': 0,
                'last_update': datetime.now().strftime('%H:%M:%S')
            }
    
    def _count_users(self):
        """Count users in users.conf"""
        try:
            with open(self.users_file, 'r') as f:
                return len([line for line in f if line.strip() and not line.startswith('#')])
        except:
            return 0
    
    def start(self):
        """Start 3proxy"""
        try:
            result = subprocess.run(['sudo', 'systemctl', 'start', '3proxy'], 
                                  capture_output=True, text=True)
            return {
                'success': result.returncode == 0,
                'message': '3proxy started successfully' if result.returncode == 0 else f'Failed to start 3proxy: {result.stderr}'
            }
        except Exception as e:
            return {'success': False, 'message': f'Error: {str(e)}'}
    
    def stop(self):
        """Stop 3proxy"""
        try:
            result = subprocess.run(['sudo', 'systemctl', 'stop', '3proxy'],
                                  capture_output=True, text=True)
            return {
                'success': result.returncode == 0,
                'message': '3proxy stopped successfully' if result.returncode == 0 else f'Failed to stop 3proxy: {result.stderr}'
            }
        except Exception as e:
            return {'success': False, 'message': f'Error: {str(e)}'}
    
    def restart(self):
        """Restart 3proxy"""
        try:
            result = subprocess.run(['sudo', 'systemctl', 'restart', '3proxy'],
                                  capture_output=True, text=True)
            return {
                'success': result.returncode == 0,
                'message': '3proxy restarted successfully' if result.returncode == 0 else f'Failed to restart 3proxy: {result.stderr}'
            }
        except Exception as e:
            return {'success': False, 'message': f'Error: {str(e)}'}
    
    def get_users(self):
        """Get all users from users.conf"""
        try:
            users = []
            with open(self.users_file, 'r') as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('#'):
                        parts = line.split(':')
                        if len(parts) >= 3:
                            users.append({
                                'username': parts[0],
                                'type': parts[1],
                                'password': parts[2] if len(parts[2]) < 20 else '***'  # Hide long passwords
                            })
            return {'success': True, 'users': users}
        except Exception as e:
            return {'success': False, 'message': f'Error reading users: {str(e)}', 'users': []}
    
    def add_user(self, username, password):
        """Add new user"""
        try:
            result = subprocess.run([self.user_manager_script, 'add', username, password],
                                  capture_output=True, text=True)
            return {
                'success': result.returncode == 0,
                'message': result.stdout if result.returncode == 0 else result.stderr
            }
        except Exception as e:
            return {'success': False, 'message': f'Error: {str(e)}'}
    
    def remove_user(self, username):
        """Remove user"""
        try:
            result = subprocess.run([self.user_manager_script, 'remove', username],
                                  capture_output=True, text=True)
            return {
                'success': result.returncode == 0,
                'message': result.stdout if result.returncode == 0 else result.stderr
            }
        except Exception as e:
            return {'success': False, 'message': f'Error: {str(e)}'}
    
    def change_password(self, username, new_password):
        """Change user password"""
        try:
            result = subprocess.run([self.user_manager_script, 'passwd', username, new_password],
                                  capture_output=True, text=True)
            return {
                'success': result.returncode == 0,
                'message': result.stdout if result.returncode == 0 else result.stderr
            }
        except Exception as e:
            return {'success': False, 'message': f'Error: {str(e)}'}
    
    def test_proxy(self, port, username=None, password=None):
        """Test proxy connection"""
        try:
            if username and password:
                # Test with auth
                result = subprocess.run([
                    'curl', '--connect-timeout', '10', '--max-time', '15',
                    '--proxy-user', f'{username}:{password}',
                    '-x', f'localhost:{port}',
                    'http://httpbin.org/ip'
                ], capture_output=True, text=True)
            else:
                # Test without auth
                result = subprocess.run([
                    'curl', '--connect-timeout', '10', '--max-time', '15',
                    '-x', f'localhost:{port}',
                    'http://httpbin.org/ip'
                ], capture_output=True, text=True)
            
            if result.returncode == 0:
                try:
                    ip_info = json.loads(result.stdout)
                    return {
                        'success': True,
                        'message': f'Proxy test successful',
                        'ip': ip_info.get('origin', 'Unknown'),
                        'response_time': 'OK'
                    }
                except:
                    return {
                        'success': True,
                        'message': 'Proxy test successful (non-JSON response)',
                        'ip': 'Unknown',
                        'response_time': 'OK'
                    }
            else:
                return {
                    'success': False,
                    'message': f'Proxy test failed: {result.stderr}',
                    'ip': 'N/A',
                    'response_time': 'Failed'
                }
        except Exception as e:
            return {
                'success': False,
                'message': f'Test error: {str(e)}',
                'ip': 'N/A',
                'response_time': 'Error'
            }

# Initialize managers
dcom = DCOMManager()
proxy = ProxyManager()

@app.route('/')
def dashboard():
    """Main dashboard page"""
    return render_template('dashboard.html')

@app.route('/proxy-endpoints')
def proxy_endpoints():
    """Proxy endpoints page"""
    return render_template('proxy_endpoints.html')

@app.route('/users')
def user_management():
    """User management page"""
    return render_template('user_management.html')

@app.route('/dcom-devices')
def dcom_devices():
    """DCOM devices page"""
    return render_template('dcom_management.html')

@app.route('/proxy-assignment')
def proxy_assignment():
    """Proxy assignment page"""
    return render_template('proxy_assignment.html')

@app.route('/dcom-management')
def dcom_management():
    """DCOM management and user assignment page"""
    return render_template('dcom_management.html')

@app.route('/direct-connection')
def direct_connection():
    """Direct DCOM connection page"""
    return render_template('direct_connection.html')

@app.route('/analytics')
def analytics():
    """Analytics page"""
    return render_template('dashboard.html')  # placeholder for now

@app.route('/settings')
def settings():
    """Settings page"""
    return render_template('dashboard.html')  # placeholder for now

@app.route('/api/status')
def api_status():
    """Get overall system status"""
    dcom_status = dcom.get_status()
    proxy_status = proxy.get_status()
    apn_info = dcom.get_current_apn()
    
    return jsonify({
        'dcom': dcom_status,
        'proxy': proxy_status,
        'apn': apn_info,
        'system': {
            'timestamp': datetime.now().isoformat(),
            'uptime': _get_uptime()
        }
    })

@app.route('/api/dcom/restart', methods=['POST'])
def api_dcom_restart_legacy():
    """Restart DCOM connection (legacy endpoint)"""
    result = dcom.restart_connection()
    return jsonify(result)

@app.route('/api/proxy/start', methods=['POST'])
def api_proxy_start():
    """Start 3proxy"""
    result = proxy.start()
    return jsonify(result)

@app.route('/api/proxy/stop', methods=['POST'])
def api_proxy_stop():
    """Stop 3proxy"""
    result = proxy.stop()
    return jsonify(result)

@app.route('/api/proxy/restart', methods=['POST'])
def api_proxy_restart():
    """Restart 3proxy"""
    result = proxy.restart()
    return jsonify(result)

@app.route('/api/proxy/users')
def api_proxy_users():
    """Get all proxy users"""
    result = proxy.get_users()
    return jsonify(result)

@app.route('/api/proxy/users/add', methods=['POST'])
def api_proxy_add_user():
    """Add new proxy user"""
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')
    
    if not username or not password:
        return jsonify({'success': False, 'message': 'Username and password required'})
    
    result = proxy.add_user(username, password)
    return jsonify(result)

@app.route('/api/proxy/users/remove', methods=['POST'])
def api_proxy_remove_user():
    """Remove proxy user"""
    data = request.get_json()
    username = data.get('username')
    
    if not username:
        return jsonify({'success': False, 'message': 'Username required'})
    
    result = proxy.remove_user(username)
    return jsonify(result)

@app.route('/api/proxy/users/password', methods=['POST'])
def api_proxy_change_password():
    """Change user password"""
    data = request.get_json()
    username = data.get('username')
    new_password = data.get('new_password')
    
    if not username or not new_password:
        return jsonify({'success': False, 'message': 'Username and new password required'})
    
    result = proxy.change_password(username, new_password)
    return jsonify(result)

@app.route('/api/proxy/test', methods=['POST'])
def api_proxy_test():
    """Test proxy connection"""
    data = request.get_json()
    port = data.get('port', 3338)  # Default to no-auth port
    username = data.get('username')
    password = data.get('password')
    
    result = proxy.test_proxy(port, username, password)
    return jsonify(result)

@app.route('/api/proxy/generate-random-user', methods=['POST'])
def api_generate_random_user():
    """Generate random user with credentials"""
    data = request.get_json() if request.get_json() else {}
    port_type = data.get('port_type', 'http')
    custom_username = data.get('custom_username')
    
    result = proxy.create_random_user(port_type, custom_username)
    return jsonify(result)

@app.route('/api/proxy/generate-config', methods=['POST'])
def api_generate_config():
    """Generate proxy config for existing user"""
    data = request.get_json()
    username = data.get('username')
    port_type = data.get('port_type', 'http')
    connection_mode = data.get('connection_mode', 'direct')
    
    if not username:
        return jsonify({'success': False, 'message': 'Username required'})
    
    # Get user password from users file
    users_result = proxy.get_users()
    if users_result['success']:
        user_found = None
        for user in users_result['users']:
            if user['username'] == username:
                user_found = user
                break
        
        if user_found:
            config = proxy.generate_proxy_config(username, user_found['password'], port_type, connection_mode)
            return jsonify({'success': True, 'config': config})
        else:
            return jsonify({'success': False, 'message': 'User not found'})
    else:
        return jsonify({'success': False, 'message': 'Could not read users'})

@app.route('/api/proxy/generate-direct-config', methods=['POST'])
def api_generate_direct_config():
    """Generate direct DCOM connection config for user"""
    data = request.get_json()
    username = data.get('username')
    port_type = data.get('port_type', 'http')
    
    if not username:
        return jsonify({'success': False, 'message': 'Username required'})
    
    # Get user password from users file
    users_result = proxy.get_users()
    if users_result['success']:
        user_found = None
        for user in users_result['users']:
            if user['username'] == username:
                user_found = user
                break
        
        if user_found:
            # Generate direct connection config
            config = proxy.generate_proxy_config(username, user_found['password'], port_type, 'direct')
            
            # Add direct connection specific info
            config['connection_type'] = 'Direct DCOM Connection'
            config['benefits'] = [
                'Direct connection to DCOM device',
                'No proxy server overhead',
                'Dedicated IP per user',
                'Lower latency',
                'Better performance'
            ]
            
            return jsonify({'success': True, 'config': config})
        else:
            return jsonify({'success': False, 'message': 'User not found'})
    else:
        return jsonify({'success': False, 'message': 'Could not read users'})

@app.route('/api/proxy/connections')
def api_proxy_connections():
    """Get active proxy connections"""
    username = request.args.get('username')
    result = proxy.get_user_connections(username)
    return jsonify(result)

@app.route('/api/fail2ban/status')
def api_fail2ban_status():
    """Get fail2ban status"""
    try:
        result = subprocess.run(['sudo', 'fail2ban-client', 'status'], capture_output=True, text=True)
        if result.returncode == 0:
            return jsonify({
                'success': True,
                'status': 'running',
                'output': result.stdout
            })
        else:
            return jsonify({
                'success': False,
                'status': 'error',
                'message': result.stderr
            })
    except Exception as e:
        return jsonify({
            'success': False,
            'status': 'error',
            'message': str(e)
        })

@app.route('/api/fail2ban/3proxy')
def api_fail2ban_3proxy():
    """Get 3proxy jail status"""
    try:
        result = subprocess.run(['sudo', 'fail2ban-client', 'status', '3proxy'], capture_output=True, text=True)
        if result.returncode == 0:
            return jsonify({
                'success': True,
                'jail_status': result.stdout
            })
        else:
            return jsonify({
                'success': False,
                'message': result.stderr
            })
    except Exception as e:
        return jsonify({
            'success': False,
            'message': str(e)
        })

@app.route('/api/users/stats')
def api_users_stats():
    """Get detailed user statistics"""
    try:
        users_result = proxy.get_users()
        connections_result = proxy.get_user_connections()
        
        if users_result['success']:
            total_users = len(users_result['users'])
            online_users = max(1, int(total_users * 0.7))  # Mock 70% online
            active_connections = connections_result.get('total', 0) if connections_result['success'] else 0
            
            return jsonify({
                'success': True,
                'stats': {
                    'total_users': total_users,
                    'online_users': online_users,
                    'active_connections': active_connections,
                    'bandwidth_usage': {
                        'total': '2.5 GB',
                        'average': '150 MB/user'
                    },
                    'top_users': users_result['users'][:5]
                }
            })
        else:
            return jsonify({'success': False, 'message': 'Failed to get user stats'})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)})

@app.route('/api/proxy/assignments')
def api_proxy_assignments():
    """Get current proxy port assignments"""
    try:
        # Mock assignment data - in real implementation, store this in database
        assignments = {
            '3330': ['admin', 'user1', 'user2'],
            '3331': ['user3', 'customer1'],
            '3335': ['vip1'],
            '3337': ['test1'],
            '3338': [],
            '3339': []
        }
        
        return jsonify({
            'success': True,
            'assignments': assignments,
            'load_stats': {
                '3330': {'load': 75, 'capacity': 100, 'connections': 15},
                '3331': {'load': 45, 'capacity': 50, 'connections': 8},
                '3335': {'load': 20, 'capacity': 50, 'connections': 3},
                '3337': {'load': 10, 'capacity': 30, 'connections': 1},
                '3338': {'load': 0, 'capacity': 50, 'connections': 0},
                '3339': {'load': 0, 'capacity': 50, 'connections': 0}
            }
        })
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)})

@app.route('/api/proxy/assignments/save', methods=['POST'])
def api_save_assignments():
    """Save proxy assignments"""
    try:
        data = request.get_json()
        assignments = data.get('assignments', {})
        
        # In real implementation, save to database
        # For now, just return success
        
        return jsonify({
            'success': True,
            'message': 'Assignments saved successfully',
            'saved_assignments': assignments
        })
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)})

@app.route('/api/dcom/devices')
def api_dcom_devices():
    """Get all DCOM devices"""
    try:
        devices = dcom.get_all_devices()
        return jsonify({
            'success': True,
            'devices': devices,
            'total_devices': len(devices),
            'active_devices': len([d for d in devices.values() if d['status'] == 'active'])
        })
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)})

@app.route('/api/dcom/assign', methods=['POST'])
def api_dcom_assign():
    """Assign user to DCOM device"""
    try:
        data = request.get_json()
        username = data.get('username')
        dcom_id = data.get('dcom_id')
        
        if not username or not dcom_id:
            return jsonify({'success': False, 'message': 'Username and DCOM ID required'})
        
        result = dcom.assign_user_to_dcom(username, dcom_id)
        return jsonify(result)
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)})

@app.route('/api/dcom/unassign', methods=['POST'])
def api_dcom_unassign():
    """Remove user from DCOM assignment"""
    try:
        data = request.get_json()
        username = data.get('username')
        
        if not username:
            return jsonify({'success': False, 'message': 'Username required'})
        
        result = dcom.remove_user_from_dcom(username)
        return jsonify(result)
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)})

@app.route('/api/dcom/auto-assign', methods=['POST'])
def api_dcom_auto_assign():
    """Auto assign users to DCOM devices"""
    try:
        data = request.get_json()
        usernames = data.get('usernames', [])
        mode = data.get('mode', 'round_robin')
        
        if not usernames:
            return jsonify({'success': False, 'message': 'User list required'})
        
        result = dcom.auto_assign_users(usernames, mode)
        return jsonify(result)
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)})

@app.route('/api/dcom/assignments')
def api_dcom_assignments():
    """Get current DCOM-User assignments"""
    try:
        return jsonify({
            'success': True,
            'user_assignments': dcom.user_assignments,
            'dcom_assignments': dcom.dcom_assignments,
            'devices': dcom.get_all_devices()
        })
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)})

@app.route('/api/dcom/health')
def api_dcom_health():
    """Get health status of all DCOM devices"""
    try:
        devices = dcom.get_all_devices()
        health_data = {}
        
        for device_id, device in devices.items():
            # Mock health data - in real implementation, ping/check each device
            health_data[device_id] = {
                'device_id': device_id,
                'name': device['name'],
                'status': device['status'],
                'response_time': f"{random.randint(50, 200)}ms" if device['status'] == 'active' else 'N/A',
                'uptime': f"{random.randint(1, 72)}h {random.randint(0, 59)}m" if device['status'] == 'active' else 'N/A',
                'signal_strength': device['signal'],
                'data_usage': f"{random.randint(1, 50)}GB" if device['status'] == 'active' else 'N/A',
                'last_check': datetime.now().strftime('%H:%M:%S'),
                'health_score': random.randint(70, 100) if device['status'] == 'active' else 0
            }
        
        return jsonify({
            'success': True,
            'health_data': health_data,
            'overall_health': sum(h['health_score'] for h in health_data.values()) / len(health_data)
        })
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)})

@app.route('/api/dcom/rotate-ip/<dcom_id>', methods=['POST'])
def api_dcom_rotate_ip(dcom_id):
    """Rotate IP for specific DCOM device"""
    try:
        devices = dcom.get_all_devices()
        if dcom_id not in devices:
            return jsonify({'success': False, 'message': 'DCOM device not found'})
        
        device = devices[dcom_id]
        if device['status'] != 'active':
            return jsonify({'success': False, 'message': 'DCOM device is not active'})
        
        # Mock IP rotation - in real implementation, restart DCOM connection
        old_ip = device['public_ip']
        new_ip = f"103.21.244.{random.randint(10, 99)}"
        
        # Update device IP
        dcom.devices[dcom_id]['public_ip'] = new_ip
        
        # Track IP change
        change_record = dcom.track_ip_change(dcom_id, old_ip, new_ip)
        notification = dcom.notify_users_ip_change(dcom_id, old_ip, new_ip)
        
        return jsonify({
            'success': True,
            'message': f'IP rotated successfully for {device["name"]}',
            'old_ip': old_ip,
            'new_ip': new_ip,
            'device_id': dcom_id,
            'affected_users': change_record['affected_users'],
            'notification': notification
        })
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)})

@app.route('/api/dcom/restart/<dcom_id>', methods=['POST'])
def api_dcom_restart(dcom_id):
    """Restart specific DCOM device"""
    try:
        devices = dcom.get_all_devices()
        if dcom_id not in devices:
            return jsonify({'success': False, 'message': 'DCOM device not found'})
        
        device = devices[dcom_id]
        
        # Mock restart - in real implementation, call restart script
        # result = subprocess.run([f'{SCRIPTS_PATH}/restart-dcom.sh', device['interface']])
        
        return jsonify({
            'success': True,
            'message': f'DCOM device {device["name"]} restarted successfully',
            'device_id': dcom_id
        })
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)})

@app.route('/api/dcom/performance')
def api_dcom_performance():
    """Get performance metrics for all DCOM devices"""
    try:
        devices = dcom.get_all_devices()
        performance_data = {}
        
        for device_id, device in devices.items():
            if device['status'] == 'active':
                performance_data[device_id] = {
                    'device_id': device_id,
                    'name': device['name'],
                    'cpu_usage': f"{random.randint(20, 80)}%",
                    'memory_usage': f"{random.randint(30, 70)}%",
                    'network_usage': f"{random.randint(10, 90)}%",
                    'bandwidth': f"{random.randint(50, 200)} Mbps",
                    'latency': f"{random.randint(10, 50)}ms",
                    'packet_loss': f"{random.randint(0, 5)}%",
                    'connected_users': len(dcom.dcom_assignments.get(device_id, [])),
                    'throughput': f"{random.randint(100, 500)} MB/s"
                }
            else:
                performance_data[device_id] = {
                    'device_id': device_id,
                    'name': device['name'],
                    'status': 'inactive',
                    'message': 'Device is offline'
                }
        
        return jsonify({
            'success': True,
            'performance_data': performance_data,
            'timestamp': datetime.now().isoformat()
        })
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)})

@app.route('/api/dcom/ip-changes')
def api_dcom_ip_changes():
    """Get recent IP changes"""
    try:
        hours = int(request.args.get('hours', 24))
        dcom_id = request.args.get('dcom_id')
        
        changes = dcom.get_ip_changes(dcom_id, hours)
        
        return jsonify({
            'success': True,
            'changes': changes,
            'total_changes': len(changes)
        })
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)})

@app.route('/api/proxy/generate-gateway-config', methods=['POST'])
def api_generate_gateway_config():
    """Generate gateway-based proxy config (recommended for IP rotation)"""
    try:
        data = request.get_json()
        username = data.get('username')
        port_type = data.get('port_type', 'http')
        
        if not username:
            return jsonify({'success': False, 'message': 'Username required'})
        
        # Get user password from users file
        users_result = proxy.get_users()
        if users_result['success']:
            user_found = None
            for user in users_result['users']:
                if user['username'] == username:
                    user_found = user
                    break
            
            if user_found:
                # Generate gateway config
                config = proxy.generate_dynamic_proxy_config(username, user_found['password'], port_type)
                
                return jsonify({'success': True, 'config': config})
            else:
                return jsonify({'success': False, 'message': 'User not found'})
        else:
            return jsonify({'success': False, 'message': 'Could not read users'})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)})

@app.route('/api/system/permissions/check')
def api_check_permissions():
    """Check file permissions status"""
    try:
        permission_issues = []
        
        # Critical files to check
        critical_files = [
            f'{SCRIPTS_PATH}/user-manager.sh',
            f'{SCRIPTS_PATH}/hilink-advanced.sh',
            f'{SCRIPTS_PATH}/connection-control.sh',
            f'{PROJECT_ROOT}/webapp/app.py',
            f'{PROJECT_ROOT}/fix-permissions.sh'
        ]
        
        for file_path in critical_files:
            if os.path.exists(file_path):
                # Check if file is executable
                if not os.access(file_path, os.X_OK):
                    permission_issues.append({
                        'file': file_path,
                        'issue': 'Not executable',
                        'recommended': 'chmod +x'
                    })
            else:
                permission_issues.append({
                    'file': file_path,
                    'issue': 'File not found',
                    'recommended': 'Check file path'
                })
        
        # Check directories
        directories = [
            f'{PROJECT_ROOT}/scripts',
            f'{PROJECT_ROOT}/configs',
            f'{PROJECT_ROOT}/logs',
            f'{PROJECT_ROOT}/webapp'
        ]
        
        for dir_path in directories:
            if os.path.exists(dir_path):
                if not os.access(dir_path, os.R_OK | os.W_OK | os.X_OK):
                    permission_issues.append({
                        'file': dir_path,
                        'issue': 'Directory not accessible',
                        'recommended': 'chmod 755'
                    })
        
        return jsonify({
            'success': True,
            'permission_issues': permission_issues,
            'total_issues': len(permission_issues),
            'status': 'good' if len(permission_issues) == 0 else 'needs_fix'
        })
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)})

@app.route('/api/system/permissions/fix', methods=['POST'])
def api_fix_permissions():
    """Fix file permissions automatically"""
    try:
        # Run the auto-permissions script
        fix_script = f'{PROJECT_ROOT}/fix-permissions.sh'
        
        if not os.path.exists(fix_script):
            return jsonify({
                'success': False, 
                'message': 'Permission fix script not found'
            })
        
        # Make sure the fix script is executable
        os.chmod(fix_script, 0o755)
        
        # Run the fix script
        result = subprocess.run(
            ['sudo', fix_script],
            capture_output=True,
            text=True,
            timeout=30
        )
        
        if result.returncode == 0:
            return jsonify({
                'success': True,
                'message': 'Permissions fixed successfully',
                'output': result.stdout,
                'fixes_applied': [
                    'Directory permissions set to 755',
                    'Shell scripts made executable',
                    'Python files made executable',
                    'Config files secured',
                    'Log directories created'
                ]
            })
        else:
            return jsonify({
                'success': False,
                'message': 'Permission fix failed',
                'error': result.stderr,
                'output': result.stdout
            })
            
    except subprocess.TimeoutExpired:
        return jsonify({
            'success': False,
            'message': 'Permission fix timed out'
        })
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)})

@app.route('/api/system/upload-status')
def api_upload_status():
    """Check if files were recently uploaded and need permission fix"""
    try:
        import time
        
        # Check modification times of critical files
        recent_uploads = []
        current_time = time.time()
        
        critical_files = [
            f'{PROJECT_ROOT}/webapp/app.py',
            f'{SCRIPTS_PATH}/user-manager.sh',
            f'{PROJECT_ROOT}/webapp/templates/dashboard.html'
        ]
        
        for file_path in critical_files:
            if os.path.exists(file_path):
                mtime = os.path.getmtime(file_path)
                # If modified in last 10 minutes
                if current_time - mtime < 600:  
                    recent_uploads.append({
                        'file': os.path.basename(file_path),
                        'modified': datetime.fromtimestamp(mtime).isoformat(),
                        'needs_permission_check': not os.access(file_path, os.X_OK) if file_path.endswith(('.sh', '.py')) else False
                    })
        
        return jsonify({
            'success': True,
            'recent_uploads': recent_uploads,
            'upload_detected': len(recent_uploads) > 0,
            'recommendation': 'Run permission fix if files were uploaded via SFTP' if recent_uploads else None
        })
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)})

@app.route('/api/apn/list')
def api_apn_list():
    """List available APN profiles"""
    try:
        result = subprocess.run(
            [f'{SCRIPTS_PATH}/apn-manager.sh', 'list'],
            capture_output=True, text=True, timeout=10
        )
        
        profiles = []
        if result.returncode == 0:
            lines = result.stdout.split('\n')
            in_table = False
            for line in lines:
                if '├─────────────────────┼─────────────────────────┼─────────────────────────────────┤' in line:
                    in_table = True
                    continue
                elif '└─────────────────────┴─────────────────────────┴─────────────────────────────────┘' in line:
                    break
                elif in_table and '│' in line:
                    parts = [p.strip() for p in line.split('│')[1:-1]]
                    if len(parts) >= 3:
                        profiles.append({
                            'name': parts[0],
                            'apn': parts[1],
                            'description': parts[2]
                        })
        
        return jsonify({'profiles': profiles})
    except Exception as e:
        return jsonify({'error': str(e), 'profiles': []})

def _get_uptime():
    """Get system uptime"""
    try:
        with open('/proc/uptime', 'r') as f:
            uptime_seconds = float(f.readline().split()[0])
            return f"{int(uptime_seconds // 3600)}h {int((uptime_seconds % 3600) // 60)}m"
    except:
        return "Unknown"

if __name__ == '__main__':
    print("🚀 Starting Proxy Farm System - Phase 1")
    print(f"📁 Project root: {PROJECT_ROOT}")
    print(f"🔧 Scripts path: {SCRIPTS_PATH}")
    print(f"⚙️  Configs path: {CONFIGS_PATH}")
    print("🌐 Web interface will be available at: http://localhost:5000")
    
    app.run(debug=True, host='0.0.0.0', port=5000)
