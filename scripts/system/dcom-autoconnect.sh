#!/bin/bash
# Auto DCOM connection script

INTERFACE="enx0c5b8f279a64"
GATEWAY="192.168.8.1"

log() {
    echo "[$(date +'%H:%M:%S')] $1"
}

# Function to setup DCOM
setup_dcom() {
    log "🔄 Setting up DCOM connection..."
    
    # Bring interface up
    sudo ip link set $INTERFACE up
    
    # Get IP via DHCP
    log "📡 Getting IP via DHCP..."
    sudo dhclient $INTERFACE
    
    # Check if we got IP
    if ip addr show $INTERFACE | grep -q "inet "; then
        local ip=$(ip addr show $INTERFACE | grep "inet " | awk '{print $2}')
        log "✅ Got IP: $ip"
        
        # Add default route with lower metric (higher priority)
        sudo ip route add default via $GATEWAY dev $INTERFACE metric 50 2>/dev/null || log "Route already exists"
        
        # Set DNS
        setup_dns
        
        # Test connection
        if curl --interface $INTERFACE --connect-timeout 5 -s http://httpbin.org/ip >/dev/null 2>&1; then
            log "✅ DCOM internet connection working!"
            return 0
        else
            log "❌ DCOM internet connection failed"
            return 1
        fi
    else
        log "❌ Failed to get IP from DCOM"
        return 1
    fi
}

# Function to setup DNS
setup_dns() {
    log "🌐 Setting up DNS..."
    
    # Backup original resolv.conf
    sudo cp /etc/resolv.conf /etc/resolv.conf.backup 2>/dev/null
    
    # Set DNS servers
    sudo tee /etc/resolv.conf << EOF
# DCOM DNS configuration
nameserver 192.168.8.1
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF
}

# Function to check DCOM status
check_dcom() {
    if ip addr show $INTERFACE | grep -q "inet " && \
       ping -c 1 -W 2 $GATEWAY >/dev/null 2>&1; then
        echo "connected"
    else
        echo "disconnected"
    fi
}

# Function to auto-restart if disconnected
monitor_dcom() {
    while true; do
        if [ "$(check_dcom)" == "disconnected" ]; then
            log "🔄 DCOM disconnected, reconnecting..."
            setup_dcom
        fi
        sleep 30
    done
}

case "${1:-setup}" in
    setup)
        setup_dcom
        ;;
    check)
        status=$(check_dcom)
        echo "DCOM status: $status"
        [ "$status" == "connected" ] && exit 0 || exit 1
        ;;
    monitor)
        log "📊 Starting DCOM monitor..."
        monitor_dcom
        ;;
    dns)
        setup_dns
        ;;
    *)
        echo "Usage: $0 {setup|check|monitor|dns}"
        echo ""
        echo "  setup   - Setup DCOM connection"
        echo "  check   - Check DCOM status"
        echo "  monitor - Monitor and auto-reconnect"
        echo "  dns     - Setup DNS only"
        ;;
esac
