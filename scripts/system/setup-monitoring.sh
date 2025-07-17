#!/bin/bash
# Setup automated monitoring with cron jobs

echo "=== Setting up automated monitoring ==="

# Create log rotation script
cat > /home/proxy-farm-system/scripts/system/rotate-logs.sh << 'EOF'
#!/bin/bash
# Log rotation script

LOG_DIR="/home/proxy-farm-system/logs"
MAX_SIZE="100M"

# Rotate logs larger than MAX_SIZE
find "$LOG_DIR" -name "*.log" -size +$MAX_SIZE -exec truncate -s 50M {} \;

# Remove old backup logs
find "$LOG_DIR" -name "*.log.*" -mtime +7 -delete

echo "Log rotation completed: $(date)"
EOF

chmod +x /home/proxy-farm-system/scripts/system/rotate-logs.sh

# Setup cron jobs for monitoring
(crontab -l 2>/dev/null; cat << 'EOF'

# Proxy Farm System Monitoring
# Full system check every 5 minutes
*/5 * * * * /home/proxy-farm-system/scripts/system/system-monitor.sh all >> /home/proxy-farm-system/logs/cron-monitor.log 2>&1

# USB device check every minute
* * * * * /home/proxy-farm-system/scripts/system/system-monitor.sh usb >/dev/null 2>&1

# Security check every 15 minutes
*/15 * * * * /home/proxy-farm-system/scripts/system/system-monitor.sh security >/dev/null 2>&1

# Log rotation daily at 2 AM
0 2 * * * /home/proxy-farm-system/scripts/system/rotate-logs.sh

# System summary hourly
0 * * * * /home/proxy-farm-system/scripts/system/system-monitor.sh summary >> /home/proxy-farm-system/logs/hourly-summary.log 2>&1

EOF
) | crontab -

echo "✅ Automated monitoring configured"
echo ""
echo "📅 Cron jobs scheduled:"
echo "   - Full system check: Every 5 minutes"
echo "   - USB device check: Every minute"
echo "   - Security check: Every 15 minutes"
echo "   - Log rotation: Daily at 2 AM"
echo "   - Summary report: Every hour"
echo ""
echo "📝 Log files:"
echo "   - Main log: /home/proxy-farm-system/logs/system-monitor.log"
echo "   - Cron log: /home/proxy-farm-system/logs/cron-monitor.log"
echo "   - Summary log: /home/proxy-farm-system/logs/hourly-summary.log"
