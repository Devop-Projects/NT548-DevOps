const express = require('express');
const cors = require('cors');
const pinoHttp = require('pino-http');
require('dotenv').config();

const logger = require('./config/logger');
const { validateConfig } = require('./config/validate');
const sequelize = require('./config/database');

// Import models (Sequelize needs to know them)
require('./models/User');
require('./models/Task');

const authRoutes = require('./routes/auth.routes');
const taskRoutes = require('./routes/task.routes');

/**
 * Application bootstrap with graceful shutdown.
 *
 * 12-Factor compliance:
 * - #3 Config: validateConfig() at startup
 * - #6 Stateless: no in-memory state
 * - #9 Disposability: graceful shutdown handling SIGTERM
 * - #11 Logs: structured JSON via pino
 * - #12 Admin: migrations separated (run npm run migrate)
 */

// Step 1: Validate config FIRST (fail fast if env vars missing)
validateConfig();

const app = express();

// HTTP request logging middleware (replaces morgan)
app.use(pinoHttp({
  logger,
  // Don't log health checks (would flood logs in K8s)
  autoLogging: {
    ignore: (req) => req.url === '/health/live' || req.url === '/health/ready',
  },
  // Customize log fields
  customLogLevel: (req, res, err) => {
    if (res.statusCode >= 500 || err) return 'error';
    if (res.statusCode >= 400) return 'warn';
    return 'info';
  },
}));

app.use(cors());
app.use(express.json());

// ─── Health Check Endpoints ─────────────────────────────────────
//
// LIVENESS: "Is the process alive?" → should K8s restart pod?
// Don't check dependencies. If this fails, restart will help.
//
// READINESS: "Can the app handle traffic?" → should K8s route requests here?
// Check dependencies (DB). If fails, K8s won't route until ready.
//
// Why split? See https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/

app.get('/health/live', (req, res) => {
  // Simplest possible — if Express responds, process is alive
  res.json({ status: 'alive' });
});

app.get('/health/ready', async (req, res) => {
  try {
    // Check DB connection
    await sequelize.authenticate();
    res.json({ status: 'ready', dependencies: { database: 'ok' } });
  } catch (err) {
    logger.warn({ err }, 'Readiness check failed');
    res.status(503).json({
      status: 'not_ready',
      dependencies: { database: 'unreachable' }
    });
  }
});

// Legacy health endpoint (backward compatibility)
app.get('/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// ─── Routes ─────────────────────────────────────────────────────
app.use('/api/auth', authRoutes);
app.use('/api/tasks', taskRoutes);

// 404 handler
app.use((req, res) => {
  res.status(404).json({ message: 'Route not found' });
});

// Global error handler (catches errors thrown in async handlers)
app.use((err, req, res, next) => {
  logger.error({ err, path: req.path }, 'Unhandled error in request');
  res.status(500).json({ message: 'Internal server error' });
});

// ─── Server Startup ─────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
let server;

async function startServer() {
  try {
    // Verify DB reachable but DON'T sync schema (use migrations)
    await sequelize.testConnection();

    server = app.listen(PORT, () => {
      logger.info({ port: PORT }, 'Server started');
    });

    // Tune server keep-alive for K8s/load balancer
    server.keepAliveTimeout = 65000;  // > load balancer's idle timeout
    server.headersTimeout = 66000;    // slightly higher than keepAliveTimeout

  } catch (err) {
    logger.fatal({ err }, 'Failed to start server');
    process.exit(1);
  }
}

// ─── Graceful Shutdown (Factor #9: Disposability) ────────────────
//
// Sequence when K8s terminates pod:
//   T=0s    : K8s sends SIGTERM
//   T=0s    : Mark pod NotReady (stop new requests via readiness)
//   T=0-30s : Finish in-flight requests, close DB connections
//   T=30s   : K8s sends SIGKILL if still alive (terminationGracePeriodSeconds)
//
// Without this code: SIGTERM kills process immediately → in-flight requests fail (502)

let isShuttingDown = false;

async function gracefulShutdown(signal) {
  if (isShuttingDown) return;
  isShuttingDown = true;

  logger.info({ signal }, 'Shutdown signal received, starting graceful shutdown');

  // Step 1: Stop accepting new connections
  if (server) {
    server.close(async () => {
      logger.info('HTTP server closed (no new connections)');

      // Step 2: Close DB connection pool
      try {
        await sequelize.close();
        logger.info('Database connection pool closed');
      } catch (err) {
        logger.error({ err }, 'Error closing database');
      }

      // Step 3: Exit cleanly
      logger.info('Graceful shutdown completed');
      process.exit(0);
    });

    // Force exit after timeout (K8s default grace period is 30s)
    const SHUTDOWN_TIMEOUT = 25000;  // 25s, leave 5s buffer for K8s SIGKILL
    setTimeout(() => {
      logger.error('Could not close connections in time, forcing shutdown');
      process.exit(1);
    }, SHUTDOWN_TIMEOUT).unref();  // .unref() so this timer doesn't keep process alive

  } else {
    process.exit(0);
  }
}

// Register signal handlers
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));   // Ctrl+C

// Catch unhandled errors (don't crash silently)
process.on('uncaughtException', (err) => {
  logger.fatal({ err }, 'Uncaught exception');
  gracefulShutdown('uncaughtException');
});

process.on('unhandledRejection', (reason, promise) => {
  logger.fatal({ reason, promise }, 'Unhandled promise rejection');
  gracefulShutdown('unhandledRejection');
});

// Start the server
startServer();

module.exports = app;