const { Worker } = require("bullmq");
const { connection } = require("./redis");
const { config } = require("./config");
const { queueName } = require("./queueName");
const { callOpenAIChat } = require("./openai");
const { callElevenLabsTTS } = require("./elevenlabs");
const { createConsolidatedPrompt } = require("./templates");

function buildVoiceConfig(voice) {
  return {
    voiceId: voice?.voiceId,
    modelId: voice?.modelId,
    stability: voice?.stability,
    similarityBoost: voice?.similarityBoost,
    style: voice?.style,
    useSpeakerBoost: voice?.useSpeakerBoost
  };
}

async function handleConversationTurn(data) {
  const replyText = await callOpenAIChat({
    model: data.llm.model,
    systemMessage: data.llm.systemMessage,
    userMessage: data.llm.userMessage,
    temperature: data.llm.temperature,
    maxTokens: data.llm.maxTokens,
    presencePenalty: data.llm.presencePenalty,
    frequencyPenalty: data.llm.frequencyPenalty
  });

  let parsed;
  try {
    parsed = JSON.parse(replyText);
  } catch (error) {
    throw new Error(`Conversation JSON parse failed: ${error.message}`);
  }

  const { buffer, mime } = await callElevenLabsTTS({
    text: parsed.reply,
    ...buildVoiceConfig(data.voice)
  });

  return {
    isAwake: Boolean(parsed.isAwake),
    reason: String(parsed.reason ?? ""),
    replyText: String(parsed.reply ?? ""),
    replyAudioBase64: buffer.toString("base64"),
    replyAudioMime: mime
  };
}

async function handleConsolidatedWakeMessage(data) {
  const prompt = createConsolidatedPrompt({
    goal: data.goal,
    personality: data.personality,
    isNap: data.isNap
  });

  const ssmlText = await callOpenAIChat({
    model: data.llm.model,
    systemMessage: data.llm.systemMessage,
    userMessage: prompt,
    temperature: data.llm.temperature,
    maxTokens: data.llm.maxTokens,
    presencePenalty: data.llm.presencePenalty,
    frequencyPenalty: data.llm.frequencyPenalty
  });

  const { buffer, mime } = await callElevenLabsTTS({
    text: ssmlText,
    ...buildVoiceConfig(data.voice)
  });

  return {
    ssmlText,
    audioBase64: buffer.toString("base64"),
    audioMime: mime
  };
}

async function handlePersonalMessage(data) {
  const messageText = await callOpenAIChat({
    model: data.llm.model,
    systemMessage: data.llm.systemMessage,
    userMessage: data.llm.userMessage,
    temperature: data.llm.temperature,
    maxTokens: data.llm.maxTokens,
    presencePenalty: data.llm.presencePenalty,
    frequencyPenalty: data.llm.frequencyPenalty
  });

  const { buffer, mime } = await callElevenLabsTTS({
    text: messageText,
    ...buildVoiceConfig(data.voice)
  });

  return {
    messageText,
    audioBase64: buffer.toString("base64"),
    audioMime: mime
  };
}

const worker = new Worker(
  queueName,
  async (job) => {
    switch (job.name) {
    case "conversationTurn":
      return handleConversationTurn(job.data);
    case "consolidatedWakeMessage":
      return handleConsolidatedWakeMessage(job.data);
    case "personalMessage":
      return handlePersonalMessage(job.data);
    default:
      throw new Error(`Unknown job name: ${job.name}`);
    }
  },
  {
    connection,
    drainDelay: Math.max(1, config.bullmqDrainDelaySeconds)
  }
);

worker.on("failed", (job, error) => {
  console.error(`[worker] Job ${job?.id ?? "unknown"} failed:`, error);
});

worker.on("completed", (job) => {
  console.log(`[worker] Job ${job.id} completed`);
});
