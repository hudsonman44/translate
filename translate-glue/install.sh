#!/bin/bash

# Quick Installation Script for FFmpeg Translation Middleware on Ubuntu
# This script downloads and installs the application

set -e

APP_NAME="ffmpeg-translation-middleware"
INSTALL_DIR="/tmp/$APP_NAME-install"
GITHUB_URL="https://github.com/your-username/ffmpeg-translation-middleware"  # Update this URL

echo "=== FFmpeg Translation Middleware Installer ==="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root or with sudo:"
    echo "curl -fsSL https://raw.githubusercontent.com/your-username/ffmpeg-translation-middleware/main/install.sh | sudo bash"
    exit 1
fi

# Check Ubuntu version
if ! grep -q "Ubuntu" /etc/os-release; then
    echo "Warning: This installer is designed for Ubuntu. Proceeding anyway..."
fi

echo "Installing on: $(lsb_release -d | cut -f2)"

# Create temporary directory
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

# For now, we'll assume the files are in the current directory
# In a real deployment, you would download from GitHub:
# echo "Downloading application files..."
# wget -O app.tar.gz "$GITHUB_URL/archive/main.tar.gz"
# tar -xzf app.tar.gz --strip-components=1

echo "Running deployment script..."
chmod +x deploy-ubuntu.sh
./deploy-ubuntu.sh

# Cleanup
cd /
rm -rf $INSTALL_DIR

echo ""
echo "Installation complete! 🎉"
echo ""
echo "Next steps:"
echo "1. Update the Cloudflare Worker URL in /etc/default/$APP_NAME"
echo "2. Update your frontend to point to this server's IP"
echo "3. Test the service: curl http://localhost:3001/health"
