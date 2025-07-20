# Proxy Farm System - Windows Setup Guide

## 🚀 Quick Start for Windows

### Prerequisites
1. **Python 3.8+** installed
2. **3proxy for Windows** - Download from [3proxy releases](https://github.com/3proxy/3proxy/releases)
3. **Git** (optional, for version control)

### Installation Steps

1. **Download 3proxy for Windows**
   - Go to https://github.com/3proxy/3proxy/releases
   - Download the Windows version (3proxy-x.x.x-win32.zip or win64.zip)
   - Extract `3proxy.exe` to `D:\Python\proxy-farm-system\bin\`

2. **Start the system**
   ```batch
   cd D:\Python\proxy-farm-system
   start-all-windows.bat
   ```

3. **Access the Dashboard**
   - Open browser: http://localhost:5000
   - Login: admin / admin123

## 📁 File Structure

```
D:\Python\proxy-farm-system\
├── bin\
│   └── 3proxy.exe          # You need to add this!
├── configs\
│   └── 3proxy\
│       ├── 3proxy-windows.cfg   # Windows config
│       └── users.conf           # User credentials
├── webapp\
│   ├── app.py              # Flask application
│   ├── templates\          # HTML templates
│   └── static\             # CSS/JS files
├── logs\                   # Log files
├── start-all-windows.bat   # Start everything
├── start-webapp-windows.bat # Start webapp only
├── start-3proxy-windows.bat # Start proxy only
└── status-windows.bat      # Check status
```

## 🔧 Configuration

### Adding Users
Edit `configs\3proxy\users.conf`:
```
username:CL:password
```

### Changing Ports
Edit `configs\3proxy\3proxy-windows.cfg`

## 🛠️ Troubleshooting

### 3proxy not starting
1. Check if 3proxy.exe is in `bin\` folder
2. Check Windows Firewall settings
3. Run as Administrator if needed
4. Check logs in `logs\3proxy\`

### Webapp not starting
1. Check if Python is installed: `python --version`
2. Check if port 5000 is free: `netstat -an | findstr :5000`
3. Install Flask: `pip install flask`

### Cannot connect to proxy
1. Check Windows Firewall
2. Try disabling antivirus temporarily
3. Test with: `curl --proxy-user admin:admin123 -x localhost:3330 http://httpbin.org/ip`

## 📊 Default Proxy Ports

| Port | Protocol | Authentication |
|------|----------|---------------|
| 3330 | HTTP/SOCKS5 | Required |
| 3331-3334 | HTTP | Required |
| 3335-3337 | SOCKS5 | Required |
| 3338 | HTTP | None |
| 3339 | SOCKS5 | None |

## 🔐 Security Notes

- Change default passwords in `users.conf`
- Configure Windows Firewall rules
- Use strong passwords
- Limit access to trusted IPs only

## 📝 Notes for Windows

- This system was originally designed for Linux
- DCOM USB modem features may not work on Windows
- Use WSL2 for better compatibility if needed
- Some features require Administrator privileges

## 🆘 Support

For issues specific to Windows setup:
1. Check Event Viewer for errors
2. Run scripts as Administrator
3. Ensure all paths use Windows format (D:\... not /home/...)
4. Check antivirus/firewall logs