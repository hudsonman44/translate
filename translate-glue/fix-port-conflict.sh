#!/bin/bash

# Fix port 3001 conflict for translate-glue service

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "🔧 Fixing Port 3001 Conflict"
echo "============================"

# 1. Find what's using port 3001
print_status "Finding processes using port 3001..."
PROCESSES=$(sudo lsof -i :3001 2>/dev/null)

if [ -n "$PROCESSES" ]; then
    echo "$PROCESSES"
    
    # Extract PIDs
    PIDS=$(echo "$PROCESSES" | awk 'NR>1 {print $2}' | sort -u)
    
    print_warning "Found processes using port 3001. PIDs: $PIDS"
    
    # Kill the processes
    for PID in $PIDS; do
        print_status "Killing process $PID..."
        sudo kill -9 $PID 2>/dev/null && print_success "Killed process $PID" || print_warning "Could not kill process $PID"
    done
    
    # Wait a moment
    sleep 2
    
    # Check if port is now free
    if sudo lsof -i :3001 2>/dev/null; then
        print_error "Port 3001 is still in use!"
    else
        print_success "Port 3001 is now free!"
    fi
else
    print_warning "No processes found using port 3001 (this is strange given the error)"
fi

# 2. Stop any systemd service that might be running
print_status "Stopping translate-glue systemd service..."
sudo systemctl stop translate-glue.service 2>/dev/null && print_success "Stopped systemd service" || print_warning "Systemd service was not running"

# 3. Kill any remaining node processes that might be related
print_status "Looking for any remaining Node.js processes..."
NODE_PROCESSES=$(ps aux | grep -E "(node.*server\.js|node.*translate)" | grep -v grep)
if [ -n "$NODE_PROCESSES" ]; then
    print_warning "Found Node.js processes that might be related:"
    echo "$NODE_PROCESSES"
    
    # Extract PIDs and kill them
    NODE_PIDS=$(echo "$NODE_PROCESSES" | awk '{print $2}')
    for PID in $NODE_PIDS; do
        print_status "Killing Node.js process $PID..."
        sudo kill -9 $PID 2>/dev/null && print_success "Killed Node.js process $PID" || print_warning "Could not kill process $PID"
    done
else
    print_success "No suspicious Node.js processes found"
fi

# 4. Final check
print_status "Final port check..."
sleep 2
if sudo lsof -i :3001 2>/dev/null; then
    print_error "Port 3001 is STILL in use. Manual intervention needed."
    print_status "Processes still using port 3001:"
    sudo lsof -i :3001
else
    print_success "Port 3001 is now completely free!"
fi

# 5. Try to start the service
print_status "Attempting to start translate-glue service..."
sudo systemctl start translate-glue.service

sleep 3

# 6. Check if service started successfully
if systemctl is-active --quiet translate-glue.service; then
    print_success "translate-glue service is now running!"
    print_status "Testing the endpoint..."
    
    sleep 2
    if curl -f -s http://localhost:3001/health > /dev/null; then
        print_success "Health endpoint is responding!"
        curl http://localhost:3001/health
    else
        print_warning "Service is running but health endpoint not responding yet"
    fi
else
    print_error "Service failed to start. Check logs:"
    print_status "Recent logs:"
    journalctl -u translate-glue.service -n 10 --no-pager
fi

print_status "Done! Check the output above for any remaining issues."
