#!/bin/bash
# 3proxy Auto-installer for Ubuntu/Debian
# This script downloads, compiles and installs 3proxy into the project directory

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$SCRIPT_DIR"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}3proxy Auto-Installer for Proxy Farm${NC}"
echo -e "${GREEN}========================================${NC}"
echo

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
       echo -e "${YELLOW}This script should not be run as root!${NC}"
       echo "Please run as normal user with sudo privileges."
       exit 1
    fi
}

# Function to install dependencies
install_dependencies() {
    echo -e "${GREEN}[1/5] Installing build dependencies...${NC}"
    sudo apt-get update
    sudo apt-get install -y \
        build-essential \
        git \
        wget \
        curl \
        libssl-dev \
        make \
        gcc \
        g++ \
        tar
}

# Function to download 3proxy
download_3proxy() {
    echo -e "${GREEN}[2/5] Downloading 3proxy source...${NC}"
    
    # Create temp directory
    TEMP_DIR="$PROJECT_ROOT/temp_3proxy_build"
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # Download latest stable version
    PROXY_VERSION="0.9.4"  # Update this to latest version if needed
    wget -O 3proxy.tar.gz "https://github.com/3proxy/3proxy/archive/refs/tags/${PROXY_VERSION}.tar.gz"
    
    # Extract
    tar -xzf 3proxy.tar.gz
    cd "3proxy-${PROXY_VERSION}"
}

# Function to compile 3proxy
compile_3proxy() {
    echo -e "${GREEN}[3/5] Compiling 3proxy...${NC}"
    
    # Clean any previous builds
    make clean || true
    
    # Compile with Linux settings
    make -f Makefile.Linux
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Compilation failed!${NC}"
        exit 1
    fi
}

# Function to install 3proxy to project
install_3proxy() {
    echo -e "${GREEN}[4/5] Installing 3proxy to project...${NC}"
    
    # Create bin directory in project
    mkdir -p "$PROJECT_ROOT/bin"
    
    # Copy compiled binary
    cp src/3proxy "$PROJECT_ROOT/bin/"
    chmod +x "$PROJECT_ROOT/bin/3proxy"
    
    # Copy other useful binaries
    for binary in proxy socks ftppr pop3p tcppm udppm mycrypt; do
        if [ -f "src/$binary" ]; then
            cp "src/$binary" "$PROJECT_ROOT/bin/"
            chmod +x "$PROJECT_ROOT/bin/$binary"
        fi
    done
    
    # Create systemd service file
    create_systemd_service
    
    # Clean up temp directory
    cd "$PROJECT_ROOT"
    rm -rf "$TEMP_DIR"
}

# Function to create systemd service
create_systemd_service() {
    echo -e "${GREEN}[5/5] Creating systemd service...${NC}"
    
    # Create service file
    cat > "$PROJECT_ROOT/3proxy.service" << EOF
[Unit]
Description=3proxy Proxy Server
After=network.target

[Service]
Type=simple
ExecStart=$PROJECT_ROOT/bin/3proxy $PROJECT_ROOT/configs/3proxy/3proxy.cfg
ExecReload=/bin/kill -SIGUSR1 \$MAINPID
Restart=on-failure
RestartSec=5
User=$(whoami)
Group=$(whoami)

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$PROJECT_ROOT/logs

[Install]
WantedBy=multi-user.target
EOF

    echo -e "${YELLOW}Systemd service file created at: $PROJECT_ROOT/3proxy.service${NC}"
    echo -e "${YELLOW}To install as system service, run:${NC}"
    echo "sudo cp $PROJECT_ROOT/3proxy.service /etc/systemd/system/"
    echo "sudo systemctl daemon-reload"
    echo "sudo systemctl enable 3proxy"
    echo "sudo systemctl start 3proxy"
}

# Function to create start/stop scripts
create_control_scripts() {
    # Create start script
    cat > "$PROJECT_ROOT/start-3proxy.sh" << 'EOF'
#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

echo "Starting 3proxy..."

# Kill any existing 3proxy process
pkill -f 3proxy || true

# Ensure log directory exists
mkdir -p "$SCRIPT_DIR/logs/3proxy"

# Start 3proxy
"$SCRIPT_DIR/bin/3proxy" "$SCRIPT_DIR/configs/3proxy/3proxy.cfg"

# Check if started
sleep 2
if pgrep -f 3proxy > /dev/null; then
    echo "3proxy started successfully!"
    echo "PID: $(pgrep -f 3proxy)"
else
    echo "Failed to start 3proxy!"
    exit 1
fi
EOF
    chmod +x "$PROJECT_ROOT/start-3proxy.sh"
    
    # Create stop script
    cat > "$PROJECT_ROOT/stop-3proxy.sh" << 'EOF'
#!/bin/bash
echo "Stopping 3proxy..."
pkill -f 3proxy || true
echo "3proxy stopped."
EOF
    chmod +x "$PROJECT_ROOT/stop-3proxy.sh"
    
    # Create status script
    cat > "$PROJECT_ROOT/status-3proxy.sh" << 'EOF'
#!/bin/bash
if pgrep -f 3proxy > /dev/null; then
    echo "3proxy is running (PID: $(pgrep -f 3proxy))"
    echo ""
    echo "Listening ports:"
    netstat -tlnp 2>/dev/null | grep 3proxy || sudo netstat -tlnp | grep 3proxy
else
    echo "3proxy is not running"
fi
EOF
    chmod +x "$PROJECT_ROOT/status-3proxy.sh"
}

# Function to test installation
test_installation() {
    echo
    echo -e "${GREEN}Testing 3proxy installation...${NC}"
    
    # Check binary
    if [ -x "$PROJECT_ROOT/bin/3proxy" ]; then
        echo -e "${GREEN}✓ 3proxy binary installed successfully${NC}"
        "$PROJECT_ROOT/bin/3proxy" --version || true
    else
        echo -e "${RED}✗ 3proxy binary not found or not executable${NC}"
        exit 1
    fi
}

# Main installation flow
main() {
    check_root
    install_dependencies
    download_3proxy
    compile_3proxy
    install_3proxy
    create_control_scripts
    test_installation
    
    echo
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}3proxy installation completed!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    echo "3proxy binary location: $PROJECT_ROOT/bin/3proxy"
    echo
    echo "Control scripts:"
    echo "  - Start: ./start-3proxy.sh"
    echo "  - Stop:  ./stop-3proxy.sh"
    echo "  - Status: ./status-3proxy.sh"
    echo
    echo "To start 3proxy now, run:"
    echo "  ./start-3proxy.sh"
    echo
}

# Run main function
main