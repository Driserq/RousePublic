import Foundation

// ============================================================================
// USER CONFIGURATION FILE
// ============================================================================
// Edit the values below to customize your Talking Alarm app behavior
// ============================================================================

struct UserConfig {
    
    // MARK: - OpenAI Settings
    static let openAI = OpenAIConfig(
        apiKey: AppConfig.shared.openAIKey,  // Uses your existing key
        baseURL: "https://api.openai.com/v1",
        model: "gpt-4o-mini",               // Change to: "gpt-4", "gpt-3.5-turbo", etc.
        temperature: 0.8,                    // 0.0 = very focused, 1.0 = very creative
        maxTokens: 150,                      // Maximum response length
        presencePenalty: 0.6,                // Encourages new topics
        frequencyPenalty: 0.3,               // Reduces repetition
        systemPrompt: "You are The Grind Master: a brisk, effective morning coach.",
        userPromptTemplate: "Tone: {tone}. User's goal: {goal}. Slept about {hours} hours. {lastReply} Ask a short question requiring them to state a concrete action they will take right now.",
        goodLuckPromptTemplate: "The user just successfully completed their wake-up challenge for their goal: {goal}. Their response was: '{userResponse}'. Give them an enthusiastic, brief good luck message that references what they said and encourages them for their day. Keep it under 25 words and make it energetic and positive. End with something like 'Now go crush it!' or 'Let's make it happen!'",
        promptVariables: [:]
    )
    
    // MARK: - Custom Prompt Examples
    
    // Example 1: Motivational Coach Style
    static let motivationalCoach = OpenAIConfig.custom(
        systemPrompt: "You are The Motivational Master: an inspiring, energetic coach who believes in the user's potential.",
        userPromptTemplate: "Style: {tone}. Goal: {goal}. Sleep: {hours} hours. {lastReply} Inspire them with a powerful question that makes them excited to take action right now. Use motivational language and energy.",
        goodLuckPromptTemplate: "Goal: {goal}. Response: '{userResponse}'. Give them a powerful, motivational send-off that celebrates their commitment and fills them with energy for the day ahead!"
    )
    
    // Example 2: Drill Sergeant Style
    static let drillSergeant = OpenAIConfig.custom(
        systemPrompt: "You are The Drill Sergeant: a tough, no-nonsense coach who demands excellence.",
        userPromptTemplate: "Style: {tone}. Mission: {goal}. Sleep: {hours} hours. {lastReply} Give them a direct, challenging question that demands a specific, actionable response. Be authoritative and demanding.",
        goodLuckPromptTemplate: "Mission: {goal}. Response: '{userResponse}'. Acknowledge their commitment with a brief, authoritative command to go execute their plan."
    )
    
    // Example 3: Zen Master Style
    static let zenMaster = OpenAIConfig.custom(
        systemPrompt: "You are The Zen Master: a calm, wise coach who guides through mindfulness and clarity.",
        userPromptTemplate: "Approach: {tone}. Goal: {goal}. Sleep: {hours} hours. {lastReply} Ask them a thoughtful, reflective question that helps them find clarity about their next action. Be calm and insightful.",
        goodLuckPromptTemplate: "Goal: {goal}. Response: '{userResponse}'. Give them a calm, wise blessing for their day ahead, acknowledging their clarity and commitment."
    )
    
    // Example 4: Personal Trainer Style
    static let personalTrainer = OpenAIConfig.custom(
        systemPrompt: "You are The Personal Trainer: a fitness-focused coach who builds strength and discipline.",
        userPromptTemplate: "Energy: {tone}. Fitness Goal: {goal}. Sleep: {hours} hours. {lastReply} Ask them for a specific exercise or fitness action they'll do right now. Be encouraging but push them to commit to something concrete.",
        goodLuckPromptTemplate: "Fitness Goal: {goal}. Response: '{userResponse}'. Give them a fitness-focused encouragement that gets them pumped to crush their workout and dominate the day!"
    )
    
    // Example 5: Business Coach Style
    static let businessCoach = OpenAIConfig.custom(
        systemPrompt: "You are The Business Coach: a strategic, results-oriented mentor who focuses on productivity and achievement.",
        userPromptTemplate: "Approach: {tone}. Business Goal: {goal}. Sleep: {hours} hours. {lastReply} Ask them for a specific, measurable action they'll take in the next 30 minutes to advance their goal. Focus on results and execution.",
        goodLuckPromptTemplate: "Business Goal: {goal}. Response: '{userResponse}'. Give them a professional, results-focused encouragement that sets them up for a productive, successful day."
    )
    
    // MARK: - ElevenLabs Voice Settings
    static let elevenLabs = ElevenLabsConfig(
        apiKey: AppConfig.shared.elevenLabsKey,  // Uses your existing key
        baseURL: "https://api.elevenlabs.io/v1",
        voiceId: "CwhRBWXzGAHq8TQ4Fs17",        // Change to any voice ID you prefer
        modelId: "eleven_turbo_v2_5",            // Change to: "eleven_monolingual_v1", etc.
        stability: 0.3,                          // 0.0 = very expressive, 1.0 = very stable
        similarityBoost: 0.9,                    // How similar to original voice
        style: 0.8,                              // 0.0 = neutral, 1.0 = very styled
        useSpeakerBoost: true,                   // Enhances voice clarity
        sampleRate: 44100,                       // Audio quality: 22050, 44100, 48000
        bitDepth: 16,                            // Audio quality: 16, 24
        channels: 1                               // 1 = mono, 2 = stereo
    )
    
    
    // MARK: - App Behavior Settings
    static let behavior = AppBehaviorConfig(
        maxAttempts: 5,                          // Maximum conversation attempts
        evaluationDelaySeconds: 2.0,             // Wait time after user speaks
        autoContinueDelaySeconds: 0.5,           // Delay before auto-continuing
        confidenceThresholds: [                  // Confidence required per attempt
            1: 0.7,                              // First attempt: 70% confidence
            2: 0.65,                             // Second attempt: 65% confidence
            3: 0.6,                              // Third attempt: 60% confidence
            4: 0.55,                             // Fourth attempt: 55% confidence
            5: 0.5                               // Fifth attempt: 50% confidence
        ],
        heuristicWeight: 0.3,                    // Weight for coherence analysis
        recordingSampleRate: 16000,              // Recording quality
        recordingChannels: 1,                    // Mono recording
        recordingBitDepth: 16,                   // 16-bit audio
        enableAutoStop: true,                    // Enable automatic recording stop
        silenceThresholdSeconds: 2.0,            // Stop after 2.0s of silence (increased from 1.2s for groggy users)
        maxRecordingDurationSeconds: 20.0,       // Maximum recording length
        warningDurationSeconds: 15.0,            // Show warning at 15s
        volumeThreshold: 0.015,                  // Minimum volume to detect speech
        debugModeEnabled: true,                  // Show debug information
        showConfidenceScores: true,              // Display confidence scores
        showTranscripts: true                    // Display user transcripts
    )

    // MARK: - Alarm Mode
    // Toggle to use media-based alarm (recommended) instead of escalating notifications
    static let useMediaAlarm: Bool = true
    
    // MARK: - Current Configuration
    static let current = UserConfig.self
}

// ============================================================================
// QUICK PRESETS - Uncomment one to use instead of custom settings above
// ============================================================================

// MARK: - Fast Response Preset
// static let current = MasterConfig.performance

// MARK: - High Quality Preset  
// static let current = MasterConfig.quality

// MARK: - Conservative Preset
// static let current = MasterConfig.conservative

// MARK: - Custom Settings (Default)
// static let current = MasterConfig(
//     openAI: UserConfig.openAI,
//     elevenLabs: UserConfig.elevenLabs,
//     assemblyAI: UserConfig.assemblyAI,
//     behavior: UserConfig.behavior
// )

// ============================================================================
// PROMPT CUSTOMIZATION GUIDE
// ============================================================================
/*
 
 HOW TO CUSTOMIZE PROMPTS:
 
 1. SYSTEM PROMPT: Defines the AI's personality and role
    - Example: "You are The Grind Master: a brisk, effective morning coach."
    - Change to: "You are The Motivational Master: an inspiring, energetic coach..."
 
 2. USER PROMPT TEMPLATE: The structure of what you ask the AI
    - Variables: {tone}, {goal}, {hours}, {lastReply}
    - Example: "Tone: {tone}. Goal: {goal}. Sleep: {hours} hours. Ask a question..."
 
 3. GOOD LUCK PROMPT TEMPLATE: What you ask for the success message
    - Variables: {goal}, {userResponse}
    - Example: "Goal: {goal}. Response: '{userResponse}'. Give encouragement..."
 
 4. PROMPT VARIABLES: Default values for template variables
    - Used when building prompts dynamically
 
 QUICK SWITCHES:
 
 To use a different style, change this line in UserConfig:
 
 // Instead of: openAI: UserConfig.openAI
 openAI: UserConfig.motivationalCoach    // For motivational style
 openAI: UserConfig.drillSergeant        // For tough love style
 openAI: UserConfig.zenMaster            // For calm wisdom style
 openAI: UserConfig.personalTrainer      // For fitness focus
 openAI: UserConfig.businessCoach        // For business focus
 
 Or create your own custom configuration:
 
 openAI: OpenAIConfig.custom(
     systemPrompt: "Your custom personality here...",
     userPromptTemplate: "Your custom prompt structure with {variables}...",
     goodLuckPromptTemplate: "Your custom success message prompt..."
 )
 
 */
