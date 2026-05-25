const { config } = require("./config");

async function callOpenAIChat({
  model,
  systemMessage,
  userMessage,
  temperature,
  maxTokens,
  presencePenalty,
  frequencyPenalty
}) {
  if (!config.openAiApiKey) {
    throw new Error("OPENAI_API_KEY missing");
  }

  const response = await fetch(`${config.openAiBaseUrl}/chat/completions`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${config.openAiApiKey}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      model,
      messages: [
        { role: "system", content: systemMessage },
        { role: "user", content: userMessage }
      ],
      temperature,
      max_tokens: maxTokens,
      presence_penalty: presencePenalty,
      frequency_penalty: frequencyPenalty
    })
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`OpenAI error ${response.status}: ${text}`);
  }

  const data = await response.json();
  const reply = data?.choices?.[0]?.message?.content;
  if (!reply) {
    throw new Error("OpenAI returned empty response");
  }

  return reply;
}

module.exports = { callOpenAIChat };
