#!/bin/bash

# Ubuntu Server Deployment Script for FFmpeg Translation Middleware
# This script deploys the application as a service on Ubuntu Server

set -e  # Exit on any error

echo "=== FFmpeg Translation Middleware Ubuntu Deployment ==="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root or with sudo"
    exit 1
fi

# Get the current directory (where the script is located)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="ffmpeg-translation-middleware"
APP_DIR="/opt/$APP_NAME"
SERVICE_USER="ffmpeg-service"

echo "Script directory: $SCRIPT_DIR"
echo "Target directory: $APP_DIR"

# Update system packages
echo "Updating system packages..."
apt-get update

# Install Node.js 18 LTS
echo "Installing Node.js 18 LTS..."
if ! command -v node &> /dev/null || [[ $(node -v | cut -d'v' -f2 | cut -d'.' -f1) -lt 18 ]]; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
fi

# Install FFmpeg
echo "Installing FFmpeg..."
apt-get install -y ffmpeg

# Verify installations
echo "Verifying installations..."
node_version=$(node -v)
npm_version=$(npm -v)
ffmpeg_version=$(ffmpeg -version | head -n1)

echo "Node.js version: $node_version"
echo "npm version: $npm_version"
echo "FFmpeg version: $ffmpeg_version"

# Create service user
echo "Creating service user: $SERVICE_USER"
if ! id "$SERVICE_USER" &>/dev/null; then
    useradd --system --no-create-home --shell /bin/false $SERVICE_USER
fi

# Create application directory
echo "Creating application directory: $APP_DIR"
mkdir -p $APP_DIR

# Copy application files
echo "Copying application files..."
cp -r $SCRIPT_DIR/* $APP_DIR/
cd $APP_DIR

# Remove deployment scripts from the app directory
rm -f $APP_DIR/deploy-ubuntu.sh $APP_DIR/deploy-to-lxc.sh $APP_DIR/Dockerfile

# Install Node.js dependencies
echo "Installing Node.js dependencies..."
npm install --production --no-optional

# Create necessary directories
echo "Creating working directories..."
mkdir -p uploads converted logs
mkdir -p /var/log/$APP_NAME

# Set proper ownership and permissions
echo "Setting permissions..."
chown -R $SERVICE_USER:$SERVICE_USER $APP_DIR
chown -R $SERVICE_USER:$SERVICE_USER /var/log/$APP_NAME
chmod -R 755 $APP_DIR
chmod -R 755 /var/log/$APP_NAME

# Create environment file
echo "Creating environment configuration..."
cat > /etc/default/$APP_NAME << EOF
# FFmpeg Translation Middleware Environment Configuration
NODE_ENV=production
PORT=3001
CLOUDFLARE_WORKER_URL=https://translate.lab-account-850.workers.dev/api/translate

# Uncomment and modify as needed:
# MAX_FILE_SIZE=104857600  # 100MB in bytes
# UPLOAD_TIMEOUT=300000    # 5 minutes in milliseconds
EOF

# Create systemd service file
echo "Creating systemd service..."
cat > /etc/systemd/system/$APP_NAME.service << EOF
[Unit]
Description=FFmpeg Translation Middleware
Documentation=https://github.com/your-repo/ffmpeg-translation-middleware
After=network.target
Wants=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
TimeoutStopSec=20

# Environment
EnvironmentFile=/etc/default/$APP_NAME

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$APP_DIR /var/log/$APP_NAME

# Logging
StandardOutput=append:/var/log/$APP_NAME/app.log
StandardError=append:/var/log/$APP_NAME/error.log
SyslogIdentifier=$APP_NAME

# Resource limits
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF

# Create log rotation configuration
echo "Setting up log rotation..."
cat > /etc/logrotate.d/$APP_NAME << EOF
/var/log/$APP_NAME/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0644 $SERVICE_USER $SERVICE_USER
    postrotate
        systemctl reload $APP_NAME > /dev/null 2>&1 || true
    endscript
}
EOF

# Setup firewall (if ufw is active)
if systemctl is-active --quiet ufw; then
    echo "Configuring firewall..."
    ufw allow 3001/tcp comment "FFmpeg Translation Middleware"
fi

# Reload systemd and enable service
echo "Enabling and starting service..."
systemctl daemon-reload
systemctl enable $APP_NAME.service
systemctl start $APP_NAME.service

# Wait a moment for service to start
sleep 3

# Check service status
echo ""
echo "=== Service Status ==="
systemctl status $APP_NAME.service --no-pager --lines=10

# Test health endpoint
echo ""
echo "=== Testing Health Endpoint ==="
if curl -f http://localhost:3001/health 2>/dev/null; then
    echo "✅ Health check passed!"
else
    echo "❌ Health check failed. Check logs for details."
fi

echo ""
echo "=== Deployment Complete ==="
echo "Service: $APP_NAME"
echo "Status: systemctl status $APP_NAME"
echo "Logs: journalctl -u $APP_NAME -f"
echo "Config: /etc/default/$APP_NAME"
echo ""
echo "API Endpoints:"
echo "  Health: http://localhost:3001/health"
echo "  Process: http://localhost:3001/api/process-and-translate"
echo ""
echo "Management Commands:"
echo "  Start:   systemctl start $APP_NAME"
echo "  Stop:    systemctl stop $APP_NAME"
echo "  Restart: systemctl restart $APP_NAME"
echo "  Status:  systemctl status $APP_NAME"
echo "  Logs:    journalctl -u $APP_NAME -f"
echo ""
echo "Configuration file: /etc/default/$APP_NAME"
echo "Application directory: $APP_DIR"
echo "Log directory: /var/log/$APP_NAME"
