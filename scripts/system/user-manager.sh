#!/bin/bash
# User Management for Proxy Farm System

USERS_FILE="/home/proxy-farm-system/configs/3proxy/users.conf"
BACKUP_DIR="/home/proxy-farm-system/configs/3proxy/backups"

# Create backup
backup_users() {
    mkdir -p "$BACKUP_DIR"
    cp "$USERS_FILE" "$BACKUP_DIR/users.txt.$(date +%Y%m%d_%H%M%S)"
    echo "✅ Users backed up"
}

# Add user
add_user() {
    local username="$1"
    local password="$2"
    
    if [ -z "$username" ] || [ -z "$password" ]; then
        echo "❌ Usage: add_user <username> <password>"
        return 1
    fi
    
    # Check if user exists
    if grep -q "^$username:" "$USERS_FILE"; then
        echo "❌ User $username already exists!"
        return 1
    fi
    
    backup_users
    
    # Add user
    echo "$username:CL:$password" | sudo tee -a "$USERS_FILE"
    sudo chmod 600 "$USERS_FILE"
    
    echo "✅ User $username added to project"
    echo "🔄 Restart 3proxy: sudo systemctl restart 3proxy"
}

# Remove user
remove_user() {
    local username="$1"
    
    if [ -z "$username" ]; then
        echo "❌ Usage: remove_user <username>"
        return 1
    fi
    
    backup_users
    
    sudo sed -i "/^$username:/d" "$USERS_FILE"
    echo "✅ User $username removed from project"
    echo "🔄 Restart 3proxy: sudo systemctl restart 3proxy"
}

# List users
list_users() {
    echo "👥 Proxy Farm System Users:"
    echo "┌─────────────────────┬─────────────────────┐"
    echo "│ Username            │ Password Type       │"
    echo "├─────────────────────┼─────────────────────┤"
    
    while IFS=':' read -r username type password; do
        printf "│ %-19s │ %-19s │\n" "$username" "$type"
    done < "$USERS_FILE"
    
    echo "└─────────────────────┴─────────────────────┘"
    echo "Total users: $(wc -l < "$USERS_FILE")"
    echo "File: $USERS_FILE"
}

# Change password
change_password() {
    local username="$1"
    local new_password="$2"
    
    if [ -z "$username" ] || [ -z "$new_password" ]; then
        echo "❌ Usage: change_password <username> <new_password>"
        return 1
    fi
    
    if ! grep -q "^$username:" "$USERS_FILE"; then
        echo "❌ User $username not found!"
        return 1
    fi
    
    backup_users
    
    sudo sed -i "s/^$username:CL:.*/$username:CL:$new_password/" "$USERS_FILE"
    echo "✅ Password changed for user $username"
    echo "🔄 Restart 3proxy: sudo systemctl restart 3proxy"
}

case "$1" in
    add) add_user "$2" "$3" ;;
    remove) remove_user "$2" ;;
    list) list_users ;;
    passwd) change_password "$2" "$3" ;;
    *) 
        echo "🔧 Proxy Farm System - User Manager"
        echo ""
        echo "Usage: $0 {add|remove|list|passwd}"
        echo ""
        echo "Commands:"
        echo "  add <user> <pass>      - Add new user"
        echo "  remove <user>          - Remove user"  
        echo "  list                   - List all users"
        echo "  passwd <user> <pass>   - Change password"
        echo ""
        echo "Examples:"
        echo "  $0 add john pass123        - Add user john"
        echo "  $0 remove john             - Remove user john"
        echo "  $0 passwd john newpass     - Change john's password"
        echo ""
        echo "Project: /home/proxy-farm-system/"
        ;;
esac
