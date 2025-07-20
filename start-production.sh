#!/bin/bash

# ProxyFarm System - Production Startup Script
# Use this to start the system in production mode with Gunicorn

set -e

# Configuration
PROJECT_ROOT="/home/proxy-farm-system"
VENV_PATH="$PROJECT_ROOT/venv"
APP_PATH="$PROJECT_ROOT/webapp/app.py"
WORKERS=4
BIND_ADDRESS="0.0.0.0:5000"
LOG_LEVEL="info"
ACCESS_LOG="$PROJECT_ROOT/logs/webapp/access.log"
ERROR_LOG="$PROJECT_ROOT/logs/webapp/error.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting ProxyFarm System in Production Mode${NC}"

# Check if project directory exists
if [ ! -d "$PROJECT_ROOT" ]; then
    echo -e "${RED}❌ Project directory not found: $PROJECT_ROOT${NC}"
    exit 1
fi

# Navigate to project directory
cd "$PROJECT_ROOT"

# Check if virtual environment exists
if [ ! -d "$VENV_PATH" ]; then
    echo -e "${YELLOW}⚠️  Virtual environment not found. Creating...${NC}"
    python3 -m venv venv
fi

# Activate virtual environment
echo -e "${BLUE}🔧 Activating virtual environment...${NC}"
source "$VENV_PATH/bin/activate"

# Install/upgrade dependencies
echo -e "${BLUE}📦 Installing dependencies...${NC}"
pip install --upgrade pip
pip install flask gunicorn

# Create log directories
echo -e "${BLUE}📂 Creating log directories...${NC}"
mkdir -p logs/webapp
mkdir -p logs/3proxy
mkdir -p logs/system

# Set environment variables
export FLASK_ENV=production
export PYTHONPATH="$PROJECT_ROOT"

# Check if app file exists
if [ ! -f "$APP_PATH" ]; then
    echo -e "${RED}❌ App file not found: $APP_PATH${NC}"
    exit 1
fi

# Kill any existing instances
echo -e "${YELLOW}🔄 Stopping existing instances...${NC}"
pkill -f "gunicorn.*app:app" || true
sleep 2

# Start with Gunicorn
echo -e "${GREEN}🌟 Starting Gunicorn server...${NC}"
echo -e "${BLUE}   Workers: $WORKERS${NC}"
echo -e "${BLUE}   Binding: $BIND_ADDRESS${NC}"
echo -e "${BLUE}   Log Level: $LOG_LEVEL${NC}"
echo -e "${BLUE}   Access Log: $ACCESS_LOG${NC}"
echo -e "${BLUE}   Error Log: $ERROR_LOG${NC}"

gunicorn \
    --workers $WORKERS \
    --bind $BIND_ADDRESS \
    --log-level $LOG_LEVEL \
    --access-logfile "$ACCESS_LOG" \
    --error-logfile "$ERROR_LOG" \
    --timeout 300 \
    --keep-alive 2 \
    --max-requests 1000 \
    --max-requests-jitter 100 \
    --preload \
    --daemon \
    --pid "$PROJECT_ROOT/logs/webapp/gunicorn.pid" \
    --chdir "$PROJECT_ROOT/webapp" \
    app:app

echo -e "${GREEN}✅ ProxyFarm System started successfully!${NC}"
echo -e "${BLUE}🌐 Web interface: http://$(hostname -I | awk '{print $1}'):5000${NC}"
echo -e "${BLUE}📊 Process ID: $(cat $PROJECT_ROOT/logs/webapp/gunicorn.pid)${NC}"
echo -e "${BLUE}📝 Logs: tail -f $ACCESS_LOG${NC}"
echo ""
echo -e "${YELLOW}📋 Management commands:${NC}"
echo -e "   ${GREEN}./stop-production.sh${NC}     - Stop the service"
echo -e "   ${GREEN}./restart-production.sh${NC}  - Restart the service"
echo -e "   ${GREEN}./status-production.sh${NC}   - Check service status"