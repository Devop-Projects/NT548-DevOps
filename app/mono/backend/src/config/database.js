const { Sequelize } = require('sequelize');
const logger = require('./logger');
require('dotenv').config();

/**
 * Database connection with production-grade pool config.
 *
 * 12-Factor Compliance (Factor #3 — Config):
 * Single Source of Truth pattern:
 *   - Password: from POSTGRES_PASSWORD (same Secret as Postgres pod)
 *   - Connection metadata (host, port, db name, user): from ConfigMap
 *   - Full DATABASE_URL is built at runtime, never stored
 *
 * Why this matters?
 *   - One password, one Secret → no drift between Postgres & Backend
 *   - Sensitive vs non-sensitive cleanly separated
 *   - Easier rotation: update one Secret, both pods reload
 *
 * Backward compatibility:
 *   - If DATABASE_URL is set (e.g., docker-compose), use it directly
 *   - Otherwise, build from components (K8s pattern)
 */

function buildDatabaseUrl() {
  // Backward compat: if DATABASE_URL is fully provided, use it
  if (process.env.DATABASE_URL) {
    logger.debug('Using DATABASE_URL from environment');
    return process.env.DATABASE_URL;
  }

  // K8s pattern: build URL from components
  const host = process.env.DB_HOST;
  const port = process.env.DB_PORT || '5432';
  const name = process.env.DB_NAME;
  const user = process.env.DB_USER;
  const pass = process.env.POSTGRES_PASSWORD;

  // Validate required components
  const missing = [];
  if (!host) missing.push('DB_HOST');
  if (!name) missing.push('DB_NAME');
  if (!user) missing.push('DB_USER');
  if (!pass) missing.push('POSTGRES_PASSWORD');

  if (missing.length > 0) {
    throw new Error(
      `Cannot build DATABASE_URL. Missing env vars: ${missing.join(', ')}. ` +
      `Either set DATABASE_URL directly or provide all components.`
    );
  }

  // encodeURIComponent handles special chars in password (e.g., @, :, /)
  const encodedPass = encodeURIComponent(pass);
  return `postgres://${user}:${encodedPass}@${host}:${port}/${name}`;
}

const databaseUrl = buildDatabaseUrl();

// Log connection target (without password) for debugging
const safeUrl = databaseUrl.replace(/:([^:@]+)@/, ':***@');
logger.info({ databaseUrl: safeUrl }, 'Database connection target');

// Determine SSL config based on DB_SSL env var
// - DB_SSL=true:    Enable SSL with rejectUnauthorized=false (works with RDS)
// - DB_SSL=verify:  Enable SSL with strict cert verification (production)
// - DB_SSL=false (default): No SSL (for local docker-compose)
//
// AWS RDS requires SSL by default (rds.force_ssl=1).
// rejectUnauthorized=false: accept RDS cert without CA bundle.
// For strict verification, mount RDS CA bundle and set rejectUnauthorized=true.
const dbSslMode = (process.env.DB_SSL || 'false').toLowerCase();
let sslConfig = false;

if (dbSslMode === 'true') {
  sslConfig = {
    require: true,
    rejectUnauthorized: false,
  };
  logger.info('Database SSL enabled (no strict verification)');
} else if (dbSslMode === 'verify') {
  sslConfig = {
    require: true,
    rejectUnauthorized: true,
  };
  logger.info('Database SSL enabled (strict verification)');
}

const sequelize = new Sequelize(databaseUrl, {
  dialect: 'postgres',

  // SSL config (must be inside dialectOptions for pg driver)
  dialectOptions: {
    ssl: sslConfig,
  },

  logging: process.env.LOG_LEVEL === 'debug'
    ? (msg) => logger.debug({ sql: msg }, 'SQL query')
    : false,

  pool: {
    max: parseInt(process.env.DB_POOL_MAX || '10', 10),
    min: parseInt(process.env.DB_POOL_MIN || '2', 10),
    acquire: 30000,
    idle: 10000,
  },

  retry: {
    max: 3,
    match: [
      /ECONNRESET/,
      /ETIMEDOUT/,
      /ENOTFOUND/,
      /SequelizeConnectionError/,
    ],
  },
});

/**
 * Test connection - call at startup to verify DB reachable.
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