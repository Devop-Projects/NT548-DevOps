/**
 * Config validator — fail-fast pattern.
 *
 * Validates 2 modes:
 *   Mode 1 (Docker Compose): DATABASE_URL provided directly
 *   Mode 2 (K8s): Build URL from DB_HOST, DB_PORT, DB_NAME, DB_USER, POSTGRES_PASSWORD
 *
 * At least one mode must be fully satisfied.
 */

const logger = require('./logger');

// Always required (regardless of mode)
const ALWAYS_REQUIRED = [
  'PORT',
  'JWT_SECRET',
  'JWT_EXPIRES_IN',
];

// Mode 2 required vars (when DATABASE_URL not set)
const DB_COMPONENTS = [
  'DB_HOST',
  'DB_NAME',
  'DB_USER',
  'POSTGRES_PASSWORD',
];

const RECOMMENDED_VARS = [
  'NODE_ENV',
  'LOG_LEVEL',
];

function validateConfig() {
  const missing = [];
  const warnings = [];

  // Check always-required
  for (const key of ALWAYS_REQUIRED) {
    if (!process.env[key] || process.env[key].trim() === '') {
      missing.push(key);
    }
  }

  // Check DB config (one of two modes must be satisfied)
  const hasDbUrl = !!(process.env.DATABASE_URL && process.env.DATABASE_URL.trim() !== '');

  if (!hasDbUrl) {
    // Mode 2: Need all components
    const dbMissing = DB_COMPONENTS.filter(
      key => !process.env[key] || process.env[key].trim() === ''
    );
    if (dbMissing.length > 0) {
      missing.push(`(Either DATABASE_URL OR all of: ${dbMissing.join(', ')})`);
    }
  } else {
    logger.info('Using DATABASE_URL (Mode 1: Direct)');
  }

  // Check recommended
  for (const key of RECOMMENDED_VARS) {
    if (!process.env[key]) {
      warnings.push(key);
    }
  }

  // Validate specific values
  if (process.env.JWT_SECRET && process.env.JWT_SECRET.length < 32) {
    warnings.push('JWT_SECRET should be at least 32 characters for security');
  }

  if (process.env.NODE_ENV === 'production' && process.env.JWT_SECRET === 'dev-secret-change-in-production') {
    missing.push('JWT_SECRET (using default dev value in production!)');
  }

  // Fail fast on missing required
  if (missing.length > 0) {
    logger.fatal(
      { missing },
      'FATAL: Missing required environment variables. App cannot start.'
    );
    logger.fatal('Always required: ' + ALWAYS_REQUIRED.join(', '));
    logger.fatal('DB config: Either DATABASE_URL OR all of (' + DB_COMPONENTS.join(', ') + ')');
    process.exit(1);
  }

  // Warn on recommended
  if (warnings.length > 0) {
    logger.warn({ warnings }, 'Configuration warnings');
  }

  logger.info({
    nodeEnv: process.env.NODE_ENV || 'development',
    port: process.env.PORT,
    logLevel: process.env.LOG_LEVEL || 'info',
    dbMode: hasDbUrl ? 'direct-url' : 'components',
  }, 'Configuration validated successfully');
}

module.exports = { validateConfig };