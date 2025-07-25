# Cloudflare Tunnel Setup for translate-glue

This guide will help you set up a Cloudflare Tunnel to provide secure HTTPS access to your translate-glue HTTP server, solving the Mixed Content Policy issues when your frontend is hosted on HTTPS (Cloudflare Pages).

## 🎯 What This Solves

- **Mixed Content Policy**: HTTPS frontend can now securely connect to your HTTP backend
- **SSL Certificate Management**: No need to manage SSL certificates on your server
- **Security**: Traffic is encrypted between users and Cloudflare, then securely tunneled to your server
- **Reliability**: Cloudflare's global network provides better performance and uptime

## 🚀 Quick Setup

### Step 1: Run the Setup Script

```bash
cd /path/to/translate-glue
chmod +x setup-cloudflare-tunnel.sh
./setup-cloudflare-tunnel.sh
```

### Step 2: Configure DNS (Choose One Option)

**Option A: Automatic DNS Setup**
```bash
cloudflared tunnel route dns translate-glue-tunnel translate-glue.aaronbhudson.com
```

**Option B: Manual DNS Setup**
1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Select your domain (`aaronbhudson.com`)
3. Go to **DNS** → **Records**
4. Add a CNAME record:
   - **Name**: `translate-glue`
   - **Target**: `[TUNNEL-UUID].cfargotunnel.com` (shown in setup script output)
   - **Proxy status**: Proxied (🟠 orange cloud)

### Step 3: Update Your Frontend

Update your frontend to use the HTTPS tunnel URL:

```javascript
// In frontend/main.js
const GLUE_API_URL = 'https://translate-glue.aaronbhudson.com/api/process-and-translate';
```

## 🔧 Manual Setup (Alternative)

If you prefer to set up manually:

### 1. Install cloudflared

```bash
# Download cloudflared
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o cloudflared
chmod +x cloudflared
sudo mv cloudflared /usr/local/bin/
```

### 2. Authenticate with Cloudflare

```bash
cloudflared tunnel login
```

### 3. Create Tunnel

```bash
cloudflared tunnel create translate-glue-tunnel
```

### 4. Configure Tunnel

Create `~/.cloudflared/config.yml`:

```yaml
tunnel: [YOUR-TUNNEL-UUID]
credentials-file: /home/[USERNAME]/.cloudflared/[TUNNEL-UUID].json

ingress:
  - hostname: translate-glue.aaronbhudson.com
    service: http://localhost:3001
  - service: http_status:404
```

### 5. Create Systemd Service

```bash
sudo nano /etc/systemd/system/cloudflared-tunnel.service
```

```ini
[Unit]
Description=Cloudflare Tunnel
After=network.target

[Service]
Type=simple
User=[YOUR-USERNAME]
ExecStart=/usr/local/bin/cloudflared tunnel --config /home/[USERNAME]/.cloudflared/config.yml run
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
```

### 6. Enable and Start Service

```bash
sudo systemctl daemon-reload
sudo systemctl enable cloudflared-tunnel.service
sudo systemctl start cloudflared-tunnel.service
```

## 🧪 Testing

### 1. Check Tunnel Status

```bash
systemctl status cloudflared-tunnel.service
```

### 2. Test Health Endpoint

```bash
curl https://translate-glue.aaronbhudson.com/health
```

### 3. Test API Endpoint

```bash
curl -X POST https://translate-glue.aaronbhudson.com/api/process-and-translate \
  -F "media=@test-audio.mp3" \
  -F "language=spanish"
```

## 🔍 Troubleshooting

### Tunnel Not Starting

```bash
# Check logs
journalctl -u cloudflared-tunnel.service -f

# Common issues:
# 1. Incorrect tunnel UUID in config.yml
# 2. Wrong file permissions on credentials file
# 3. Port 3001 not accessible (firewall/service not running)
```

### DNS Not Resolving

```bash
# Check DNS propagation
dig translate-glue.aaronbhudson.com

# Should show CNAME pointing to cfargotunnel.com
```

### 502 Bad Gateway

- Ensure your translate-glue service is running on port 3001
- Check if localhost:3001 is accessible from the tunnel

```bash
# Test local service
curl http://localhost:3001/health

# Check if service is running
systemctl status translate-glue.service
```

## 📊 Monitoring

### View Tunnel Logs

```bash
journalctl -u cloudflared-tunnel.service -f
```

### Check Tunnel Metrics

```bash
cloudflared tunnel info translate-glue-tunnel
```

### Cloudflare Dashboard

Monitor traffic and performance in your Cloudflare Dashboard under **Zero Trust** → **Access** → **Tunnels**.

## 🔧 Management Commands

```bash
# Restart tunnel
sudo systemctl restart cloudflared-tunnel.service

# Stop tunnel
sudo systemctl stop cloudflared-tunnel.service

# View tunnel configuration
cat ~/.cloudflared/config.yml

# List all tunnels
cloudflared tunnel list

# Delete tunnel (if needed)
cloudflared tunnel delete translate-glue-tunnel
```

## 🔐 Security Considerations

1. **Tunnel Credentials**: Keep your tunnel credentials file (`~/.cloudflared/[UUID].json`) secure
2. **Service User**: Run the tunnel service as a non-root user
3. **Firewall**: Your server doesn't need to expose port 3001 to the internet - the tunnel handles this securely
4. **Access Control**: Consider implementing Cloudflare Access rules for additional security

## 🚀 Next Steps

After setup is complete:

1. ✅ Update your frontend to use `https://translate-glue.aaronbhudson.com`
2. ✅ Test the full workflow: upload → process → translate
3. ✅ Monitor tunnel performance in Cloudflare Dashboard
4. 🔄 Consider setting up health checks and alerts

## 📚 Additional Resources

- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Tunnel Configuration Reference](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/tunnel-guide/local/local-management/configuration-file/)
- [Zero Trust Dashboard](https://one.dash.cloudflare.com/)
