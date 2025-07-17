#!/bin/bash
# Master Installation Script for All System Optimizations

set -e

echo "🚀 PROXY FARM SYSTEM OPTIMIZATION INSTALLER"
echo "============================================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ This script must be run as root"
    exit 1
fi

# Define script directory
SCRIPT_DIR="/home/proxy-farm-system"

echo "📍 Working directory: $SCRIPT_DIR"
echo ""

# Step 1: System optimization
echo "🔧 Step 1: Installing system optimizations..."
$SCRIPT_DIR/scripts/system/install-optimization.sh

echo ""
echo "⏸️  Press Enter to continue with udev rules setup..."
read

# Step 2: Deploy udev rules
echo "🏷️  Step 2: Deploying udev rules..."
$SCRIPT_DIR/scripts/system/deploy-udev-rules.sh

echo ""
echo "⏸️  Press Enter to continue with firewall setup..."
read

# Step 3: Setup firewall
echo "🔥 Step 3: Setting up firewall and security..."
$SCRIPT_DIR/scripts/system/setup-firewall.sh

echo ""
echo "⏸️  Press Enter to continue with monitoring setup..."
read

# Step 4: Setup monitoring
echo "📊 Step 4: Setting up system monitoring..."
$SCRIPT_DIR/scripts/system/setup-monitoring.sh

echo ""
echo "🎉 INSTALLATION COMPLETED!"
echo "=========================="
echo ""
echo "✅ System optimizations applied"
echo "✅ udev rules for stable device naming deployed"
echo "✅ Firewall and security configured"
echo "✅ Automated monitoring setup"
echo ""
echo "⚠️  IMPORTANT NEXT STEPS:"
echo "1. REBOOT the system for all changes to take effect:"
echo "   reboot"
echo ""
echo "2. After reboot, verify installation:"
echo "   /home/proxy-farm-system/manage.sh status"
echo ""
echo "3. Test device detection:"
echo "   /home/proxy-farm-system/scripts/system/detect-dcom-devices.sh"
echo ""
echo "4. Monitor system:"
echo "   /home/proxy-farm-system/scripts/system/system-monitor.sh all"
echo ""
echo "📁 All configuration files backed up with timestamps"
echo "📝 Logs available in: /home/proxy-farm-system/logs/"
echo ""
echo "🎯 Ready for DCOM devices and 3proxy configuration!"
