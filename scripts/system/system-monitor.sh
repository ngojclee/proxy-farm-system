#!/bin/bash
# Comprehensive System Monitoring for Proxy Farm

LOG_FILE="/home/proxy-farm-system/logs/system-monitor.log"
ALERT_THRESHOLD_CPU=80
ALERT_THRESHOLD_MEM=90
ALERT_THRESHOLD_DISK=85

# Ensure log directory exists
mkdir -p /home/proxy-farm-system/logs

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "$LOG_FILE"
}

check_usb_devices() {
    echo "=== USB Device Status ==="
    
    # Count USB DCOM devices
    usb_count=$(lsusb | grep -E "(12d1|19d2|05c6)" | wc -l)
    tty_count=$(ls /dev/ttyUSB* 2>/dev/null | wc -l)
    stable_links=$(ls /dev/dcom* 2>/dev/null | wc -l)
    
    log_message "USB DCOM devices detected: $usb_count"
    log_message "TTY serial devices: $tty_count"
    log_message "Stable device links: $stable_links"
    
    # Alert if device count is low
    if [ "$usb_count" -lt 5 ]; then
        log_message "⚠️  WARNING: Low USB DCOM device count ($usb_count)"
    fi
    
    if [ "$tty_count" -lt 5 ]; then
        log_message "⚠️  WARNING: Low TTY device count ($tty_count)"
    fi
    
    # Check for disconnected devices
    dmesg | tail -20 | grep -i "usb.*disconnect" | tail -5 | while read line; do
        log_message "USB Disconnect: $line"
    done
}

check_system_resources() {
    echo "=== System Resources ==="
    
    # CPU usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 | cut -d',' -f1)
    cpu_usage=${cpu_usage%us}  # Remove 'us' suffix
    log_message "CPU usage: ${cpu_usage}%"
    
    if [ "${cpu_usage%.*}" -gt "$ALERT_THRESHOLD_CPU" ]; then
        log_message "🚨 ALERT: High CPU usage (${cpu_usage}%)"
    fi
    
    # Memory usage
    mem_info=$(free | grep Mem)
    mem_total=$(echo $mem_info | awk '{print $2}')
    mem_used=$(echo $mem_info | awk '{print $3}')
    mem_percent=$((mem_used * 100 / mem_total))
    log_message "Memory usage: ${mem_percent}% (${mem_used}/${mem_total})"
    
    if [ "$mem_percent" -gt "$ALERT_THRESHOLD_MEM" ]; then
        log_message "🚨 ALERT: High memory usage (${mem_percent}%)"
    fi
    
    # Disk usage
    disk_usage=$(df / | awk 'NR==2{print $5}' | cut -d'%' -f1)
    log_message "Disk usage: ${disk_usage}%"
    
    if [ "$disk_usage" -gt "$ALERT_THRESHOLD_DISK" ]; then
        log_message "🚨 ALERT: High disk usage (${disk_usage}%)"
    fi
    
    # Load average
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | xargs)
    log_message "Load average: $load_avg"
    
    # Process count
    process_count=$(ps aux | wc -l)
    log_message "Active processes: $process_count"
}

check_network_performance() {
    echo "=== Network Performance ==="
    
    # Check internet connectivity to multiple targets
    connectivity_ok=0
    test_hosts=("8.8.8.8" "1.1.1.1" "208.67.222.222")
    
    for host in "${test_hosts[@]}"; do
        if ping -c 1 -W 3 "$host" >/dev/null 2>&1; then
            connectivity_ok=1
            ping_time=$(ping -c 1 "$host" | grep "time=" | cut -d'=' -f4)
            log_message "Connectivity to $host: OK ($ping_time)"
            break
        fi
    done
    
    if [ "$connectivity_ok" -eq 0 ]; then
        log_message "🚨 ALERT: No internet connectivity"
    fi
    
    # Network interface status
    interface_count=0
    while IFS= read -r interface; do
        interface=$(echo "$interface" | cut -d: -f2 | xargs)
        if [ "$interface" != "lo" ]; then
            status=$(ip link show "$interface" | grep -o "state [A-Z]*" | cut -d' ' -f2)
            log_message "Interface $interface: $status"
            
            if [ "$status" = "UP" ]; then
                interface_count=$((interface_count + 1))
            fi
        fi
    done < <(ip link show | grep -E "^[0-9]" | head -10)
    
    log_message "Active network interfaces: $interface_count"
    
    # Check for USB network interfaces (HiLink devices)
    usb_interfaces=$(ip link show | grep -c "enx" || echo "0")
    log_message "USB network interfaces (HiLink): $usb_interfaces"
}

check_services() {
    echo "=== Service Status ==="
    
    services=("3proxy" "ssh" "fail2ban" "ufw")
    failed_services=0
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            log_message "Service $service: ✅ RUNNING"
        else
            log_message "Service $service: ❌ NOT RUNNING"
            failed_services=$((failed_services + 1))
        fi
    done
    
    if [ "$failed_services" -gt 0 ]; then
        log_message "🚨 ALERT: $failed_services service(s) not running"
    fi
    
    # Check 3proxy specifically
    if systemctl is-active --quiet 3proxy; then
        proxy_connections=$(netstat -tlpn | grep -c ":312[8-9]" || echo "0")
        log_message "3proxy listening ports: $proxy_connections"
    fi
}

check_security_status() {
    echo "=== Security Status ==="
    
    # Check fail2ban status
    if command -v fail2ban-client >/dev/null 2>&1; then
        banned_ips=$(fail2ban-client status | grep "Jail list" | cut -d: -f2 | xargs | wc -w)
        log_message "Fail2ban active jails: $banned_ips"
        
        # Check for recent bans
        recent_bans=$(fail2ban-client status sshd 2>/dev/null | grep "Currently banned" | cut -d: -f2 | xargs | wc -w || echo "0")
        if [ "$recent_bans" -gt 0 ]; then
            log_message "⚠️  Recent SSH bans: $recent_bans IPs"
        fi
    fi
    
    # Check UFW status
    if command -v ufw >/dev/null 2>&1; then
        ufw_status=$(ufw status | head -1 | awk '{print $2}')
        log_message "UFW firewall: $ufw_status"
    fi
    
    # Check for suspicious authentication attempts
    auth_failures=$(grep "authentication failure" /var/log/auth.log 2>/dev/null | tail -10 | wc -l || echo "0")
    if [ "$auth_failures" -gt 5 ]; then
        log_message "⚠️  Recent authentication failures: $auth_failures"
    fi
}

generate_summary_report() {
    echo ""
    echo "📋 SYSTEM HEALTH SUMMARY"
    echo "========================"
    echo "Timestamp: $(date)"
    echo "Uptime: $(uptime | awk -F'up ' '{print $2}' | awk -F', load' '{print $1}')"
    echo ""
    
    # Count alerts in recent log entries
    recent_alerts=$(tail -50 "$LOG_FILE" | grep -c "ALERT\|WARNING" || echo "0")
    if [ "$recent_alerts" -gt 0 ]; then
        echo "🚨 Active alerts: $recent_alerts"
        echo "📝 Check log: $LOG_FILE"
    else
        echo "✅ No active alerts"
    fi
}

# Main execution
case "$1" in
    "usb")
        check_usb_devices
        ;;
    "system")
        check_system_resources
        ;;
    "network")
        check_network_performance
        ;;
    "services")
        check_services
        ;;
    "security")
        check_security_status
        ;;
    "summary")
        generate_summary_report
        ;;
    "all"|"")
        check_usb_devices
        check_system_resources
        check_network_performance
        check_services
        check_security_status
        generate_summary_report
        ;;
    *)
        echo "Usage: $0 {usb|system|network|services|security|summary|all}"
        echo ""
        echo "Options:"
        echo "  usb      - Check USB DCOM devices"
        echo "  system   - Check system resources (CPU, memory, disk)"
        echo "  network  - Check network connectivity and interfaces"
        echo "  services - Check critical service status"
        echo "  security - Check security status and alerts"
        echo "  summary  - Generate summary report"
        echo "  all      - Run all checks (default)"
        exit 1
        ;;
esac
