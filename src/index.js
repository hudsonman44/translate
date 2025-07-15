/**
 * Welcome to Cloudflare Workers! This is your first worker.
 *
 * - Run `npm run dev` in your terminal to start a development server
 * - Open a browser tab at http://localhost:8787/ to see your worker in action
 * - Run `npm run deploy` to publish your worker
 *
 * Learn more at https://developers.cloudflare.com/workers/
 */

export default {
    async fetch(request, env, ctx) {
        // We only want to handle POST requests for transcription
        if (request.method !== 'POST') {
            // For GET requests, you might want to serve the HTML interface.
            // This example assumes the HTML is served separately or via Pages.
            // If you want to serve the HTML from this worker, you'd add that logic here.
            return new Response('Please send a POST request with a YouTube URL.', {
                status: 405,
                headers: {
                    'Allow': 'POST'
                }
            });
        }

        try {
            const {
                url,
                language
            } = await request.json();

            if (!url) {
                return new Response(JSON.stringify({
                    error: 'YouTube URL is required'
                }), {
                    status: 400,
                    headers: {
                        'Content-Type': 'application/json'
                    }
                });
            }

            // A very basic regex to extract video ID from various YouTube URL formats
            const videoIdMatch = url.match(/(?:v=|\/|embed\/|watch\?v=|\.be\/)([a-zA-Z0-9_-]{11})/);
            if (!videoIdMatch || !videoIdMatch[1]) {
                return new Response(JSON.stringify({
                    error: 'Invalid YouTube URL'
                }), {
                    status: 400,
                    headers: {
                        'Content-Type': 'application/json'
                    }
                });
            }
            const videoId = videoIdMatch[1];

            // This is a placeholder for a service that can extract audio.
            // In a real-world scenario, you would use a library or an external API
            // to get a direct audio stream URL from the YouTube video.
            // For this example, we'll simulate this process.
            // NOTE: Directly downloading from YouTube can be against their ToS.
            // Always use legitimate APIs for this. A service like `ytdl-core`
            // running on a server or another serverless function could provide this.
            // For this example, we cannot perform the audio extraction directly in the worker.
            // We will proceed assuming we have the audio bytes.

            // Let's assume you have a way to get the audio file.
            // For the purpose of this example, we'll use a placeholder.
            // In a real application, you would fetch the audio from the video.
            // This is the most complex part of the problem to solve in a Worker
            // without external services.
            //
            // A realistic approach would be:
            // 1. User sends URL to Worker.
            // 2. Worker calls a service (e.g., another function, a dedicated server)
            //    that uses a library like `ytdl-core` to get an audio stream.
            // 3. That service streams the audio back to this worker.
            // 4. This worker streams it to the Whisper model.
            //
            // Since we can't do that here, we'll return a mock response.
            // To make this functional, you need to solve the audio extraction part.
            // Let's pretend we got the audio and sent it to Whisper AI.

            // This is where you would interact with the Whisper AI model binding.
            // The `AI` binding is configured in your `wrangler.toml`.
            // const audioBlob = await getAudioFromYouTube(videoId); // This function is hypothetical
            // const inputs = { audio: [...new Uint8Array(audioBlob)] };
            // const response = await env.AI.run('@cf/openai/whisper', inputs);

            // SIMULATED RESPONSE for demonstration purposes:
            const simulatedResponse = {
                text: `This is a simulated transcription in ${language === 'es' ? 'Spanish' : 'English'} for the video ${videoId}. To make this application fully functional, you need to implement a service to extract the audio from the YouTube video, as this cannot be done directly within a Cloudflare Worker due to platform limitations and YouTube's terms of service. Once you have the audio data, you can pass it to the Whisper model using 'env.AI.run'.`
            };

            return new Response(JSON.stringify(simulatedResponse), {
                status: 200,
                headers: {
                    'Content-Type': 'application/json'
                }
            });

        } catch (error) {
            console.error('Error processing transcription request:', error);
            return new Response(JSON.stringify({
                error: 'An internal error occurred.'
            }), {
                status: 500,
                headers: {
                    'Content-Type': 'application/json'
                }
            });
        }
    },
};
