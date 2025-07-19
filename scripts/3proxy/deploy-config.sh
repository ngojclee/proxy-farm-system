#!/bin/bash
# Deploy 3proxy configuration to system

SCRIPT_DIR="/home/proxy-farm-system"
SOURCE_CONFIG="$SCRIPT_DIR/configs/3proxy/3proxy.cfg"
SYSTEM_CONFIG="/etc/3proxy/3proxy.cfg"
BACKUP_DIR="$SCRIPT_DIR/configs/3proxy/backups"

echo "=== Deploying 3proxy Configuration ==="

# Check if source config exists
if [ ! -f "$SOURCE_CONFIG" ]; then
    echo "❌ Source config not found: $SOURCE_CONFIG"
    echo "💡 Run generate-config.sh first"
    exit 1
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup existing system config
if [ -f "$SYSTEM_CONFIG" ]; then
    BACKUP_FILE="$BACKUP_DIR/3proxy.cfg.backup.$(date +%Y%m%d_%H%M%S)"
    echo "📋 Backing up existing config to: $BACKUP_FILE"
    cp "$SYSTEM_CONFIG" "$BACKUP_FILE"
fi

# Ensure system directory exists
mkdir -p "$(dirname "$SYSTEM_CONFIG")"

# Test configuration syntax
echo "🧪 Testing configuration syntax..."
if /usr/bin/3proxy -t "$SOURCE_CONFIG"; then
    echo "✅ Configuration syntax is valid"
else
    echo "❌ Configuration syntax error"
    echo "💡 Fix errors in: $SOURCE_CONFIG"
    exit 1
fi

# Deploy configuration
echo "📦 Deploying configuration..."
cp "$SOURCE_CONFIG" "$SYSTEM_CONFIG"

# Set proper permissions
chown root:root "$SYSTEM_CONFIG"
chmod 644 "$SYSTEM_CONFIG"

# Create log directory if needed
mkdir -p /var/log/3proxy
chown proxy:proxy /var/log/3proxy 2>/dev/null || true

echo "✅ Configuration deployed successfully"

# Ask about restarting service
echo ""
read -p "🔄 Restart 3proxy service now? (y/N): " restart_choice

if [ "$restart_choice" = "y" ] || [ "$restart_choice" = "Y" ]; then
    echo "🔄 Restarting 3proxy service..."
    
    if systemctl restart 3proxy; then
        echo "✅ 3proxy service restarted successfully"
        
        # Check service status
        sleep 2
        if systemctl is-active --quiet 3proxy; then
            echo "✅ 3proxy is running"
            
            # Show listening ports
            echo "📊 Listening ports:"
            netstat -tlpn | grep 3proxy | head -5
        else
            echo "❌ 3proxy failed to start"
            echo "📝 Check logs: journalctl -u 3proxy -n 20"
        fi
    else
        echo "❌ Failed to restart 3proxy"
        echo "📝 Check configuration and logs"
    fi
else
    echo "⚠️  Configuration deployed but service not restarted"
    echo "💡 Manual restart: systemctl restart 3proxy"
fi

echo ""
echo "📁 Files:"
echo "   Source: $SOURCE_CONFIG"
echo "   System: $SYSTEM_CONFIG"
echo "   Backup: $BACKUP_DIR/"
