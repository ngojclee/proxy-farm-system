#!/bin/bash
MODEM_IP="192.168.8.1"

get_token() {
    curl -s "http://$MODEM_IP/api/webserver/token" | grep -oP '(?<=<token>)[^<]*'
}

api_call() {
    local endpoint="$1"
    local token=$(get_token)
    curl -s -H "__RequestVerificationToken: $token" "http://$MODEM_IP/$endpoint"
}

dashboard() {
    clear
    echo "╔════════════════════════════════════════════╗"
    echo "║           HILINK 4G DASHBOARD              ║"
    echo "╚════════════════════════════════════════════╝"
    
    # Basic info
    echo "📱 Device Information:"
    api_call "api/device/basic_information" | grep -oP '(?<=<DeviceName>)[^<]*|(?<=<HardwareVersion>)[^<]*|(?<=<SoftwareVersion>)[^<]*'
    
    # Status
    echo -e "\n🌐 Connection Status:"
    api_call "api/monitoring/status" | grep -oP '(?<=<ConnectionStatus>)[^<]*|(?<=<CurrentNetworkType>)[^<]*'
    
    # Login state  
    echo -e "\n🔐 Login State:"
    api_call "api/user/state-login" | grep -oP '(?<=<State>)[^<]*'
    
    echo -e "\n📊 DHCP Settings:"
    api_call "api/dhcp/settings" | grep -oP '(?<=<DhcpIPAddress>)[^<]*'
}

case "${1:-dashboard}" in
    dashboard) dashboard ;;
    token) get_token ;;
    info) api_call "api/device/basic_information" ;;
    status) api_call "api/monitoring/status" ;;
    *) echo "Usage: $0 {dashboard|token|info|status}" ;;
esac