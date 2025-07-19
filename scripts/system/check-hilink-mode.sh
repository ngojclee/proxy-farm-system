#!/bin/bash
# Check HiLink Mode E3372 Functionality

echo "=== E3372 HiLink Mode Analysis ==="
echo "Device detected: 12d1:14dc (HiLink mode)"
echo ""

# Check network interfaces
echo "🌐 Step 1: Network Interface Detection"
echo "======================================"

USB_NET_INTERFACES=$(ip link show | grep -E "(enx|usb)" | wc -l)
echo "USB network interfaces: $USB_NET_INTERFACES"

if [ "$USB_NET_INTERFACES" -gt 0 ]; then
    echo "✅ USB network interfaces found:"
    ip link show | grep -E "(enx|usb)" | while read line; do
        interface=$(echo "$line" | cut -d: -f2 | xargs)
        echo "  Interface: $interface"
        
        # Check IP configuration
        ip_info=$(ip addr show "$interface" | grep "inet " | awk '{print $2}')
        if [ -n "$ip_info" ]; then
            echo "    IP: $ip_info"
        else
            echo "    IP: Not configured"
        fi
    done
else
    echo "❌ No USB network interfaces found"
    echo "💡 Device may need time to initialize or driver issues"
fi

echo ""

# Check HiLink web interface
echo "🌐 Step 2: HiLink Web Interface Test"
echo "==================================="

# Common HiLink IP addresses
hilink_ips=("192.168.8.1" "192.168.1.1" "192.168.0.1")

hilink_accessible=false
for ip in "${hilink_ips[@]}"; do
    echo "Testing HiLink IP: $ip"
    
    if ping -c 1 -W 2 "$ip" >/dev/null 2>&1; then
        echo "✅ HiLink device responding at $ip"
        hilink_accessible=true
        HILINK_IP="$ip"
        
        # Test web interface
        echo "Testing web interface..."
        
        # Basic connectivity
        if curl -s --connect-timeout 5 "http://$ip" >/dev/null; then
            echo "✅ Web interface accessible"
            
            # Try to get device info
            device_info=$(curl -s --connect-timeout 5 "http://$ip/api/device/information" 2>/dev/null)
            if [ -n "$device_info" ]; then
                echo "✅ API responding"
                echo "Device info preview: $(echo "$device_info" | head -c 100)..."
            else
                echo "⚠️  API may use different endpoints"
            fi
        else
            echo "⚠️  Web interface not responding"
        fi
        break
    else
        echo "❌ No response from $ip"
    fi
done

if [ "$hilink_accessible" = false ]; then
    echo "❌ HiLink web interface not accessible"
    echo "💡 Device may need network configuration"
fi

echo ""

# Check connection status
echo "📡 Step 3: Connection Status Check"
echo "=================================="

if [ "$hilink_accessible" = true ]; then
    echo "Checking connection status via API..."
    
    # Try common API endpoints
    api_endpoints=(
        "/api/monitoring/status"
        "/api/dialup/connection"
        "/api/device/signal"
        "/api/net/current-plmn"
    )
    
    for endpoint in "${api_endpoints[@]}"; do
        echo "Testing endpoint: $endpoint"
        response=$(curl -s --connect-timeout 3 "http://$HILINK_IP$endpoint" 2>/dev/null)
        if [ -n "$response" ] && [ "$response" != "error" ]; then
            echo "✅ $endpoint: $(echo "$response" | head -c 50)..."
        else
            echo "❌ $endpoint: No valid response"
        fi
    done
else
    echo "❌ Cannot check connection status - HiLink not accessible"
fi

echo ""

# Test internet connectivity through device
echo "🌐 Step 4: Internet Connectivity Test"
echo "====================================="

if [ "$USB_NET_INTERFACES" -gt 0 ]; then
    # Try to get default route through USB interface
    usb_interface=$(ip link show | grep -E "(enx|usb)" | head -1 | cut -d: -f2 | xargs)
    
    if [ -n "$usb_interface" ]; then
        echo "Testing internet via USB interface: $usb_interface"
        
        # Check if interface has IP
        usb_ip=$(ip addr show "$usb_interface" | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
        
        if [ -n "$usb_ip" ]; then
            echo "USB interface IP: $usb_ip"
            
            # Test connectivity
            if ping -c 3 -I "$usb_interface" 8.8.8.8 >/dev/null 2>&1; then
                echo "✅ Internet connectivity via USB interface: SUCCESS"
                
                # Get external IP
                external_ip=$(curl -s --interface "$usb_interface" --connect-timeout 10 http://httpbin.org/ip 2>/dev/null | grep -o '"origin":"[^"]*' | cut -d'"' -f4)
                if [ -n "$external_ip" ]; then
                    echo "✅ External IP: $external_ip"
                fi
            else
                echo "❌ No internet connectivity via USB interface"
            fi
        else
            echo "❌ USB interface has no IP address"
            echo "💡 May need DHCP or manual configuration"
        fi
    fi
else
    echo "❌ No USB interface available for testing"
fi

echo ""

# Summary and recommendations
echo "📋 SUMMARY & RECOMMENDATIONS"
echo "============================"

if [ "$hilink_accessible" = true ] && [ "$USB_NET_INTERFACES" -gt 0 ]; then
    echo "🎉 HiLink mode E3372 is working!"
    echo ""
    echo "✅ Device status: Functional HiLink mode"
    echo "✅ Web interface: Accessible at $HILINK_IP"
    echo "✅ Network interface: Available"
    echo ""
    echo "🔧 For 3proxy integration:"
    echo "   1. Use HTTP API for control (not AT commands)"
    echo "   2. Configure 3proxy to use USB network interface"
    echo "   3. IP rotation via HiLink web API"
    echo ""
    echo "📝 Next steps:"
    echo "   1. Configure 3proxy with USB interface: -e$usb_interface"
    echo "   2. Create HiLink API scripts for IP rotation"
    echo "   3. Test proxy functionality"
    
elif [ "$USB_NET_INTERFACES" -eq 0 ] && [ "$hilink_accessible" = false ]; then
    echo "❌ HiLink mode not working properly"
    echo ""
    echo "🔧 Troubleshooting options:"
    echo "   1. Try mode switch to Stick mode:"
    echo "      usb_modeswitch -v 12d1 -p 14dc -M '55534243123456780000000000000011062000000100000000000000000000'"
    echo "   2. Install missing drivers:"
    echo "      apt install usb-modeswitch usb-modeswitch-data"
    echo "   3. Check USB power management"
    echo "   4. Try different USB port"
    echo "   5. Consider getting E3372S (Stick mode) device"

else
    echo "⚠️  Partial HiLink functionality"
    echo "💡 May need additional configuration or drivers"
fi

echo ""
echo "Test completed: $(date)"