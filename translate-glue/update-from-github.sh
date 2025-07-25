#!/bin/bash

# Simple update script for translate-glue service from GitHub
# Run this script on your server to pull latest changes and restart service

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "🔄 Updating translate-glue from GitHub"
echo "====================================="

# Configuration
REPO_DIR="/opt/translate-glue"
BACKUP_DIR="/opt/translate-glue-backup-$(date +%Y%m%d-%H%M%S)"
SERVICE_NAME="translate-glue.service"

# Step 1: Create backup
print_status "Creating backup..."
sudo cp -r "$REPO_DIR" "$BACKUP_DIR"
print_success "Backup created at $BACKUP_DIR"

# Step 2: Stop the service
print_status "Stopping translate-glue service..."
sudo systemctl stop "$SERVICE_NAME"
print_success "Service stopped"

# Step 3: Pull latest changes
print_status "Pulling latest changes from GitHub..."
cd "$REPO_DIR"

# Check if git repo exists
if [ ! -d ".git" ]; then
    print_error "Not a git repository. Please clone from GitHub first."
    print_status "To initialize:"
    echo "  cd $REPO_DIR"
    echo "  git init"
    echo "  git remote add origin https://github.com/hudsonman44/translate.git"
    echo "  git pull origin main"
    exit 1
fi

# Stash any local changes
git stash push -m "Auto-stash before update $(date)"

# Pull latest changes
git pull origin main
print_success "Latest changes pulled"

# Step 4: Install/update dependencies
print_status "Updating Node.js dependencies..."
npm ci --production
print_success "Dependencies updated"

# Step 5: Set correct permissions
print_status "Setting correct permissions..."
sudo chown -R ahudson:ahudson "$REPO_DIR"
sudo chmod +x "$REPO_DIR"/*.sh
sudo mkdir -p "$REPO_DIR/uploads"
sudo chown ahudson:ahudson "$REPO_DIR/uploads"
sudo chmod 755 "$REPO_DIR/uploads"
print_success "Permissions set"

# Step 6: Restart service
print_status "Starting translate-glue service..."
sudo systemctl start "$SERVICE_NAME"

# Wait a moment for service to start
sleep 3

# Step 7: Verify service is running
if systemctl is-active --quiet "$SERVICE_NAME"; then
    print_success "Service is running!"
    
    # Test health endpoint
    if curl -f -s http://localhost:3001/health > /dev/null; then
        print_success "Health check passed!"
        curl -s http://localhost:3001/health | jq . 2>/dev/null || curl -s http://localhost:3001/health
    else
        print_warning "Health check failed - service may still be starting"
    fi
else
    print_error "Service failed to start!"
    print_status "Check logs: journalctl -u $SERVICE_NAME -n 20"
    exit 1
fi

# Step 8: Show recent logs
print_status "Recent service logs:"
journalctl -u "$SERVICE_NAME" -n 10 --no-pager

print_success "Update complete! 🎉"
echo ""
echo "📋 Summary:"
echo "- Backup created: $BACKUP_DIR"
echo "- Service restarted successfully"
echo "- Health check: http://localhost:3001/health"
echo "- API endpoint: https://translate-glue.aaronbhudson.com/api/process-and-translate"
echo ""
echo "🔧 To rollback if needed:"
echo "sudo systemctl stop $SERVICE_NAME"
echo "sudo rm -rf $REPO_DIR"
echo "sudo mv $BACKUP_DIR $REPO_DIR"
echo "sudo systemctl start $SERVICE_NAME"
