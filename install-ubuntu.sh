#!/bin/bash
# Complete installation script for Proxy Farm System on Ubuntu/Debian

set -e  # Exit on error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$SCRIPT_DIR"

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}Proxy Farm System - Ubuntu/Debian Installer${NC}"
echo -e "${BLUE}============================================${NC}"
echo

# Function to check Ubuntu/Debian
check_os() {
    if [[ ! -f /etc/debian_version ]]; then
        echo -e "${RED}This script is designed for Ubuntu/Debian systems only!${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Detected Debian-based system${NC}"
}

# Function to install system dependencies
install_system_deps() {
    echo -e "${GREEN}[Step 1/7] Installing system dependencies...${NC}"
    
    sudo apt-get update
    sudo apt-get install -y \
        python3 \
        python3-pip \
        python3-venv \
        git \
        curl \
        wget \
        net-tools \
        build-essential \
        libssl-dev \
        nginx \
        supervisor \
        ufw \
        htop \
        iptables \
        fail2ban
}

# Function to setup Python environment
setup_python_env() {
    echo -e "${GREEN}[Step 2/7] Setting up Python environment...${NC}"
    
    cd "$PROJECT_ROOT"
    
    # Create virtual environment
    python3 -m venv venv
    
    # Activate and install requirements
    source venv/bin/activate
    
    # Create requirements.txt if not exists
    if [ ! -f requirements.txt ]; then
        cat > requirements.txt << EOF
flask==2.3.2
python-dotenv==1.0.0
requests==2.31.0
gunicorn==21.2.0
EOF
    fi
    
    pip install --upgrade pip
    pip install -r requirements.txt
}

# Function to install 3proxy
install_3proxy() {
    echo -e "${GREEN}[Step 3/7] Installing 3proxy...${NC}"
    
    # Make install script executable
    chmod +x "$PROJECT_ROOT/install-3proxy.sh"
    
    # Run 3proxy installer
    "$PROJECT_ROOT/install-3proxy.sh"
}

# Function to configure firewall
configure_firewall() {
    echo -e "${GREEN}[Step 4/7] Configuring firewall...${NC}"
    
    # Enable UFW
    sudo ufw --force enable
    
    # Allow SSH (important!)
    sudo ufw allow 22/tcp
    
    # Allow web interface
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    sudo ufw allow 5000/tcp
    
    # Allow proxy ports
    for port in 3330 3331 3332 3333 3334 3335 3336 3337 3338 3339; do
        sudo ufw allow $port/tcp
    done
    
    echo -e "${GREEN}✓ Firewall configured${NC}"
}

# Function to setup Nginx
setup_nginx() {
    echo -e "${GREEN}[Step 5/7] Configuring Nginx...${NC}"
    
    # Create Nginx config
    sudo tee /etc/nginx/sites-available/proxyfarm << EOF
server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://localhost:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    location /static {
        alias $PROJECT_ROOT/webapp/static;
    }
}
EOF
    
    # Enable site
    sudo ln -sf /etc/nginx/sites-available/proxyfarm /etc/nginx/sites-enabled/
    sudo rm -f /etc/nginx/sites-enabled/default
    
    # Test and reload Nginx
    sudo nginx -t
    sudo systemctl restart nginx
}

# Function to setup supervisor
setup_supervisor() {
    echo -e "${GREEN}[Step 6/7] Setting up Supervisor...${NC}"
    
    # Create supervisor config for webapp
    sudo tee /etc/supervisor/conf.d/proxyfarm-webapp.conf << EOF
[program:proxyfarm-webapp]
command=$PROJECT_ROOT/venv/bin/gunicorn -w 4 -b 127.0.0.1:5000 app:app
directory=$PROJECT_ROOT/webapp
user=$USER
autostart=true
autorestart=true
stderr_logfile=$PROJECT_ROOT/logs/webapp/error.log
stdout_logfile=$PROJECT_ROOT/logs/webapp/access.log
environment=PATH="$PROJECT_ROOT/venv/bin",FLASK_ENV="production"
EOF

    # Create supervisor config for 3proxy
    sudo tee /etc/supervisor/conf.d/proxyfarm-3proxy.conf << EOF
[program:proxyfarm-3proxy]
command=$PROJECT_ROOT/bin/3proxy $PROJECT_ROOT/configs/3proxy/3proxy.cfg
directory=$PROJECT_ROOT
user=$USER
autostart=true
autorestart=true
stderr_logfile=$PROJECT_ROOT/logs/3proxy/error.log
stdout_logfile=$PROJECT_ROOT/logs/3proxy/access.log
EOF

    # Create log directories
    mkdir -p "$PROJECT_ROOT/logs/webapp"
    mkdir -p "$PROJECT_ROOT/logs/3proxy"
    
    # Reload supervisor
    sudo supervisorctl reread
    sudo supervisorctl update
}

# Function to create management scripts
create_management_scripts() {
    echo -e "${GREEN}[Step 7/7] Creating management scripts...${NC}"
    
    # Start all script
    cat > "$PROJECT_ROOT/start-all.sh" << 'EOF'
#!/bin/bash
echo "Starting Proxy Farm System..."
sudo supervisorctl start proxyfarm-webapp proxyfarm-3proxy
sudo systemctl start nginx
echo "System started!"
echo "Access dashboard at: http://$(hostname -I | awk '{print $1}')"
EOF
    chmod +x "$PROJECT_ROOT/start-all.sh"
    
    # Stop all script
    cat > "$PROJECT_ROOT/stop-all.sh" << 'EOF'
#!/bin/bash
echo "Stopping Proxy Farm System..."
sudo supervisorctl stop proxyfarm-webapp proxyfarm-3proxy
echo "System stopped!"
EOF
    chmod +x "$PROJECT_ROOT/stop-all.sh"
    
    # Status script
    cat > "$PROJECT_ROOT/status.sh" << 'EOF'
#!/bin/bash
echo "=== Proxy Farm System Status ==="
echo
echo "Supervisor services:"
sudo supervisorctl status | grep proxyfarm
echo
echo "Nginx status:"
sudo systemctl status nginx --no-pager | grep Active
echo
echo "Listening ports:"
sudo netstat -tlnp | grep -E ":(5000|3330|3331|3332|3333|3334|3335|3336|3337|3338|3339|80)"
echo
echo "System resources:"
free -h | grep Mem
df -h | grep -E "/$|/home"
echo
echo "Dashboard URL: http://$(hostname -I | awk '{print $1}')"
EOF
    chmod +x "$PROJECT_ROOT/status.sh"
    
    # Logs script
    cat > "$PROJECT_ROOT/show-logs.sh" << 'EOF'
#!/bin/bash
echo "=== Recent logs ==="
echo
echo "Webapp logs:"
tail -n 20 logs/webapp/access.log 2>/dev/null || echo "No webapp logs yet"
echo
echo "3proxy logs:"
tail -n 20 logs/3proxy/3proxy.log 2>/dev/null || echo "No 3proxy logs yet"
EOF
    chmod +x "$PROJECT_ROOT/show-logs.sh"
}

# Function to show final instructions
show_instructions() {
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    echo
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}Installation Completed Successfully!${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo
    echo -e "${BLUE}Access Information:${NC}"
    echo "Dashboard URL: http://$SERVER_IP"
    echo "Username: admin"
    echo "Password: admin123"
    echo
    echo -e "${BLUE}Proxy Endpoints:${NC}"
    echo "HTTP Proxy: $SERVER_IP:3330-3334 (auth required)"
    echo "SOCKS5 Proxy: $SERVER_IP:3335-3337 (auth required)"
    echo "HTTP Proxy: $SERVER_IP:3338 (no auth)"
    echo "SOCKS5 Proxy: $SERVER_IP:3339 (no auth)"
    echo
    echo -e "${BLUE}Management Commands:${NC}"
    echo "./start-all.sh  - Start all services"
    echo "./stop-all.sh   - Stop all services"
    echo "./status.sh     - Check system status"
    echo "./show-logs.sh  - View recent logs"
    echo
    echo -e "${YELLOW}Security Notes:${NC}"
    echo "1. Change default passwords in configs/3proxy/users.conf"
    echo "2. Configure firewall rules for your IPs only"
    echo "3. Enable HTTPS with Let's Encrypt"
    echo
    echo -e "${GREEN}To start the system now, run:${NC}"
    echo "  ./start-all.sh"
    echo
}

# Main installation flow
main() {
    check_os
    install_system_deps
    setup_python_env
    install_3proxy
    configure_firewall
    setup_nginx
    setup_supervisor
    create_management_scripts
    
    # Start services
    echo -e "${GREEN}Starting services...${NC}"
    "$PROJECT_ROOT/start-all.sh"
    
    show_instructions
}

# Confirmation prompt
echo "This script will install Proxy Farm System on Ubuntu/Debian."
echo "It will install: Python3, Nginx, Supervisor, 3proxy, and configure firewall."
echo
read -p "Continue with installation? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 1
fi

# Run installation
main