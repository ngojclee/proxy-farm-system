#!/bin/bash

# ProxyFarm System - Production Restart Script

set -e

PROJECT_ROOT="/home/proxy-farm-system"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔄 Restarting ProxyFarm System...${NC}"

# Stop the service
./stop-production.sh

# Wait a moment
sleep 2

# Start the service
./start-production.sh

echo -e "${GREEN}✅ ProxyFarm System restarted successfully!${NC}"