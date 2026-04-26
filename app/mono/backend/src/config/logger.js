const pino = require('pino');

/**
 * Centralized logger using pino.
 *
 * Why pino?
 * - Fastest Node.js logger (5-10x faster than winston)
 * - Native JSON output (structured logging - 12-factor #11)
 * - Async by default (won't block event loop)
 *
 * Levels (lowest to highest):
 *   trace, debug, info, warn, error, fatal
 *
 * In production: log level = info (skip debug/trace for performance)
 * In dev: log level = debug, with pretty-print for readability
 */

const isDev = process.env.NODE_ENV !== 'production';

const logger = pino({
  level: process.env.LOG_LEVEL || (isDev ? 'debug' : 'info'),

  // Pretty print for dev, JSON for production
  ...(isDev && {
    transport: {
      target: 'pino-pretty',
      options: {
        colorize: true,
        translateTime: 'SYS:HH:MM:ss',
        ignore: 'pid,hostname',
      },
    },
  }),

  // Base fields included in every log line
  base: {
    service: 'task-manager-backend',
    env: process.env.NODE_ENV || 'development',
  },

  // Redact sensitive fields automatically
  redact: {
    paths: ['password', '*.password', 'authorization', '*.authorization', 'token', '*.token'],
    censor: '[REDACTED]',
  },

  // Format error objects properly
  serializers: {
    err: pino.stdSerializers.err,
    req: pino.stdSerializers.req,
    res: pino.stdSerializers.res,
  },
});

module.exports = logger;