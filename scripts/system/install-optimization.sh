#!/bin/bash
# System Optimization Script for Multiple USB DCOM Devices
# Optimizes Ubuntu for handling 20+ USB devices

set -e

echo "=== Ubuntu System Optimization for Multiple USB Devices ==="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ This script must be run as root"
    exit 1
fi

echo "📝 Step 1: Optimizing system limits..."

# Backup original sysctl.conf
cp /etc/sysctl.conf /etc/sysctl.conf.backup.$(date +%Y%m%d_%H%M%S)

# Add optimizations to sysctl.conf
cat >> /etc/sysctl.conf << 'EOF'

# ========================================
# USB DCOM Proxy Farm Optimizations
# ========================================

# USB and device optimization
kernel.pid_max = 4194304
fs.file-max = 2097152
fs.nr_open = 2097152

# Network optimization for proxy traffic
net.core.somaxconn = 65535
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.netdev_max_backlog = 5000
net.core.netdev_budget = 600

# TCP optimization
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = bbr
net.ipv4.ip_forward = 1

# Memory optimization
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.overcommit_memory = 1

# Connection tracking for multiple proxies
net.netfilter.nf_conntrack_max = 1048576
net.nf_conntrack_max = 1048576
EOF

echo "✅ System limits configured"

echo "📝 Step 2: Configuring USB power management..."

# Disable USB autosuspend in GRUB
if grep -q "usbcore.autosuspend" /etc/default/grub; then
    echo "USB autosuspend already configured"
else
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& usbcore.autosuspend=-1/' /etc/default/grub
    update-grub
    echo "✅ USB autosuspend disabled"
fi

echo "📝 Step 3: Increasing file descriptor limits..."

# Backup limits.conf
cp /etc/security/limits.conf /etc/security/limits.conf.backup.$(date +%Y%m%d_%H%M%S)

# Add limits
cat >> /etc/security/limits.conf << 'EOF'

# Proxy Farm File Descriptor Limits
* soft nofile 65536
* hard nofile 65536
* soft nproc 65536
* hard nproc 65536
root soft nofile 65536
root hard nofile 65536
EOF

echo "✅ File descriptor limits increased"

echo "📝 Step 4: Configuring systemd limits..."

# Configure systemd system limits
mkdir -p /etc/systemd/system.conf.d
cat > /etc/systemd/system.conf.d/limits.conf << 'EOF'
[Manager]
DefaultLimitNOFILE=65536
DefaultLimitNPROC=65536
EOF

# Configure systemd user limits
mkdir -p /etc/systemd/user.conf.d
cat > /etc/systemd/user.conf.d/limits.conf << 'EOF'
[Manager]
DefaultLimitNOFILE=65536
DefaultLimitNPROC=65536
EOF

echo "✅ Systemd limits configured"

echo "📝 Step 5: Applying changes..."

# Apply sysctl changes
sysctl -p

# Reload systemd
systemctl daemon-reload

echo ""
echo "🎉 System optimization completed!"
echo ""
echo "⚠️  IMPORTANT: Reboot required for all changes to take effect"
echo "    Run: reboot"
echo ""
echo "📊 Verification commands after reboot:"
echo "    sysctl kernel.pid_max"
echo "    ulimit -n"
echo "    cat /proc/sys/fs/file-max"
