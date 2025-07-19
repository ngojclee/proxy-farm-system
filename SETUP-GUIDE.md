# 🚀 Proxy Farm System - Setup Guide

## 📋 Quick Setup After SFTP Upload

### ⚡ Method 1: Auto-Fix Script (Recommended)
```bash
# Navigate to project directory
cd /home/proxy-farm-system

# Run quick permission fix
sudo ./fix-permissions.sh
```

### 🔧 Method 2: Manual Commands
```bash
# Make directories accessible
sudo chmod 755 /home/proxy-farm-system
sudo chmod 755 /home/proxy-farm-system/scripts
sudo chmod 755 /home/proxy-farm-system/webapp

# Make scripts executable
sudo chmod +x /home/proxy-farm-system/scripts/system/*.sh
sudo chmod +x /home/proxy-farm-system/scripts/3proxy/*.sh
sudo chmod +x /home/proxy-farm-system/webapp/app.py

# Secure config files
sudo chmod 600 /home/proxy-farm-system/configs/3proxy/users.conf
sudo chmod 644 /home/proxy-farm-system/configs/3proxy/3proxy.cfg
```

### 🌐 Method 3: Web Interface
1. Start the webapp: `python3 /home/proxy-farm-system/webapp/app.py`
2. Open browser: `http://your-server:5000`
3. Check **System Management** card
4. Click **🔧 Fix Permissions** button

---

## 📁 File Permission Requirements

### 🔨 Executable Files (chmod +x)
```
✓ All .sh scripts in /scripts/
✓ webapp/app.py
✓ fix-permissions.sh
```

### 📄 Config Files (chmod 644)
```
✓ configs/3proxy/3proxy.cfg
✓ configs/dcom/apn-profiles.conf
✓ webapp/templates/*.html
```

### 🔒 Sensitive Files (chmod 600)
```
✓ configs/3proxy/users.conf
✓ configs/dcom/user_assignments.json
```

### 📁 Directories (chmod 755)
```
✓ /home/proxy-farm-system/
✓ scripts/
✓ webapp/
✓ configs/
✓ logs/
```

---

## 🔄 Auto-Fix Features

### 📊 System Monitoring
- **Permission Check**: Automatically detects permission issues
- **Upload Detection**: Monitors recent file changes
- **Auto-Fix Service**: Runs every hour via systemd timer

### ⚙️ Auto-Fix Service Setup
```bash
# Enable automatic permission fixing
sudo /home/proxy-farm-system/scripts/system/auto-permissions.sh

# Check service status
sudo systemctl status proxy-farm-permissions.timer

# Manual run
sudo systemctl start proxy-farm-permissions.service
```

---

## 🚨 Common Issues & Solutions

### ❌ "Permission denied" when running scripts
```bash
# Fix: Make scripts executable
sudo chmod +x /home/proxy-farm-system/scripts/system/*.sh
```

### ❌ "Cannot access config files"
```bash
# Fix: Set proper directory permissions
sudo chmod 755 /home/proxy-farm-system/configs
```

### ❌ "Flask app won't start"
```bash
# Fix: Make Python file executable
sudo chmod +x /home/proxy-farm-system/webapp/app.py
```

### ❌ "3proxy config error"
```bash
# Fix: Secure config file permissions
sudo chmod 644 /home/proxy-farm-system/configs/3proxy/3proxy.cfg
sudo chmod 600 /home/proxy-farm-system/configs/3proxy/users.conf
```

---

## 📝 SFTP Upload Workflow

### 1. Upload Files
```bash
# Using SFTP client
sftp user@your-server
put -r proxy-farm-system/* /home/proxy-farm-system/
```

### 2. Fix Permissions
```bash
# SSH to server
ssh user@your-server

# Run auto-fix
cd /home/proxy-farm-system
sudo ./fix-permissions.sh
```

### 3. Verify Setup
```bash
# Check if webapp starts
python3 webapp/app.py

# Check if scripts are executable
ls -la scripts/system/user-manager.sh
```

---

## 🔐 Security Notes

### 🛡️ File Security
- **users.conf** (600): Contains sensitive user credentials
- **user_assignments.json** (600): Contains user-DCOM mappings
- **Script files** (+x): Need execute permissions
- **Config files** (644): Readable but not writable by others

### 🔒 Directory Security
- **Root directory** (755): Standard directory permissions
- **Logs directory** (755): Accessible for monitoring
- **Backups directory** (755): Accessible for maintenance

---

## 📊 Monitoring & Maintenance

### 🔍 Check System Status
```bash
# Via web interface
curl http://localhost:5000/api/system/permissions/check

# Via command line
ls -la /home/proxy-farm-system/scripts/system/
```

### 🔧 Manual Maintenance
```bash
# Run full permission setup
sudo /home/proxy-farm-system/scripts/system/auto-permissions.sh

# Quick fix only
sudo /home/proxy-farm-system/fix-permissions.sh --quick

# Enable file watcher
sudo /home/proxy-farm-system/scripts/system/auto-permissions.sh --watch
```

---

## ✅ Verification Checklist

After upload and permission fix, verify:

- [ ] `sudo ./fix-permissions.sh` runs without errors
- [ ] `python3 webapp/app.py` starts successfully
- [ ] Web interface loads at `http://server:5000`
- [ ] System Management card shows "Good" permissions
- [ ] Scripts are executable: `ls -la scripts/system/*.sh`
- [ ] Config files are secure: `ls -la configs/3proxy/users.conf`

---

## 🆘 Quick Help

### 🔧 One-line fix after SFTP upload:
```bash
cd /home/proxy-farm-system && sudo ./fix-permissions.sh
```

### 🌐 Start webapp:
```bash
cd /home/proxy-farm-system/webapp && python3 app.py
```

### 📊 Check status via API:
```bash
curl http://localhost:5000/api/system/permissions/check
```

**🎯 Goal: Make SFTP upload → Production ready in 30 seconds!**