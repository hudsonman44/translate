# FFmpeg Translation Middleware

A Node.js application designed to run on Ubuntu Server that handles video-to-audio conversion and interfaces with Cloudflare Workers for transcription and translation.

## Architecture

```
Frontend → Ubuntu Server → Cloudflare Worker → Ubuntu Server → Frontend
```

1. **Frontend** uploads video/audio files to Ubuntu server
2. **Ubuntu Server** converts video to MP3 using FFmpeg
3. **Ubuntu Server** sends MP3 to Cloudflare Worker for transcription/translation
4. **Cloudflare Worker** returns translated text
5. **Ubuntu Server** returns result to frontend

## Features

- Video to MP3 conversion using FFmpeg
- Support for multiple video and audio formats
- Automatic file cleanup after processing
- Health check endpoint
- Error handling and logging
- Configurable Cloudflare Worker endpoint

## Installation

### Quick Installation

1. **Copy the application files** to your Ubuntu server
2. **Run the deployment script:**
```bash
sudo chmod +x deploy-ubuntu.sh
sudo ./deploy-ubuntu.sh
```

### What the installer does:
- Installs Node.js 18 LTS and FFmpeg
- Creates a dedicated service user
- Sets up the application in `/opt/ffmpeg-translation-middleware`
- Creates a systemd service for automatic startup
- Configures logging and log rotation
- Sets up firewall rules (if ufw is active)

### Manual Installation Steps

If you prefer to install manually:

```bash
# 1. Install dependencies
sudo apt update
sudo apt install -y nodejs npm ffmpeg

# 2. Create application directory
sudo mkdir -p /opt/ffmpeg-translation-middleware
sudo cp -r . /opt/ffmpeg-translation-middleware/
cd /opt/ffmpeg-translation-middleware

# 3. Install Node.js dependencies
sudo npm install --production

# 4. Run the deployment script for service setup
sudo ./deploy-ubuntu.sh
```

## Configuration

### Environment Variables

- `PORT`: Server port (default: 3001)
- `CLOUDFLARE_WORKER_URL`: URL of your Cloudflare Worker API endpoint

### Frontend Configuration

Update the `LXC_API_URL` in your frontend `main.js`:

```javascript
// For local development
const LXC_API_URL = 'http://localhost:3001/api/process-and-translate';

// For production (replace with your Ubuntu server IP)
const LXC_API_URL = 'http://192.168.1.100:3001/api/process-and-translate';
```

## API Endpoints

### POST /api/process-and-translate

Processes video/audio files and returns translation.

**Request:**
- `media`: Video or audio file (multipart/form-data)
- `language`: Target language code (e.g., 'es', 'fr', 'de')

**Response:**
```json
{
  "success": true,
  "originalFile": "video.mp4",
  "convertedSize": 1234567,
  "translation": {
    "translated_text": "Translated content here"
  }
}
```

### GET /health

Health check endpoint.

**Response:**
```json
{
  "status": "OK",
  "message": "FFmpeg Translation Middleware is running"
}
```

## File Limits

- Maximum file size: 100MB
- Supported formats: All video and audio formats supported by FFmpeg

## Logging

- Application logs: `/var/log/ffmpeg-translation.log`
- Error logs: `/var/log/ffmpeg-translation-error.log`
- Service logs: `journalctl -u ffmpeg-translation.service -f`

## Service Management

Use the included management script for easy service control:

```bash
# Make the script executable
chmod +x manage-service.sh

# Service operations
./manage-service.sh start      # Start the service
./manage-service.sh stop       # Stop the service
./manage-service.sh restart    # Restart the service
./manage-service.sh status     # Check status
./manage-service.sh logs       # View live logs
./manage-service.sh health     # Test health endpoint
./manage-service.sh config     # Edit configuration
./manage-service.sh uninstall  # Complete removal
```

### Manual Service Management

```bash
# Check service status
sudo systemctl status ffmpeg-translation-middleware

# Restart service
sudo systemctl restart ffmpeg-translation-middleware

# View logs
sudo journalctl -u ffmpeg-translation-middleware -f

# Edit configuration
sudo nano /etc/default/ffmpeg-translation-middleware
```

## Troubleshooting

### Common Issues

1. **FFmpeg not found**: Ensure FFmpeg is installed: `apt-get install ffmpeg`
2. **Port already in use**: Change the PORT environment variable
3. **File upload fails**: Check file size limits and permissions
4. **Worker connection fails**: Verify CLOUDFLARE_WORKER_URL is correct

## Development

```bash
# Install dependencies
npm install

# Run in development mode
npm run dev

# Run in production mode
npm start
```

## Security Considerations

- The application automatically cleans up uploaded files after processing
- File type validation prevents non-media file uploads
- Consider implementing authentication for production use
- Use HTTPS in production environments
