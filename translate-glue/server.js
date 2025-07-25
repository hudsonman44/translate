const express = require('express');
const multer = require('multer');
const ffmpeg = require('fluent-ffmpeg');
const cors = require('cors');
const axios = require('axios');
const fs = require('fs-extra');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware - Configure CORS for Cloudflare Pages
const corsOptions = {
  origin: function (origin, callback) {
    console.log('🔍 CORS check for origin:', origin);
    
    // Allow requests with no origin (like mobile apps or curl requests)
    if (!origin) {
      console.log('✅ CORS: Allowing request with no origin');
      return callback(null, true);
    }
    
    const allowedOrigins = [
      'http://localhost:3000',  // Keep HTTP for local development
      'http://localhost:8080',  // Keep HTTP for local development
      'https://localhost:3000', // HTTPS for local SSL testing
      'https://localhost:8080', // HTTPS for local SSL testing 
      'https://b23370b1.translate-19i.pages.dev', // Your current Pages domain
      'https://translate.aaronbhudson.com', // Your current Pages domain
    ];
    
    // Check exact matches
    if (allowedOrigins.includes(origin)) {
      console.log('✅ CORS: Origin allowed (exact match):', origin);
      return callback(null, true);
    }
    
    // Check regex patterns
    if (/\.pages\.dev$/.test(origin) || /\.aaronbhudson\.com$/.test(origin)) {
      console.log('✅ CORS: Origin allowed (regex match):', origin);
      return callback(null, true);
    }
    
    console.log('❌ CORS: Origin BLOCKED:', origin);
    console.log('📋 CORS: Allowed origins:', allowedOrigins);
    callback(new Error('Not allowed by CORS'));
  },
  credentials: true,
  methods: ['GET', 'POST', 'OPTIONS', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'Accept', 'Origin'],
  optionsSuccessStatus: 200 // Some legacy browsers choke on 204
};

app.use(cors(corsOptions));
app.use(express.json());

// Handle preflight requests
app.options('*', cors(corsOptions));

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadDir = './uploads';
    fs.ensureDirSync(uploadDir);
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, file.fieldname + '-' + uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({ 
  storage: storage,
  limits: {
    fileSize: 100 * 1024 * 1024 // 100MB limit
  },
  fileFilter: (req, file, cb) => {
    // Accept video and audio files
    if (file.mimetype.startsWith('video/') || file.mimetype.startsWith('audio/')) {
      cb(null, true);
    } else {
      cb(new Error('Only video and audio files are allowed!'), false);
    }
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'OK', message: 'FFmpeg Translation Middleware is running' });
});

// Main endpoint for video/audio processing and translation
app.post('/api/process-and-translate', upload.single('media'), async (req, res) => {
  let inputFile = null;
  let outputFile = null;

  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No media file provided' });
    }

    const { language = 'en' } = req.body;
    inputFile = req.file.path;
    const outputDir = './converted';
    await fs.ensureDir(outputDir);
    
    // Generate output filename
    const outputFilename = `converted-${Date.now()}.mp3`;
    outputFile = path.join(outputDir, outputFilename);

    console.log(`Processing file: ${inputFile}`);
    console.log(`Converting to: ${outputFile}`);

    // Convert video/audio to MP3 using FFmpeg
    await new Promise((resolve, reject) => {
      ffmpeg(inputFile)
        .toFormat('mp3')
        .audioCodec('mp3')
        .audioBitrate(128)
        .on('start', (commandLine) => {
          console.log('FFmpeg command: ' + commandLine);
        })
        .on('progress', (progress) => {
          console.log('Processing: ' + progress.percent + '% done');
        })
        .on('end', () => {
          console.log('Conversion finished successfully');
          resolve();
        })
        .on('error', (err) => {
          console.error('FFmpeg error:', err);
          reject(err);
        })
        .save(outputFile);
    });

    // Read the converted MP3 file
    const audioBuffer = await fs.readFile(outputFile);
    
    // Create FormData to send to Cloudflare Worker
    const formData = new FormData();
    const audioBlob = new Blob([audioBuffer], { type: 'audio/mp3' });
    formData.append('audio', audioBlob, 'converted.mp3');
    formData.append('language', language);

    console.log('Sending audio to Cloudflare Worker for transcription and translation...');

    // Send to Cloudflare Worker
    const workerUrl = process.env.CLOUDFLARE_WORKER_URL || 'https://translate.lab-account-850.workers.dev/api/translate';
    const workerResponse = await axios.post(workerUrl, formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
      timeout: 60000 // 60 second timeout
    });

    console.log('Received response from Cloudflare Worker');

    // Return the translation result
    res.json({
      success: true,
      originalFile: req.file.originalname,
      convertedSize: audioBuffer.length,
      translation: workerResponse.data
    });

  } catch (error) {
    console.error('Error processing request:', error);
    
    let errorMessage = 'An error occurred during processing';
    if (error.response) {
      // Error from Cloudflare Worker
      errorMessage = `Worker error: ${error.response.data?.error || error.response.statusText}`;
    } else if (error.message) {
      errorMessage = error.message;
    }

    res.status(500).json({
      error: errorMessage,
      details: error.message
    });
  } finally {
    // Clean up temporary files
    try {
      if (inputFile && await fs.pathExists(inputFile)) {
        await fs.remove(inputFile);
        console.log('Cleaned up input file:', inputFile);
      }
      if (outputFile && await fs.pathExists(outputFile)) {
        await fs.remove(outputFile);
        console.log('Cleaned up output file:', outputFile);
      }
    } catch (cleanupError) {
      console.error('Error cleaning up files:', cleanupError);
    }
  }
});

// Error handling middleware
app.use((error, req, res, next) => {
  if (error instanceof multer.MulterError) {
    if (error.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({ error: 'File too large. Maximum size is 100MB.' });
    }
  }
  
  console.error('Unhandled error:', error);
  res.status(500).json({ error: error.message || 'Internal server error' });
});

// Start server
app.listen(PORT, () => {
  console.log(`FFmpeg Translation Middleware running on port ${PORT}`);
  console.log(`Health check: http://localhost:${PORT}/health`);
  console.log(`API endpoint: http://localhost:${PORT}/api/process-and-translate`);
});

module.exports = app;
