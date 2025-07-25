#!/usr/bin/env node

// Test FFmpeg availability and codecs from Node.js context
const { exec } = require('child_process');

console.log('🧪 Testing FFmpeg availability from Node.js...');

// Test 1: Check if FFmpeg is in PATH
exec('which ffmpeg', (error, stdout, stderr) => {
    if (error) {
        console.error('❌ FFmpeg not found in PATH:', error.message);
    } else {
        console.log('✅ FFmpeg found at:', stdout.trim());
    }
    
    // Test 2: Check FFmpeg version
    exec('ffmpeg -version', (error, stdout, stderr) => {
        if (error) {
            console.error('❌ Cannot get FFmpeg version:', error.message);
        } else {
            console.log('✅ FFmpeg version:', stdout.split('\n')[0]);
        }
        
        // Test 3: Check available codecs
        exec('ffmpeg -codecs | grep mp3', (error, stdout, stderr) => {
            if (error) {
                console.error('❌ Cannot check codecs:', error.message);
            } else {
                console.log('✅ MP3 codec availability:');
                console.log(stdout.trim());
            }
            
            // Test 4: Try to encode a simple MP3
            exec('ffmpeg -f lavfi -i "sine=frequency=1000:duration=1" -c:a mp3 /tmp/test-mp3.mp3 -y', (error, stdout, stderr) => {
                if (error) {
                    console.error('❌ MP3 encoding test failed:', error.message);
                    console.error('Stderr:', stderr);
                } else {
                    console.log('✅ MP3 encoding test successful!');
                    
                    // Cleanup
                    exec('rm -f /tmp/test-mp3.mp3', () => {});
                }
                
                console.log('\n📋 Environment info:');
                console.log('PATH:', process.env.PATH);
                console.log('USER:', process.env.USER);
                console.log('Working directory:', process.cwd());
            });
        });
    });
});
