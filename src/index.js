/**
 * Welcome to Cloudflare Workers!
 * This worker serves the HTML interface on GET requests. On POST requests,
 * it transcribes audio to English with Whisper, then translates the
 * resulting text to a target language with M2M100.
 */

// The HTML content is now part of the worker script.
const HTML_CONTENT = `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Audio File Translation</title>
    <script src="https://cdn.tailwindcss.com"><\/script>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    <style>
        body {
            font-family: 'Inter', sans-serif;
        }
        /* Style for the file input button */
        input[type="file"]::file-selector-button {
            @apply font-semibold bg-blue-50 text-blue-700 hover:bg-blue-100 border-0 py-2 px-4 rounded-lg cursor-pointer transition-colors duration-200;
        }
    </style>
</head>
<body class="bg-gray-100 text-gray-800">
    <div class="container mx-auto max-w-2xl px-4 py-12">
        <div class="bg-white rounded-2xl shadow-lg p-8">
            <h1 class="text-3xl font-bold text-center mb-2 text-gray-900">Audio File Translation</h1>
            <p class="text-center text-gray-500 mb-8">Upload a file to transcribe its audio to English and then translate it.</p>

            <form id="translation-form" class="space-y-6">
                <div>
                    <label for="audio-file" class="block text-sm font-medium text-gray-700 mb-1">Upload File</label>
                    <input type="file" id="audio-file" name="audio-file" class="w-full text-sm text-gray-500 file:mr-4 file:rounded-lg file:border-0 file:bg-gray-100 file:py-2 file:px-4 file:text-sm file:font-semibold file:text-gray-700 hover:file:bg-gray-200 border border-gray-300 rounded-lg cursor-pointer" accept="audio/*,video/mp4" required>
                </div>

                <div>
                    <label for="language" class="block text-sm font-medium text-gray-700 mb-1">Translate to Language</label>
                    <select id="language" name="language" class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition">
                        <option value="es">Spanish</option>
                        <option value="en">English</option>
                    </select>
                </div>

                <div>
                    <button type="submit" id="translate-button" class="w-full bg-blue-600 text-white font-semibold py-3 px-4 rounded-lg hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 transition-all duration-300 ease-in-out flex items-center justify-center">
                        <span id="button-text">Transcribe & Translate</span>
                        <div id="loading-spinner" class="hidden animate-spin rounded-full h-5 w-5 border-b-2 border-white ml-3"></div>
                    </button>
                </div>
            </form>

            <div id="error-message" class="hidden mt-6 p-4 bg-red-100 text-red-700 rounded-lg"></div>

            <div class="mt-8">
                <label for="translation-output" class="block text-sm font-medium text-gray-700 mb-1">Translation</label>
                <div class="relative">
                    <textarea id="translation-output" readonly class="w-full h-64 p-4 border border-gray-300 rounded-lg bg-gray-50 resize-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition" placeholder="Translated text will appear here..."></textarea>
                    <button id="copy-button" class="absolute top-3 right-3 bg-gray-200 hover:bg-gray-300 text-gray-700 font-semibold py-1 px-3 rounded-lg text-sm transition-all duration-200">
                        Copy
                    </button>
                </div>
            </div>
        </div>
        <footer class="text-center text-gray-500 mt-8 text-sm">
            Powered by <a href="https://www.cloudflare.com/products/workers-ai/" target="_blank" class="text-blue-600 hover:underline">Cloudflare Workers AI</a>
        </footer>
    </div>

    <script>
        const translationForm = document.getElementById('translation-form');
        const audioFileInput = document.getElementById('audio-file');
        const languageSelect = document.getElementById('language');
        const translationOutput = document.getElementById('translation-output');
        const translateButton = document.getElementById('translate-button');
        const buttonText = document.getElementById('button-text');
        const loadingSpinner = document.getElementById('loading-spinner');
        const errorMessage = document.getElementById('error-message');
        const copyButton = document.getElementById('copy-button');

translationForm.addEventListener('submit', async (event) => {
    event.preventDefault();

    const file = audioFileInput.files[0];
    const language = languageSelect.value;
    if (!file) {
        errorMessage.textContent = "Please upload a file.";
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
        const response = await fetch('/', {
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
        navigator.clipboard.writeText(translationOutput.value)
            .then(() => {
                copyButton.textContent = 'Copied!';
                setTimeout(() => {
                    copyButton.textContent = 'Copy';
                }, 2000);
</body>
</html>
`;

export default {
    async fetch(request, env, ctx) {
        // Handle GET requests by serving the HTML page
        if (request.method === 'GET') {
            return new Response(HTML_CONTENT, {
                headers: {
                    'Content-Type': 'text/html;charset=UTF-8',
                },
            });
        }

        // Handle POST requests for transcription and translation
        if (request.method === 'POST') {
            try {
                const formData = await request.formData();
                const audioFile = formData.get('audio');
                const targetLang = formData.get('language');

                if (!audioFile || typeof audioFile === 'string') {
                    return new Response(JSON.stringify({
                        error: 'Audio file is required.'
                    }), {
                        status: 400,
                        headers: {
                            'Content-Type': 'application/json'
                        }
                    });
                }

                const audioBuffer = await audioFile.arrayBuffer();
                const audioArray = [...new Uint8Array(audioBuffer)];

                // Step 1: Transcribe audio to English text using Whisper
                const whisperInputs = {
                    audio: audioArray
                };
                const transcription = await env.AI.run('@cf/openai/whisper', whisperInputs);

                if (!transcription.text) {
                     return new Response(JSON.stringify({
                        error: 'Failed to transcribe audio.'
                    }), {
                        status: 500,
                        headers: {
                            'Content-Type': 'application/json'
                        }
                    });
                }
                
                const englishText = transcription.text;

                // Step 2: Translate the English text to the target language
                const translationInputs = {
                    text: englishText,
                    source_lang: 'en',
                    target_lang: targetLang
                };
                
                const translation = await env.AI.run('@cf/meta/m2m100-1.2b', translationInputs);

                return new Response(JSON.stringify(translation), {
                    status: 200,
                    headers: {
                        'Content-Type': 'application/json'
                    }
                });

            } catch (error) {
                console.error('Error processing request:', error);
                const errorMessage = error.message || 'An internal error occurred.';
                return new Response(JSON.stringify({
                    error: errorMessage
                }), {
                    status: 500,
                    headers: {
                        'Content-Type': 'application/json'
                    }
                });
            }
        }

        // Handle other methods
        return new Response('Method Not Allowed', {
            status: 405,
            headers: {
                'Allow': 'GET, POST'
            }
        });
    },
};
