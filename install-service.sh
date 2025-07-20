#!/bin/bash

# ProxyFarm System - Service Installation Script
# Run as root: sudo ./install-service.sh

set -e

echo "🚀 Installing ProxyFarm System Service..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root: sudo ./install-service.sh"
    exit 1
fi

# Get current directory
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="/home/proxy-farm-system"
SERVICE_NAME="proxyfarm"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

echo "Current directory: $CURRENT_DIR"
echo "Target directory: $PROJECT_ROOT"

# Create project directory if not exists
if [ ! -d "$PROJECT_ROOT" ]; then
    echo "📁 Creating project directory: $PROJECT_ROOT"
    mkdir -p "$PROJECT_ROOT"
fi

# Copy all project files if not already in target directory
if [ "$CURRENT_DIR" != "$PROJECT_ROOT" ]; then
    echo "📂 Copying project files to $PROJECT_ROOT..."
    cp -r "$CURRENT_DIR"/* "$PROJECT_ROOT"/ 2>/dev/null || true
    cp -r "$CURRENT_DIR"/.* "$PROJECT_ROOT"/ 2>/dev/null || true
fi

# Copy service file
echo "📝 Installing systemd service..."
if [ -f "$PROJECT_ROOT/proxyfarm.service" ]; then
    cp "$PROJECT_ROOT/proxyfarm.service" "$SERVICE_FILE"
elif [ -f "$CURRENT_DIR/proxyfarm.service" ]; then
    cp "$CURRENT_DIR/proxyfarm.service" "$SERVICE_FILE"
else
    echo "❌ proxyfarm.service not found!"
    exit 1
fi

# Install Python dependencies
echo "🐍 Installing Python dependencies..."
apt update
apt install -y python3 python3-pip python3-venv

# Create virtual environment
echo "🔧 Setting up virtual environment..."
cd "$PROJECT_ROOT"
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi

# Activate virtual environment and install dependencies
source venv/bin/activate
pip install --upgrade pip
pip install flask gunicorn

# Create necessary directories
echo "📂 Creating directories..."
mkdir -p logs/{3proxy,system,webapp}
mkdir -p configs/{3proxy,dcom,udev,webapp}
mkdir -p scripts/{3proxy,dcom,system}

# Set permissions
echo "🔐 Setting permissions..."
chown -R root:root "$PROJECT_ROOT"
# Only chmod if directories and files exist
[[ -d "scripts/system" ]] && find scripts/system -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
[[ -d "scripts/3proxy" ]] && find scripts/3proxy -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
[[ -d "scripts/dcom" ]] && find scripts/dcom -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

# Reload systemd and enable service
echo "⚙️ Enabling service..."
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"

echo "✅ Service installed successfully!"
echo ""
echo "📋 Available commands:"
echo "  sudo systemctl start $SERVICE_NAME     # Start service"
echo "  sudo systemctl stop $SERVICE_NAME      # Stop service"
echo "  sudo systemctl restart $SERVICE_NAME   # Restart service"
echo "  sudo systemctl status $SERVICE_NAME    # Check status"
echo "  sudo journalctl -u $SERVICE_NAME -f    # View logs"
echo ""
echo "🌐 Web interface will be available at: http://your-server-ip:5000"
echo ""
echo "⚠️  Next steps:"
echo "1. Go to project directory: cd $PROJECT_ROOT"
echo "2. Fix permissions: sudo ./fix-permissions.sh"
echo "3. Start the service: sudo systemctl start $SERVICE_NAME"
echo "4. Check status: sudo systemctl status $SERVICE_NAME"
echo ""
echo "🔧 Or use production scripts:"
echo "   cd $PROJECT_ROOT"
echo "   ./start-production.sh"
echo "   ./status-production.sh"
echo ""
echo "🌐 Web interface: http://$(hostname -I | awk '{print $1}'):5000"