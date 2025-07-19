#!/bin/bash
# 3proxy Management Utilities

SCRIPT_DIR="/home/proxy-farm-system"
USERS_FILE="$SCRIPT_DIR/configs/3proxy/users.txt"

show_status() {
    echo "=== 3proxy Status ==="
    
    if systemctl is-active --quiet 3proxy; then
        echo "✅ Service: Running"
        
        # Show listening ports
        echo ""
        echo "📊 Listening ports:"
        netstat -tlpn | grep 3proxy | while read line; do
            port=$(echo "$line" | awk '{print $4}' | cut -d: -f2)
            echo "   Port $port"
        done
        
        # Show recent connections
        echo ""
        echo "🔗 Recent connections (last 10):"
        tail -10 /var/log/3proxy/3proxy.log 2>/dev/null | tail -5 || echo "   No logs available"
        
    else
        echo "❌ Service: Not running"
        echo "💡 Start with: systemctl start 3proxy"
    fi
}

show_users() {
    echo "=== 3proxy Users ==="
    
    if [ -f "$USERS_FILE" ]; then
        echo "📋 Configured users:"
        echo ""
        printf "%-15s %-15s %-8s %-15s\n" "Username" "Password" "Port" "Interface"
        printf "%-15s %-15s %-8s %-15s\n" "--------" "--------" "----" "---------"
        
        grep -v '^#' "$USERS_FILE" | grep -v '^$' | while IFS=':' read -r username password port interface; do
            printf "%-15s %-15s %-8s %-15s\n" "$username" "$password" "$port" "$interface"
        done
    else
        echo "❌ Users file not found: $USERS_FILE"
        echo "💡 Generate config first: generate-config.sh"
    fi
}

add_user() {
    local username="$1"
    local password="$2"
    local port="$3"
    local interface="$4"
    
    if [ -z "$username" ] || [ -z "$password" ] || [ -z "$port" ]; then
        echo "Usage: $0 add-user <username> <password> <port> [interface]"
        return 1
    fi
    
    # Default interface
    if [ -z "$interface" ]; then
        interface="auto"
    fi
    
    # Create users file if not exists
    if [ ! -f "$USERS_FILE" ]; then
        echo "# Proxy Users Configuration" > "$USERS_FILE"
        echo "# Format: username:password:port:interface" >> "$USERS_FILE"
        echo "" >> "$USERS_FILE"
    fi
    
    # Check if user already exists
    if grep -q "^$username:" "$USERS_FILE" 2>/dev/null; then
        echo "❌ User '$username' already exists"
        return 1
    fi
    
    # Check if port already used
    if grep -q ":$port:" "$USERS_FILE" 2>/dev/null; then
        echo "❌ Port $port already in use"
        return 1
    fi
    
    # Add user
    echo "$username:$password:$port:$interface" >> "$USERS_FILE"
    echo "✅ User '$username' added successfully"
    echo "🔧 Remember to regenerate and deploy config:"
    echo "   generate-config.sh && deploy-config.sh"
}

remove_user() {
    local username="$1"
    
    if [ -z "$username" ]; then
        echo "Usage: $0 remove-user <username>"
        return 1
    fi
    
    if [ ! -f "$USERS_FILE" ]; then
        echo "❌ Users file not found"
        return 1
    fi
    
    if grep -q "^$username:" "$USERS_FILE"; then
        # Remove user
        grep -v "^$username:" "$USERS_FILE" > "$USERS_FILE.tmp"
        mv "$USERS_FILE.tmp" "$USERS_FILE"
        echo "✅ User '$username' removed successfully"
        echo "🔧 Remember to regenerate and deploy config:"
        echo "   generate-config.sh && deploy-config.sh"
    else
        echo "❌ User '$username' not found"
    fi
}

test_proxy() {
    local username="$1"
    local password="$2"
    local port="$3"
    
    if [ -z "$username" ] || [ -z "$password" ] || [ -z "$port" ]; then
        echo "Usage: $0 test-proxy <username> <password> <port>"
        return 1
    fi
    
    echo "🧪 Testing proxy: $username@localhost:$port"
    
    if curl -s --connect-timeout 10 --max-time 15 \
       --proxy "$username:$password@127.0.0.1:$port" \
       "http://httpbin.org/ip" > /dev/null; then
        echo "✅ Proxy test successful"
        
        # Get IP
        ip_result=$(curl -s --proxy "$username:$password@127.0.0.1:$port" "http://httpbin.org/ip" | grep -o '"origin":"[^"]*' | cut -d'"' -f4)
        echo "📡 External IP: $ip_result"
    else
        echo "❌ Proxy test failed"
        echo "💡 Check service status and configuration"
    fi
}

# Main command handling
case "$1" in
    "status")
        show_status
        ;;
    "users")
        show_users
        ;;
    "add-user")
        add_user "$2" "$3" "$4" "$5"
        ;;
    "remove-user")
        remove_user "$2"
        ;;
    "test-proxy")
        test_proxy "$2" "$3" "$4"
        ;;
    "restart")
        echo "🔄 Restarting 3proxy..."
        systemctl restart 3proxy
        sleep 2
        show_status
        ;;
    "logs")
        echo "=== Recent 3proxy Logs ==="
        tail -20 /var/log/3proxy/3proxy.log 2>/dev/null || echo "No logs available"
        ;;
    *)
        echo "3proxy Management Utilities"
        echo "=========================="
        echo ""
        echo "Usage: $0 {command} [options]"
        echo ""
        echo "Status Commands:"
        echo "  status           - Show service status and ports"
        echo "  users            - List all configured users"
        echo "  logs             - Show recent logs"
        echo ""
        echo "User Management:"
        echo "  add-user <user> <pass> <port> [interface]  - Add new user"
        echo "  remove-user <user>                         - Remove user"
        echo ""
        echo "Testing:"
        echo "  test-proxy <user> <pass> <port>           - Test proxy"
        echo ""
        echo "Service Control:"
        echo "  restart          - Restart 3proxy service"
        echo ""
        echo "Examples:"
        echo "  $0 status"
        echo "  $0 add-user proxy1 mypass 3128 eth0"
        echo "  $0 test-proxy proxy1 mypass 3128"
        ;;
esac
