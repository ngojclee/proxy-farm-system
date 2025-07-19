#!/bin/bash
# Verification script to check installation after reboot

echo "🔍 SYSTEM OPTIMIZATION VERIFICATION"
echo "===================================="
echo ""

errors=0

# Check system limits
echo "📊 Checking system limits..."

# Check sysctl values
sysctl_checks=(
    "kernel.pid_max:4194304"
    "fs.file-max:2097152"
    "vm.swappiness:10"
    "net.core.somaxconn:65535"
)

for check in "${sysctl_checks[@]}"; do
    param=$(echo "$check" | cut -d: -f1)
    expected=$(echo "$check" | cut -d: -f2)
    actual=$(sysctl -n "$param" 2>/dev/null)
    
    if [ "$actual" = "$expected" ]; then
        echo "  ✅ $param = $actual"
    else
        echo "  ❌ $param = $actual (expected: $expected)"
        errors=$((errors + 1))
    fi
done

# Check file descriptor limits
echo ""
echo "📁 Checking file descriptor limits..."
ulimit_check=$(ulimit -n)
if [ "$ulimit_check" -ge 65536 ]; then
    echo "  ✅ ulimit -n = $ulimit_check"
else
    echo "  ❌ ulimit -n = $ulimit_check (expected: >= 65536)"
    errors=$((errors + 1))
fi

# Check udev rules
echo ""
echo "🏷️  Checking udev rules..."
if [ -f "/etc/udev/rules.d/99-dcom-stable.rules" ]; then
    echo "  ✅ udev rules file exists"
    
    # Check if rules are loaded
    rule_count=$(grep -c "SYMLINK" /etc/udev/rules.d/99-dcom-stable.rules)
    echo "  ✅ $rule_count udev rules loaded"
else
    echo "  ❌ udev rules file missing"
    errors=$((errors + 1))
fi

# Check firewall
echo ""
echo "🔥 Checking firewall status..."
if command -v ufw >/dev/null 2>&1; then
    ufw_status=$(ufw status | head -1 | awk '{print $2}')
    if [ "$ufw_status" = "active" ]; then
        echo "  ✅ UFW firewall: $ufw_status"
    else
        echo "  ❌ UFW firewall: $ufw_status"
        errors=$((errors + 1))
    fi
else
    echo "  ❌ UFW not installed"
    errors=$((errors + 1))
fi

# Check fail2ban
if systemctl is-active --quiet fail2ban; then
    echo "  ✅ fail2ban: running"
else
    echo "  ❌ fail2ban: not running"
    errors=$((errors + 1))
fi

# Check services
echo ""
echo "🔧 Checking required services..."
services=("ssh" "cron")

for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service"; then
        echo "  ✅ $service: running"
    else
        echo "  ❌ $service: not running"
        errors=$((errors + 1))
    fi
done

# Check cron jobs
echo ""
echo "📅 Checking cron jobs..."
cron_count=$(crontab -l 2>/dev/null | grep -c "proxy-farm-system" || echo "0")
if [ "$cron_count" -gt 0 ]; then
    echo "  ✅ $cron_count monitoring cron jobs configured"
else
    echo "  ❌ No monitoring cron jobs found"
    errors=$((errors + 1))
fi

# Check log directory
echo ""
echo "📝 Checking log directory..."
if [ -d "/home/proxy-farm-system/logs" ]; then
    echo "  ✅ Log directory exists"
    log_files=$(ls -la /home/proxy-farm-system/logs/ | wc -l)
    echo "  📂 Log files: $((log_files - 2))"
else
    echo "  ❌ Log directory missing"
    errors=$((errors + 1))
fi

# Summary
echo ""
echo "📋 VERIFICATION SUMMARY"
echo "======================"
if [ "$errors" -eq 0 ]; then
    echo "🎉 ALL CHECKS PASSED!"
    echo "✅ System optimization installation successful"
    echo ""
    echo "🎯 Ready for next steps:"
    echo "   1. Connect DCOM devices"
    echo "   2. Run device detection: detect-dcom-devices.sh"
    echo "   3. Configure 3proxy"
else
    echo "❌ $errors ERROR(S) FOUND"
    echo "⚠️  Please review and fix issues above"
    echo ""
    echo "🔧 Common fixes:"
    echo "   - Reboot if system limits not applied"
    echo "   - Re-run installation scripts for missing components"
    echo "   - Check system logs for detailed error messages"
fi

echo ""
echo "📊 System status:"
echo "   Uptime: $(uptime | awk -F'up ' '{print $2}' | awk -F', load' '{print $1}')"
echo "   Load: $(uptime | awk -F'load average:' '{print $2}')"
echo "   Memory: $(free -h | grep Mem | awk '{print $3"/"$2}')"
echo "   Disk: $(df -h / | awk 'NR==2{print $5}')"

exit $errors
