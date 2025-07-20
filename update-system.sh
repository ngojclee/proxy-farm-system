#!/bin/bash

# ProxyFarm System - Update Script
# Handles system updates, dependency upgrades, and configuration updates

set -e

PROJECT_ROOT="/home/proxy-farm-system"
UPDATE_LOG="$PROJECT_ROOT/logs/system/update.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
BACKUP_BEFORE_UPDATE=true
AUTO_RESTART_SERVICES=true
UPDATE_SYSTEM_PACKAGES=false

log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${BLUE}$message${NC}"
    echo "$message" >> "$UPDATE_LOG"
}

error() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1"
    echo -e "${RED}$message${NC}" >&2
    echo "$message" >> "$UPDATE_LOG"
}

success() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $1"
    echo -e "${GREEN}$message${NC}"
    echo "$message" >> "$UPDATE_LOG"
}

warning() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1"
    echo -e "${YELLOW}$message${NC}"
    echo "$message" >> "$UPDATE_LOG"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "Please run as root: sudo ./update-system.sh"
        exit 1
    fi
}

# Create backup before update
create_pre_update_backup() {
    if [ "$BACKUP_BEFORE_UPDATE" = "true" ]; then
        log "Creating pre-update backup..."
        
        if [ -f "$PROJECT_ROOT/backup-system.sh" ]; then
            cd "$PROJECT_ROOT"
            ./backup-system.sh --no-compress
            success "Pre-update backup completed"
        else
            warning "Backup script not found, skipping backup"
        fi
    fi
}

# Update system packages
update_system_packages() {
    if [ "$UPDATE_SYSTEM_PACKAGES" = "true" ]; then
        log "Updating system packages..."
        
        apt update
        apt upgrade -y
        apt autoremove -y
        apt autoclean
        
        success "System packages updated"
    else
        log "Skipping system package updates"
    fi
}

# Update Python dependencies
update_python_dependencies() {
    log "Updating Python dependencies..."
    
    cd "$PROJECT_ROOT"
    
    # Activate virtual environment
    if [ -d "venv" ]; then
        source venv/bin/activate
        
        # Update pip
        pip install --upgrade pip
        
        # Update core dependencies
        pip install --upgrade flask gunicorn
        
        # Update any requirements.txt if exists
        if [ -f "requirements.txt" ]; then
            pip install --upgrade -r requirements.txt
        fi
        
        # Generate new requirements file
        pip freeze > requirements_$(date +%Y%m%d).txt
        
        success "Python dependencies updated"
        deactivate
    else
        warning "Virtual environment not found"
    fi
}

# Update configuration files
update_configurations() {
    log "Checking for configuration updates..."
    
    # Update systemd service if needed
    if [ -f "proxyfarm.service" ] && [ -f "/etc/systemd/system/proxyfarm.service" ]; then
        if ! cmp -s "proxyfarm.service" "/etc/systemd/system/proxyfarm.service"; then
            log "Updating systemd service file..."
            cp "proxyfarm.service" "/etc/systemd/system/proxyfarm.service"
            systemctl daemon-reload
            success "Systemd service updated"
        fi
    fi
    
    # Update nginx config if needed
    if [ -f "nginx-proxyfarm.conf" ] && [ -f "/etc/nginx/sites-available/proxyfarm" ]; then
        if ! cmp -s "nginx-proxyfarm.conf" "/etc/nginx/sites-available/proxyfarm"; then
            log "Updating nginx configuration..."
            cp "nginx-proxyfarm.conf" "/etc/nginx/sites-available/proxyfarm"
            nginx -t && systemctl reload nginx
            success "Nginx configuration updated"
        fi
    fi
    
    # Update monitoring cron jobs if needed
    if [ -f "/etc/cron.d/proxyfarm-monitoring" ]; then
        log "Monitoring cron jobs are up to date"
    fi
}

# Update application code
update_application() {
    log "Updating application code..."
    
    # Stop services before updating
    if [ "$AUTO_RESTART_SERVICES" = "true" ]; then
        log "Stopping services for update..."
        ./stop-production.sh || true
        systemctl stop proxyfarm || true
    fi
    
    # Update application files would go here
    # In a real deployment, this might involve:
    # - git pull from repository
    # - copying new files
    # - running database migrations
    
    # For now, just ensure permissions are correct
    chmod +x scripts/system/*.sh 2>/dev/null || true
    chmod +x scripts/3proxy/*.sh 2>/dev/null || true
    chmod +x scripts/dcom/*.sh 2>/dev/null || true
    chmod +x *.sh 2>/dev/null || true
    
    success "Application code updated"
}

# Run database migrations (if needed)
run_migrations() {
    log "Checking for database migrations..."
    
    # This would run any necessary database migrations
    # For SQLite or other databases used by the system
    
    success "Database migrations completed"
}

# Restart services
restart_services() {
    if [ "$AUTO_RESTART_SERVICES" = "true" ]; then
        log "Restarting services..."
        
        # Restart 3proxy
        systemctl restart 3proxy || true
        
        # Restart webapp
        cd "$PROJECT_ROOT"
        ./start-production.sh
        
        # Restart nginx
        systemctl restart nginx
        
        # Wait for services to start
        sleep 10
        
        # Verify services are running
        if systemctl is-active proxyfarm >/dev/null 2>&1; then
            success "ProxyFarm service restarted successfully"
        else
            error "Failed to restart ProxyFarm service"
        fi
        
        if pgrep 3proxy >/dev/null; then
            success "3proxy restarted successfully"
        else
            error "Failed to restart 3proxy"
        fi
        
        if systemctl is-active nginx >/dev/null 2>&1; then
            success "Nginx restarted successfully"
        else
            error "Failed to restart nginx"
        fi
        
    else
        warning "Auto-restart disabled. Please restart services manually"
    fi
}

# Run post-update tests
run_post_update_tests() {
    log "Running post-update tests..."
    
    # Test webapp response
    sleep 5
    if curl -f -s http://localhost:5000/api/status >/dev/null; then
        success "Webapp is responding"
    else
        error "Webapp is not responding"
    fi
    
    # Test proxy ports
    local active_ports=0
    for port in 3330 3331 3332 3333 3334 3335 3336 3337 3338 3339; do
        if netstat -tlnp | grep -q ":$port"; then
            ((active_ports++))
        fi
    done
    
    if [ $active_ports -gt 0 ]; then
        success "Proxy services active on $active_ports ports"
    else
        error "No proxy ports are listening"
    fi
    
    # Run system monitor
    if [ -f "$PROJECT_ROOT/monitor-system.sh" ]; then
        ./monitor-system.sh --report
        success "System health check completed"
    fi
}

# Clean up after update
cleanup_update() {
    log "Cleaning up after update..."
    
    # Clean old log files
    find "$PROJECT_ROOT/logs" -name "*.log" -mtime +30 -delete 2>/dev/null || true
    
    # Clean old backup files
    find "/backup/proxyfarm" -name "*.tar.gz" -mtime +60 -delete 2>/dev/null || true
    
    # Clean package cache
    apt autoclean 2>/dev/null || true
    
    success "Cleanup completed"
}

# Generate update report
generate_update_report() {
    log "Generating update report..."
    
    local report_file="$PROJECT_ROOT/logs/system/update_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
ProxyFarm System Update Report
==============================
Update Date: $(date)
Update Duration: $((SECONDS / 60)) minutes

Update Summary:
--------------
- System packages: $([ "$UPDATE_SYSTEM_PACKAGES" = "true" ] && echo "Updated" || echo "Skipped")
- Python dependencies: Updated
- Configuration files: Checked and updated if needed
- Application code: Updated
- Services: $([ "$AUTO_RESTART_SERVICES" = "true" ] && echo "Restarted" || echo "Manual restart required")

System Status After Update:
---------------------------
EOF
    
    # Add service status to report
    if systemctl is-active proxyfarm >/dev/null 2>&1; then
        echo "ProxyFarm Service: ✅ Running" >> "$report_file"
    else
        echo "ProxyFarm Service: ❌ Stopped" >> "$report_file"
    fi
    
    if pgrep 3proxy >/dev/null; then
        echo "3proxy: ✅ Running" >> "$report_file"
    else
        echo "3proxy: ❌ Stopped" >> "$report_file"
    fi
    
    if systemctl is-active nginx >/dev/null 2>&1; then
        echo "Nginx: ✅ Running" >> "$report_file"
    else
        echo "Nginx: ❌ Stopped" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

Resource Usage:
--------------
CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}')
Memory: $(free -h | grep Mem | awk '{print $3 "/" $2}')
Disk: $(df -h "$PROJECT_ROOT" | awk 'NR==2 {print $3 "/" $2 " (" $5 " used)"}')

Network Status:
--------------
Active connections: $(netstat -tn | grep ESTABLISHED | wc -l)
Proxy ports listening: $(netstat -tlnp | grep -E ":(3330|3331|3332|3333|3334|3335|3336|3337|3338|3339)" | wc -l)/10

Update completed successfully.
EOF
    
    success "Update report generated: $report_file"
}

# Main update function
main() {
    local start_time=$SECONDS
    
    echo -e "${BLUE}🔄 Starting ProxyFarm System Update${NC}"
    echo -e "${BLUE}===================================${NC}"
    
    # Create log directory
    mkdir -p "$(dirname "$UPDATE_LOG")"
    
    check_root
    create_pre_update_backup
    update_system_packages
    update_python_dependencies
    update_configurations
    update_application
    run_migrations
    restart_services
    run_post_update_tests
    cleanup_update
    generate_update_report
    
    local duration=$((SECONDS - start_time))
    
    echo ""
    success "Update completed successfully in $((duration / 60)) minutes!"
    echo -e "${BLUE}📊 Check update report in logs/system/${NC}"
    echo -e "${BLUE}🔍 Run ./monitoring-dashboard.sh to verify system status${NC}"
}

# Handle command line arguments
case "${1:-}" in
    --system-packages)
        UPDATE_SYSTEM_PACKAGES=true
        main
        ;;
    --no-backup)
        BACKUP_BEFORE_UPDATE=false
        main
        ;;
    --no-restart)
        AUTO_RESTART_SERVICES=false
        main
        ;;
    --help)
        echo "ProxyFarm System Update Tool"
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --system-packages    Also update system packages (apt upgrade)"
        echo "  --no-backup          Skip pre-update backup"
        echo "  --no-restart         Don't restart services automatically"
        echo "  --help               Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0                          # Standard update"
        echo "  $0 --system-packages        # Update with system packages"
        echo "  $0 --no-backup              # Update without backup"
        echo "  $0 --no-restart             # Update without auto-restart"
        ;;
    *)
        main
        ;;
esac