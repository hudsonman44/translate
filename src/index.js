/**
 * Welcome to Cloudflare Workers!
 * This worker handles audio file uploads and uses the Whisper model for transcription.
 */

export default {
    async fetch(request, env, ctx) {
        // We only want to handle POST requests for transcription.
        if (request.method !== 'POST') {
            return new Response('Please send a POST request with an audio file.', {
                status: 405,
                headers: {
                    'Allow': 'POST'
                }
            });
        }

        try {
            // The request body is now FormData, not JSON.
            const formData = await request.formData();
            const audioFile = formData.get('audio');
            // The language is optional, Whisper can auto-detect.
            const language = formData.get('language'); 

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

            // Convert the audio file to a Uint8Array.
            const audioBuffer = await audioFile.arrayBuffer();
            const audioArray = [...new Uint8Array(audioBuffer)];

            // Prepare the inputs for the Whisper AI model.
            const inputs = {
                audio: audioArray
            };

            // Execute the Whisper model.
            // The `AI` binding is configured in your `wrangler.toml`.
            const response = await env.AI.run('@cf/openai/whisper', inputs);

            // Return the transcribed text.
            return new Response(JSON.stringify(response), {
                status: 200,
                headers: {
                    'Content-Type': 'application/json'
                }
            });

        } catch (error) {
            console.error('Error processing transcription request:', error);
            // It's helpful to log the full error for debugging.
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
    },
};
