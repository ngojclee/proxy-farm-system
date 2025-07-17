#!/bin/bash
# Complete E3372 Mode Switch Script

echo "=== E3372 Mode Switch Process ==="
echo "Started: $(date)"
echo ""

# Current status
echo "🔍 Current Status:"
echo "Device: $(lsusb | grep 12d1)"
echo "Serial devices: $(ls /dev/ttyUSB* 2>/dev/null | wc -l)"
echo ""

# Install tools
echo "📦 Installing usb-modeswitch..."
apt update >/dev/null 2>&1
apt install usb-modeswitch usb-modeswitch-data -y >/dev/null 2>&1

# Method 1: Standard mode switch
echo "🔄 Method 1: Standard mode switch"
usb_modeswitch -v 12d1 -p 14dc -M '55534243123456780000000000000011062000000100000000000000000000'
sleep 15

# Check results
NEW_DEVICE=$(lsusb | grep 12d1)
TTY_COUNT=$(ls /dev/ttyUSB* 2>/dev/null | wc -l)

echo "After Method 1:"
echo "  Device: $NEW_DEVICE"
echo "  TTY devices: $TTY_COUNT"
echo ""

# Method 2: If still not working
if [ "$TTY_COUNT" -eq 0 ]; then
    echo "🔄 Method 2: Alternative mode switch"
    usb_modeswitch -v 12d1 -p 14dc -c /usr/share/usb_modeswitch/12d1:14dc 2>/dev/null
    sleep 10
    
    TTY_COUNT=$(ls /dev/ttyUSB* 2>/dev/null | wc -l)
    echo "After Method 2: $TTY_COUNT TTY devices"
fi

# Method 3: Force reset and switch
if [ "$TTY_COUNT" -eq 0 ]; then
    echo "🔄 Method 3: Force reset"
    
    # Reset USB device
    echo "Resetting USB device..."
    echo "2-1" > /sys/bus/usb/drivers/usb/unbind 2>/dev/null
    sleep 3
    echo "2-1" > /sys/bus/usb/drivers/usb/bind 2>/dev/null
    sleep 5
    
    # Try switch again
    usb_modeswitch -v 12d1 -p 14dc -M '55534243123456780000000000000011062000000100000000000000000000'
    sleep 15
    
    TTY_COUNT=$(ls /dev/ttyUSB* 2>/dev/null | wc -l)
    echo "After Method 3: $TTY_COUNT TTY devices"
fi

# Final status
echo ""
echo "=== Final Results ==="
FINAL_DEVICE=$(lsusb | grep 12d1)
FINAL_TTY_COUNT=$(ls /dev/ttyUSB* 2>/dev/null | wc -l)

echo "Final device: $FINAL_DEVICE"
echo "Final TTY count: $FINAL_TTY_COUNT"

if [ "$FINAL_TTY_COUNT" -gt 0 ]; then
    echo ""
    echo "🎉 SUCCESS: Mode switch successful!"
    echo "✅ Serial interfaces available:"
    ls -la /dev/ttyUSB* | head -5
    
    echo ""
    echo "🧪 Testing AT commands on first device:"
    FIRST_TTY=$(ls /dev/ttyUSB* | head -1)
    echo "AT" > "$FIRST_TTY" 2>/dev/null && echo "✅ AT command sent to $FIRST_TTY"
    
    echo ""
    echo "📝 Next steps:"
    echo "1. Test SIM: minicom -D $FIRST_TTY -b 115200"
    echo "2. Setup PPP connections"
    echo "3. Configure 3proxy with serial interfaces"
    
else
    echo ""
    echo "❌ FAILED: Mode switch unsuccessful"
    echo ""
    echo "🔧 Hardware troubleshooting needed:"
    echo "1. Device may be locked to HiLink mode"
    echo "2. Try different USB port"
    echo "3. Check if device is genuine E3372S"
    echo "4. Consider getting dedicated E3372S (Stick mode)"
    echo ""
    echo "📋 Device info for reference:"
    lsusb -v -d 12d1: 2>/dev/null | grep -E "(idProduct|bcdDevice|iManufacturer|iProduct)" | head -10
fi

echo ""
echo "Completed: $(date)"