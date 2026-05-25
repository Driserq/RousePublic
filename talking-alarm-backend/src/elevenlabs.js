const { config } = require("./config");

async function callElevenLabsTTS({
  text,
  voiceId,
  modelId,
  stability,
  similarityBoost,
  style,
  useSpeakerBoost
}) {
  if (!config.elevenLabsApiKey) {
    throw new Error("ELEVENLABS_API_KEY missing");
  }

  if (!voiceId) {
    throw new Error("voiceId missing");
  }

  const response = await fetch(`${config.elevenLabsBaseUrl}/text-to-speech/${voiceId}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "xi-api-key": config.elevenLabsApiKey
    },
    body: JSON.stringify({
      text,
      model_id: modelId,
      voice_settings: {
        stability,
        similarity_boost: similarityBoost,
        style,
        use_speaker_boost: useSpeakerBoost
      }
    })
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`ElevenLabs error ${response.status}: ${errorText}`);
  }

  const arrayBuffer = await response.arrayBuffer();
  const buffer = Buffer.from(arrayBuffer);
  const mime = response.headers.get("content-type") ?? "audio/mpeg";

  return { buffer, mime };
}

module.exports = { callElevenLabsTTS };
