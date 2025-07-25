#!/bin/bash

# Cloudflare Tunnel Setup Script for translate-glue service
# This script sets up a Cloudflare Tunnel to provide HTTPS access to your HTTP server

set -e

echo "🚇 Setting up Cloudflare Tunnel for translate-glue service..."

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo "❌ This script should not be run as root for security reasons"
   exit 1
fi

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

# Step 1: Install cloudflared
print_status "Installing cloudflared..."

# Download and install cloudflared
if ! command -v cloudflared &> /dev/null; then
    print_status "Downloading cloudflared..."
    
    # Detect architecture
    ARCH=$(uname -m)
    if [[ "$ARCH" == "x86_64" ]]; then
        CLOUDFLARED_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"
    elif [[ "$ARCH" == "aarch64" ]] || [[ "$ARCH" == "arm64" ]]; then
        CLOUDFLARED_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64"
    else
        print_error "Unsupported architecture: $ARCH"
        exit 1
    fi
    
    # Download cloudflared
    curl -L "$CLOUDFLARED_URL" -o cloudflared
    chmod +x cloudflared
    sudo mv cloudflared /usr/local/bin/
    
    print_success "cloudflared installed successfully"
else
    print_success "cloudflared is already installed"
fi

# Step 2: Authenticate with Cloudflare
print_status "Setting up Cloudflare authentication..."
print_warning "You'll need to authenticate with Cloudflare in your browser"
print_status "Opening browser for authentication..."

cloudflared tunnel login

# Step 3: Create tunnel
print_status "Creating Cloudflare tunnel..."

TUNNEL_NAME="translate-glue-tunnel"
TUNNEL_UUID=$(cloudflared tunnel create $TUNNEL_NAME 2>/dev/null | grep -o '[a-f0-9-]\{36\}' | head -1)

if [ -z "$TUNNEL_UUID" ]; then
    # Tunnel might already exist, try to get its UUID
    TUNNEL_UUID=$(cloudflared tunnel list | grep $TUNNEL_NAME | awk '{print $1}')
    if [ -z "$TUNNEL_UUID" ]; then
        print_error "Failed to create or find tunnel"
        exit 1
    else
        print_success "Using existing tunnel: $TUNNEL_UUID"
    fi
else
    print_success "Created tunnel: $TUNNEL_UUID"
fi

# Step 4: Create tunnel configuration
print_status "Creating tunnel configuration..."

TUNNEL_CONFIG_DIR="$HOME/.cloudflared"
mkdir -p "$TUNNEL_CONFIG_DIR"

cat > "$TUNNEL_CONFIG_DIR/config.yml" << EOF
tunnel: $TUNNEL_UUID
credentials-file: $TUNNEL_CONFIG_DIR/$TUNNEL_UUID.json

ingress:
  # Route for your translate-glue API
  - hostname: translate-glue.aaronbhudson.com
    service: http://localhost:3001
  # Catch-all rule (required)
  - service: http_status:404
EOF

print_success "Tunnel configuration created at $TUNNEL_CONFIG_DIR/config.yml"

# Step 5: Create systemd service
print_status "Creating systemd service..."

sudo tee /etc/systemd/system/cloudflared-tunnel.service > /dev/null << EOF
[Unit]
Description=Cloudflare Tunnel
After=network.target

[Service]
Type=simple
User=$USER
ExecStart=/usr/local/bin/cloudflared tunnel --config $TUNNEL_CONFIG_DIR/config.yml run
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# Step 6: Enable and start the service
print_status "Enabling and starting cloudflared service..."
sudo systemctl daemon-reload
sudo systemctl enable cloudflared-tunnel.service
sudo systemctl start cloudflared-tunnel.service

# Step 7: Display DNS setup instructions
print_success "Cloudflare Tunnel setup complete!"
echo ""
print_warning "IMPORTANT: You need to configure DNS in Cloudflare Dashboard:"
echo ""
echo "1. Go to your Cloudflare Dashboard"
echo "2. Select your domain (aaronbhudson.com)"
echo "3. Go to DNS settings"
echo "4. Add a CNAME record:"
echo "   - Name: translate-glue"
echo "   - Target: $TUNNEL_UUID.cfargotunnel.com"
echo "   - Proxy status: Proxied (orange cloud)"
echo ""
print_status "Or run this command to set up DNS automatically:"
echo "cloudflared tunnel route dns $TUNNEL_NAME translate-glue.aaronbhudson.com"
echo ""

# Step 8: Test the tunnel
print_status "Testing tunnel status..."
sleep 5
if systemctl is-active --quiet cloudflared-tunnel.service; then
    print_success "Cloudflared tunnel is running!"
    print_status "Service status:"
    systemctl status cloudflared-tunnel.service --no-pager -l
else
    print_error "Cloudflared tunnel failed to start"
    print_status "Check logs with: journalctl -u cloudflared-tunnel.service -f"
fi

echo ""
print_success "Setup complete! Your API will be available at:"
echo "https://translate-glue.aaronbhudson.com/api/process-and-translate"
echo ""
print_status "Next steps:"
echo "1. Configure DNS (see instructions above)"
echo "2. Update your frontend to use the HTTPS URL"
echo "3. Test the connection"
echo ""
print_status "Useful commands:"
echo "- Check tunnel status: systemctl status cloudflared-tunnel.service"
echo "- View tunnel logs: journalctl -u cloudflared-tunnel.service -f"
echo "- Restart tunnel: sudo systemctl restart cloudflared-tunnel.service"
