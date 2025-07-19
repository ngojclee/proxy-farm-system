#!/bin/bash
# 3proxy Configuration Generator

SCRIPT_DIR="/home/proxy-farm-system"
TEMPLATE_FILE="$SCRIPT_DIR/configs/3proxy/3proxy.cfg.template"
OUTPUT_FILE="$SCRIPT_DIR/configs/3proxy/3proxy.cfg"
USERS_FILE="$SCRIPT_DIR/configs/3proxy/users.txt"
SYSTEM_CONFIG="/etc/3proxy/3proxy.cfg"

echo "=== Generating 3proxy Configuration ==="

# Check if template exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "❌ Template file not found: $TEMPLATE_FILE"
    exit 1
fi

# Function to generate users section
generate_users() {
    local users_section=""
    
    if [ -f "$USERS_FILE" ]; then
        echo "📝 Loading users from: $USERS_FILE"
        while IFS=':' read -r username password port interface; do
            # Skip comments and empty lines
            [[ "$username" =~ ^#.*$ ]] && continue
            [[ -z "$username" ]] && continue
            
            users_section+="\nusers $username:CL:$password"
        done < "$USERS_FILE"
    else
        echo "⚠️  No users file found, creating sample users"
        # Create sample users file
        cat > "$USERS_FILE" << 'EOF'
# Proxy Users Configuration
# Format: username:password:port:interface
# Example: user1:pass123:3128:eth0

user1:demo123:3128:eth0
user2:demo456:3129:ppp0
EOF
        users_section+="\nusers user1:CL:demo123"
        users_section+="\nusers user2:CL:demo456"
    fi
    
    echo "$users_section"
}

# Function to generate proxies section
generate_proxies() {
    local proxies_section=""
    
    if [ -f "$USERS_FILE" ]; then
        while IFS=':' read -r username password port interface; do
            # Skip comments and empty lines
            [[ "$username" =~ ^#.*$ ]] && continue
            [[ -z "$username" ]] && continue
            
            # Generate proxy configuration
            proxies_section+="\nallow $username"
            
            if [ -n "$interface" ] && [ "$interface" != "auto" ]; then
                proxies_section+="\nproxy -p$port -i0.0.0.0 -e$interface"
            else
                proxies_section+="\nproxy -p$port -i0.0.0.0"
            fi
            proxies_section+="\n"
        done < "$USERS_FILE"
    else
        # Default proxy configurations
        proxies_section+="\nallow user1"
        proxies_section+="\nproxy -p3128 -i0.0.0.0"
        proxies_section+="\n"
        proxies_section+="\nallow user2"
        proxies_section+="\nproxy -p3129 -i0.0.0.0 -eppp0"
    fi
    
    echo "$proxies_section"
}

# Generate sections
echo "📝 Generating users section..."
USERS_SECTION=$(generate_users)

echo "📝 Generating proxies section..."
PROXIES_SECTION=$(generate_proxies)

# Replace placeholders in template
echo "📝 Creating configuration file..."
sed -e "s|{{USERS_SECTION}}|$USERS_SECTION|g" \
    -e "s|{{PROXIES_SECTION}}|$PROXIES_SECTION|g" \
    "$TEMPLATE_FILE" > "$OUTPUT_FILE"

echo "✅ Configuration generated: $OUTPUT_FILE"

# Show summary
if [ -f "$USERS_FILE" ]; then
    user_count=$(grep -v '^#' "$USERS_FILE" | grep -v '^$' | wc -l)
    echo "📊 Users configured: $user_count"
    
    echo "📋 User summary:"
    grep -v '^#' "$USERS_FILE" | grep -v '^$' | while IFS=':' read -r username password port interface; do
        echo "   $username → Port $port ($interface)"
    done
fi

echo ""
echo "🔧 Next steps:"
echo "   1. Review config: cat $OUTPUT_FILE"
echo "   2. Deploy to system: $SCRIPT_DIR/scripts/3proxy/deploy-config.sh"
echo "   3. Restart 3proxy: systemctl restart 3proxy"
