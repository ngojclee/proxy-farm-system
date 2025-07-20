#!/bin/bash

# ProxyFarm System - Production Stop Script

set -e

PROJECT_ROOT="/home/proxy-farm-system"
PID_FILE="$PROJECT_ROOT/logs/webapp/gunicorn.pid"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🛑 Stopping ProxyFarm System...${NC}"

# Check if PID file exists
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    echo -e "${YELLOW}📍 Found PID: $PID${NC}"
    
    # Check if process is running
    if ps -p $PID > /dev/null; then
        echo -e "${YELLOW}🔄 Stopping Gunicorn process...${NC}"
        kill $PID
        
        # Wait for graceful shutdown
        sleep 3
        
        # Force kill if still running
        if ps -p $PID > /dev/null; then
            echo -e "${YELLOW}⚡ Force killing process...${NC}"
            kill -9 $PID
        fi
        
        rm -f "$PID_FILE"
        echo -e "${GREEN}✅ Process stopped successfully${NC}"
    else
        echo -e "${YELLOW}⚠️  Process not running, removing stale PID file${NC}"
        rm -f "$PID_FILE"
    fi
else
    echo -e "${YELLOW}⚠️  PID file not found${NC}"
fi

# Kill any remaining gunicorn processes
echo -e "${BLUE}🧹 Cleaning up any remaining processes...${NC}"
pkill -f "gunicorn.*app:app" || true

echo -e "${GREEN}🏁 ProxyFarm System stopped${NC}"