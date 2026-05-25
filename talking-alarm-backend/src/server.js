const Fastify = require("fastify");
const { Resend } = require("resend");
const { config } = require("./config");
const { getQueue, getQueueEvents } = require("./queue");

const queue = getQueue();
const queueEvents = getQueueEvents();
const resend = config.resendApiKey ? new Resend(config.resendApiKey) : null;

const app = Fastify({ logger: true });

app.addHook("preHandler", async (request, reply) => {
  const sharedKey = request.headers["x-talkingalarm-key"];
  if (!sharedKey || sharedKey !== config.sharedKey) {
    reply.code(401);
    throw new Error("Unauthorized");
  }
});

app.post("/v1/conversation/turn", async (request) => {
  const { llm, voice } = request.body ?? {};
  if (!llm || !voice) {
    return { error: "Missing llm or voice payload" };
  }

  const job = await queue.add("conversationTurn", { llm, voice });
  return { jobId: job.id };
});

app.post("/v1/onboarding/wake-message", async (request) => {
  const { goal, personality, isNap, llm, voice } = request.body ?? {};
  if (!goal || !personality || !llm || !voice) {
    return { error: "Missing goal, personality, llm, or voice payload" };
  }

  const job = await queue.add("consolidatedWakeMessage", {
    goal,
    personality,
    isNap: Boolean(isNap),
    llm,
    voice
  });
  return { jobId: job.id };
});

app.post("/v1/tts/personal-message", async (request) => {
  const { llm, voice } = request.body ?? {};
  if (!llm || !voice) {
    return { error: "Missing llm or voice payload" };
  }

  const job = await queue.add("personalMessage", { llm, voice });
  return { jobId: job.id };
});

app.get("/v1/jobs/:id/long-poll", async (request, reply) => {
  const jobId = request.params.id;
  const timeoutSeconds = Number(request.query?.timeout ?? 45);
  const timeoutMs = Math.max(1, timeoutSeconds) * 1000;

  const job = await queue.getJob(jobId);
  if (!job) {
    reply.code(404);
    return { error: "Job not found" };
  }

  const state = await job.getState();
  if (state === "completed") {
    return job.returnvalue;
  }
  if (state === "failed") {
    reply.code(500);
    return { error: job.failedReason ?? "Job failed" };
  }

  let result;
  try {
    result = await job.waitUntilFinished(queueEvents, timeoutMs);
  } catch (error) {
    if (error?.name === "TimeoutError") {
      reply.code(204);
      return null;
    }
    reply.code(500);
    return { error: error?.message ?? "Job wait failed" };
  }

  return result;
});

app.post("/v1/report-issue", async (request, reply) => {
  const {
    message,
    appVersion,
    buildNumber,
    osVersion,
    deviceModel,
    goal,
    lastPromptText,
    lastSSML,
    timestamp
  } = request.body ?? {};

  if (!resend) {
    app.log.warn("Resend not configured, skipping email");
    return { status: "skipped" };
  }

  const htmlBody = `
    <h2>Issue Report</h2>
    <p><strong>Message:</strong> ${message ?? "N/A"}</p>
    <p><strong>Timestamp:</strong> ${timestamp ?? "N/A"}</p>
    <hr/>
    <h3>App Info</h3>
    <p><strong>Version:</strong> ${appVersion ?? "N/A"} (${buildNumber ?? "N/A"})</p>
    <p><strong>OS:</strong> ${osVersion ?? "N/A"}</p>
    <p><strong>Device:</strong> ${deviceModel ?? "N/A"}</p>
    <hr/>
    <h3>User Context</h3>
    <p><strong>Goal:</strong> ${goal ?? "N/A"}</p>
    <hr/>
    <h3>Last AI Interaction</h3>
    <p><strong>Prompt:</strong></p>
    <pre>${lastPromptText ?? "N/A"}</pre>
    <p><strong>SSML Response:</strong></p>
    <pre>${lastSSML ?? "N/A"}</pre>
  `;

  try {
    const { data, error } = await resend.emails.send({
      from: `Talking Alarm <${config.resendFromEmail}>`,
      to: [config.resendToEmail],
      subject: `[Issue Report] ${message ?? "User Report"} - ${timestamp ?? ""}`,
      html: htmlBody
    });

    if (error) {
      app.log.error({ error }, "Resend email failed");
      reply.code(500);
      return { status: "error", error: error.message };
    }

    app.log.info({ emailId: data?.id }, "Issue report sent");
    return { status: "sent" };
  } catch (err) {
    app.log.error({ err }, "Resend email exception");
    reply.code(500);
    return { status: "error", error: err.message };
  }
});

app.listen({ port: config.port, host: "0.0.0.0" }).catch((error) => {
  app.log.error(error);
  process.exit(1);
});
