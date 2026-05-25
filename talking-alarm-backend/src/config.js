const config = {
  port: Number(process.env.PORT ?? 3000),
  redisUrl: process.env.REDIS_URL ?? "redis://127.0.0.1:6379",
  redisConnectionName: process.env.REDIS_CONNECTION_NAME,
  sharedKey: process.env.TALKING_ALARM_SHARED_KEY ?? "ta-dev-shared-key",
  bullmqDrainDelaySeconds: Number(process.env.BULLMQ_DRAIN_DELAY_SECONDS ?? 60),
  openAiApiKey: process.env.OPENAI_API_KEY ?? "",
  openAiBaseUrl: process.env.OPENAI_BASE_URL ?? "https://api.openai.com/v1",
  elevenLabsApiKey: process.env.ELEVENLABS_API_KEY ?? "",
  elevenLabsBaseUrl: process.env.ELEVENLABS_BASE_URL ?? "https://api.elevenlabs.io/v1",
  resendApiKey: process.env.RESEND_API_KEY ?? "",
  resendFromEmail: process.env.RESEND_FROM_EMAIL ?? "noreply@app.kubaszewczyk.me",
  resendToEmail: process.env.RESEND_TO_EMAIL ?? "kuba@kubaszewczyk.me"
};

module.exports = { config };
