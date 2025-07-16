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
        errorMessage.textContent = 'Please upload an audio file.';
        errorMessage.classList.remove('hidden');
        return;
    }
    errorMessage.classList.add('hidden');
    translateButton.disabled = true;
    buttonText.textContent = 'Processing...';
    loadingSpinner.classList.remove('hidden');
    const formData = new FormData();
    formData.append('audio', file); // Must be 'audio' to match backend
    formData.append('language', language);
    try {
        // IMPORTANT: Update the endpoint URL to your deployed Worker API
        const response = await fetch('https://YOUR-WORKER-SUBDOMAIN.workers.dev/api/translate', {
            method: 'POST',
            body: formData
        });
        if (!response.ok) {
            const errorData = await response.json();
            throw new Error(errorData.error || `HTTP error! status: ${response.status}`);
        }
        const data = await response.json();
        translationOutput.value = data.translated_text || JSON.stringify(data);
    } catch (error) {
        errorMessage.textContent = `Error: ${error.message}`;
        errorMessage.classList.remove('hidden');
    } finally {
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
