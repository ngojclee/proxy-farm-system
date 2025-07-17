#!/bin/bash
MODEM_IP="192.168.8.1"
CONFIG_FILE="/home/proxy-farm-system/configs/dcom/apn-profiles.conf"

get_token() {
    curl -s "http://$MODEM_IP/api/webserver/token" | grep -oP '(?<=<token>)[^<]*'
}

api_call() {
    local endpoint="$1" 
    local token=$(get_token)
    curl -s -H "__RequestVerificationToken: $token" "http://$MODEM_IP/$endpoint"
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

# Tạo file config với Lebara làm mặc định
init_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        sudo tee "$CONFIG_FILE" > /dev/null << 'EOF'
# HiLink APN Profiles Configuration
# Format: PROFILE_NAME:APN:USERNAME:PASSWORD:DESCRIPTION

# Current network (Lebara France) - từ modem hiện tại
lebara_france:fr.lebara.mobi:lebara::Lebara France (current profile)

# France networks
sfr_france:websfr:::SFR France
orange_france:orange:::Orange France  
free_france:free:::Free France
bouygues_france:mmsbouygtel.com:::Bouygues Telecom France
red_sfr:sl2sfr:::RED by SFR

# Vietnam networks
viettel_default:v-internet:::Viettel Internet (mặc định)
viettel_wap:v-wap:::Viettel WAP
mobifone_default:m-wap:::MobiFone WAP (mặc định)
mobifone_internet:internet:::MobiFone Internet
vinaphone_default:m3-world:::VinaPhone M3-World (mặc định)
vinaphone_internet:internet:::VinaPhone Internet

# International examples
uk_ee:everywhere:::EE UK
uk_o2:mobile.o2.co.uk:::O2 UK
uk_three:3internet:::Three UK
us_att:broadband:::AT&T US
us_verizon:vzwinternet:::Verizon US
us_tmobile:fast.t-mobile.com:::T-Mobile US

# Custom profiles (add your own here)
custom1::::Custom APN 1
custom2::::Custom APN 2
EOF
        echo "✅ Created config file: $CONFIG_FILE"
        echo "📝 Lebara France profile added as default"
    fi
}

show_current_profile() {
    echo "📋 Current APN Configuration from Modem:"
    local current=$(api_call "api/dialup/profiles")
    
    # Parse và hiển thị đẹp hơn
    local name=$(echo "$current" | grep -oP '(?<=<Name>)[^<]*')
    local apn=$(echo "$current" | grep -oP '(?<=<ApnName>)[^<]*')
    local username=$(echo "$current" | grep -oP '(?<=<Username>)[^<]*')
    local index=$(echo "$current" | grep -oP '(?<=<Index>)[^<]*')
    
    echo "┌─────────────────────┬─────────────────────────────────────┐"
    echo "│ Field               │ Value                               │"
    echo "├─────────────────────┼─────────────────────────────────────┤"
    printf "│ %-19s │ %-35s │\n" "Profile Index" "$index"
    printf "│ %-19s │ %-35s │\n" "Profile Name" "$name"
    printf "│ %-19s │ %-35s │\n" "APN" "$apn"
    printf "│ %-19s │ %-35s │\n" "Username" "${username:-'(none)'}"
    echo "└─────────────────────┴─────────────────────────────────────┘"
    
    echo ""
    echo "📄 Raw XML (for debugging):"
    echo "$current" | xmlstarlet fo 2>/dev/null || echo "$current"
}

list_saved_profiles() {
    init_config
    echo "📋 Saved APN Profiles:"
    echo "┌─────────────────────┬─────────────────────────┬─────────────────────────────────┐"
    echo "│ Profile Name        │ APN                     │ Description                     │"
    echo "├─────────────────────┼─────────────────────────┼─────────────────────────────────┤"
    
    while IFS=':' read -r profile_name apn username password description; do
        # Skip comments and empty lines
        [[ "$profile_name" =~ ^#.*$ ]] || [[ -z "$profile_name" ]] && continue
        
        printf "│ %-19s │ %-23s │ %-31s │\n" "$profile_name" "$apn" "$description"
    done < "$CONFIG_FILE"
    
    echo "└─────────────────────┴─────────────────────────┴─────────────────────────────────┘"
    echo ""
    echo "💡 Use '$0 use <profile_name>' to switch to a profile"
    echo "💡 Use '$0 add' to create a new profile"
}

add_custom_profile() {
    init_config
    
    echo "➕ Adding custom APN profile:"
    read -p "Profile name (no spaces, e.g. my_network): " profile_name
    read -p "APN (e.g. internet.example.com): " apn
    read -p "Username (press Enter if not required): " username
    read -p "Password (press Enter if not required): " password
    read -p "Description (e.g. My Network Provider): " description
    
    if [ -z "$profile_name" ] || [ -z "$apn" ]; then
        echo "❌ Profile name and APN are required!"
        return 1
    fi
    
    # Validate profile name (no spaces, special chars)
    if [[ "$profile_name" =~ [[:space:]] ]]; then
        echo "❌ Profile name cannot contain spaces!"
        return 1
    fi
    
    # Check if profile already exists
    if grep -q "^$profile_name:" "$CONFIG_FILE"; then
        echo "⚠️  Profile '$profile_name' already exists!"
        read -p "Overwrite? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "❌ Cancelled"
            return 1
        fi
        # Remove existing profile
        sudo sed -i "/^$profile_name:/d" "$CONFIG_FILE"
    fi
    
    # Add new profile
    echo "$profile_name:$apn:$username:$password:$description" | sudo tee -a "$CONFIG_FILE" > /dev/null
    echo "✅ Added profile: $profile_name"
    echo "💡 Use '$0 use $profile_name' to switch to this profile"
}

change_apn_by_profile() {
    local profile_name="$1"
    init_config
    
    if [ -z "$profile_name" ]; then
        echo "❌ Please specify profile name"
        echo "💡 Use: $0 list - to see available profiles"
        return 1
    fi
    
    # Find profile in config
    local profile_line=$(grep "^$profile_name:" "$CONFIG_FILE")
    if [ -z "$profile_line" ]; then
        echo "❌ Profile '$profile_name' not found!"
        echo "💡 Use: $0 list - to see available profiles"
        echo "💡 Use: $0 add - to add a new profile"
        return 1
    fi
    
    # Parse profile
    IFS=':' read -r pname apn username password description <<< "$profile_line"
    
    echo "🔧 Switching to profile: $profile_name"
    echo "📡 APN: $apn"
    echo "👤 Username: ${username:-'(none)'}"
    echo "🔒 Password: ${password:+'***'}"
    echo "📝 Description: $description"
    echo ""
    
    read -p "Continue? (Y/n): " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        echo "❌ Cancelled"
        return 1
    fi
    
    # Build XML with proper structure based on current profile format
    xml_data="<?xml version=\"1.0\" encoding=\"UTF-8\"?><request><profiles><profile><index>1</index><name>$profile_name</name><apnname>$apn</apnname><username>$username</username><password>$password</password><authmode>0</authmode><iptype>2</iptype></profile></profiles></request>"
    
    echo "🔄 Applying APN change..."
    result=$(api_post "api/dialup/profiles" "$xml_data")
    
    echo "Response: $result"
    
    if echo "$result" | grep -q "OK\|response"; then
        echo "✅ APN profile changed successfully!"
        echo "🔄 Restarting connection to apply changes..."
        
        # Restart connection
        echo "   Disconnecting..."
        api_post "api/dialup/mobile-dataswitch" '<?xml version="1.0" encoding="UTF-8"?><request><dataswitch>0</dataswitch></request>' > /dev/null
        sleep 5
        echo "   Reconnecting..."
        api_post "api/dialup/mobile-dataswitch" '<?xml version="1.0" encoding="UTF-8"?><request><dataswitch>1</dataswitch></request>' > /dev/null
        
        echo "⏳ Waiting for reconnection (15 seconds)..."
        sleep 15
        
        # Check new status
        echo "📊 New connection status:"
        if command -v ./connection-control.sh >/dev/null; then
            ./connection-control.sh status 2>/dev/null
        fi
        
        echo ""
        echo "📋 New APN configuration:"
        show_current_profile
        
    else
        echo "❌ Failed to change APN profile"
        echo "💡 Try using manual mode: $0 manual"
    fi
}

change_apn_manual() {
    echo "🔧 Manual APN Configuration:"
    read -p "Enter profile name: " profile_name
    read -p "Enter APN: " apn
    read -p "Enter Username (optional): " username  
    read -p "Enter Password (optional): " password
    
    if [ -z "$apn" ]; then
        echo "❌ APN is required!"
        return 1
    fi
    
    if [ -z "$profile_name" ]; then
        profile_name="manual_$(date +%s)"
    fi
    
    echo "🔄 Applying manual APN configuration:"
    echo "   Profile: $profile_name"
    echo "   APN: $apn"
    echo "   Username: ${username:-'(none)'}"
    
    xml_data="<?xml version=\"1.0\" encoding=\"UTF-8\"?><request><profiles><profile><index>1</index><name>$profile_name</name><apnname>$apn</apnname><username>$username</username><password>$password</password><authmode>0</authmode><iptype>2</iptype></profile></profiles></request>"
    
    result=$(api_post "api/dialup/profiles" "$xml_data")
    echo "Result: $result"
    
    if echo "$result" | grep -q "OK\|response"; then
        echo "✅ APN configuration applied!"
        read -p "Restart connection now? (Y/n): " restart
        if [[ ! "$restart" =~ ^[Nn]$ ]]; then
            echo "🔄 Restarting connection..."
            api_post "api/dialup/mobile-dataswitch" '<?xml version="1.0" encoding="UTF-8"?><request><dataswitch>0</dataswitch></request>' > /dev/null
            sleep 5
            api_post "api/dialup/mobile-dataswitch" '<?xml version="1.0" encoding="UTF-8"?><request><dataswitch>1</dataswitch></request>' > /dev/null
            echo "⏳ Waiting for reconnection..."
            sleep 15
        fi
        
        read -p "Save this configuration as a profile? (y/N): " save
        if [[ "$save" =~ ^[Yy]$ ]]; then
            read -p "Enter description: " description
            init_config
            echo "$profile_name:$apn:$username:$password:$description" | sudo tee -a "$CONFIG_FILE" > /dev/null
            echo "✅ Saved as profile: $profile_name"
        fi
    fi
}

edit_config() {
    init_config
    echo "📝 Opening APN config file for editing..."
    echo "File location: $CONFIG_FILE"
    echo ""
    
    if command -v nano >/dev/null; then
        sudo nano "$CONFIG_FILE"
    elif command -v vi >/dev/null; then
        sudo vi "$CONFIG_FILE"
    else
        echo "❌ No text editor found. Please edit manually: $CONFIG_FILE"
        echo "You can also use: sudo vim $CONFIG_FILE"
    fi
}

remove_profile() {
    local profile_name="$1"
    init_config
    
    if [ -z "$profile_name" ]; then
        echo "Available profiles:"
        list_saved_profiles
        echo ""
        read -p "Enter profile name to remove: " profile_name
    fi
    
    if [ -z "$profile_name" ]; then
        echo "❌ No profile name provided"
        return 1
    fi
    
    if grep -q "^$profile_name:" "$CONFIG_FILE"; then
        echo "⚠️  About to remove profile: $profile_name"
        read -p "Are you sure? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            sudo sed -i "/^$profile_name:/d" "$CONFIG_FILE"
            echo "✅ Removed profile: $profile_name"
        else
            echo "❌ Cancelled"
        fi
    else
        echo "❌ Profile '$profile_name' not found!"
    fi
}

case "${1:-help}" in
    show|current) 
        show_current_profile 
        ;;
    list|ls) 
        list_saved_profiles 
        ;;
    add|new) 
        add_custom_profile 
        ;;
    use|change) 
        change_apn_by_profile "$2" 
        ;;
    manual) 
        change_apn_manual 
        ;;
    edit) 
        edit_config 
        ;;
    remove|rm) 
        remove_profile "$2" 
        ;;
    help|*) 
        echo "🔧 HiLink APN Manager v2.0"
        echo ""
        echo "Usage: $0 <command> [options]"
        echo ""
        echo "Commands:"
        echo "  show           - Show current APN configuration from modem"
        echo "  list           - List all saved APN profiles"
        echo "  add            - Add a new APN profile interactively"
        echo "  use <profile>  - Switch to saved profile"
        echo "  manual         - Configure APN manually (one-time)"
        echo "  edit           - Edit the APN profiles config file"
        echo "  remove <name>  - Remove a saved profile"
        echo ""
        echo "Examples:"
        echo "  $0 show                    - Show current modem config"
        echo "  $0 list                    - Show all saved profiles"
        echo "  $0 use lebara_france       - Switch to Lebara profile"
        echo "  $0 add                     - Add new profile interactively"
        echo "  $0 manual                  - Enter APN settings manually"
        echo ""
        echo "Config file: $CONFIG_FILE"
        echo "Current network: Lebara France (fr.lebara.mobi)"
        ;;
esac