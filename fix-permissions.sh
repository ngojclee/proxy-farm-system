#!/bin/bash

# Quick Permission Fix Script
# Run this after SFTP upload to fix common permission issues

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🔧 Proxy Farm - Quick Permission Fix${NC}"
echo "=================================="

# Get current directory
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$CURRENT_DIR"

echo "Project Root: $PROJECT_ROOT"

# Check if running with proper permissions
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Please run with sudo:${NC}"
    echo "sudo ./fix-permissions.sh"
    exit 1
fi

echo -e "${YELLOW}📁 Fixing directory permissions...${NC}"
# Fix directory permissions
chmod 755 "$PROJECT_ROOT"
chmod 755 "$PROJECT_ROOT/scripts" 2>/dev/null
chmod 755 "$PROJECT_ROOT/scripts/system" 2>/dev/null
chmod 755 "$PROJECT_ROOT/scripts/3proxy" 2>/dev/null
chmod 755 "$PROJECT_ROOT/webapp" 2>/dev/null
chmod 755 "$PROJECT_ROOT/webapp/templates" 2>/dev/null
chmod 755 "$PROJECT_ROOT/configs" 2>/dev/null
chmod 755 "$PROJECT_ROOT/configs/3proxy" 2>/dev/null
chmod 755 "$PROJECT_ROOT/configs/dcom" 2>/dev/null
chmod 755 "$PROJECT_ROOT/logs" 2>/dev/null

echo -e "${YELLOW}🔨 Fixing script permissions...${NC}"
# Fix all shell scripts
find "$PROJECT_ROOT/scripts" -name "*.sh" -type f -exec chmod +x {} \; 2>/dev/null

# Critical scripts
chmod +x "$PROJECT_ROOT/fix-permissions.sh" 2>/dev/null
chmod +x "$PROJECT_ROOT/scripts/system/auto-permissions.sh" 2>/dev/null
chmod +x "$PROJECT_ROOT/scripts/system/user-manager.sh" 2>/dev/null
chmod +x "$PROJECT_ROOT/scripts/system/hilink-advanced.sh" 2>/dev/null
chmod +x "$PROJECT_ROOT/scripts/system/connection-control.sh" 2>/dev/null
chmod +x "$PROJECT_ROOT/scripts/3proxy/manage-3proxy.sh" 2>/dev/null

echo -e "${YELLOW}🐍 Fixing Python permissions...${NC}"
# Python files
chmod +x "$PROJECT_ROOT/webapp/app.py" 2>/dev/null
find "$PROJECT_ROOT/webapp" -name "*.py" -type f -exec chmod +x {} \; 2>/dev/null

echo -e "${YELLOW}📄 Fixing config file permissions...${NC}"
# Config files
chmod 644 "$PROJECT_ROOT/configs/3proxy/3proxy.cfg" 2>/dev/null
chmod 600 "$PROJECT_ROOT/configs/3proxy/users.conf" 2>/dev/null  # Sensitive
chmod 644 "$PROJECT_ROOT/configs/dcom/apn-profiles.conf" 2>/dev/null
chmod 644 "$PROJECT_ROOT/webapp/templates/*.html" 2>/dev/null

# HTML templates
find "$PROJECT_ROOT/webapp/templates" -name "*.html" -type f -exec chmod 644 {} \; 2>/dev/null

echo -e "${YELLOW}📊 Creating log directories...${NC}"
# Log directories
mkdir -p "$PROJECT_ROOT/logs/3proxy" 2>/dev/null
mkdir -p "$PROJECT_ROOT/logs/system" 2>/dev/null
mkdir -p "$PROJECT_ROOT/logs/webapp" 2>/dev/null
chmod 755 "$PROJECT_ROOT/logs"/* 2>/dev/null

echo -e "${GREEN}✅ Permission fix completed!${NC}"
echo ""
echo -e "${YELLOW}📋 Summary:${NC}"
echo "✓ Directory permissions: 755"
echo "✓ Shell scripts (.sh): +x (executable)"
echo "✓ Python files (.py): +x (executable)"
echo "✓ Config files: 644 (readable)"
echo "✓ Sensitive files: 600 (secure)"
echo "✓ HTML templates: 644 (readable)"
echo "✓ Log directories: created"
echo ""
echo -e "${GREEN}🚀 Ready to run!${NC}"
echo "Start webapp: cd webapp && python3 app.py"

# Quick test
echo ""
echo -e "${YELLOW}🧪 Quick Test:${NC}"
if [[ -x "$PROJECT_ROOT/webapp/app.py" ]]; then
    echo "✅ webapp/app.py is executable"
else
    echo "❌ webapp/app.py permission issue"
fi

if [[ -x "$PROJECT_ROOT/scripts/system/user-manager.sh" ]]; then
    echo "✅ user-manager.sh is executable"
else
    echo "❌ user-manager.sh permission issue"
fi

echo ""
echo -e "${YELLOW}💡 Tip: Run this script after every SFTP upload:${NC}"
echo "sudo ./fix-permissions.sh"