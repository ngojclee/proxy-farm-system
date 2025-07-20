#!/bin/bash

# ProxyFarm System - Enhanced Permission Fix Script
# Run this after SFTP upload or updates to fix all permission issues

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}🔧 ProxyFarm System - Enhanced Permission Fix${NC}"
echo "============================================="

# Get current directory
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$CURRENT_DIR"

echo "Project Root: $PROJECT_ROOT"
echo "Date: $(date)"

# Check if running with proper permissions
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Please run with sudo:${NC}"
    echo "sudo ./fix-permissions.sh"
    exit 1
fi

echo -e "${BLUE}📁 Creating and fixing directory structure...${NC}"
# Create all necessary directories
mkdir -p "$PROJECT_ROOT"/{scripts/{system,3proxy,dcom},configs/{3proxy,dcom,udev,webapp},logs/{3proxy,system,webapp},webapp/{templates,static/css},backups}

# Fix directory permissions
chmod 755 "$PROJECT_ROOT"
chmod 755 "$PROJECT_ROOT/scripts" 
chmod 755 "$PROJECT_ROOT/scripts/system" 
chmod 755 "$PROJECT_ROOT/scripts/3proxy" 
chmod 755 "$PROJECT_ROOT/scripts/dcom" 
chmod 755 "$PROJECT_ROOT/webapp" 
chmod 755 "$PROJECT_ROOT/webapp/templates" 
chmod 755 "$PROJECT_ROOT/webapp/static"
chmod 755 "$PROJECT_ROOT/webapp/static/css"
chmod 755 "$PROJECT_ROOT/configs" 
chmod 755 "$PROJECT_ROOT/configs/3proxy" 
chmod 755 "$PROJECT_ROOT/configs/dcom" 
chmod 755 "$PROJECT_ROOT/configs/udev"
chmod 755 "$PROJECT_ROOT/configs/webapp"
chmod 755 "$PROJECT_ROOT/logs" 
chmod 755 "$PROJECT_ROOT/logs/3proxy" 
chmod 755 "$PROJECT_ROOT/logs/system" 
chmod 755 "$PROJECT_ROOT/logs/webapp" 
chmod 755 "$PROJECT_ROOT/backups" 

echo -e "${YELLOW}🔨 Fixing all shell script permissions...${NC}"
# Fix all shell scripts recursively
find "$PROJECT_ROOT" -name "*.sh" -type f -exec chmod +x {} \; 2>/dev/null

# Production management scripts (new)
chmod +x "$PROJECT_ROOT/start-production.sh" 2>/dev/null
chmod +x "$PROJECT_ROOT/stop-production.sh" 2>/dev/null  
chmod +x "$PROJECT_ROOT/restart-production.sh" 2>/dev/null
chmod +x "$PROJECT_ROOT/status-production.sh" 2>/dev/null

# Installation and setup scripts (new)
chmod +x "$PROJECT_ROOT/install-service.sh" 2>/dev/null
chmod +x "$PROJECT_ROOT/setup-nginx.sh" 2>/dev/null
chmod +x "$PROJECT_ROOT/setup-monitoring.sh" 2>/dev/null

# Monitoring scripts (new)
chmod +x "$PROJECT_ROOT/monitor-system.sh" 2>/dev/null
chmod +x "$PROJECT_ROOT/monitoring-dashboard.sh" 2>/dev/null
chmod +x "$PROJECT_ROOT/send-alerts.sh" 2>/dev/null

# Backup and update scripts (new)
chmod +x "$PROJECT_ROOT/backup-system.sh" 2>/dev/null
chmod +x "$PROJECT_ROOT/update-system.sh" 2>/dev/null

# Original critical scripts (only if they exist)
chmod +x "$PROJECT_ROOT/fix-permissions.sh" 2>/dev/null

# System scripts
[[ -f "$PROJECT_ROOT/scripts/system/auto-permissions.sh" ]] && chmod +x "$PROJECT_ROOT/scripts/system/auto-permissions.sh"
[[ -f "$PROJECT_ROOT/scripts/system/user-manager.sh" ]] && chmod +x "$PROJECT_ROOT/scripts/system/user-manager.sh"
[[ -f "$PROJECT_ROOT/scripts/system/hilink-advanced.sh" ]] && chmod +x "$PROJECT_ROOT/scripts/system/hilink-advanced.sh"
[[ -f "$PROJECT_ROOT/scripts/system/connection-control.sh" ]] && chmod +x "$PROJECT_ROOT/scripts/system/connection-control.sh"
[[ -f "$PROJECT_ROOT/scripts/system/apn-manager.sh" ]] && chmod +x "$PROJECT_ROOT/scripts/system/apn-manager.sh"
[[ -f "$PROJECT_ROOT/scripts/system/dcom-autoconnect.sh" ]] && chmod +x "$PROJECT_ROOT/scripts/system/dcom-autoconnect.sh"
[[ -f "$PROJECT_ROOT/scripts/system/detect-dcom-devices.sh" ]] && chmod +x "$PROJECT_ROOT/scripts/system/detect-dcom-devices.sh"
[[ -f "$PROJECT_ROOT/scripts/system/system-monitor.sh" ]] && chmod +x "$PROJECT_ROOT/scripts/system/system-monitor.sh"

# 3proxy scripts
[[ -f "$PROJECT_ROOT/scripts/3proxy/manage-3proxy.sh" ]] && chmod +x "$PROJECT_ROOT/scripts/3proxy/manage-3proxy.sh"
[[ -f "$PROJECT_ROOT/scripts/3proxy/generate-config.sh" ]] && chmod +x "$PROJECT_ROOT/scripts/3proxy/generate-config.sh"
[[ -f "$PROJECT_ROOT/scripts/3proxy/deploy-config.sh" ]] && chmod +x "$PROJECT_ROOT/scripts/3proxy/deploy-config.sh"

# DCOM scripts (if any exist)
if [[ -d "$PROJECT_ROOT/scripts/dcom" ]]; then
    find "$PROJECT_ROOT/scripts/dcom" -name "*.sh" -type f -exec chmod +x {} \; 2>/dev/null
fi

echo -e "${BLUE}🐍 Fixing Python file permissions...${NC}"
# Python files
chmod +x "$PROJECT_ROOT/webapp/app.py" 2>/dev/null
find "$PROJECT_ROOT/webapp" -name "*.py" -type f -exec chmod +x {} \; 2>/dev/null

echo -e "${YELLOW}📄 Fixing configuration file permissions...${NC}"
# Config files - readable by owner/group, not world
chmod 640 "$PROJECT_ROOT/configs/3proxy/3proxy.cfg" 2>/dev/null
chmod 600 "$PROJECT_ROOT/configs/3proxy/users.conf" 2>/dev/null  # Sensitive
chmod 644 "$PROJECT_ROOT/configs/3proxy/3proxy.cfg.template" 2>/dev/null
chmod 644 "$PROJECT_ROOT/configs/dcom/apn-profiles.conf" 2>/dev/null
chmod 644 "$PROJECT_ROOT/configs/dcom/user_assignments.json" 2>/dev/null
chmod 644 "$PROJECT_ROOT/configs/udev/99-dcom-stable.rules" 2>/dev/null

# Service files
chmod 644 "$PROJECT_ROOT/proxyfarm.service" 2>/dev/null
chmod 644 "$PROJECT_ROOT/nginx-proxyfarm.conf" 2>/dev/null

echo -e "${BLUE}🌐 Fixing web files permissions...${NC}"
# HTML templates
find "$PROJECT_ROOT/webapp/templates" -name "*.html" -type f -exec chmod 644 {} \; 2>/dev/null

# CSS files  
find "$PROJECT_ROOT/webapp/static" -name "*.css" -type f -exec chmod 644 {} \; 2>/dev/null

# JavaScript files (if any)
find "$PROJECT_ROOT/webapp/static" -name "*.js" -type f -exec chmod 644 {} \; 2>/dev/null

echo -e "${YELLOW}📋 Fixing documentation permissions...${NC}"
# Documentation files
chmod 644 "$PROJECT_ROOT/README"*.md 2>/dev/null
chmod 644 "$PROJECT_ROOT/SETUP-GUIDE.md" 2>/dev/null

echo -e "${GREEN}📊 Setting up log directories with proper permissions...${NC}"
# Log directories with write permissions
chmod 755 "$PROJECT_ROOT/logs"
chmod 755 "$PROJECT_ROOT/logs/3proxy"
chmod 755 "$PROJECT_ROOT/logs/system" 
chmod 755 "$PROJECT_ROOT/logs/webapp"

# Create initial log files if they don't exist
touch "$PROJECT_ROOT/logs/system/monitor.log" 2>/dev/null
touch "$PROJECT_ROOT/logs/system/alerts.log" 2>/dev/null
touch "$PROJECT_ROOT/logs/system/backup.log" 2>/dev/null
touch "$PROJECT_ROOT/logs/webapp/access.log" 2>/dev/null
touch "$PROJECT_ROOT/logs/webapp/error.log" 2>/dev/null

# Set log file permissions
chmod 644 "$PROJECT_ROOT/logs"/*/*.log 2>/dev/null

echo -e "${BLUE}🔐 Setting ownership...${NC}"
# Set ownership to root for system files
chown -R root:root "$PROJECT_ROOT"

# Make specific files owned by appropriate users
# Web files can be owned by www-data if nginx is running
if id "www-data" >/dev/null 2>&1; then
    chown -R www-data:www-data "$PROJECT_ROOT/webapp/static" 2>/dev/null
fi

echo -e "${GREEN}✅ Enhanced permission fix completed!${NC}"
echo ""
echo -e "${YELLOW}📋 Detailed Summary:${NC}"
echo "✓ Directory permissions: 755 (all directories)"
echo "✓ Shell scripts (.sh): +x (all executable)"
echo "✓ Python files (.py): +x (executable)"
echo "✓ Config files: 644/640 (readable)"
echo "✓ Sensitive files: 600 (secure)"
echo "✓ HTML/CSS files: 644 (readable)"
echo "✓ Service files: 644 (readable)"
echo "✓ Log directories: created with proper permissions"
echo "✓ Documentation: 644 (readable)"
echo "✓ Ownership: root:root (system files)"
echo ""
echo -e "${BLUE}🔧 Scripts now executable:${NC}"
echo "• Production: start/stop/restart/status-production.sh"
echo "• Installation: install-service.sh, setup-*.sh"
echo "• Monitoring: monitor-system.sh, monitoring-dashboard.sh"
echo "• Maintenance: backup-system.sh, update-system.sh"
echo "• System: all scripts in scripts/ directory"
echo ""
echo -e "${GREEN}🚀 System ready for deployment!${NC}"

# Enhanced test
echo ""
echo -e "${YELLOW}🧪 System Verification:${NC}"

# Test critical files (only check files that should exist)
CRITICAL_FILES=(
    "webapp/app.py"
    "start-production.sh"
    "install-service.sh"
    "monitor-system.sh"
    "backup-system.sh"
    "fix-permissions.sh"
)

FAILED_COUNT=0
for file in "${CRITICAL_FILES[@]}"; do
    if [[ -x "$PROJECT_ROOT/$file" ]]; then
        echo "✅ $file is executable"
    else
        echo "❌ $file permission issue"
        ((FAILED_COUNT++))
    fi
done

# Test directories
REQUIRED_DIRS=(
    "logs/system"
    "logs/webapp" 
    "configs/3proxy"
    "configs/dcom"
    "webapp/static/css"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [[ -d "$PROJECT_ROOT/$dir" ]]; then
        echo "✅ Directory $dir exists"
    else
        echo "❌ Directory $dir missing"
        ((FAILED_COUNT++))
    fi
done

echo ""
if [[ $FAILED_COUNT -eq 0 ]]; then
    echo -e "${GREEN}🎉 All checks passed! System is ready.${NC}"
    echo ""
    echo -e "${BLUE}📋 Quick Start Commands:${NC}"
    echo "• Install service: sudo ./install-service.sh"
    echo "• Start production: ./start-production.sh"  
    echo "• Check status: ./status-production.sh"
    echo "• Monitor system: ./monitoring-dashboard.sh"
else
    echo -e "${RED}⚠️  $FAILED_COUNT issues found. Please check the errors above.${NC}"
fi

echo ""
echo -e "${YELLOW}💡 Tips:${NC}"
echo "• Run this after every file upload: sudo ./fix-permissions.sh"
echo "• For Ubuntu Server deployment: see README-DEPLOYMENT.md"
echo "• Check logs in: logs/system/ logs/webapp/"