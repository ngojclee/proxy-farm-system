# Makefile for Proxy Farm System
# Easy management commands

.PHONY: help install install-3proxy update-3proxy start stop restart status logs clean test backup

# Default target
help:
	@echo "Proxy Farm System - Management Commands"
	@echo "======================================"
	@echo "Installation:"
	@echo "  make install        - Full installation on Ubuntu/Debian"
	@echo "  make install-3proxy - Install only 3proxy"
	@echo ""
	@echo "Service Management:"
	@echo "  make start          - Start all services"
	@echo "  make stop           - Stop all services"
	@echo "  make restart        - Restart all services"
	@echo "  make status         - Check system status"
	@echo ""
	@echo "Maintenance:"
	@echo "  make update-3proxy  - Update 3proxy to latest version"
	@echo "  make logs           - Show recent logs"
	@echo "  make clean          - Clean temporary files"
	@echo "  make backup         - Backup configuration"
	@echo "  make test           - Test proxy connectivity"

# Full installation
install:
	@chmod +x install-ubuntu.sh
	@./install-ubuntu.sh

# Install only 3proxy
install-3proxy:
	@chmod +x install-3proxy.sh
	@./install-3proxy.sh

# Update 3proxy
update-3proxy:
	@chmod +x update-3proxy.sh
	@./update-3proxy.sh

# Start services
start:
	@if [ -f start-all.sh ]; then \
		./start-all.sh; \
	else \
		echo "Starting services manually..."; \
		sudo supervisorctl start proxyfarm-webapp proxyfarm-3proxy 2>/dev/null || true; \
		./start-3proxy.sh 2>/dev/null || true; \
		cd webapp && ../venv/bin/python app.py & \
	fi

# Stop services
stop:
	@if [ -f stop-all.sh ]; then \
		./stop-all.sh; \
	else \
		echo "Stopping services manually..."; \
		sudo supervisorctl stop proxyfarm-webapp proxyfarm-3proxy 2>/dev/null || true; \
		pkill -f 3proxy || true; \
		pkill -f "python.*app.py" || true; \
	fi

# Restart services
restart: stop start

# Check status
status:
	@if [ -f status.sh ]; then \
		./status.sh; \
	else \
		echo "=== Service Status ==="; \
		pgrep -f 3proxy > /dev/null && echo "3proxy: Running" || echo "3proxy: Stopped"; \
		pgrep -f "python.*app.py" > /dev/null && echo "Webapp: Running" || echo "Webapp: Stopped"; \
		echo ""; \
		echo "=== Listening Ports ==="; \
		netstat -tlnp 2>/dev/null | grep -E ":(5000|333[0-9])" || sudo netstat -tlnp | grep -E ":(5000|333[0-9])"; \
	fi

# Show logs
logs:
	@if [ -f show-logs.sh ]; then \
		./show-logs.sh; \
	else \
		echo "=== Recent Logs ==="; \
		echo "3proxy logs:"; \
		tail -n 20 logs/3proxy/3proxy.log 2>/dev/null || echo "No logs available"; \
		echo ""; \
		echo "Webapp logs:"; \
		tail -n 20 logs/webapp/access.log 2>/dev/null || echo "No logs available"; \
	fi

# Clean temporary files
clean:
	@echo "Cleaning temporary files..."
	@find . -type f -name "*.pyc" -delete
	@find . -type f -name "*.pyo" -delete
	@find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name ".DS_Store" -delete 2>/dev/null || true
	@rm -rf temp_3proxy_* 2>/dev/null || true
	@echo "Cleanup completed!"

# Test proxy
test:
	@echo "=== Testing Proxy Connectivity ==="
	@echo "Testing HTTP proxy on port 3330..."
	@curl -s --connect-timeout 5 --proxy-user admin:admin123 -x localhost:3330 http://httpbin.org/ip | python3 -m json.tool || echo "HTTP proxy test failed!"
	@echo ""
	@echo "Testing SOCKS5 proxy on port 3335..."
	@curl -s --connect-timeout 5 --socks5 admin:admin123@localhost:3335 http://httpbin.org/ip | python3 -m json.tool || echo "SOCKS5 proxy test failed!"
	@echo ""
	@echo "Testing no-auth HTTP proxy on port 3338..."
	@curl -s --connect-timeout 5 -x localhost:3338 http://httpbin.org/ip | python3 -m json.tool || echo "No-auth proxy test failed!"

# Backup configuration
backup:
	@echo "Creating backup..."
	@BACKUP_NAME="backup_$$(date +%Y%m%d_%H%M%S).tar.gz"; \
	tar -czf "$$BACKUP_NAME" \
		configs/ \
		webapp/templates/ \
		webapp/static/ \
		webapp/app.py \
		*.sh \
		Makefile \
		README*.md \
		--exclude='*.pyc' \
		--exclude='__pycache__' && \
	echo "Backup created: $$BACKUP_NAME"

# Development mode
dev:
	@echo "Starting in development mode..."
	@cd webapp && FLASK_ENV=development FLASK_DEBUG=1 ../venv/bin/python app.py