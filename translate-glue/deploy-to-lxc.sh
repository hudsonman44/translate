#!/bin/bash

# LXC Deployment Script for FFmpeg Translation Middleware
# This script helps deploy the application to a Proxmox LXC container

echo "=== FFmpeg Translation Middleware LXC Deployment ==="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root or with sudo"
    exit 1
fi

# Update system packages
echo "Updating system packages..."
apt-get update

# Install Node.js 18
echo "Installing Node.js 18..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# Install FFmpeg
echo "Installing FFmpeg..."
apt-get install -y ffmpeg

# Install PM2 for process management
echo "Installing PM2..."
npm install -g pm2

# Create application directory
APP_DIR="/opt/ffmpeg-translation-middleware"
echo "Creating application directory: $APP_DIR"
mkdir -p $APP_DIR

# Copy application files (assuming this script is run from the app directory)
echo "Copying application files..."
cp -r . $APP_DIR/
cd $APP_DIR

# Install dependencies
echo "Installing Node.js dependencies..."
npm install --production

# Create necessary directories
mkdir -p uploads converted logs

# Set proper permissions
chown -R www-data:www-data $APP_DIR
chmod -R 755 $APP_DIR

# Create systemd service file
echo "Creating systemd service..."
cat > /etc/systemd/system/ffmpeg-translation.service << EOF
[Unit]
Description=FFmpeg Translation Middleware
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=PORT=3001

# Logging
StandardOutput=append:/var/log/ffmpeg-translation.log
StandardError=append:/var/log/ffmpeg-translation-error.log

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable service
systemctl daemon-reload
systemctl enable ffmpeg-translation.service

# Start the service
echo "Starting FFmpeg Translation Middleware..."
systemctl start ffmpeg-translation.service

# Check service status
echo "Service status:"
systemctl status ffmpeg-translation.service --no-pager

# Setup firewall rule (if ufw is installed)
if command -v ufw &> /dev/null; then
    echo "Opening port 3001 in firewall..."
    ufw allow 3001
fi

echo ""
echo "=== Deployment Complete ==="
echo "Service is running on port 3001"
echo "Health check: curl http://localhost:3001/health"
echo "API endpoint: http://localhost:3001/api/process-and-translate"
echo ""
echo "To check logs: journalctl -u ffmpeg-translation.service -f"
echo "To restart service: systemctl restart ffmpeg-translation.service"
echo "To stop service: systemctl stop ffmpeg-translation.service"
