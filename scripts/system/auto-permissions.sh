#!/bin/bash

# Auto Permission Management Script
# Automatically sets correct permissions for all files in proxy-farm-system

PROJECT_ROOT="/home/proxy-farm-system"
LOG_FILE="$PROJECT_ROOT/logs/permissions.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
    log_message "INFO: $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    log_message "WARNING: $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log_message "ERROR: $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE} Auto Permission Management${NC}"
    echo -e "${BLUE}================================${NC}"
    log_message "Starting auto permission management"
}

# Check if running as root or with sudo
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root or with sudo"
        exit 1
    fi
}

# Set executable permissions for all shell scripts
set_script_permissions() {
    print_status "Setting executable permissions for shell scripts..."
    
    # Find all .sh files and make them executable
    find "$PROJECT_ROOT/scripts" -name "*.sh" -type f -exec chmod +x {} \; 2>/dev/null
    
    # Specific scripts that need executable permissions
    local scripts=(
        "$PROJECT_ROOT/scripts/system/auto-permissions.sh"
        "$PROJECT_ROOT/scripts/system/apn-manager.sh"
        "$PROJECT_ROOT/scripts/system/check-hilink-mode.sh"
        "$PROJECT_ROOT/scripts/system/check-wan-ip.sh"
        "$PROJECT_ROOT/scripts/system/connection-control.sh"
        "$PROJECT_ROOT/scripts/system/dcom-autoconnect.sh"
        "$PROJECT_ROOT/scripts/system/deploy-udev-rules.sh"
        "$PROJECT_ROOT/scripts/system/detect-dcom-devices.sh"
        "$PROJECT_ROOT/scripts/system/hilink-advanced.sh"
        "$PROJECT_ROOT/scripts/system/hilink-dashboard.sh"
        "$PROJECT_ROOT/scripts/system/install-all-optimizations.sh"
        "$PROJECT_ROOT/scripts/system/install-optimization.sh"
        "$PROJECT_ROOT/scripts/system/mode-switch-e3372.sh"
        "$PROJECT_ROOT/scripts/system/proxy-control.sh"
        "$PROJECT_ROOT/scripts/system/setup-firewall.sh"
        "$PROJECT_ROOT/scripts/system/setup-monitoring.sh"
        "$PROJECT_ROOT/scripts/system/system-monitor.sh"
        "$PROJECT_ROOT/scripts/system/user-manager.sh"
        "$PROJECT_ROOT/scripts/system/verify-installation.sh"
        "$PROJECT_ROOT/scripts/3proxy/deploy-config.sh"
        "$PROJECT_ROOT/scripts/3proxy/generate-config.sh"
        "$PROJECT_ROOT/scripts/3proxy/manage-3proxy.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            chmod +x "$script"
            print_status "Set executable: $script"
        else
            print_warning "Script not found: $script"
        fi
    done
}

# Set permissions for Python files
set_python_permissions() {
    print_status "Setting permissions for Python files..."
    
    # Make Python scripts executable
    find "$PROJECT_ROOT/webapp" -name "*.py" -type f -exec chmod +x {} \; 2>/dev/null
    
    # Specific Python files
    if [[ -f "$PROJECT_ROOT/webapp/app.py" ]]; then
        chmod +x "$PROJECT_ROOT/webapp/app.py"
        print_status "Set executable: webapp/app.py"
    fi
}

# Set permissions for configuration files
set_config_permissions() {
    print_status "Setting permissions for configuration files..."
    
    # Config directories
    chmod 755 "$PROJECT_ROOT/configs" 2>/dev/null
    chmod 755 "$PROJECT_ROOT/configs/3proxy" 2>/dev/null
    chmod 755 "$PROJECT_ROOT/configs/dcom" 2>/dev/null
    chmod 755 "$PROJECT_ROOT/configs/webapp" 2>/dev/null
    
    # 3proxy config files
    if [[ -f "$PROJECT_ROOT/configs/3proxy/3proxy.cfg" ]]; then
        chmod 644 "$PROJECT_ROOT/configs/3proxy/3proxy.cfg"
        print_status "Set permissions: 3proxy.cfg"
    fi
    
    if [[ -f "$PROJECT_ROOT/configs/3proxy/users.conf" ]]; then
        chmod 600 "$PROJECT_ROOT/configs/3proxy/users.conf"  # Sensitive file
        print_status "Set secure permissions: users.conf"
    fi
    
    # DCOM config files
    if [[ -f "$PROJECT_ROOT/configs/dcom/apn-profiles.conf" ]]; then
        chmod 644 "$PROJECT_ROOT/configs/dcom/apn-profiles.conf"
        print_status "Set permissions: apn-profiles.conf"
    fi
    
    # UDEV rules
    if [[ -f "$PROJECT_ROOT/configs/udev/99-dcom-stable.rules" ]]; then
        chmod 644 "$PROJECT_ROOT/configs/udev/99-dcom-stable.rules"
        print_status "Set permissions: udev rules"
    fi
}

# Set permissions for log directories
set_log_permissions() {
    print_status "Setting permissions for log directories..."
    
    # Create log directories if they don't exist
    mkdir -p "$PROJECT_ROOT/logs/3proxy" 2>/dev/null
    mkdir -p "$PROJECT_ROOT/logs/system" 2>/dev/null
    mkdir -p "$PROJECT_ROOT/logs/webapp" 2>/dev/null
    
    # Set permissions
    chmod 755 "$PROJECT_ROOT/logs" 2>/dev/null
    chmod 755 "$PROJECT_ROOT/logs/3proxy" 2>/dev/null
    chmod 755 "$PROJECT_ROOT/logs/system" 2>/dev/null
    chmod 755 "$PROJECT_ROOT/logs/webapp" 2>/dev/null
    
    # Log files
    find "$PROJECT_ROOT/logs" -name "*.log" -type f -exec chmod 644 {} \; 2>/dev/null
    
    print_status "Log directories configured"
}

# Set permissions for backup directories
set_backup_permissions() {
    print_status "Setting permissions for backup directories..."
    
    mkdir -p "$PROJECT_ROOT/backups" 2>/dev/null
    chmod 755 "$PROJECT_ROOT/backups" 2>/dev/null
    
    if [[ -d "$PROJECT_ROOT/configs/3proxy/backups" ]]; then
        chmod 755 "$PROJECT_ROOT/configs/3proxy/backups"
        find "$PROJECT_ROOT/configs/3proxy/backups" -type f -exec chmod 644 {} \; 2>/dev/null
        print_status "Backup directories configured"
    fi
}

# Set ownership
set_ownership() {
    print_status "Setting correct ownership..."
    
    # Change ownership to current user (usually proxy-farm or root)
    local current_user=$(logname 2>/dev/null || echo "root")
    
    if [[ "$current_user" != "root" ]]; then
        chown -R "$current_user:$current_user" "$PROJECT_ROOT" 2>/dev/null
        print_status "Changed ownership to: $current_user"
    else
        print_status "Running as root - keeping root ownership"
    fi
}

# Fix webapp permissions specifically
set_webapp_permissions() {
    print_status "Setting webapp specific permissions..."
    
    # Web templates
    if [[ -d "$PROJECT_ROOT/webapp/templates" ]]; then
        chmod 755 "$PROJECT_ROOT/webapp/templates"
        find "$PROJECT_ROOT/webapp/templates" -name "*.html" -type f -exec chmod 644 {} \; 2>/dev/null
        print_status "HTML templates configured"
    fi
    
    # Virtual environment (if exists)
    if [[ -d "$PROJECT_ROOT/webapp/venv" ]]; then
        chmod 755 "$PROJECT_ROOT/webapp/venv"
        find "$PROJECT_ROOT/webapp/venv/bin" -type f -exec chmod +x {} \; 2>/dev/null
        print_status "Python virtual environment configured"
    fi
}

# Create auto-fix service
create_autofix_service() {
    print_status "Creating auto-fix systemd service..."
    
    local service_file="/etc/systemd/system/proxy-farm-permissions.service"
    local timer_file="/etc/systemd/system/proxy-farm-permissions.timer"
    
    # Create service file
    cat > "$service_file" << 'EOF'
[Unit]
Description=Proxy Farm Permissions Auto-fix
After=network.target

[Service]
Type=oneshot
ExecStart=/home/proxy-farm-system/scripts/system/auto-permissions.sh --quiet
User=root
Group=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # Create timer file (run every hour)
    cat > "$timer_file" << 'EOF'
[Unit]
Description=Run Proxy Farm Permissions Auto-fix every hour
Requires=proxy-farm-permissions.service

[Timer]
OnCalendar=hourly
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # Set service permissions
    chmod 644 "$service_file"
    chmod 644 "$timer_file"
    
    # Reload systemd and enable timer
    systemctl daemon-reload
    systemctl enable proxy-farm-permissions.timer
    systemctl start proxy-farm-permissions.timer
    
    print_status "Auto-fix service created and enabled"
}

# Quick fix function for common issues
quick_fix() {
    print_status "Running quick permission fix..."
    
    # Most common files that need fixing after SFTP upload
    local critical_files=(
        "$PROJECT_ROOT/webapp/app.py"
        "$PROJECT_ROOT/scripts/system/user-manager.sh"
        "$PROJECT_ROOT/scripts/system/hilink-advanced.sh"
        "$PROJECT_ROOT/scripts/system/connection-control.sh"
        "$PROJECT_ROOT/scripts/3proxy/manage-3proxy.sh"
    )
    
    for file in "${critical_files[@]}"; do
        if [[ -f "$file" ]]; then
            chmod +x "$file"
            print_status "Quick fix: $file"
        fi
    done
    
    # Fix most common directories
    chmod 755 "$PROJECT_ROOT" 2>/dev/null
    chmod 755 "$PROJECT_ROOT/scripts" 2>/dev/null
    chmod 755 "$PROJECT_ROOT/scripts/system" 2>/dev/null
    chmod 755 "$PROJECT_ROOT/webapp" 2>/dev/null
    chmod 755 "$PROJECT_ROOT/configs" 2>/dev/null
    
    print_status "Quick fix completed"
}

# Watch for file changes and auto-fix permissions
setup_file_watcher() {
    print_status "Setting up file watcher for auto-permissions..."
    
    # Install inotify if not present
    if ! command -v inotifywait &> /dev/null; then
        apt-get update && apt-get install -y inotify-tools
    fi
    
    # Create watcher script
    cat > "$PROJECT_ROOT/scripts/system/permission-watcher.sh" << 'EOF'
#!/bin/bash

PROJECT_ROOT="/home/proxy-farm-system"

# Watch for file uploads and auto-fix permissions
inotifywait -m -r -e create,moved_to "$PROJECT_ROOT" --format '%w%f %e' | while read file event; do
    if [[ "$file" == *.sh ]]; then
        chmod +x "$file"
        echo "Auto-fixed permissions for: $file"
    elif [[ "$file" == *.py ]]; then
        chmod +x "$file"
        echo "Auto-fixed permissions for: $file"
    fi
done
EOF

    chmod +x "$PROJECT_ROOT/scripts/system/permission-watcher.sh"
    print_status "File watcher configured"
}

# Display summary
show_summary() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE} Permission Setup Complete${NC}"
    echo -e "${BLUE}================================${NC}"
    echo -e "${GREEN}✓ Script permissions set${NC}"
    echo -e "${GREEN}✓ Python files configured${NC}"
    echo -e "${GREEN}✓ Config files secured${NC}"
    echo -e "${GREEN}✓ Log directories created${NC}"
    echo -e "${GREEN}✓ Ownership configured${NC}"
    echo -e "${GREEN}✓ Auto-fix service enabled${NC}"
    echo ""
    echo -e "${YELLOW}Usage:${NC}"
    echo -e "  ${BLUE}sudo $0${NC}                 # Full permission setup"
    echo -e "  ${BLUE}sudo $0 --quick${NC}         # Quick fix common issues"
    echo -e "  ${BLUE}sudo $0 --watch${NC}         # Setup file watcher"
    echo ""
    echo -e "${YELLOW}Auto-fix runs every hour via systemd timer${NC}"
    log_message "Permission setup completed successfully"
}

# Main execution
main() {
    print_header
    check_permissions
    
    case "${1:-full}" in
        "--quick")
            quick_fix
            ;;
        "--watch")
            setup_file_watcher
            ;;
        "--quiet")
            # For systemd service - minimal output
            set_script_permissions > /dev/null 2>&1
            set_python_permissions > /dev/null 2>&1
            set_config_permissions > /dev/null 2>&1
            quick_fix > /dev/null 2>&1
            log_message "Auto-fix completed (quiet mode)"
            ;;
        *)
            set_script_permissions
            set_python_permissions
            set_config_permissions
            set_log_permissions
            set_backup_permissions
            set_webapp_permissions
            set_ownership
            create_autofix_service
            show_summary
            ;;
    esac
}

# Run main function with all arguments
main "$@"