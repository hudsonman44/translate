// ffmpeg.wasm setup
const { createFFmpeg, fetchFile } = FFmpeg;
const ffmpeg = createFFmpeg({ log: true }); // log: true for debugging

async function extractAudioFromVideo(file) {
    if (!ffmpeg.isLoaded()) {
        await ffmpeg.load();
    }
    ffmpeg.FS('writeFile', 'input.mp4', await fetchFile(file));
    await ffmpeg.run('-i', 'input.mp4', '-vn', '-acodec', 'mp3', 'output.mp3');
    const audioData = ffmpeg.FS('readFile', 'output.mp3');
    return new Blob([audioData.buffer], { type: 'audio/mp3' });
}

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
    let file = audioInput.files[0];
    const language = languageSelect.value;
    if (!file) {
        errorMessage.textContent = 'Please upload an audio or video file.';
        errorMessage.classList.remove('hidden');
        return;
    }

    // If the file is a video, extract audio before uploading
    if (file.type.startsWith('video/')) {
        buttonText.textContent = 'Extracting audio...';
        loadingSpinner.classList.remove('hidden');
        try {
            file = await extractAudioFromVideo(file);
        } catch (err) {
            errorMessage.textContent = 'Failed to extract audio from video.';
            errorMessage.classList.remove('hidden');
            translateButton.disabled = false;
            buttonText.textContent = 'Transcribe & Translate';
            loadingSpinner.classList.add('hidden');
            return;
        }
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
        const response = await fetch('https://translate.lab-account-850.workers.dev/api/translate', {
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
