#!/bin/bash
# 3Proxy Control Script

USERS_FILE="/home/proxy-farm-system/configs/3proxy/users.txt"
LOG_FILE="/home/proxy-farm-system/logs/3proxy/3proxy.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Get status
get_status() {
    if systemctl is-active 3proxy >/dev/null; then
        echo "running"
    else
        echo "stopped"
    fi
}

# Show detailed status
show_status() {
    echo "╔════════════════════════════════════════════╗"
    echo "║           3PROXY STATUS REPORT             ║"
    echo "╚════════════════════════════════════════════╝"
    
    local status=$(get_status)
    echo "📊 Status: $status"
    
    if [ "$status" == "running" ]; then
        echo "🔢 PID: $(systemctl show 3proxy -p MainPID --value)"
        echo "📁 Config: /etc/3proxy/3proxy.cfg"
        echo "📝 Log: $LOG_FILE"
        echo "👥 Users: $(count_users) users configured"
        echo ""
        show_listening_ports
        echo ""
        show_active_connections
    else
        echo "❌ 3proxy is not running"
    fi
}

# Show listening ports
show_listening_ports() {
    echo "🔗 Listening Ports:"
    netstat -tlnp 2>/dev/null | grep 3proxy | while read line; do
        local port=$(echo "$line" | awk '{print $4}' | cut -d: -f2)
        local type="Unknown"
        
        case $port in
            8080|8081|8082|3128) type="HTTP Proxy" ;;
            1080|1081|1082|1090) type="SOCKS5 Proxy" ;;
        esac
        
        echo "   Port $port: $type"
    done
}

# Show active connections
show_active_connections() {
    echo "🌐 Active Connections:"
    local count=$(netstat -tn 2>/dev/null | grep -E ":(8080|8081|8082|1080|1081|1082|3128|1090)" | grep ESTABLISHED | wc -l)
    echo "   $count active connections"
}

# Count users
count_users() {
    if [ -f "$USERS_FILE" ]; then
        grep -v "^#" "$USERS_FILE" | grep -v "^$" | wc -l
    else
        echo "0"
    fi
}

# Start service
start_service() {
    log "Starting 3proxy service..."
    sudo systemctl start 3proxy
    sleep 2
    
    if [ "$(get_status)" == "running" ]; then
        log "✅ 3proxy started successfully"
        show_listening_ports
    else
        error "❌ Failed to start 3proxy"
        sudo journalctl -u 3proxy --no-pager -l | tail -10
    fi
}

# Stop service
stop_service() {
    log "Stopping 3proxy service..."
    sudo systemctl stop 3proxy
    log "✅ 3proxy stopped"
}

# Restart service
restart_service() {
    log "Restarting 3proxy service..."
    sudo systemctl restart 3proxy
    sleep 2
    show_status
}

# Add user
add_user() {
    local username="$1"
    local password="$2"
    local bandwidth="${3:-}"
    
    if [ -z "$username" ] || [ -z "$password" ]; then
        error "Usage: add_user <username> <password> [bandwidth_limit]"
        return 1
    fi
    
    # Check if user exists
    if grep -q "^$username:" "$USERS_FILE" 2>/dev/null; then
        error "User '$username' already exists!"
        return 1
    fi
    
    # Add user to file
    local user_line="$username:$password:::"
    if [ -n "$bandwidth" ]; then
        user_line="$username:$password::*:$bandwidth"
    fi
    
    echo "$user_line" >> "$USERS_FILE"
    log "✅ User '$username' added successfully"
    
    # Reload if running
    if [ "$(get_status)" == "running" ]; then
        sudo systemctl reload 3proxy
        log "🔄 Configuration reloaded"
    fi
}

# Remove user
remove_user() {
    local username="$1"
    
    if [ -z "$username" ]; then
        error "Usage: remove_user <username>"
        return 1
    fi
    
    if grep -q "^$username:" "$USERS_FILE" 2>/dev/null; then
        sed -i "/^$username:/d" "$USERS_FILE"
        log "✅ User '$username' removed successfully"
        
        # Reload if running
        if [ "$(get_status)" == "running" ]; then
            sudo systemctl reload 3proxy
            log "🔄 Configuration reloaded"
        fi
    else
        error "User '$username' not found!"
        return 1
    fi
}

# List users
list_users() {
    echo "👥 Configured Users:"
    echo "┌─────────────────────┬─────────────────────┬─────────────────────┐"
    echo "│ Username            │ Password            │ Bandwidth Limit     │"
    echo "├─────────────────────┼─────────────────────┼─────────────────────┤"
    
    if [ -f "$USERS_FILE" ]; then
        while IFS=':' read -r username password ip_allow ip_deny bandwidth; do
            # Skip comments and empty lines
            [[ "$username" =~ ^#.*$ ]] || [[ -z "$username" ]] && continue
            
            local bw_display="${bandwidth:-'No limit'}"
            printf "│ %-19s │ %-19s │ %-19s │\n" "$username" "$password" "$bw_display"
        done < "$USERS_FILE"
    fi
    
    echo "└─────────────────────┴─────────────────────┴─────────────────────┘"
    echo "Total users: $(count_users)"
}

# Test proxy
test_proxy() {
    local port="${1:-8080}"
    local user="${2:-admin}"
    local pass="${3:-admin123}"
    
    echo "🧪 Testing proxy on port $port with user $user..."
    
    # Test with authentication
    if curl -x "$user:$pass@localhost:$port" --connect-timeout 5 -s http://httpbin.org/ip; then
        log "✅ Proxy test successful on port $port"
    else
        error "❌ Proxy test failed on port $port"
    fi
}

# Update DCOM interface
update_interface() {
    local interface="$1"
    
    if [ -z "$interface" ]; then
        # Auto-detect DCOM interface
        interface=$(ip route | grep 192.168.8 | head -1 | awk '{print $3}')
    fi
    
    if [ -n "$interface" ]; then
        log "Updating 3proxy interface to: $interface"
        sudo sed -i "s/^external .*/external $interface/" /etc/3proxy/3proxy.cfg
        
        if [ "$(get_status)" == "running" ]; then
            sudo systemctl reload 3proxy
            log "✅ Interface updated and service reloaded"
        else
            log "✅ Interface updated (service not running)"
        fi
    else
        error "Interface not found or not specified"
        return 1
    fi
}

case "${1:-help}" in
    start) start_service ;;
    stop) stop_service ;;
    restart) restart_service ;;
    status) show_status ;;
    add-user) add_user "$2" "$3" "$4" ;;
    remove-user) remove_user "$2" ;;
    list-users) list_users ;;
    test) test_proxy "$2" "$3" "$4" ;;
    update-interface) update_interface "$2" ;;
    help|*)
        echo "🔧 3Proxy Control Script"
        echo ""
        echo "Usage: $0 <command> [options]"
        echo ""
        echo "Service Commands:"
        echo "  start              - Start 3proxy service"
        echo "  stop               - Stop 3proxy service"
        echo "  restart            - Restart 3proxy service"
        echo "  status             - Show detailed status"
        echo ""
        echo "User Management:"
        echo "  add-user <user> <pass> [bw]    - Add new user"
        echo "  remove-user <user>             - Remove user"
        echo "  list-users                     - List all users"
        echo ""
        echo "Testing & Config:"
        echo "  test [port] [user] [pass]      - Test proxy connection"
        echo "  update-interface [interface]   - Update DCOM interface"
        echo ""
        echo "Examples:"
        echo "  $0 start                       - Start proxy service"
        echo "  $0 add-user john pass123       - Add user without bandwidth limit"
        echo "  $0 add-user jane pass456 100000   - Add user with 100KB/s limit"
        echo "  $0 test 8080 admin admin123    - Test HTTP proxy"
        echo "  $0 update-interface             - Auto-detect and update interface"
        ;;
esac
