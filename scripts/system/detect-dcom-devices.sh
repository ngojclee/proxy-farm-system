#!/bin/bash
# DCOM Device Detection and Status Script

echo "=== DCOM Device Detection ==="
echo "Scan time: $(date)"
echo ""

# Function to get USB device info
get_device_info() {
    local device_path="$1"
    local vendor_id=$(cat "$device_path/../idVendor" 2>/dev/null)
    local product_id=$(cat "$device_path/../idProduct" 2>/dev/null)
    local serial=$(cat "$device_path/../serial" 2>/dev/null)
    local manufacturer=$(cat "$device_path/../manufacturer" 2>/dev/null)
    local product=$(cat "$device_path/../product" 2>/dev/null)
    
    echo "    Vendor:Product = $vendor_id:$product_id"
    echo "    Manufacturer = $manufacturer"
    echo "    Product = $product"
    echo "    Serial = $serial"
}

# Scan for connected DCOM devices
echo "🔍 Scanning for USB DCOM devices..."
device_count=0

for device in /sys/bus/usb-serial/devices/*; do
    if [ -d "$device" ]; then
        device_name=$(basename "$device")
        usb_path=$(readlink -f "$device/device")
        
        # Get vendor ID to identify DCOM devices
        vendor_id=$(cat "$usb_path/../idVendor" 2>/dev/null)
        
        # Check if it's a known DCOM device
        case "$vendor_id" in
            "12d1"|"19d2"|"05c6")
                echo ""
                echo "📱 Device: /dev/$device_name"
                get_device_info "$usb_path"
                
                # Get USB topology
                usb_port=$(echo "$usb_path" | grep -o '[0-9]-[0-9].*[0-9]' | head -1)
                echo "    USB Port = $usb_port"
                
                # Check for stable symlinks
                stable_links=$(find /dev -name "dcom-*" -exec ls -l {} \; 2>/dev/null | grep "$device_name" | awk '{print $9}')
                if [ -n "$stable_links" ]; then
                    echo "    Stable link = $stable_links"
                else
                    echo "    Stable link = Not created"
                fi
                
                device_count=$((device_count + 1))
                ;;
        esac
    fi
done

echo ""
echo "📊 Summary:"
echo "    Total DCOM devices found: $device_count"

# Show all stable device links
echo ""
echo "🔗 Available stable device links:"
ls -la /dev/dcom* 2>/dev/null | awk '{print "    " $0}' || echo "    No stable links found"

# Show USB device tree
echo ""
echo "🌳 USB device tree:"
lsusb -t | grep -E "(12d1|19d2|05c6)" || echo "    No DCOM devices in USB tree"

# Network interfaces (for HiLink devices)
echo ""
echo "🌐 Network interfaces (HiLink devices):"
ip link show | grep -E "enx|usb" | awk '{print "    " $0}' || echo "    No USB network interfaces found"
