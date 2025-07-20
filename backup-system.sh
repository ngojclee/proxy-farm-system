#!/bin/bash

# ProxyFarm System - Backup Script
# Creates comprehensive backups of configurations, data, and logs

set -e

PROJECT_ROOT="/home/proxy-farm-system"
BACKUP_ROOT="/backup/proxyfarm"
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$BACKUP_ROOT/$BACKUP_DATE"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
RETENTION_DAYS=30
COMPRESS_BACKUPS=true
INCLUDE_LOGS=false

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

# Create backup directory
create_backup_dir() {
    log "Creating backup directory: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        error "Failed to create backup directory"
        exit 1
    fi
}

# Backup configurations
backup_configs() {
    log "Backing up configurations..."
    
    local config_backup="$BACKUP_DIR/configs"
    mkdir -p "$config_backup"
    
    # Backup 3proxy configs
    if [ -d "$PROJECT_ROOT/configs/3proxy" ]; then
        cp -r "$PROJECT_ROOT/configs/3proxy" "$config_backup/"
        success "3proxy configs backed up"
    fi
    
    # Backup DCOM configs
    if [ -d "$PROJECT_ROOT/configs/dcom" ]; then
        cp -r "$PROJECT_ROOT/configs/dcom" "$config_backup/"
        success "DCOM configs backed up"
    fi
    
    # Backup udev rules
    if [ -d "$PROJECT_ROOT/configs/udev" ]; then
        cp -r "$PROJECT_ROOT/configs/udev" "$config_backup/"
        success "Udev configs backed up"
    fi
    
    # Backup webapp configs
    if [ -d "$PROJECT_ROOT/configs/webapp" ]; then
        cp -r "$PROJECT_ROOT/configs/webapp" "$config_backup/"
        success "Webapp configs backed up"
    fi
    
    # Backup system configs
    mkdir -p "$config_backup/system"
    
    # Nginx config
    if [ -f "/etc/nginx/sites-available/proxyfarm" ]; then
        cp "/etc/nginx/sites-available/proxyfarm" "$config_backup/system/"
        success "Nginx config backed up"
    fi
    
    # Systemd services
    if [ -f "/etc/systemd/system/proxyfarm.service" ]; then
        cp "/etc/systemd/system/proxyfarm.service" "$config_backup/system/"
    fi
    
    if [ -f "/etc/systemd/system/proxyfarm-monitor.service" ]; then
        cp "/etc/systemd/system/proxyfarm-monitor.service" "$config_backup/system/"
    fi
    
    # Cron jobs
    if [ -f "/etc/cron.d/proxyfarm-monitoring" ]; then
        cp "/etc/cron.d/proxyfarm-monitoring" "$config_backup/system/"
    fi
    
    # Logrotate config
    if [ -f "/etc/logrotate.d/proxyfarm" ]; then
        cp "/etc/logrotate.d/proxyfarm" "$config_backup/system/"
    fi
    
    success "System configurations backed up"
}

# Backup application files
backup_application() {
    log "Backing up application files..."
    
    local app_backup="$BACKUP_DIR/webapp"
    mkdir -p "$app_backup"
    
    # Backup Python application
    if [ -d "$PROJECT_ROOT/webapp" ]; then
        cp -r "$PROJECT_ROOT/webapp" "$app_backup/"
        success "Webapp files backed up"
    fi
    
    # Backup scripts
    if [ -d "$PROJECT_ROOT/scripts" ]; then
        cp -r "$PROJECT_ROOT/scripts" "$BACKUP_DIR/"
        success "Scripts backed up"
    fi
    
    # Backup root level scripts and configs
    for file in "$PROJECT_ROOT"/*.sh "$PROJECT_ROOT"/*.service "$PROJECT_ROOT"/*.conf; do
        if [ -f "$file" ]; then
            cp "$file" "$BACKUP_DIR/"
        fi
    done
    
    success "Application files backed up"
}

# Backup logs (optional)
backup_logs() {
    if [ "$INCLUDE_LOGS" = "true" ]; then
        log "Backing up logs..."
        
        local log_backup="$BACKUP_DIR/logs"
        
        if [ -d "$PROJECT_ROOT/logs" ]; then
            # Only backup recent logs (last 7 days)
            mkdir -p "$log_backup"
            find "$PROJECT_ROOT/logs" -name "*.log" -mtime -7 -exec cp --parents {} "$log_backup/" \;
            success "Recent logs backed up"
        fi
    else
        log "Skipping logs backup (INCLUDE_LOGS=false)"
    fi
}

# Backup database (if exists)
backup_database() {
    log "Checking for databases to backup..."
    
    # Check for SQLite databases
    find "$PROJECT_ROOT" -name "*.db" -o -name "*.sqlite" -o -name "*.sqlite3" | while read -r db_file; do
        if [ -f "$db_file" ]; then
            local db_backup="$BACKUP_DIR/database"
            mkdir -p "$db_backup"
            cp "$db_file" "$db_backup/"
            success "Database backed up: $(basename "$db_file")"
        fi
    done
}

# Create backup manifest
create_manifest() {
    log "Creating backup manifest..."
    
    local manifest="$BACKUP_DIR/MANIFEST.txt"
    
    cat > "$manifest" << EOF
ProxyFarm System Backup Manifest
================================
Backup Date: $(date)
Backup Location: $BACKUP_DIR
System: $(hostname)
User: $(whoami)

Backup Contents:
---------------
EOF
    
    # List all backed up files with sizes
    find "$BACKUP_DIR" -type f -exec ls -lh {} \; | awk '{print $9 "\t" $5}' | sort >> "$manifest"
    
    # Add system info
    cat >> "$manifest" << EOF

System Information:
------------------
OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown")
Kernel: $(uname -r)
Uptime: $(uptime -p)
Disk Usage: $(df -h "$PROJECT_ROOT" | awk 'NR==2 {print $3 "/" $2 " (" $5 " used)"}')

Service Status:
--------------
EOF
    
    # Check service status
    if systemctl is-active proxyfarm >/dev/null 2>&1; then
        echo "ProxyFarm Service: Running" >> "$manifest"
    else
        echo "ProxyFarm Service: Stopped" >> "$manifest"
    fi
    
    if pgrep 3proxy >/dev/null; then
        echo "3proxy: Running" >> "$manifest"
    else
        echo "3proxy: Stopped" >> "$manifest"
    fi
    
    success "Backup manifest created"
}

# Compress backup (optional)
compress_backup() {
    if [ "$COMPRESS_BACKUPS" = "true" ]; then
        log "Compressing backup..."
        
        local archive_name="proxyfarm_backup_$BACKUP_DATE.tar.gz"
        local archive_path="$BACKUP_ROOT/$archive_name"
        
        cd "$BACKUP_ROOT"
        tar -czf "$archive_name" "$BACKUP_DATE"
        
        if [ -f "$archive_path" ]; then
            # Remove uncompressed backup
            rm -rf "$BACKUP_DIR"
            
            local archive_size=$(du -h "$archive_path" | cut -f1)
            success "Backup compressed to $archive_path ($archive_size)"
            
            # Update backup directory reference
            BACKUP_DIR="$archive_path"
        else
            error "Failed to create compressed backup"
        fi
    fi
}

# Cleanup old backups
cleanup_old_backups() {
    log "Cleaning up old backups (older than $RETENTION_DAYS days)..."
    
    if [ -d "$BACKUP_ROOT" ]; then
        # Remove old backup directories
        find "$BACKUP_ROOT" -maxdepth 1 -type d -name "20*" -mtime +$RETENTION_DAYS -exec rm -rf {} \;
        
        # Remove old backup archives
        find "$BACKUP_ROOT" -name "proxyfarm_backup_*.tar.gz" -mtime +$RETENTION_DAYS -delete
        
        local remaining_backups=$(find "$BACKUP_ROOT" -maxdepth 1 \( -type d -name "20*" -o -name "*.tar.gz" \) | wc -l)
        success "Cleanup completed. $remaining_backups backups remaining"
    fi
}

# Send backup notification
send_notification() {
    local backup_size=""
    
    if [ -f "$BACKUP_DIR" ]; then
        # Compressed backup
        backup_size=$(du -h "$BACKUP_DIR" | cut -f1)
    elif [ -d "$BACKUP_DIR" ]; then
        # Uncompressed backup
        backup_size=$(du -sh "$BACKUP_DIR" | cut -f1)
    fi
    
    local notification="ProxyFarm backup completed successfully
Backup Date: $(date)
Backup Size: $backup_size
Location: $BACKUP_DIR"
    
    # Log notification
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $notification" >> "$PROJECT_ROOT/logs/system/backup.log"
    
    # Send to alert system (if configured)
    if [ -f "$PROJECT_ROOT/send-alerts.sh" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $notification" >> "$PROJECT_ROOT/logs/system/alerts.log"
    fi
}

# Main backup function
main() {
    echo -e "${BLUE}🗄️  Starting ProxyFarm System Backup${NC}"
    echo -e "${BLUE}====================================${NC}"
    
    # Check if backup root exists
    if [ ! -d "$BACKUP_ROOT" ]; then
        log "Creating backup root directory: $BACKUP_ROOT"
        mkdir -p "$BACKUP_ROOT"
    fi
    
    # Check disk space
    local available_space=$(df "$BACKUP_ROOT" | awk 'NR==2 {print $4}')
    local required_space=$(du -s "$PROJECT_ROOT" | awk '{print $1}')
    
    if [ "$available_space" -lt "$((required_space * 2))" ]; then
        error "Insufficient disk space for backup"
        exit 1
    fi
    
    create_backup_dir
    backup_configs
    backup_application
    backup_logs
    backup_database
    create_manifest
    compress_backup
    cleanup_old_backups
    send_notification
    
    echo ""
    success "Backup completed successfully!"
    echo -e "${BLUE}📍 Backup location: $BACKUP_DIR${NC}"
    
    if [ -f "$BACKUP_DIR" ]; then
        echo -e "${BLUE}📦 Backup size: $(du -h "$BACKUP_DIR" | cut -f1)${NC}"
    elif [ -d "$BACKUP_DIR" ]; then
        echo -e "${BLUE}📦 Backup size: $(du -sh "$BACKUP_DIR" | cut -f1)${NC}"
    fi
}

# Handle command line arguments
case "${1:-}" in
    --include-logs)
        INCLUDE_LOGS=true
        main
        ;;
    --no-compress)
        COMPRESS_BACKUPS=false
        main
        ;;
    --retention)
        if [ -n "$2" ]; then
            RETENTION_DAYS="$2"
            shift 2
            main "$@"
        else
            error "Please specify retention days: --retention 30"
            exit 1
        fi
        ;;
    --help)
        echo "ProxyFarm System Backup Tool"
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --include-logs     Include log files in backup"
        echo "  --no-compress      Don't compress backup archive"
        echo "  --retention DAYS   Set backup retention period (default: 30)"
        echo "  --help             Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0                          # Standard backup"
        echo "  $0 --include-logs           # Backup with logs"
        echo "  $0 --no-compress            # Uncompressed backup"
        echo "  $0 --retention 60           # Keep backups for 60 days"
        ;;
    *)
        main
        ;;
esac