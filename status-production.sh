#!/bin/bash

# ProxyFarm System - Production Status Script

PROJECT_ROOT="/home/proxy-farm-system"
PID_FILE="$PROJECT_ROOT/logs/webapp/gunicorn.pid"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📊 ProxyFarm System Status${NC}"
echo -e "${BLUE}=========================${NC}"

# Check PID file
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    echo -e "${BLUE}📍 PID File: ${GREEN}Found${NC} (PID: $PID)"
    
    # Check if process is running
    if ps -p $PID > /dev/null; then
        echo -e "${BLUE}🔄 Process: ${GREEN}Running${NC}"
        
        # Get process info
        MEMORY=$(ps -p $PID -o rss= | awk '{print $1/1024 " MB"}')
        CPU=$(ps -p $PID -o %cpu= | awk '{print $1"%"}')
        START_TIME=$(ps -p $PID -o lstart= | awk '{print $2, $3, $4}')
        
        echo -e "${BLUE}💾 Memory Usage: ${YELLOW}$MEMORY${NC}"
        echo -e "${BLUE}⚡ CPU Usage: ${YELLOW}$CPU${NC}"
        echo -e "${BLUE}🕐 Started: ${YELLOW}$START_TIME${NC}"
        
        # Check listening ports
        LISTENING_PORTS=$(netstat -tlnp 2>/dev/null | grep "$PID" | awk '{print $4}' | cut -d: -f2 | sort | uniq | tr '\n' ' ')
        if [ ! -z "$LISTENING_PORTS" ]; then
            echo -e "${BLUE}🌐 Listening Ports: ${GREEN}$LISTENING_PORTS${NC}"
        fi
        
    else
        echo -e "${BLUE}🔄 Process: ${RED}Not Running${NC} (stale PID file)"
    fi
else
    echo -e "${BLUE}📍 PID File: ${RED}Not Found${NC}"
    echo -e "${BLUE}🔄 Process: ${RED}Not Running${NC}"
fi

# Check for any gunicorn processes
GUNICORN_PROCESSES=$(pgrep -f "gunicorn.*app:app" | wc -l)
if [ $GUNICORN_PROCESSES -gt 0 ]; then
    echo -e "${BLUE}👥 Gunicorn Processes: ${GREEN}$GUNICORN_PROCESSES${NC}"
    pgrep -f "gunicorn.*app:app" | while read pid; do
        MEMORY=$(ps -p $pid -o rss= | awk '{print $1/1024 " MB"}')
        CPU=$(ps -p $pid -o %cpu= | awk '{print $1"%"}')
        echo -e "${BLUE}   └── PID $pid: Memory: $MEMORY, CPU: $CPU${NC}"
    done
else
    echo -e "${BLUE}👥 Gunicorn Processes: ${RED}None${NC}"
fi

# Check log files
echo -e "\n${BLUE}📝 Recent Logs:${NC}"
ACCESS_LOG="$PROJECT_ROOT/logs/webapp/access.log"
ERROR_LOG="$PROJECT_ROOT/logs/webapp/error.log"

if [ -f "$ACCESS_LOG" ]; then
    echo -e "${BLUE}📄 Access Log (last 3 lines):${NC}"
    tail -n 3 "$ACCESS_LOG" | sed 's/^/   /'
fi

if [ -f "$ERROR_LOG" ]; then
    echo -e "${BLUE}❌ Error Log (last 3 lines):${NC}"
    tail -n 3 "$ERROR_LOG" | sed 's/^/   /'
fi

# Check network connectivity
echo -e "\n${BLUE}🌐 Network Status:${NC}"
if netstat -tlnp 2>/dev/null | grep -q ":5000"; then
    echo -e "${BLUE}🔗 Port 5000: ${GREEN}Open${NC}"
else
    echo -e "${BLUE}🔗 Port 5000: ${RED}Closed${NC}"
fi

# Check disk space
DISK_USAGE=$(df -h "$PROJECT_ROOT" | awk 'NR==2 {print $5}')
echo -e "${BLUE}💽 Disk Usage: ${YELLOW}$DISK_USAGE${NC}"

echo -e "\n${BLUE}📋 Management Commands:${NC}"
echo -e "   ${GREEN}./start-production.sh${NC}    - Start service"
echo -e "   ${GREEN}./stop-production.sh${NC}     - Stop service"
echo -e "   ${GREEN}./restart-production.sh${NC}  - Restart service"
echo -e "   ${GREEN}tail -f logs/webapp/access.log${NC} - View live access logs"
echo -e "   ${GREEN}tail -f logs/webapp/error.log${NC}  - View live error logs"