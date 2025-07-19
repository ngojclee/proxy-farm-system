#!/bin/bash
# Firewall and Security Configuration for Proxy Farm

set -e

echo "=== Setting up UFW Firewall and Security ==="

# Install required packages
echo "📝 Installing security packages..."
apt update
apt install -y ufw fail2ban iptables-persistent

echo "📝 Configuring UFW firewall..."

# Reset UFW to clean state
ufw --force reset

# Set default policies
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (with rate limiting)
ufw allow ssh
ufw limit ssh comment "SSH with rate limiting"

# Allow proxy ports (assuming 20 proxies from port 3128-3147)
ufw allow 3128:3147/tcp comment "3proxy ports"

# Allow web management interface
ufw allow 3000/tcp comment "Web UI"
ufw allow 8080/tcp comment "API server"

# Advanced iptables rules for proxy protection
echo "📝 Adding advanced iptables rules..."

# Rate limiting for proxy ports (max 20 new connections per minute per IP)
iptables -A INPUT -p tcp --dport 3128:3147 -m state --state NEW -m recent --set --name proxy_rate
iptables -A INPUT -p tcp --dport 3128:3147 -m state --state NEW -m recent --update --seconds 60 --hitcount 20 --name proxy_rate -j DROP

# Block common attack patterns
iptables -A INPUT -p tcp --dport 3128:3147 -m string --string "CONNECT " --algo bm -m recent --set --name malicious
iptables -A INPUT -p tcp --dport 3128:3147 -m recent --name malicious --update --seconds 600 --hitcount 5 -j DROP

# Save iptables rules
iptables-save > /etc/iptables/rules.v4

echo "📝 Configuring fail2ban..."

# Configure fail2ban for SSH and proxy
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
backend = systemd

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
maxretry = 3
bantime = 7200

[3proxy]
enabled = true
port = 3128:3147
logpath = /var/log/3proxy/3proxy.log
maxretry = 10
findtime = 300
bantime = 1800
filter = 3proxy
EOF

# Create 3proxy filter for fail2ban
cat > /etc/fail2ban/filter.d/3proxy.conf << 'EOF'
[Definition]
failregex = ^.* <HOST>.*407.*$
            ^.* <HOST>.*403.*$
            ^.* <HOST>.*Bad Request.*$
ignoreregex =
EOF

# Enable UFW
ufw --force enable

# Enable and start fail2ban
systemctl enable fail2ban
systemctl restart fail2ban

echo "✅ Firewall and security configured"
echo ""
echo "🔒 Security summary:"
echo "   - UFW firewall: Enabled"
echo "   - SSH: Protected with rate limiting"
echo "   - Proxy ports: 3128-3147 allowed"
echo "   - Web interface: 3000, 8080 allowed"
echo "   - Fail2ban: Monitoring SSH and proxy attempts"
echo "   - Rate limiting: 20 connections/minute per IP"
