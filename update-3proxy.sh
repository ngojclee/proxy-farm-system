#!/bin/bash
# Script to update 3proxy to latest version

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

echo -e "${GREEN}3proxy Update Script${NC}"
echo "===================="

# Check current version
if [ -f "$SCRIPT_DIR/bin/3proxy" ]; then
    echo "Current 3proxy installation found"
    "$SCRIPT_DIR/bin/3proxy" --version 2>/dev/null || echo "Version info not available"
else
    echo -e "${RED}3proxy not installed! Run install-3proxy.sh first.${NC}"
    exit 1
fi

# Get latest version from GitHub
echo
echo "Checking for latest version..."
LATEST_VERSION=$(curl -s https://api.github.com/repos/3proxy/3proxy/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

echo "Latest version available: $LATEST_VERSION"
echo

read -p "Update to version $LATEST_VERSION? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Update cancelled."
    exit 0
fi

# Backup current binary
echo -e "${YELLOW}Backing up current binary...${NC}"
cp "$SCRIPT_DIR/bin/3proxy" "$SCRIPT_DIR/bin/3proxy.backup.$(date +%Y%m%d_%H%M%S)"

# Stop 3proxy if running
echo "Stopping 3proxy..."
pkill -f 3proxy || true
sudo supervisorctl stop proxyfarm-3proxy 2>/dev/null || true

# Download and compile new version
echo -e "${GREEN}Downloading and compiling new version...${NC}"

TEMP_DIR="$SCRIPT_DIR/temp_3proxy_update"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# Download
wget -O 3proxy.tar.gz "https://github.com/3proxy/3proxy/archive/refs/tags/${LATEST_VERSION}.tar.gz"
tar -xzf 3proxy.tar.gz
cd "3proxy-${LATEST_VERSION#v}"  # Remove 'v' prefix if present

# Compile
make -f Makefile.Linux

# Install new binary
echo -e "${GREEN}Installing new binary...${NC}"
cp src/3proxy "$SCRIPT_DIR/bin/"
chmod +x "$SCRIPT_DIR/bin/3proxy"

# Copy other binaries
for binary in proxy socks ftppr pop3p tcppm udppm mycrypt; do
    if [ -f "src/$binary" ]; then
        cp "src/$binary" "$SCRIPT_DIR/bin/"
        chmod +x "$SCRIPT_DIR/bin/$binary"
    fi
done

# Clean up
cd "$SCRIPT_DIR"
rm -rf "$TEMP_DIR"

# Restart 3proxy
echo -e "${GREEN}Starting updated 3proxy...${NC}"
sudo supervisorctl start proxyfarm-3proxy 2>/dev/null || "$SCRIPT_DIR/start-3proxy.sh"

echo
echo -e "${GREEN}Update completed successfully!${NC}"
echo "New version:"
"$SCRIPT_DIR/bin/3proxy" --version 2>/dev/null || echo "Version: $LATEST_VERSION"