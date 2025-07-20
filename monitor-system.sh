#!/bin/bash

# ProxyFarm System - System Monitoring Script
# This script monitors the health of all components and sends alerts

PROJECT_ROOT="/home/proxy-farm-system"
LOG_FILE="$PROJECT_ROOT/logs/system/monitor.log"
ALERT_LOG="$PROJECT_ROOT/logs/system/alerts.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
WEBAPP_PORT=5000
PROXY_PORTS="3330 3331 3332 3333 3334 3335 3336 3337 3338 3339"
MAX_CPU_PERCENT=80
MAX_MEMORY_PERCENT=80
MIN_DISK_SPACE_GB=5

# Create log directories
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$(dirname "$ALERT_LOG")"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

alert() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ALERT: $1" | tee -a "$ALERT_LOG"
    log "ALERT: $1"
}

# Check if webapp is running
check_webapp() {
    log "Checking webapp status..."
    
    # Check if process is running
    if pgrep -f "gunicorn.*app:app" > /dev/null; then
        log "✅ Webapp process is running"
        
        # Check if port is listening
        if netstat -tlnp | grep -q ":$WEBAPP_PORT"; then
            log "✅ Webapp is listening on port $WEBAPP_PORT"
            
            # Test HTTP response
            if curl -f -s http://localhost:$WEBAPP_PORT/api/status > /dev/null; then
                log "✅ Webapp is responding to HTTP requests"
                return 0
            else
                alert "Webapp is not responding to HTTP requests"
                return 1
            fi
        else
            alert "Webapp is not listening on port $WEBAPP_PORT"
            return 1
        fi
    else
        alert "Webapp process is not running"
        return 1
    fi
}

# Check 3proxy status
check_3proxy() {
    log "Checking 3proxy status..."
    
    if pgrep 3proxy > /dev/null; then
        log "✅ 3proxy process is running"
        
        # Check listening ports
        local listening_ports=0
        for port in $PROXY_PORTS; do
            if netstat -tlnp | grep -q ":$port"; then
                ((listening_ports++))
            fi
        done
        
        log "✅ 3proxy listening on $listening_ports ports"
        
        if [ $listening_ports -eq 0 ]; then
            alert "3proxy is running but not listening on any configured ports"
            return 1
        fi
        
        return 0
    else
        alert "3proxy process is not running"
        return 1
    fi
}

# Check system resources
check_system_resources() {
    log "Checking system resources..."
    
    # CPU usage
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    CPU_USAGE=${CPU_USAGE%.*}  # Remove decimal part
    
    if [ "$CPU_USAGE" -gt "$MAX_CPU_PERCENT" ]; then
        alert "High CPU usage: ${CPU_USAGE}% (threshold: ${MAX_CPU_PERCENT}%)"
    else
        log "✅ CPU usage: ${CPU_USAGE}%"
    fi
    
    # Memory usage
    MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
    
    if [ "$MEMORY_USAGE" -gt "$MAX_MEMORY_PERCENT" ]; then
        alert "High memory usage: ${MEMORY_USAGE}% (threshold: ${MAX_MEMORY_PERCENT}%)"
    else
        log "✅ Memory usage: ${MEMORY_USAGE}%"
    fi
    
    # Disk space
    DISK_AVAILABLE=$(df -BG "$PROJECT_ROOT" | awk 'NR==2 {print $4}' | sed 's/G//')
    
    if [ "$DISK_AVAILABLE" -lt "$MIN_DISK_SPACE_GB" ]; then
        alert "Low disk space: ${DISK_AVAILABLE}GB available (threshold: ${MIN_DISK_SPACE_GB}GB)"
    else
        log "✅ Disk space: ${DISK_AVAILABLE}GB available"
    fi
}

# Check DCOM devices
check_dcom_devices() {
    log "Checking DCOM devices..."
    
    # Check if any USB modems are connected
    DCOM_DEVICES=$(lsusb | grep -E "(Huawei|E3372|12d1:)" | wc -l)
    
    if [ "$DCOM_DEVICES" -gt 0 ]; then
        log "✅ Found $DCOM_DEVICES DCOM device(s)"
        
        # Check network interfaces
        ACTIVE_INTERFACES=$(ip link show | grep -E "enx[0-9a-f]+" | grep "state UP" | wc -l)
        log "✅ Active DCOM interfaces: $ACTIVE_INTERFACES"
        
        if [ "$ACTIVE_INTERFACES" -eq 0 ]; then
            alert "DCOM devices found but no active network interfaces"
        fi
    else
        alert "No DCOM devices detected"
    fi
}

# Check log file sizes
check_log_sizes() {
    log "Checking log file sizes..."
    
    # Find large log files (>100MB)
    find "$PROJECT_ROOT/logs" -name "*.log" -size +100M 2>/dev/null | while read -r large_log; do
        SIZE=$(du -h "$large_log" | cut -f1)
        alert "Large log file detected: $large_log ($SIZE)"
    done
    
    # Check total log directory size
    TOTAL_LOG_SIZE=$(du -sh "$PROJECT_ROOT/logs" 2>/dev/null | cut -f1)
    log "✅ Total log directory size: $TOTAL_LOG_SIZE"
}

# Restart services if needed
restart_failed_services() {
    log "Checking if services need restart..."
    
    # Restart webapp if down
    if ! check_webapp; then
        log "Attempting to restart webapp..."
        cd "$PROJECT_ROOT"
        ./restart-production.sh
        sleep 10
        
        if check_webapp; then
            log "✅ Webapp restarted successfully"
        else
            alert "Failed to restart webapp"
        fi
    fi
    
    # Restart 3proxy if down
    if ! check_3proxy; then
        log "Attempting to restart 3proxy..."
        systemctl restart 3proxy
        sleep 5
        
        if check_3proxy; then
            log "✅ 3proxy restarted successfully"
        else
            alert "Failed to restart 3proxy"
        fi
    fi
}

# Generate health report
generate_health_report() {
    local report_file="$PROJECT_ROOT/logs/system/health_report_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "ProxyFarm System Health Report"
        echo "Generated: $(date)"
        echo "=================================="
        echo ""
        
        echo "Services Status:"
        echo "---------------"
        if check_webapp >/dev/null 2>&1; then
            echo "Webapp: ✅ Running"
        else
            echo "Webapp: ❌ Down"
        fi
        
        if check_3proxy >/dev/null 2>&1; then
            echo "3proxy: ✅ Running"
        else
            echo "3proxy: ❌ Down"
        fi
        
        echo ""
        echo "System Resources:"
        echo "----------------"
        echo "CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}')"
        echo "Memory Usage: $(free -h | grep Mem | awk '{print $3 "/" $2}')"
        echo "Disk Space: $(df -h "$PROJECT_ROOT" | awk 'NR==2 {print $4 " available"}')"
        
        echo ""
        echo "Network:"
        echo "--------"
        echo "Active connections: $(netstat -tn | grep ESTABLISHED | wc -l)"
        echo "Listening ports: $(netstat -tlnp | grep -E ":(3330|3331|3332|3333|3334|3335|3336|3337|3338|3339|5000)" | wc -l)"
        
        echo ""
        echo "DCOM Devices:"
        echo "------------"
        lsusb | grep -E "(Huawei|E3372|12d1:)" || echo "No DCOM devices found"
        
    } > "$report_file"
    
    log "Health report generated: $report_file"
}

# Main monitoring function
main() {
    log "=== Starting ProxyFarm System Monitor ==="
    
    check_webapp
    check_3proxy
    check_system_resources
    check_dcom_devices
    check_log_sizes
    
    # Auto-restart if AUTO_RESTART is enabled
    if [ "${AUTO_RESTART:-false}" = "true" ]; then
        restart_failed_services
    fi
    
    # Generate health report if requested
    if [ "${GENERATE_REPORT:-false}" = "true" ]; then
        generate_health_report
    fi
    
    log "=== Monitor check completed ==="
    echo ""
    
    # Show summary
    echo -e "${BLUE}📊 Monitor Summary:${NC}"
    if grep -q "ALERT" "$LOG_FILE"; then
        echo -e "${RED}❌ Issues detected - check $ALERT_LOG${NC}"
        return 1
    else
        echo -e "${GREEN}✅ All systems operational${NC}"
        return 0
    fi
}

# Handle command line arguments
case "${1:-}" in
    --auto-restart)
        AUTO_RESTART=true
        main
        ;;
    --report)
        GENERATE_REPORT=true
        main
        ;;
    --continuous)
        echo "Starting continuous monitoring (every 5 minutes)..."
        while true; do
            main
            sleep 300
        done
        ;;
    --help)
        echo "ProxyFarm System Monitor"
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --auto-restart    Automatically restart failed services"
        echo "  --report          Generate detailed health report"
        echo "  --continuous      Run continuously every 5 minutes"
        echo "  --help            Show this help message"
        ;;
    *)
        main
        ;;
esac