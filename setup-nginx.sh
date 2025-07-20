#!/bin/bash

# ProxyFarm System - Nginx Setup Script
# Run as root: sudo ./setup-nginx.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🌐 Setting up Nginx for ProxyFarm System${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Please run as root: sudo ./setup-nginx.sh${NC}"
    exit 1
fi

# Install Nginx
echo -e "${BLUE}📦 Installing Nginx...${NC}"
apt update
apt install -y nginx

# Stop nginx if running
systemctl stop nginx 2>/dev/null || true

# Backup existing default config
if [ -f "/etc/nginx/sites-enabled/default" ]; then
    echo -e "${YELLOW}📋 Backing up default nginx config...${NC}"
    mv /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/default.backup
fi

# Copy our config
echo -e "${BLUE}📝 Installing ProxyFarm nginx config...${NC}"
cp nginx-proxyfarm.conf /etc/nginx/sites-available/proxyfarm

# Create symlink to enable site
ln -sf /etc/nginx/sites-available/proxyfarm /etc/nginx/sites-enabled/

# Test nginx configuration
echo -e "${BLUE}🔍 Testing nginx configuration...${NC}"
nginx -t

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Nginx configuration is valid${NC}"
    
    # Enable and start nginx
    systemctl enable nginx
    systemctl start nginx
    
    echo -e "${GREEN}🚀 Nginx started successfully!${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  Important Configuration Steps:${NC}"
    echo -e "${BLUE}1. Update server_name in /etc/nginx/sites-available/proxyfarm${NC}"
    echo -e "${BLUE}2. Install SSL certificate (recommended):${NC}"
    echo -e "   ${GREEN}sudo apt install certbot python3-certbot-nginx${NC}"
    echo -e "   ${GREEN}sudo certbot --nginx -d your-domain.com${NC}"
    echo -e "${BLUE}3. Update firewall rules:${NC}"
    echo -e "   ${GREEN}sudo ufw allow 'Nginx Full'${NC}"
    echo -e "${BLUE}4. Reload nginx after SSL setup:${NC}"
    echo -e "   ${GREEN}sudo systemctl reload nginx${NC}"
    echo ""
    echo -e "${BLUE}📊 Service Status:${NC}"
    systemctl status nginx --no-pager -l
    
else
    echo -e "${RED}❌ Nginx configuration test failed${NC}"
    echo -e "${YELLOW}Please check the configuration file and try again${NC}"
    exit 1
fi