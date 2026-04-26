const { Sequelize } = require('sequelize');
const logger = require('./logger');
require('dotenv').config();

/**
 * Database connection with production-grade pool config.
 *
 * Why pool config matters?
 *
 * Default Sequelize: pool max=5
 *   - Only 5 concurrent DB connections per process
 *   - With 10 backend pods → 50 connections total
 *   - Postgres default max_connections=100 → OK now
 *   - But scale to 30 pods → 150 → DB rejects new connections
 *
 * Tune based on:
 *   - Postgres max_connections (default 100)
 *   - Number of app replicas in K8s
 *   - Average concurrent requests per pod
 *
 * Formula: pool.max × replicas <= postgres.max_connections × 0.8
 */

const sequelize = new Sequelize(process.env.DATABASE_URL, {
  dialect: 'postgres',

  // Use pino logger for SQL queries (only in debug mode)
  logging: process.env.LOG_LEVEL === 'debug'
    ? (msg) => logger.debug({ sql: msg }, 'SQL query')
    : false,

  // Connection pool tuning
  pool: {
    max: parseInt(process.env.DB_POOL_MAX || '10', 10),
    min: parseInt(process.env.DB_POOL_MIN || '2', 10),
    acquire: 30000,  // Max time (ms) to get connection from pool before throwing
    idle: 10000,     // Close connection after idle for 10s
  },

  // Retry on connection failure (transient network issues)
  retry: {
    max: 3,
    match: [
      /ECONNRESET/,
      /ETIMEDOUT/,
      /ENOTFOUND/,
      /SequelizeConnectionError/,
    ],
  },

  // Disable sync in production (use migrations instead)
  // We do NOT call .sync() here anymore - migrations are explicit
});

/**
 * Test connection - call at startup to verify DB reachable.
 * Returns Promise that resolves when connected, rejects on failure.
 */
sequelize.testConnection = async function() {
  try {
    await sequelize.authenticate();
    logger.info('Database connection established successfully');
    return true;
  } catch (err) {
    logger.error({ err }, 'Unable to connect to database');
    throw err;
  }
};

module.exports = sequelize;