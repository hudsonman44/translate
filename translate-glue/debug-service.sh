#!/bin/bash

# Debug script specifically for translate-glue service issues
# This script focuses on diagnosing why the service isn't responding

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_section() { echo -e "\n${BLUE}=== $1 ===${NC}"; }

echo "🔧 Debugging translate-glue Service"
echo "===================================="

# 1. Check if service exists and its status
print_section "Service Status Check"

if systemctl list-unit-files | grep -q "translate-glue.service"; then
    print_success "translate-glue.service file exists"
    
    print_status "Service status:"
    systemctl status translate-glue.service --no-pager -l || true
    
    print_status "Service is enabled:" 
    systemctl is-enabled translate-glue.service || print_warning "Service is not enabled"
    
    print_status "Service is active:"
    systemctl is-active translate-glue.service || print_error "Service is not active"
else
    print_error "translate-glue.service not found!"
    print_status "Available services with 'translate' in name:"
    systemctl list-unit-files | grep -i translate || print_warning "No translate services found"
fi

# 2. Check for Node.js processes
print_section "Process Check"

print_status "Looking for Node.js processes:"
ps aux | grep -E "(node|npm)" | grep -v grep || print_warning "No Node.js processes found"

print_status "Looking for processes on port 3001:"
sudo lsof -i :3001 || print_warning "No processes found on port 3001"

print_status "All listening ports:"
netstat -tlnp | grep LISTEN | head -10

# 3. Check service file configuration
print_section "Service Configuration"

SERVICE_FILE="/etc/systemd/system/translate-glue.service"
if [ -f "$SERVICE_FILE" ]; then
    print_success "Service file exists at $SERVICE_FILE"
    print_status "Service file contents:"
    cat "$SERVICE_FILE"
    
    # Extract working directory and exec start from service file
    WORKING_DIR=$(grep "WorkingDirectory" "$SERVICE_FILE" | cut -d'=' -f2 || echo "")
    EXEC_START=$(grep "ExecStart" "$SERVICE_FILE" | cut -d'=' -f2- || echo "")
    USER_NAME=$(grep "User=" "$SERVICE_FILE" | cut -d'=' -f2 || echo "")
    
    print_status "Working Directory: $WORKING_DIR"
    print_status "Exec Start: $EXEC_START"
    print_status "User: $USER_NAME"
else
    print_error "Service file not found at $SERVICE_FILE"
    print_status "Looking for service files:"
    find /etc/systemd/system/ -name "*translate*" 2>/dev/null || true
fi

# 4. Check working directory and files
print_section "File System Check"

COMMON_PATHS=(
    "/opt/translate-glue"
    "/home/ubuntu/translate-glue"
    "/root/translate-glue"
    "$(pwd)"
)

for path in "${COMMON_PATHS[@]}"; do
    if [ -d "$path" ]; then
        print_success "Found directory: $path"
        print_status "Contents:"
        ls -la "$path" | head -10
        
        if [ -f "$path/server.js" ]; then
            print_success "server.js found in $path"
            
            # Check if package.json exists
            if [ -f "$path/package.json" ]; then
                print_success "package.json found"
                print_status "Dependencies status:"
                cd "$path"
                if [ -d "node_modules" ]; then
                    print_success "node_modules directory exists"
                    npm list --depth=0 2>/dev/null | head -10 || print_warning "npm list failed"
                else
                    print_error "node_modules directory missing - need to run npm install"
                fi
            else
                print_error "package.json not found"
            fi
            
            # Try to run the server manually
            print_status "Testing manual server start:"
            cd "$path"
            timeout 5s node server.js 2>&1 || print_warning "Manual start test completed"
            
        else
            print_warning "server.js not found in $path"
        fi
        break
    fi
done

# 5. Check Node.js and dependencies
print_section "Dependencies Check"

print_status "Node.js version:"
node --version 2>/dev/null || print_error "Node.js not found"

print_status "NPM version:"
npm --version 2>/dev/null || print_error "NPM not found"

print_status "FFmpeg version:"
ffmpeg -version 2>/dev/null | head -1 || print_error "FFmpeg not found"

# 6. Check recent logs
print_section "Recent Logs"

print_status "Last 20 lines of translate-glue service logs:"
journalctl -u translate-glue.service -n 20 --no-pager || print_warning "No logs found"

print_status "System logs mentioning translate-glue:"
journalctl --since "1 hour ago" | grep -i translate-glue | tail -10 || print_warning "No system logs found"

# 7. Try to identify the issue
print_section "Issue Diagnosis"

print_status "Checking for common issues:"

# Check if service is masked
if systemctl is-masked translate-glue.service 2>/dev/null; then
    print_error "Service is masked! Run: sudo systemctl unmask translate-glue.service"
fi

# Check if systemd needs reload
print_status "Checking if systemd needs reload:"
if systemctl daemon-reload 2>/dev/null; then
    print_success "Systemd reloaded successfully"
else
    print_warning "Systemd reload had issues"
fi

# 8. Provide specific recommendations
print_section "Recommended Actions"

echo "Based on the diagnosis above, try these steps in order:"
echo ""
echo "1. 🔄 If service file exists but service isn't running:"
echo "   sudo systemctl daemon-reload"
echo "   sudo systemctl enable translate-glue.service"
echo "   sudo systemctl start translate-glue.service"
echo ""
echo "2. 📦 If node_modules is missing:"
echo "   cd /path/to/translate-glue"
echo "   npm install"
echo "   sudo systemctl restart translate-glue.service"
echo ""
echo "3. 🔧 If service file is missing or incorrect:"
echo "   Check the deployment scripts in your project"
echo "   Recreate the service file with correct paths"
echo ""
echo "4. 🐛 If there are errors in logs:"
echo "   journalctl -u translate-glue.service -f"
echo "   Fix the errors and restart the service"
echo ""
echo "5. 🧪 Test manual startup:"
echo "   cd /path/to/translate-glue"
echo "   node server.js"
echo "   (This will show immediate errors)"

print_success "Debug complete! Check the output above for specific issues."
