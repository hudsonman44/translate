/**
 * Welcome to Cloudflare Workers!
 * This worker serves the HTML interface on GET requests. On POST requests,
 * it transcribes audio to English with Whisper, then translates the
 * resulting text to a target language with M2M100.
 */


export default {
    async fetch(request, env, ctx) {
        // Handle GET requests by serving the HTML page
        if (request.method === 'GET') {
    // Read and serve the static HTML file
    const html = await fetch(new URL('./index.html', import.meta.url)).then(res => res.text());
    return new Response(html, {
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