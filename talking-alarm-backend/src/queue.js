const { Queue, QueueEvents } = require("bullmq");
const { connection } = require("./redis");
const { queueName } = require("./queueName");

let queue;
let queueEvents;

function getQueue() {
  queue ??= new Queue(queueName, { connection });
  return queue;
}

function getQueueEvents() {
  queueEvents ??= new QueueEvents(queueName, { connection });
  return queueEvents;
}

module.exports = { getQueue, getQueueEvents, queueName };
