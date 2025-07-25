# GitHub Deployment Guide for Translate Glue

This guide shows you how to deploy the `translate-glue` middleware directly from GitHub to your Ubuntu server.

## 🚀 Quick Installation (One-Liner)

Once you push your code to GitHub, users can install with a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/hudsonman44/translate/main/translate-glue/install.sh | sudo bash
```

## 📋 Prerequisites

1. **Ubuntu Server** (18.04 or later)
2. **Root access** (sudo privileges)
3. **Internet connection** for downloading packages
4. **Your GitHub repository** must be public (or you need to handle authentication)

## 🔧 Setup Steps

### 1. Update the Installation Script

Before pushing to GitHub, update these variables in `install.sh`:

```bash
GITHUB_USER="YOUR-USERNAME"    # Replace with your GitHub username
GITHUB_REPO="translate"        # Replace with your repository name  
GITHUB_BRANCH="main"          # Replace with your branch name
```

### 2. Push to GitHub

Make sure your repository structure looks like this:

```
your-repo/
├── frontend/
├── src/
├── translate-glue/
│   ├── server.js
│   ├── package.json
│   ├── deploy-ubuntu.sh
│   ├── install.sh
│   ├── manage-service.sh
│   └── README.md
└── README.md
```

### 3. Deploy to Ubuntu Server

On your Ubuntu server, run:

```bash
# Replace YOUR-USERNAME and translate with your actual GitHub info
curl -fsSL https://raw.githubusercontent.com/YOUR-USERNAME/translate/main/translate-glue/install.sh | sudo bash
```

## 🔍 What the Installer Does

1. **Downloads** the latest code from your GitHub repository
2. **Installs** Node.js 18 LTS and FFmpeg
3. **Creates** a system service user (`translate-glue`)
4. **Sets up** the application in `/opt/translate-glue`
5. **Configures** systemd service for auto-start
6. **Starts** the service automatically

## ⚙️ Post-Installation Configuration

### 1. Update Cloudflare Worker URL

```bash
sudo nano /etc/default/translate-glue
```

Update the `CLOUDFLARE_WORKER_URL` to match your deployed worker:

```bash
CLOUDFLARE_WORKER_URL=https://your-worker.workers.dev/api/translate
```

### 2. Restart the Service

```bash
sudo systemctl restart translate-glue
```

### 3. Update Your Frontend

In your frontend `main.js`, update the API URL:

```javascript
// Replace with your Ubuntu server's IP address
const GLUE_API_URL = 'https://your-domain.com:3001/api/process-and-translate'; // Use HTTPS for production
```

## 🧪 Testing the Installation

### 1. Health Check

```bash
curl http://localhost:3001/health
```

Expected response:
```json
{
  "status": "OK",
  "message": "FFmpeg Translation Middleware is running"
}
```

### 2. Service Status

```bash
sudo systemctl status translate-glue
```

### 3. View Logs

```bash
sudo journalctl -u translate-glue -f
```

## 📱 Service Management

Use the included management script:

```bash
cd /opt/translate-glue

# Check service status
./manage-service.sh status

# View live logs
./manage-service.sh logs

# Restart service
./manage-service.sh restart

# Test health endpoint
./manage-service.sh health

# Edit configuration
./manage-service.sh config
```

## 🔄 Updating the Application

To update to the latest version from GitHub:

```bash
# Stop the service
sudo systemctl stop translate-glue

# Re-run the installer (it will update the existing installation)
curl -fsSL https://raw.githubusercontent.com/YOUR-USERNAME/translate/main/translate-glue/install.sh | sudo bash
```

## 🔥 Firewall Configuration

If you're using UFW, the installer automatically opens port 3001:

```bash
# Check firewall status
sudo ufw status

# Manually open port if needed
sudo ufw allow 3001/tcp
```

## 🚨 Troubleshooting

### Installation Fails

1. **Check GitHub URL**: Ensure your repository is public and the path is correct
2. **Check Internet**: Ensure the server can reach GitHub
3. **Check Permissions**: Make sure you're running with sudo

### Service Won't Start

```bash
# Check service status
sudo systemctl status translate-glue

# Check logs
sudo journalctl -u translate-glue -n 50

# Check configuration
sudo nano /etc/default/translate-glue
```

### FFmpeg Issues

```bash
# Verify FFmpeg installation
ffmpeg -version

# Reinstall if needed
sudo apt-get install --reinstall ffmpeg
```

## 📁 File Locations

- **Application**: `/opt/translate-glue/`
- **Configuration**: `/etc/default/translate-glue`
- **Service**: `/etc/systemd/system/translate-glue.service`
- **Logs**: `/var/log/translate-glue/`
- **Management Script**: `/opt/translate-glue/manage-service.sh`

## 🗑️ Complete Removal

To completely remove the application:

```bash
cd /opt/translate-glue
sudo ./manage-service.sh uninstall
```

## 🔐 Security Notes

- The service runs as a dedicated user (`translate-glue`)
- Files are automatically cleaned up after processing
- Consider using HTTPS in production
- Implement authentication for production deployments

## 📞 Support

If you encounter issues:

1. Check the logs: `sudo journalctl -u translate-glue -f`
2. Verify the service status: `sudo systemctl status translate-glue`
3. Test the health endpoint: `curl http://localhost:3001/health`
4. Check the GitHub repository for updates
