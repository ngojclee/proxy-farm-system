#!/bin/bash
MODEM_IP="192.168.8.1"

get_token() {
    curl -s "http://$MODEM_IP/api/webserver/token" | grep -oP '(?<=<token>)[^<]*'
}

api_post() {
    local endpoint="$1"
    local data="$2"
    local token=$(get_token)
    
    curl -s -X POST \
         -H "Content-Type: application/x-www-form-urlencoded" \
         -H "__RequestVerificationToken: $token" \
         -d "$data" \
         "http://$MODEM_IP/$endpoint"
}

api_get() {
    local endpoint="$1"
    local token=$(get_token)
    curl -s -H "__RequestVerificationToken: $token" "http://$MODEM_IP/$endpoint"
}

disconnect_4g() {
    echo "🔌 Disconnecting 4G..."
    result=$(api_post "api/dialup/mobile-dataswitch" '<?xml version="1.0" encoding="UTF-8"?><request><dataswitch>0</dataswitch></request>')
    echo "Result: $result"
}

connect_4g() {
    echo "🔌 Connecting 4G..."
    result=$(api_post "api/dialup/mobile-dataswitch" '<?xml version="1.0" encoding="UTF-8"?><request><dataswitch>1</dataswitch></request>')
    echo "Result: $result"
}

restart_connection() {
    echo "🔄 Restarting 4G connection..."
    disconnect_4g
    sleep 5
    connect_4g
    
    echo "⏳ Waiting for reconnection..."
    sleep 10
    
    # Check status
    status=$(api_get "api/monitoring/status" | grep -oP '(?<=<ConnectionStatus>)[^<]*')
    case "$status" in
        "901") echo "✅ Connected successfully" ;;
        "902") echo "❌ Disconnected" ;;
        "905") echo "⏳ Still connecting..." ;;
        *) echo "❓ Unknown status: $status" ;;
    esac
}

get_connection_status() {
    echo "📊 Current connection status:"
    status_info=$(api_get "api/monitoring/status")
    
    conn_status=$(echo "$status_info" | grep -oP '(?<=<ConnectionStatus>)[^<]*')
    network_type=$(echo "$status_info" | grep -oP '(?<=<CurrentNetworkType>)[^<]*')
    
    case "$conn_status" in
        "901") echo "Status: ✅ Connected" ;;
        "902") echo "Status: ❌ Disconnected" ;;
        "905") echo "Status: ⏳ Connecting" ;;
        "903") echo "Status: 🔄 Disconnecting" ;;
        *) echo "Status: ❓ Unknown ($conn_status)" ;;
    esac
    
    echo "Network: LTE (Type: $network_type)"
}

# Check if we can control data switch
test_data_switch() {
    echo "🧪 Testing data switch control..."
    
    # Try to get current data switch status
    current_status=$(api_get "api/dialup/mobile-dataswitch")
    echo "Current dataswitch status:"
    echo "$current_status"
    
    # Try to get connection settings
    echo -e "\n📋 Connection settings:"
    api_get "api/dialup/connection" | head -10
}

case "${1:-status}" in
    status|stat) get_connection_status ;;
    disconnect|off) disconnect_4g ;;
    connect|on) connect_4g ;;
    restart|reboot) restart_connection ;;
    test) test_data_switch ;;
    *) 
        echo "Usage: $0 {status|disconnect|connect|restart|test}"
        echo ""
        echo "Commands:"
        echo "  status     - Show current connection status"
        echo "  disconnect - Disconnect 4G data"
        echo "  connect    - Connect 4G data" 
        echo "  restart    - Restart connection (disconnect + connect)"
        echo "  test       - Test data switch control capabilities"
        ;;
esac
