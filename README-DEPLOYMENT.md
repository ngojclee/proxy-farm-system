# ProxyFarm System - Ubuntu Server Deployment Guide

This guide will help you deploy the ProxyFarm System on Ubuntu Server to run as a background service.

## 🚀 Quick Start

### 1. Prepare Ubuntu Server

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y curl wget git python3 python3-pip python3-venv nginx ufw

# Create project directory
sudo mkdir -p /home/proxy-farm-system
```

### 2. Upload Project Files

Copy all project files to `/home/proxy-farm-system` on your Ubuntu server:

```bash
# Using SCP (from your local machine)
scp -r proxy-farm-system/* user@your-server:/home/proxy-farm-system/

# Or clone from git repository
cd /home/proxy-farm-system
sudo git clone <your-repo-url> .
```

### 3. Install as System Service

```bash
cd /home/proxy-farm-system

# Make scripts executable
sudo chmod +x *.sh

# Install the service
sudo ./install-service.sh

# Setup monitoring
sudo ./setup-monitoring.sh

# Setup nginx (optional but recommended)
sudo ./setup-nginx.sh
```

### 4. Start the System

```bash
# Start ProxyFarm service
sudo systemctl start proxyfarm

# Check status
sudo systemctl status proxyfarm

# Or use production scripts
./start-production.sh
./status-production.sh
```

## 📋 Available Commands

### Service Management
```bash
# SystemD service commands
sudo systemctl start proxyfarm      # Start service
sudo systemctl stop proxyfarm       # Stop service
sudo systemctl restart proxyfarm    # Restart service
sudo systemctl status proxyfarm     # Check status
sudo systemctl enable proxyfarm     # Enable auto-start

# Production scripts (alternative)
./start-production.sh               # Start with Gunicorn
./stop-production.sh                # Stop Gunicorn
./restart-production.sh             # Restart Gunicorn
./status-production.sh              # Detailed status
```

### Monitoring
```bash
./monitor-system.sh                 # Run health check
./monitor-system.sh --auto-restart  # Check and auto-restart
./monitor-system.sh --report        # Generate health report
./monitoring-dashboard.sh           # View system dashboard

# View logs
tail -f logs/webapp/access.log      # Access logs
tail -f logs/webapp/error.log       # Error logs
tail -f logs/system/monitor.log     # Monitor logs
sudo journalctl -u proxyfarm -f     # SystemD logs
```

### Backup & Updates
```bash
./backup-system.sh                  # Create backup
./backup-system.sh --include-logs   # Backup with logs
./update-system.sh                  # Update system
./update-system.sh --system-packages # Update with OS packages
```

### Nginx Management
```bash
sudo systemctl status nginx         # Check nginx status
sudo nginx -t                       # Test nginx config
sudo systemctl reload nginx         # Reload nginx config
```

## 🌐 Web Access

After installation, access the web interface:

- **Direct access**: `http://your-server-ip:5000`
- **With nginx**: `http://your-domain.com` (after SSL setup)

## 🔒 Security Setup

### 1. Firewall Configuration
```bash
# Enable UFW
sudo ufw enable

# Allow SSH
sudo ufw allow ssh

# Allow HTTP/HTTPS (if using nginx)
sudo ufw allow 'Nginx Full'

# Allow ProxyFarm web interface (if direct access)
sudo ufw allow 5000

# Allow proxy ports
sudo ufw allow 3330:3339/tcp

# Check status
sudo ufw status
```

### 2. SSL Certificate (Recommended)
```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx

# Get SSL certificate
sudo certbot --nginx -d your-domain.com

# Test auto-renewal
sudo certbot renew --dry-run
```

### 3. Update Nginx Configuration
Edit `/etc/nginx/sites-available/proxyfarm` and update:
- Replace `your-domain.com` with your actual domain
- Update SSL certificate paths if using custom certificates

## 📊 Monitoring Setup

The system includes comprehensive monitoring:

### Automatic Monitoring
- Health checks every 5 minutes
- Auto-restart failed services
- Hourly health reports
- Daily log cleanup
- Weekly backup cleanup

### Manual Monitoring
```bash
# Quick status check
./monitoring-dashboard.sh

# Detailed health check
./monitor-system.sh --report

# View recent alerts
tail -f logs/system/alerts.log

# Continuous monitoring (optional)
sudo systemctl start proxyfarm-monitor
```

## 🔧 Configuration

### Key Configuration Files
- `/etc/systemd/system/proxyfarm.service` - SystemD service
- `/etc/nginx/sites-available/proxyfarm` - Nginx config
- `/etc/cron.d/proxyfarm-monitoring` - Monitoring cron jobs
- `/home/proxy-farm-system/configs/` - Application configs

### Environment Variables
Edit the systemd service file to add environment variables:
```bash
sudo systemctl edit proxyfarm
```

Add:
```ini
[Service]
Environment="FLASK_ENV=production"
Environment="SECRET_KEY=your-secret-key"
Environment="DATABASE_URL=your-database-url"
```

## 🗄️ Backup Strategy

### Automatic Backups
Backups are automatically created:
- Before system updates
- Daily via cron (if configured)
- Stored in `/backup/proxyfarm/`
- Compressed and retained for 30 days

### Manual Backups
```bash
# Standard backup
./backup-system.sh

# Backup with logs
./backup-system.sh --include-logs

# Custom retention
./backup-system.sh --retention 60
```

## 📈 Performance Optimization

### Gunicorn Configuration
Edit `start-production.sh` to adjust:
- Number of workers (default: 4)
- Worker timeout (default: 300s)
- Memory limits

### System Resources
Monitor and adjust based on usage:
```bash
# Check resource usage
htop
iotop
nethogs

# Adjust system limits if needed
sudo ulimit -n 65536  # Increase file descriptors
```

## 🐛 Troubleshooting

### Common Issues

#### Service Won't Start
```bash
# Check service status
sudo systemctl status proxyfarm

# Check logs
sudo journalctl -u proxyfarm -n 50

# Check if port is in use
sudo netstat -tlnp | grep :5000
```

#### Permission Issues
```bash
# Fix permissions
sudo chown -R root:root /home/proxy-farm-system
sudo chmod +x /home/proxy-farm-system/scripts/*/*.sh
sudo chmod +x /home/proxy-farm-system/*.sh
```

#### High Memory Usage
```bash
# Check memory usage
free -h
ps aux --sort=-%mem | head

# Restart services
./restart-production.sh
```

#### Network Issues
```bash
# Check listening ports
sudo netstat -tlnp

# Check firewall
sudo ufw status

# Test connectivity
curl -I http://localhost:5000
```

### Log Locations
- Application logs: `/home/proxy-farm-system/logs/`
- SystemD logs: `journalctl -u proxyfarm`
- Nginx logs: `/var/log/nginx/`
- System logs: `/var/log/syslog`

## 🔄 Updates

### Manual Updates
```bash
# Standard update
sudo ./update-system.sh

# Update with system packages
sudo ./update-system.sh --system-packages

# Update without auto-restart
sudo ./update-system.sh --no-restart
```

### Automated Updates
Configure automatic updates via cron:
```bash
# Add to crontab
sudo crontab -e

# Add line for weekly updates
0 3 * * 0 cd /home/proxy-farm-system && ./update-system.sh >/dev/null 2>&1
```

## 📞 Support

### Health Checks
- Monitor dashboard: `./monitoring-dashboard.sh`
- System status: `./status-production.sh`
- Health report: `./monitor-system.sh --report`

### Log Analysis
```bash
# Recent errors
grep ERROR logs/webapp/error.log | tail -10

# Access patterns
tail -100 logs/webapp/access.log | awk '{print $1}' | sort | uniq -c

# System alerts
tail -20 logs/system/alerts.log
```

### Performance Metrics
```bash
# Connection stats
netstat -tn | grep :333 | wc -l

# Resource usage
./monitoring-dashboard.sh

# Service uptime
systemctl status proxyfarm --no-pager
```

---

## 📝 Quick Reference

### Essential Commands
```bash
# Service control
sudo systemctl {start|stop|restart|status} proxyfarm

# Production management
./start-production.sh
./stop-production.sh
./status-production.sh

# Monitoring
./monitoring-dashboard.sh
./monitor-system.sh

# Maintenance
./backup-system.sh
./update-system.sh

# Logs
tail -f logs/webapp/access.log
sudo journalctl -u proxyfarm -f
```

### Default Ports
- Web interface: 5000
- Proxy ports: 3330-3339
- HTTP: 80 (nginx)
- HTTPS: 443 (nginx)

### Important Paths
- Project root: `/home/proxy-farm-system`
- Nginx config: `/etc/nginx/sites-available/proxyfarm`
- SystemD service: `/etc/systemd/system/proxyfarm.service`
- Backups: `/backup/proxyfarm/`

This deployment setup provides a robust, production-ready environment for the ProxyFarm System with monitoring, backups, and easy management commands.