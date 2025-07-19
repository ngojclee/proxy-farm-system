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

echo "🔍 CHECKING WAN IP INFORMATION:"

# Method 1: Check monitoring status for WAN IP
echo "--- From monitoring status ---"
api_call "api/monitoring/status" | grep -oP '(?<=<WanIPAddress>)[^<]*|(?<=<PrimaryDns>)[^<]*|(?<=<SecondaryDns>)[^<]*'

# Method 2: Check connection info 
echo -e "\n--- From connection info ---"
api_call "api/dialup/connection" | xmlstarlet fo 2>/dev/null || api_call "api/dialup/connection"

# Method 3: Check network settings
echo -e "\n--- From network settings ---"
api_call "api/dhcp/settings" | xmlstarlet fo 2>/dev/null

# Method 4: Check device autorun version (sometimes contains WAN info)
echo -e "\n--- Trying other endpoints ---"
for endpoint in "api/net/current-plmn" "api/device/autorun-version" "api/cradle/status-info"; do
    echo "Testing $endpoint:"
    api_call "$endpoint" | head -5
    echo ""
done

# Method 5: Get external IP via internet services (through the 4G connection)
echo -e "\n--- External IP check via 4G ---"
echo "Public IP (via ipify): $(curl -s --interface enx0c5b8f279a64 ifconfig.me 2>/dev/null || echo 'Failed')"
echo "Public IP (via httpbin): $(curl -s --interface enx0c5b8f279a64 httpbin.org/ip | grep -oP '(?<="origin": ")[^"]*' 2>/dev/null || echo 'Failed')"
