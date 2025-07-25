#!/bin/bash

# Server-side troubleshooting script for translate-glue service
# This script helps diagnose issues with the translate-glue service and Cloudflare Tunnel

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

# Function to check if a service is running
check_service() {
    local service_name=$1
    if systemctl is-active --quiet "$service_name"; then
        print_success "$service_name is running"
        return 0
    else
        print_error "$service_name is not running"
        return 1
    fi
}

# Function to check if a port is listening
check_port() {
    local port=$1
    local service_name=$2
    if netstat -tlnp 2>/dev/null | grep ":$port " > /dev/null; then
        print_success "Port $port is listening ($service_name)"
        return 0
    else
        print_error "Port $port is not listening ($service_name)"
        return 1
    fi
}

# Function to test HTTP endpoint
test_endpoint() {
    local url=$1
    local description=$2
    print_status "Testing $description: $url"
    
    if curl -f -s -m 10 "$url" > /dev/null 2>&1; then
        print_success "$description is responding"
        return 0
    else
        print_error "$description is not responding"
        return 1
    fi
}

echo "🔍 Server-side Troubleshooting for translate-glue Service"
echo "======================================================="

# 1. Check system resources
print_section "System Resources"
print_status "CPU and Memory usage:"
top -bn1 | head -5

print_status "Disk usage:"
df -h | grep -E "(Filesystem|/dev/)"

print_status "Available memory:"
free -h

# 2. Check translate-glue service
print_section "translate-glue Service Status"

if check_service "translate-glue.service"; then
    print_status "Service details:"
    systemctl status translate-glue.service --no-pager -l
    
    print_status "Recent logs (last 20 lines):"
    journalctl -u translate-glue.service -n 20 --no-pager
else
    print_error "translate-glue service is not running!"
    print_status "Attempting to start service..."
    sudo systemctl start translate-glue.service
    sleep 3
    check_service "translate-glue.service"
fi

# 3. Check port availability
print_section "Port Status"
check_port "3001" "translate-glue"

print_status "All listening ports:"
netstat -tlnp | grep LISTEN

# 4. Test local endpoints
print_section "Local Endpoint Testing"
test_endpoint "http://localhost:3001/health" "Health endpoint"
test_endpoint "http://localhost:3001/api/process-and-translate" "API endpoint (GET - should return 405)"

# 5. Check Cloudflare Tunnel
print_section "Cloudflare Tunnel Status"

if command -v cloudflared &> /dev/null; then
    print_success "cloudflared is installed"
    cloudflared --version
    
    if check_service "cloudflared-tunnel.service"; then
        print_status "Tunnel service details:"
        systemctl status cloudflared-tunnel.service --no-pager -l
        
        print_status "Recent tunnel logs (last 20 lines):"
        journalctl -u cloudflared-tunnel.service -n 20 --no-pager
        
        print_status "Tunnel configuration:"
        if [ -f "$HOME/.cloudflared/config.yml" ]; then
            cat "$HOME/.cloudflared/config.yml"
        else
            print_error "Tunnel config file not found at $HOME/.cloudflared/config.yml"
        fi
        
        print_status "Active tunnels:"
        cloudflared tunnel list 2>/dev/null || print_warning "Could not list tunnels (may need authentication)"
    else
        print_error "Cloudflared tunnel service is not running!"
        print_status "Attempting to start tunnel service..."
        sudo systemctl start cloudflared-tunnel.service
        sleep 5
        check_service "cloudflared-tunnel.service"
    fi
else
    print_error "cloudflared is not installed"
fi

# 6. Check network connectivity
print_section "Network Connectivity"
print_status "Testing external connectivity:"
if ping -c 3 8.8.8.8 > /dev/null 2>&1; then
    print_success "Internet connectivity is working"
else
    print_error "No internet connectivity"
fi

print_status "Testing DNS resolution:"
if nslookup translate-glue.aaronbhudson.com > /dev/null 2>&1; then
    print_success "DNS resolution is working"
    nslookup translate-glue.aaronbhudson.com
else
    print_error "DNS resolution failed for translate-glue.aaronbhudson.com"
fi

# 7. Check firewall status
print_section "Firewall Status"
if command -v ufw &> /dev/null; then
    print_status "UFW firewall status:"
    sudo ufw status
elif command -v iptables &> /dev/null; then
    print_status "iptables rules:"
    sudo iptables -L -n
else
    print_warning "No firewall management tool found"
fi

# 8. Check file permissions and dependencies
print_section "File System and Dependencies"
print_status "Node.js version:"
node --version 2>/dev/null || print_error "Node.js not found"

print_status "NPM version:"
npm --version 2>/dev/null || print_error "NPM not found"

print_status "FFmpeg installation:"
ffmpeg -version 2>/dev/null | head -1 || print_error "FFmpeg not found"

print_status "Service file permissions:"
ls -la /etc/systemd/system/translate-glue.service 2>/dev/null || print_error "Service file not found"

print_status "Working directory permissions:"
ls -la /opt/translate-glue/ 2>/dev/null || print_error "Service directory not found"

# 9. Test CORS and API functionality
print_section "API Functionality Test"
print_status "Testing CORS preflight request:"
curl -X OPTIONS \
  -H "Origin: https://translate.aaronbhudson.com" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Content-Type" \
  -v http://localhost:3001/api/process-and-translate 2>&1 | grep -E "(HTTP|Access-Control)" || print_error "CORS test failed"

# 10. Check logs for errors
print_section "Error Analysis"
print_status "Checking for common errors in logs..."

print_status "translate-glue service errors:"
journalctl -u translate-glue.service --since "1 hour ago" | grep -i error || print_success "No errors found in translate-glue logs"

print_status "Cloudflared tunnel errors:"
journalctl -u cloudflared-tunnel.service --since "1 hour ago" | grep -i error || print_success "No errors found in tunnel logs"

print_status "System errors:"
journalctl --since "1 hour ago" | grep -i "translate-glue\|cloudflared" | grep -i error || print_success "No system errors found"

# 11. Recommendations
print_section "Troubleshooting Recommendations"

echo "Based on the checks above, here are some common solutions:"
echo ""
echo "🔧 If translate-glue service is not running:"
echo "   sudo systemctl start translate-glue.service"
echo "   sudo systemctl enable translate-glue.service"
echo ""
echo "🔧 If port 3001 is not listening:"
echo "   Check if another service is using the port: sudo lsof -i :3001"
echo "   Check service logs: journalctl -u translate-glue.service -f"
echo ""
echo "🔧 If Cloudflare tunnel is not working:"
echo "   Restart tunnel: sudo systemctl restart cloudflared-tunnel.service"
echo "   Check tunnel config: cat ~/.cloudflared/config.yml"
echo "   Re-authenticate: cloudflared tunnel login"
echo ""
echo "🔧 If CORS errors persist:"
echo "   Check server logs for blocked origins"
echo "   Verify frontend URL is in CORS allowlist"
echo "   Test with curl to isolate the issue"
echo ""
echo "🔧 If DNS is not resolving:"
echo "   Check Cloudflare DNS settings"
echo "   Verify CNAME record points to tunnel"
echo "   Wait for DNS propagation (up to 24 hours)"

print_section "Quick Commands for Further Debugging"
echo "# View live logs:"
echo "journalctl -u translate-glue.service -f"
echo "journalctl -u cloudflared-tunnel.service -f"
echo ""
echo "# Test endpoints manually:"
echo "curl -v http://localhost:3001/health"
echo "curl -v https://translate-glue.aaronbhudson.com/health"
echo ""
echo "# Restart services:"
echo "sudo systemctl restart translate-glue.service"
echo "sudo systemctl restart cloudflared-tunnel.service"
echo ""
echo "# Check service status:"
echo "systemctl status translate-glue.service"
echo "systemctl status cloudflared-tunnel.service"

print_success "Troubleshooting complete! Check the output above for any issues."
