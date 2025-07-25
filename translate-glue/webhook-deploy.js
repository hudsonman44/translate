#!/usr/bin/env node

// Simple webhook server to auto-deploy on GitHub push
// Listens for GitHub webhook and triggers deployment

const express = require('express');
const crypto = require('crypto');
const { exec } = require('child_process');

const app = express();
const PORT = 3002; // Different port from main service
const WEBHOOK_SECRET = process.env.WEBHOOK_SECRET || 'your-webhook-secret';

app.use(express.json());

// Webhook endpoint
app.post('/webhook', (req, res) => {
  const signature = req.headers['x-hub-signature-256'];
  const payload = JSON.stringify(req.body);
  
  // Verify GitHub signature
  if (signature) {
    const expectedSignature = 'sha256=' + crypto
      .createHmac('sha256', WEBHOOK_SECRET)
      .update(payload)
      .digest('hex');
    
    if (!crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expectedSignature))) {
      console.log('❌ Invalid signature');
      return res.status(401).send('Invalid signature');
    }
  }
  
  // Check if this is a push to main branch
  if (req.body.ref === 'refs/heads/main') {
    console.log('🚀 Received push to main branch, deploying...');
    
    // Run deployment script
    exec('cd /opt/translate-glue && ./update-from-github.sh', (error, stdout, stderr) => {
      if (error) {
        console.error('❌ Deployment failed:', error);
        return res.status(500).send('Deployment failed');
      }
      
      console.log('✅ Deployment successful');
      console.log('Output:', stdout);
      if (stderr) console.log('Warnings:', stderr);
      
      res.status(200).send('Deployment successful');
    });
  } else {
    console.log('ℹ️ Ignoring push to non-main branch:', req.body.ref);
    res.status(200).send('Ignored non-main branch');
  }
});

app.get('/status', (req, res) => {
  res.json({ status: 'Webhook server running', timestamp: new Date().toISOString() });
});

app.listen(PORT, () => {
  console.log(`🎣 Webhook server listening on port ${PORT}`);
  console.log(`Webhook URL: http://your-server:${PORT}/webhook`);
});
