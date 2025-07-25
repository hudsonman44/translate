# Server-Side Troubleshooting Guide

This guide helps you diagnose and fix issues with your translate-glue service and Cloudflare Tunnel setup.

## 🚀 Quick Diagnostic Script

Run the automated troubleshooting script first:

```bash
cd /path/to/translate-glue
chmod +x troubleshoot-server.sh
./troubleshoot-server.sh
```

## 🔍 Manual Troubleshooting Steps

### 1. Check Service Status

```bash
# Check if translate-glue service is running
systemctl status translate-glue.service

# Check if cloudflared tunnel is running
systemctl status cloudflared-tunnel.service

# View recent logs
journalctl -u translate-glue.service -n 50
journalctl -u cloudflared-tunnel.service -n 50
```

### 2. Test Local Endpoints

```bash
# Test health endpoint
curl -v http://localhost:3001/health

# Test API endpoint (should return 405 Method Not Allowed for GET)
curl -v http://localhost:3001/api/process-and-translate

# Test with a POST request
curl -X POST http://localhost:3001/api/process-and-translate \
  -F "media=@test-audio.mp3" \
  -F "language=spanish"
```

### 3. Check Network and Ports

```bash
# Check if port 3001 is listening
netstat -tlnp | grep 3001
# or
ss -tlnp | grep 3001

# Check what's using port 3001
sudo lsof -i :3001

# Test network connectivity
ping 8.8.8.8
nslookup translate-glue.aaronbhudson.com
```

### 4. Verify Cloudflare Tunnel

```bash
# Check tunnel status
cloudflared tunnel list

# Test tunnel configuration
cloudflared tunnel --config ~/.cloudflared/config.yml validate

# View tunnel info
cloudflared tunnel info translate-glue-tunnel
```

## 🚨 Common Issues and Solutions

### Issue 1: Service Won't Start

**Symptoms:**
- `systemctl status translate-glue.service` shows "failed" or "inactive"
- Port 3001 is not listening

**Diagnosis:**
```bash
# Check detailed error logs
journalctl -u translate-glue.service -f

# Check if Node.js dependencies are installed
cd /opt/translate-glue && npm list
```

**Solutions:**
```bash
# Reinstall dependencies
cd /opt/translate-glue
npm install

# Check file permissions
sudo chown -R translate-glue:translate-glue /opt/translate-glue

# Restart service
sudo systemctl restart translate-glue.service
```

### Issue 2: Port 3001 Already in Use

**Symptoms:**
- Error: "EADDRINUSE: address already in use :::3001"

**Diagnosis:**
```bash
# Find what's using port 3001
sudo lsof -i :3001
sudo netstat -tlnp | grep 3001
```

**Solutions:**
```bash
# Kill the process using the port
sudo kill -9 [PID]

# Or change the port in your service
# Edit /opt/translate-glue/server.js and change PORT
```

### Issue 3: CORS Errors

**Symptoms:**
- Browser console shows CORS policy errors
- Frontend can't connect to API

**Diagnosis:**
```bash
# Test CORS with curl
curl -X OPTIONS \
  -H "Origin: https://translate.aaronbhudson.com" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Content-Type" \
  -v http://localhost:3001/api/process-and-translate
```

**Solutions:**
1. Check server logs for "CORS blocked origin" messages
2. Verify your frontend domain is in the CORS allowlist
3. Restart the service after CORS changes

### Issue 4: Cloudflare Tunnel Not Working

**Symptoms:**
- 502 Bad Gateway when accessing https://translate-glue.aaronbhudson.com
- Tunnel service fails to start

**Diagnosis:**
```bash
# Check tunnel logs
journalctl -u cloudflared-tunnel.service -f

# Verify tunnel configuration
cat ~/.cloudflared/config.yml

# Check DNS settings
dig translate-glue.aaronbhudson.com
```

**Solutions:**
```bash
# Re-authenticate with Cloudflare
cloudflared tunnel login

# Recreate tunnel if needed
cloudflared tunnel delete translate-glue-tunnel
cloudflared tunnel create translate-glue-tunnel

# Restart tunnel service
sudo systemctl restart cloudflared-tunnel.service
```

### Issue 5: FFmpeg Not Found

**Symptoms:**
- API returns errors about FFmpeg
- Media conversion fails

**Diagnosis:**
```bash
# Check if FFmpeg is installed
ffmpeg -version
which ffmpeg
```

**Solutions:**
```bash
# Install FFmpeg (Ubuntu/Debian)
sudo apt update
sudo apt install ffmpeg

# Install FFmpeg (CentOS/RHEL)
sudo yum install epel-release
sudo yum install ffmpeg
```

### Issue 6: File Upload Issues

**Symptoms:**
- Large files fail to upload
- Timeout errors during processing

**Diagnosis:**
```bash
# Check disk space
df -h

# Check upload directory permissions
ls -la /opt/translate-glue/uploads/

# Check system limits
ulimit -a
```

**Solutions:**
```bash
# Increase file upload limits in server.js
# Add to multer configuration:
# limits: { fileSize: 100 * 1024 * 1024 } // 100MB

# Clean up old uploads
find /opt/translate-glue/uploads -type f -mtime +1 -delete

# Increase system limits if needed
sudo nano /etc/security/limits.conf
```

## 📊 Monitoring and Logs

### Real-time Log Monitoring

```bash
# Follow translate-glue logs
journalctl -u translate-glue.service -f

# Follow tunnel logs
journalctl -u cloudflared-tunnel.service -f

# Follow all system logs
journalctl -f | grep -E "(translate-glue|cloudflared)"
```

### Log Analysis

```bash
# Search for errors in the last hour
journalctl -u translate-glue.service --since "1 hour ago" | grep -i error

# Search for specific error patterns
journalctl -u translate-glue.service | grep -E "(CORS|EADDRINUSE|FFmpeg|timeout)"

# Export logs for analysis
journalctl -u translate-glue.service --since "24 hours ago" > translate-glue-logs.txt
```

### Performance Monitoring

```bash
# Check CPU and memory usage
top -p $(pgrep -f "node.*server.js")

# Check disk I/O
iotop -p $(pgrep -f "node.*server.js")

# Monitor network connections
ss -tuln | grep 3001
```

## 🔧 Advanced Debugging

### Enable Debug Mode

Add to your server.js or set environment variable:

```javascript
// In server.js, add at the top:
process.env.DEBUG = 'express:*,cors:*';

// Or set when starting the service:
DEBUG=express:*,cors:* node server.js
```

### Test with Different Clients

```bash
# Test with curl (bypasses CORS)
curl -X POST http://localhost:3001/api/process-and-translate \
  -F "media=@test.mp3" \
  -F "language=spanish" \
  -v

# Test with wget
wget --post-data="test" http://localhost:3001/health

# Test with different origins
curl -X POST \
  -H "Origin: https://translate.aaronbhudson.com" \
  -F "media=@test.mp3" \
  -F "language=spanish" \
  http://localhost:3001/api/process-and-translate
```

### Network Debugging

```bash
# Capture network traffic
sudo tcpdump -i any port 3001

# Test connectivity from different locations
# Use online tools like:
# - https://www.whatsmydns.net/
# - https://tools.pingdom.com/
```

## 🛠️ Recovery Procedures

### Complete Service Reset

```bash
# Stop all services
sudo systemctl stop translate-glue.service
sudo systemctl stop cloudflared-tunnel.service

# Clear any stuck processes
sudo pkill -f "node.*server.js"
sudo pkill -f cloudflared

# Restart services
sudo systemctl start translate-glue.service
sudo systemctl start cloudflared-tunnel.service

# Verify status
systemctl status translate-glue.service
systemctl status cloudflared-tunnel.service
```

### Reinstall Dependencies

```bash
cd /opt/translate-glue
rm -rf node_modules package-lock.json
npm install
sudo systemctl restart translate-glue.service
```

### Reset Cloudflare Tunnel

```bash
# Stop tunnel
sudo systemctl stop cloudflared-tunnel.service

# Remove old tunnel
cloudflared tunnel delete translate-glue-tunnel

# Recreate tunnel
cloudflared tunnel create translate-glue-tunnel

# Update configuration with new tunnel ID
# Edit ~/.cloudflared/config.yml

# Restart tunnel
sudo systemctl start cloudflared-tunnel.service
```

## 📞 Getting Help

If you're still having issues:

1. **Collect Information:**
   ```bash
   ./troubleshoot-server.sh > troubleshoot-output.txt
   ```

2. **Check Common Locations:**
   - Service logs: `journalctl -u translate-glue.service`
   - Tunnel logs: `journalctl -u cloudflared-tunnel.service`
   - System logs: `/var/log/syslog`

3. **Test Isolation:**
   - Test locally first: `curl http://localhost:3001/health`
   - Test tunnel: `curl https://translate-glue.aaronbhudson.com/health`
   - Test frontend separately

4. **Document the Issue:**
   - What were you trying to do?
   - What error messages did you see?
   - What have you tried already?
   - Include relevant log excerpts

Remember: Most issues are either service configuration, network connectivity, or permission problems. The troubleshooting script will help identify which category your issue falls into.
