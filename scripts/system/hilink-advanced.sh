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

parse_xml_field() {
    local xml="$1"
    local field="$2"
    echo "$xml" | grep -oP "(?<=<$field>)[^<]*" || echo "N/A"
}

get_network_type_name() {
    case "$1" in
        "0") echo "No Service" ;;
        "1") echo "GSM" ;;
        "2") echo "GPRS" ;;
        "3") echo "EDGE" ;;
        "4") echo "WCDMA" ;;
        "5") echo "HSDPA" ;;
        "6") echo "HSUPA" ;;
        "7") echo "HSPA" ;;
        "8") echo "TD-SCDMA" ;;
        "9") echo "HSPA+" ;;
        "10") echo "EVDO Rev.0" ;;
        "11") echo "EVDO Rev.A" ;;
        "12") echo "EVDO Rev.B" ;;
        "13") echo "1xRTT" ;;
        "14") echo "UMB" ;;
        "15") echo "1xEVDV" ;;
        "16") echo "3xRTT" ;;
        "17") echo "HSPA+ 64QAM" ;;
        "18") echo "HSPA+ MIMO" ;;
        "19") echo "LTE" ;;
        "101") echo "LTE" ;;
        *) echo "Unknown ($1)" ;;
    esac
}

get_connection_status() {
    case "$1" in
        "901") echo "Connected" ;;
        "902") echo "Disconnected" ;;
        "903") echo "Disconnecting" ;;
        "905") echo "Connecting" ;;
        *) echo "Unknown ($1)" ;;
    esac
}

bytes_to_human() {
    local bytes=$1
    if [ -z "$bytes" ] || [ "$bytes" = "N/A" ]; then
        echo "N/A"
        return
    fi
    
    if [ $bytes -lt 1024 ]; then
        echo "${bytes}B"
    elif [ $bytes -lt 1048576 ]; then
        echo "$((bytes/1024))KB"
    elif [ $bytes -lt 1073741824 ]; then
        echo "$((bytes/1048576))MB"
    else
        echo "$((bytes/1073741824))GB"
    fi
}

full_dashboard() {
    clear
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                    HILINK 4G DASHBOARD                    ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    
    # Device Basic Information
    echo "📱 DEVICE INFORMATION:"
    basic_info=$(api_call "api/device/basic_information")
    device_name=$(parse_xml_field "$basic_info" "DeviceName")
    hardware_ver=$(parse_xml_field "$basic_info" "HardwareVersion")
    software_ver=$(parse_xml_field "$basic_info" "SoftwareVersion")
    imei=$(parse_xml_field "$basic_info" "Imei")
    
    echo "   Device: $device_name"
    echo "   Hardware: $hardware_ver"
    echo "   Software: $software_ver"
    echo "   IMEI: $imei"
    
    # Connection Status
    echo -e "\n🌐 CONNECTION STATUS:"
    status_info=$(api_call "api/monitoring/status")
    conn_status=$(parse_xml_field "$status_info" "ConnectionStatus")
    network_type=$(parse_xml_field "$status_info" "CurrentNetworkType")
    signal_strength=$(parse_xml_field "$status_info" "SignalStrength")
    
    echo "   Status: $(get_connection_status $conn_status)"
    echo "   Network: $(get_network_type_name $network_type)"
    echo "   Signal: $signal_strength%"
    
    # Traffic Statistics
    echo -e "\n📊 DATA USAGE:"
    traffic_info=$(api_call "api/monitoring/traffic-statistics")
    current_download=$(parse_xml_field "$traffic_info" "CurrentDownload")
    current_upload=$(parse_xml_field "$traffic_info" "CurrentUpload")
    total_download=$(parse_xml_field "$traffic_info" "TotalDownload")
    total_upload=$(parse_xml_field "$traffic_info" "TotalUpload")
    
    echo "   Current: ↓$(bytes_to_human $current_download) ↑$(bytes_to_human $current_upload)"
    echo "   Total: ↓$(bytes_to_human $total_download) ↑$(bytes_to_human $total_upload)"
    
    # Signal Information (if available)
    echo -e "\n📡 SIGNAL DETAILS:"
    signal_info=$(api_call "api/device/signal")
    rssi=$(parse_xml_field "$signal_info" "rssi")
    rsrp=$(parse_xml_field "$signal_info" "rsrp")
    rsrq=$(parse_xml_field "$signal_info" "rsrq")
    sinr=$(parse_xml_field "$signal_info" "sinr")
    
    if [ "$rssi" != "N/A" ]; then
        echo "   RSSI: ${rssi}dBm"
        echo "   RSRP: ${rsrp}dBm" 
        echo "   RSRQ: ${rsrq}dB"
        echo "   SINR: ${sinr}dB"
    else
        echo "   Signal details not available"
    fi
    
    # Network Information
    echo -e "\n🔗 NETWORK INFO:"
    dhcp_info=$(api_call "api/dhcp/settings")
    gateway_ip=$(parse_xml_field "$dhcp_info" "DhcpIPAddress")
    
    echo "   Gateway: $gateway_ip"
    echo "   Interface: enx0c5b8f279a64"
    echo "   Local IP: $(ip addr show enx0c5b8f279a64 | grep -oP 'inet \K[^/]*' || echo 'N/A')"
    
    echo -e "\n⏰ Last updated: $(date)"
}

monitor_mode() {
    echo "🔄 Starting continuous monitoring (Ctrl+C to stop)..."
    while true; do
        full_dashboard
        echo -e "\n⏳ Refreshing in 10 seconds..."
        sleep 10
    done
}

# Test individual APIs
test_apis() {
    echo "🧪 TESTING ALL APIs:"
    
    apis=(
        "api/webserver/token:Token"
        "api/device/basic_information:Basic Info"
        "api/monitoring/status:Status"
        "api/monitoring/traffic-statistics:Traffic"
        "api/device/signal:Signal"
        "api/dhcp/settings:DHCP"
        "api/user/state-login:Login State"
    )
    
    for api_info in "${apis[@]}"; do
        api_endpoint="${api_info%:*}"
        api_name="${api_info#*:}"
        
        echo "--- $api_name ($api_endpoint) ---"
        result=$(api_call "$api_endpoint")
        
        if echo "$result" | grep -q "error"; then
            error_code=$(echo "$result" | grep -oP '(?<=<code>)[^<]*')
            echo "❌ Error: $error_code"
        else
            echo "✅ Success"
            echo "$result" | head -3
        fi
        echo ""
    done
}

case "${1:-dashboard}" in
    dashboard|dash) full_dashboard ;;
    monitor|mon) monitor_mode ;;
    test) test_apis ;;
    token) get_token ;;
    info) api_call "api/device/basic_information" | xmlstarlet fo 2>/dev/null ;;
    status) api_call "api/monitoring/status" | xmlstarlet fo 2>/dev/null ;;
    signal) api_call "api/device/signal" | xmlstarlet fo 2>/dev/null ;;
    traffic) api_call "api/monitoring/traffic-statistics" | xmlstarlet fo 2>/dev/null ;;
    *) echo "Usage: $0 {dashboard|monitor|test|token|info|status|signal|traffic}" ;;
esac
