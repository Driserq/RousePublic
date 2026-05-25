const IORedis = require("ioredis");
const { config } = require("./config");

const connection = new IORedis(config.redisUrl, {
  connectionName: config.redisConnectionName,
  maxRetriesPerRequest: null
});

module.exports = { connection };
