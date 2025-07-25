// Configuration for LXC middleware
const LXC_API_URL = 'https:translate-glue.aaronbhudson.com:3001/api/process-and-translate';

// Note: Update this URL to your actual LXC container IP when deployed
// Example: const LXC_API_URL = 'http://192.168.1.100:3001/api/process-and-translate';

const audioInput = document.getElementById('audioInput');
const languageSelect = document.getElementById('languageSelect');
const translateButton = document.getElementById('translateButton');
const buttonText = document.getElementById('buttonText');
const loadingSpinner = document.getElementById('loadingSpinner');
const translationOutput = document.getElementById('translationOutput');
const copyButton = document.getElementById('copyButton');
const errorMessage = document.getElementById('errorMessage');

translateButton.addEventListener('click', async () => {
    errorMessage.classList.add('hidden');
    translationOutput.value = '';
    const file = audioInput.files[0];
    const language = languageSelect.value;
    
    if (!file) {
        errorMessage.textContent = 'Please upload an audio or video file.';
        errorMessage.classList.remove('hidden');
        return;
    }

    // Disable button and show loading state
    translateButton.disabled = true;
    buttonText.textContent = 'Processing...';
    loadingSpinner.classList.remove('hidden');
    errorMessage.classList.add('hidden');

    try {
        // Create FormData to send to LXC middleware
        const formData = new FormData();
        formData.append('media', file); // Changed from 'audio' to 'media' to match LXC API
        formData.append('language', language);

        // Send to LXC middleware (handles conversion + translation)
        const response = await fetch(LXC_API_URL, {
            method: 'POST',
            body: formData
        });

        if (!response.ok) {
            const errorData = await response.json();
            throw new Error(errorData.error || `HTTP error! status: ${response.status}`);
        }

        const data = await response.json();
        
        // Display the translation result
        if (data.success && data.translation) {
            translationOutput.value = data.translation.translated_text || JSON.stringify(data.translation);
        } else {
            throw new Error('Invalid response format from server');
        }

    } catch (error) {
        console.error('Translation error:', error);
        let errorMsg = 'An error occurred during processing.';
        
        if (error.message.includes('fetch')) {
            errorMsg = 'Cannot connect to processing server. Please check if the LXC middleware is running.';
        } else {
            errorMsg = `Error: ${error.message}`;
        }
        
        errorMessage.textContent = errorMsg;
        errorMessage.classList.remove('hidden');
    } finally {
        // Reset button state
        translateButton.disabled = false;
        buttonText.textContent = 'Transcribe & Translate';
        loadingSpinner.classList.add('hidden');
    }
});

copyButton.addEventListener('click', () => {
    if (translationOutput.value) {
        navigator.clipboard.writeText(translationOutput.value).then(() => {
            copyButton.textContent = 'Copied!';
            setTimeout(() => {
                copyButton.textContent = 'Copy';
            }, 2000);
        }).catch(err => {
            console.error('Failed to copy text: ', err);
        });
    }
});
