const messages = [
  {
    attempt: 1,
    prompt: `You are [PERSONALITY_TYPE]. Generate a gentle, encouraging wake-up message.
User's goal: [USER_GOAL]
Tone: Warm, supportive, understanding
Length: 15-20 seconds when spoken
Include: Their specific goal, gentle motivation
Example tone: "Good morning! Ready to work on [goal]? Let's start this day right!"`
  },
  {
    attempt: 2,
    prompt: `You are [PERSONALITY_TYPE]. Generate a firmer wake-up message.
User's goal: [USER_GOAL]
Tone: More direct, accountability-focused, still caring
Length: 20-25 seconds when spoken
Include: Reference to their commitment, gentle pressure
Example tone: "Hey! I know you can hear me. Your [goal] won't complete itself!"`
  },
  {
    attempt: 3,
    prompt: `You are [PERSONALITY_TYPE]. Generate an urgent wake-up message.
User's goal: [USER_GOAL]
Tone: Demanding, accountability-focused, disappointed but not mean
Length: 25-30 seconds when spoken
Include: This is attempt #3, their goal is important, time is running out
Example tone: "This is attempt 3! You committed to [goal]. Stop pretending you can't hear me!"`
  },
  {
    attempt: 4,
    prompt: `You are [PERSONALITY_TYPE]. Generate a final warning wake-up message.
User's goal: [USER_GOAL]
Tone: Final ultimatum, disappointed, giving up on them
Length: 30 seconds max when spoken
Include: This is the last attempt, they're on their own now, consequences
Example tone: "FINAL WARNING! [goal] was YOUR priority. I'm done. Don't blame me when you fail!"
Add instruction: Include attention-grabbing sounds or effects in TTS`
  }
];

const napMessages = [
  {
    attempt: 1,
    prompt: `You are [PERSONALITY_TYPE]. Generate a gentle, encouraging nap wake-up message.
User's goal after the nap: [USER_GOAL]
Tone: Calm, supportive, reassuring
Length: 15-20 seconds when spoken
Include: Acknowledge the nap, help them transition to their goal
Example tone: "Welcome back from your nap. Let's ease into [goal] and get moving."`
  },
  {
    attempt: 2,
    prompt: `You are [PERSONALITY_TYPE]. Generate a firmer nap wake-up message.
User's goal after the nap: [USER_GOAL]
Tone: More direct, accountability-focused, still calm
Length: 20-25 seconds when spoken
Include: Mention the nap is done, it's time to start their plan
Example tone: "Nap's over. Time to get up and move toward [goal]."`
  },
  {
    attempt: 3,
    prompt: `You are [PERSONALITY_TYPE]. Generate an urgent nap wake-up message.
User's goal after the nap: [USER_GOAL]
Tone: Demanding, accountability-focused, not harsh
Length: 25-30 seconds when spoken
Include: This is attempt #3, nap is done, time to act
Example tone: "This is attempt 3. Nap is over. Get up and start [goal] now."`
  },
  {
    attempt: 4,
    prompt: `You are [PERSONALITY_TYPE]. Generate a final warning nap wake-up message.
User's goal after the nap: [USER_GOAL]
Tone: Final ultimatum, disappointed, urging action
Length: 30 seconds max when spoken
Include: This is the last attempt, nap time is done, consequences
Add instruction: Include attention-grabbing sounds or effects in TTS`
  }
];

function getTemplate(attempt, isNap) {
  const list = isNap ? napMessages : messages;
  return list.find((item) => item.attempt === attempt) ?? null;
}

function createConsolidatedPrompt({ goal, personality, isNap }) {
  let prompt = `You are ${personality}. Generate a sequence of 4 escalating wake-up messages.\n`;
  prompt += "Output ONLY the raw text for the TTS engine. Do not include labels like 'Attempt 1' or 'Message:'.\n";
  prompt += "Separate each message EXACTLY with this tag: <break time=\"6.0s\" />\n";
  prompt += "Ensure the output is clean text and SSML tags only.\n\n";

  for (let i = 1; i <= 4; i += 1) {
    const template = getTemplate(i, isNap);
    if (!template) {
      continue;
    }
    const specificInstruction = template.prompt
      .replace("You are [PERSONALITY_TYPE]. ", "")
      .replace("Generate a ", `Message ${i}: Generate a `);
    prompt += `${specificInstruction}\n`;
  }

  prompt += "\nExample output format:\n";
  prompt += "Good morning [goal]... <break time=\"6.0s\" /> Come on, wake up... <break time=\"6.0s\" /> ...\n";
  prompt += `Replace [USER_GOAL] with: ${goal}`;

  return prompt;
}

module.exports = { createConsolidatedPrompt };
