#!/bin/bash
# Deploy udev rules to system

echo "=== Deploying udev rules ==="

# Copy rules to system
cp /home/proxy-farm-system/configs/udev/99-dcom-stable.rules /etc/udev/rules.d/

# Set permissions
chmod 644 /etc/udev/rules.d/99-dcom-stable.rules

# Reload udev rules
echo "📝 Reloading udev rules..."
udevadm control --reload-rules
udevadm trigger

echo "✅ udev rules deployed and reloaded"
echo ""
echo "🔌 Replug USB devices or wait 30 seconds for rules to take effect"
