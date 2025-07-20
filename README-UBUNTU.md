# Proxy Farm System - Ubuntu/Debian Guide

## 🚀 Quick Installation

### One-Line Install
```bash
git clone https://github.com/yourusername/proxy-farm-system.git
cd proxy-farm-system
chmod +x install-ubuntu.sh
./install-ubuntu.sh
```

### Using Make
```bash
make install
```

## 📋 Prerequisites

- Ubuntu 20.04+ or Debian 10+
- Non-root user with sudo privileges
- At least 1GB RAM
- 10GB free disk space

## 🛠️ What Gets Installed

1. **System packages**: Python3, Nginx, Supervisor, build tools
2. **3proxy**: Compiled from source and installed in project directory
3. **Python webapp**: Flask application with Gunicorn
4. **Firewall rules**: UFW configuration for all services
5. **Process management**: Supervisor for automatic startup

## 📁 Project Structure

```
/home/user/proxy-farm-system/
├── bin/                    # 3proxy binaries (auto-compiled)
│   ├── 3proxy
│   └── other tools
├── configs/
│   └── 3proxy/
│       ├── 3proxy.cfg      # Main configuration
│       └── users.conf      # User credentials
├── webapp/
│   ├── app.py             # Flask application
│   ├── templates/         # Web interface
│   └── static/            # CSS/JS files
├── logs/                  # All log files
├── venv/                  # Python virtual environment
├── install-ubuntu.sh      # Main installer
├── install-3proxy.sh      # 3proxy installer
├── update-3proxy.sh       # Update script
├── Makefile              # Management commands
└── start-all.sh          # Start script
```

## 🔧 Configuration

### Adding Proxy Users
Edit `configs/3proxy/users.conf`:
```
username:CL:password
louis:CL:louis123
```

### Changing Ports
Edit `configs/3proxy/3proxy.cfg` and modify port numbers.

### DCOM USB Modem Setup
1. Connect USB modem
2. Check interface name: `ip link show`
3. Update `external` directive in 3proxy.cfg

## 📊 Management Commands

### Using Make
```bash
make start          # Start all services
make stop           # Stop all services
make restart        # Restart all services
make status         # Check status
make logs           # View logs
make test           # Test proxy
make backup         # Backup configs
make update-3proxy  # Update 3proxy
```

### Using Scripts
```bash
./start-all.sh      # Start everything
./stop-all.sh       # Stop everything
./status.sh         # Check status
./show-logs.sh      # View logs
```

### Using Supervisor
```bash
sudo supervisorctl status                    # Check all services
sudo supervisorctl restart proxyfarm-webapp  # Restart webapp
sudo supervisorctl restart proxyfarm-3proxy  # Restart proxy
sudo supervisorctl tail -f proxyfarm-webapp  # Live logs
```

## 🌐 Access Information

- **Web Dashboard**: http://your-server-ip
- **Default Login**: admin / admin123
- **Nginx Proxy**: Port 80 → Flask app on 5000

## 🔌 Proxy Endpoints

| Port | Type | Auth | Usage |
|------|------|------|-------|
| 3330 | HTTP/SOCKS5 | Yes | Multi-protocol |
| 3331-3334 | HTTP | Yes | Standard HTTP proxy |
| 3335-3337 | SOCKS5 | Yes | SOCKS5 proxy |
| 3338 | HTTP | No | Testing/Public |
| 3339 | SOCKS5 | No | Testing/Public |

## 🧪 Testing Proxies

```bash
# Test with authentication
curl --proxy-user admin:admin123 -x your-server-ip:3330 http://httpbin.org/ip

# Test SOCKS5
curl --socks5 admin:admin123@your-server-ip:3335 http://httpbin.org/ip

# Test no-auth proxy
curl -x your-server-ip:3338 http://httpbin.org/ip

# Quick test all proxies
make test
```

## 🔒 Security Hardening

### 1. Change Default Passwords
```bash
nano configs/3proxy/users.conf
# Change all default passwords
make restart
```

### 2. Restrict Firewall
```bash
# Allow only specific IPs
sudo ufw delete allow 3330/tcp
sudo ufw allow from YOUR.IP.HERE to any port 3330
```

### 3. Enable HTTPS
```bash
# Install certbot
sudo apt install certbot python3-certbot-nginx

# Get SSL certificate
sudo certbot --nginx -d your-domain.com
```

### 4. Add IP Whitelisting
Edit `configs/3proxy/3proxy.cfg`:
```
# Allow only specific IPs
allow * 192.168.1.0/24
deny *
```

## 🐛 Troubleshooting

### 3proxy not starting
```bash
# Check logs
tail -f logs/3proxy/3proxy.log

# Check syntax
bin/3proxy --test configs/3proxy/3proxy.cfg

# Run manually
bin/3proxy configs/3proxy/3proxy.cfg
```

### Webapp errors
```bash
# Check logs
tail -f logs/webapp/error.log

# Test manually
cd webapp
../venv/bin/python app.py
```

### Port already in use
```bash
# Find process using port
sudo lsof -i :3330

# Kill process
sudo kill -9 <PID>
```

### Permission errors
```bash
# Fix ownership
sudo chown -R $USER:$USER /home/$USER/proxy-farm-system

# Fix permissions
chmod -R 755 /home/$USER/proxy-farm-system
chmod +x *.sh
```

## 📈 Monitoring

### System Resources
```bash
# CPU and Memory
htop

# Network connections
sudo netstat -tlnp | grep 3proxy

# Active connections count
netstat -an | grep :333 | grep ESTABLISHED | wc -l
```

### Log Monitoring
```bash
# Live 3proxy logs
tail -f logs/3proxy/3proxy.log

# Live webapp logs
tail -f logs/webapp/access.log

# All supervisor logs
sudo tail -f /var/log/supervisor/supervisord.log
```

## 🔄 Updates

### Update 3proxy
```bash
make update-3proxy
# or
./update-3proxy.sh
```

### Update System
```bash
cd proxy-farm-system
git pull
make restart
```

## 🚨 Common Issues

1. **"Address already in use"**: Another service using the port
2. **"Permission denied"**: Run with sudo or check file permissions
3. **"Connection refused"**: Check if service is running and firewall rules
4. **"Authentication failed"**: Check username/password in users.conf

## 💡 Tips

1. Use `tmux` or `screen` for persistent sessions
2. Set up log rotation to prevent disk full
3. Monitor bandwidth usage with `iftop` or `nethogs`
4. Use fail2ban to prevent brute force attacks
5. Regular backups: `make backup`

## 📞 Support

For issues:
1. Check logs: `make logs`
2. Check status: `make status`
3. Run tests: `make test`
4. Check this README
5. Submit issue on GitHub

---
Built with ❤️ for high-performance proxy management