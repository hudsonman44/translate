#!/bin/bash

# GitHub-based Installation Script for Translate Glue Middleware
# Usage: curl -fsSL https://raw.githubusercontent.com/YOUR-USERNAME/translate/main/translate-glue/install.sh | sudo bash

set -e

APP_NAME="translate-glue"
GITHUB_USER="hudsonman44"  # Replace with your GitHub username
GITHUB_REPO="translate"      # Replace with your repository name
GITHUB_BRANCH="main"         # Replace with your branch name
INSTALL_DIR="/tmp/$APP_NAME-install"

echo "=== Translate Glue Middleware Installer ==="
echo "Downloading and installing from GitHub..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run as root or with sudo:"
    echo "curl -fsSL https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$GITHUB_BRANCH/translate-glue/install.sh | sudo bash"
    exit 1
fi

# Check Ubuntu version
if ! grep -q "Ubuntu" /etc/os-release; then
    echo "⚠️  Warning: This installer is designed for Ubuntu. Proceeding anyway..."
fi

echo "📋 Installing on: $(lsb_release -d | cut -f2 2>/dev/null || echo 'Unknown Linux Distribution')"

# Install required tools if not present
echo "📦 Installing required tools..."
apt-get update -qq
apt-get install -y curl wget unzip > /dev/null 2>&1

# Create temporary directory
echo "📁 Creating temporary directory..."
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

# Download from GitHub
echo "⬇️  Downloading translate-glue from GitHub..."
GITHUB_URL="https://github.com/$GITHUB_USER/$GITHUB_REPO/archive/$GITHUB_BRANCH.zip"
wget -q -O repo.zip "$GITHUB_URL" || {
    echo "❌ Failed to download from GitHub. Please check:"
    echo "   - GitHub username: $GITHUB_USER"
    echo "   - Repository name: $GITHUB_REPO"
    echo "   - Branch name: $GITHUB_BRANCH"
    echo "   - URL: $GITHUB_URL"
    exit 1
}

# Extract the translate-glue directory
echo "📂 Extracting files..."
unzip -q repo.zip
SOURCE_DIR="$GITHUB_REPO-$GITHUB_BRANCH/translate-glue"

if [ ! -d "$SOURCE_DIR" ]; then
    echo "❌ translate-glue directory not found in the repository"
    echo "Expected path: $SOURCE_DIR"
    ls -la
    exit 1
fi

# Copy translate-glue files
cp -r "$SOURCE_DIR"/* .

# Make scripts executable
chmod +x *.sh

# Run the deployment script
echo "🚀 Running deployment script..."
if [ -f "deploy-ubuntu.sh" ]; then
    ./deploy-ubuntu.sh
else
    echo "❌ deploy-ubuntu.sh not found"
    exit 1
fi

# Cleanup
echo "🧹 Cleaning up temporary files..."
cd /
rm -rf $INSTALL_DIR

echo ""
echo "✅ Installation complete! 🎉"
echo ""
echo "📋 Next steps:"
echo "1. 🔧 Update Cloudflare Worker URL: sudo nano /etc/default/translate-glue"
echo "2. 🌐 Update your frontend to point to this server's IP"
echo "3. 🏥 Test the service: curl http://localhost:3001/health"
echo "4. 📊 Check status: sudo systemctl status translate-glue"
echo ""
echo "📚 Management commands:"
echo "   ./manage-service.sh status   # Check service status"
echo "   ./manage-service.sh logs     # View logs"
echo "   ./manage-service.sh restart  # Restart service"
echo "   ./manage-service.sh health   # Test health endpoint"
