#!/bin/bash

# ProxyFarm System - Setup Monitoring Script
# This script sets up cron jobs and monitoring services

set -e

PROJECT_ROOT="/home/proxy-farm-system"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📊 Setting up ProxyFarm System Monitoring${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Please run as root: sudo ./setup-monitoring.sh${NC}"
    exit 1
fi

# Make monitoring script executable
chmod +x "$PROJECT_ROOT/monitor-system.sh"

# Create monitoring cron jobs
echo -e "${BLUE}⏰ Setting up cron jobs...${NC}"

# Create cron file for root
CRON_FILE="/etc/cron.d/proxyfarm-monitoring"

cat > "$CRON_FILE" << EOF
# ProxyFarm System Monitoring Cron Jobs
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Monitor system every 5 minutes with auto-restart
*/5 * * * * root cd $PROJECT_ROOT && ./monitor-system.sh --auto-restart >/dev/null 2>&1

# Generate health report every hour
0 * * * * root cd $PROJECT_ROOT && ./monitor-system.sh --report >/dev/null 2>&1

# Cleanup old logs daily at 2 AM
0 2 * * * root find $PROJECT_ROOT/logs -name "*.log" -mtime +7 -delete >/dev/null 2>&1

# Cleanup old health reports weekly
0 3 * * 0 root find $PROJECT_ROOT/logs/system -name "health_report_*.txt" -mtime +30 -delete >/dev/null 2>&1

# Restart services daily at 4 AM (maintenance window)
0 4 * * * root cd $PROJECT_ROOT && ./restart-production.sh >/dev/null 2>&1
EOF

# Set proper permissions for cron file
chmod 644 "$CRON_FILE"

echo -e "${GREEN}✅ Cron jobs configured${NC}"

# Setup logrotate for ProxyFarm logs
echo -e "${BLUE}📝 Setting up log rotation...${NC}"

LOGROTATE_FILE="/etc/logrotate.d/proxyfarm"

cat > "$LOGROTATE_FILE" << EOF
$PROJECT_ROOT/logs/*/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    copytruncate
    su root root
}

$PROJECT_ROOT/logs/webapp/access.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    copytruncate
    su root root
    postrotate
        if [ -f $PROJECT_ROOT/logs/webapp/gunicorn.pid ]; then
            kill -USR1 \$(cat $PROJECT_ROOT/logs/webapp/gunicorn.pid)
        fi
    endscript
}
EOF

echo -e "${GREEN}✅ Log rotation configured${NC}"

# Create systemd service for continuous monitoring (optional)
echo -e "${BLUE}🔧 Creating monitoring service...${NC}"

MONITOR_SERVICE="/etc/systemd/system/proxyfarm-monitor.service"

cat > "$MONITOR_SERVICE" << EOF
[Unit]
Description=ProxyFarm System Monitor
After=network.target
Requires=proxyfarm.service

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=$PROJECT_ROOT
ExecStart=$PROJECT_ROOT/monitor-system.sh --continuous
Restart=always
RestartSec=60
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=proxyfarm-monitor

[Install]
WantedBy=multi-user.target
EOF

# Enable monitoring service (but don't start it by default)
systemctl daemon-reload
systemctl enable proxyfarm-monitor.service

echo -e "${GREEN}✅ Monitoring service created${NC}"

# Setup alerting script
echo -e "${BLUE}📧 Setting up alert notifications...${NC}"

ALERT_SCRIPT="$PROJECT_ROOT/send-alerts.sh"

cat > "$ALERT_SCRIPT" << 'EOF'
#!/bin/bash

# ProxyFarm Alert Notification Script
# Configure this script to send alerts via email, Slack, Discord, etc.

ALERT_LOG="/home/proxy-farm-system/logs/system/alerts.log"
NOTIFICATION_LOG="/home/proxy-farm-system/logs/system/notifications.log"

log_notification() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$NOTIFICATION_LOG"
}

# Check for new alerts
if [ -f "$ALERT_LOG" ]; then
    # Get alerts from last 10 minutes
    RECENT_ALERTS=$(find "$ALERT_LOG" -mmin -10 -exec tail -n 50 {} \; | grep "ALERT:")
    
    if [ ! -z "$RECENT_ALERTS" ]; then
        # Send email notification (configure sendmail/postfix)
        # echo "$RECENT_ALERTS" | mail -s "ProxyFarm Alert" admin@yourdomain.com
        
        # Send to Slack (configure webhook URL)
        # curl -X POST -H 'Content-type: application/json' \
        #     --data "{\"text\":\"ProxyFarm Alert:\n$RECENT_ALERTS\"}" \
        #     YOUR_SLACK_WEBHOOK_URL
        
        # Send to Discord (configure webhook URL)
        # curl -X POST -H 'Content-type: application/json' \
        #     --data "{\"content\":\"ProxyFarm Alert:\n\`\`\`$RECENT_ALERTS\`\`\`\"}" \
        #     YOUR_DISCORD_WEBHOOK_URL
        
        log_notification "Alert notifications sent for: $(echo "$RECENT_ALERTS" | wc -l) alerts"
    fi
fi
EOF

chmod +x "$ALERT_SCRIPT"

# Add alert checking to cron
echo "*/10 * * * * root $PROJECT_ROOT/send-alerts.sh >/dev/null 2>&1" >> "$CRON_FILE"

echo -e "${GREEN}✅ Alert system configured${NC}"

# Create monitoring dashboard
echo -e "${BLUE}📊 Creating monitoring dashboard...${NC}"

DASHBOARD_SCRIPT="$PROJECT_ROOT/monitoring-dashboard.sh"

cat > "$DASHBOARD_SCRIPT" << 'EOF'
#!/bin/bash

# ProxyFarm Monitoring Dashboard
# Quick overview of system status

PROJECT_ROOT="/home/proxy-farm-system"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo -e "${BLUE}╔══════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        ProxyFarm Dashboard           ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════╝${NC}"
echo ""

# System info
echo -e "${BLUE}🖥️  System Information${NC}"
echo -e "   Hostname: $(hostname)"
echo -e "   Uptime: $(uptime -p)"
echo -e "   Load Average: $(uptime | awk -F'load average:' '{print $2}')"
echo ""

# Service status
echo -e "${BLUE}🔧 Service Status${NC}"
if pgrep -f "gunicorn.*app:app" > /dev/null; then
    echo -e "   Webapp: ${GREEN}✅ Running${NC}"
else
    echo -e "   Webapp: ${RED}❌ Stopped${NC}"
fi

if pgrep 3proxy > /dev/null; then
    echo -e "   3proxy: ${GREEN}✅ Running${NC}"
else
    echo -e "   3proxy: ${RED}❌ Stopped${NC}"
fi

if systemctl is-active nginx >/dev/null 2>&1; then
    echo -e "   Nginx: ${GREEN}✅ Running${NC}"
else
    echo -e "   Nginx: ${RED}❌ Stopped${NC}"
fi
echo ""

# Resource usage
echo -e "${BLUE}📊 Resource Usage${NC}"
echo -e "   CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}')"
echo -e "   Memory: $(free -h | grep Mem | awk '{print $3 "/" $2}')"
echo -e "   Disk: $(df -h $PROJECT_ROOT | awk 'NR==2 {print $3 "/" $2 " (" $5 " used)"}')"
echo ""

# Network
echo -e "${BLUE}🌐 Network Status${NC}"
echo -e "   Active connections: $(netstat -tn | grep ESTABLISHED | wc -l)"
echo -e "   Proxy ports listening: $(netstat -tlnp | grep -E ":(3330|3331|3332|3333|3334|3335|3336|3337|3338|3339)" | wc -l)/10"
echo -e "   Webapp port: $(netstat -tlnp | grep ":5000" >/dev/null && echo "✅ Open" || echo "❌ Closed")"
echo ""

# DCOM devices
echo -e "${BLUE}📱 DCOM Devices${NC}"
DCOM_COUNT=$(lsusb | grep -E "(Huawei|E3372|12d1:)" | wc -l)
echo -e "   Detected devices: $DCOM_COUNT"
ACTIVE_INTERFACES=$(ip link show | grep -E "enx[0-9a-f]+" | grep "state UP" | wc -l)
echo -e "   Active interfaces: $ACTIVE_INTERFACES"
echo ""

# Recent alerts
echo -e "${BLUE}🚨 Recent Alerts (last 24h)${NC}"
if [ -f "$PROJECT_ROOT/logs/system/alerts.log" ]; then
    ALERT_COUNT=$(find "$PROJECT_ROOT/logs/system/alerts.log" -mtime -1 -exec grep -c "ALERT:" {} \; 2>/dev/null || echo "0")
    echo -e "   Alert count: $ALERT_COUNT"
    
    if [ "$ALERT_COUNT" -gt 0 ]; then
        echo -e "   Latest alerts:"
        find "$PROJECT_ROOT/logs/system/alerts.log" -mtime -1 -exec tail -n 3 {} \; 2>/dev/null | grep "ALERT:" | tail -n 3 | sed 's/^/     /'
    fi
else
    echo -e "   No alert log found"
fi
echo ""

echo -e "${BLUE}📋 Quick Commands:${NC}"
echo -e "   ${GREEN}./status-production.sh${NC}      - Detailed service status"
echo -e "   ${GREEN}./monitor-system.sh${NC}         - Run health check"
echo -e "   ${GREEN}tail -f logs/system/monitor.log${NC} - View monitor logs"
echo -e "   ${GREEN}systemctl status proxyfarm${NC}  - Check systemd service"
EOF

chmod +x "$DASHBOARD_SCRIPT"

echo -e "${GREEN}✅ Monitoring dashboard created${NC}"

# Restart cron to apply new jobs
systemctl restart cron

echo -e "${GREEN}🎉 Monitoring setup completed!${NC}"
echo ""
echo -e "${BLUE}📋 Monitoring Features Installed:${NC}"
echo -e "   ✅ System health checks every 5 minutes"
echo -e "   ✅ Auto-restart of failed services"
echo -e "   ✅ Hourly health reports"
echo -e "   ✅ Daily log cleanup"
echo -e "   ✅ Log rotation configuration"
echo -e "   ✅ Alert notification system"
echo -e "   ✅ Monitoring dashboard"
echo ""
echo -e "${BLUE}📊 Available Commands:${NC}"
echo -e "   ${GREEN}./monitor-system.sh${NC}           - Run manual health check"
echo -e "   ${GREEN}./monitoring-dashboard.sh${NC}     - View system dashboard"
echo -e "   ${GREEN}systemctl start proxyfarm-monitor${NC} - Start continuous monitoring"
echo -e "   ${GREEN}tail -f logs/system/alerts.log${NC}   - View alerts"
echo -e "   ${GREEN}tail -f logs/system/monitor.log${NC}  - View monitor logs"
echo ""
echo -e "${YELLOW}⚠️  Next Steps:${NC}"
echo -e "   1. Configure alert notifications in send-alerts.sh"
echo -e "   2. Test monitoring: ./monitor-system.sh"
echo -e "   3. View dashboard: ./monitoring-dashboard.sh"
echo -e "   4. Optional: Start continuous monitoring service"