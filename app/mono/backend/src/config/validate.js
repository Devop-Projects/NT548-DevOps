/**
 * Config validator — fail-fast pattern.
 *
 * Why this matters?
 *
 * Bad pattern: Lazy loading env vars
 *   - App starts successfully even with missing JWT_SECRET
 *   - First user request → crash with cryptic error
 *   - Hard to debug, especially with K8s rolling deployment
 *
 * Good pattern (this file): Validate at startup
 *   - App fails to start if config invalid
 *   - K8s sees pod CrashLoopBackoff → operator notices immediately
 *   - Clear error message saying which var is missing
 *
 * Reference: 12-factor app, Factor #3 (Config)
 */

const logger = require('./logger');

const REQUIRED_VARS = [
  'PORT',
  'DATABASE_URL',
  'JWT_SECRET',
  'JWT_EXPIRES_IN',
];

const RECOMMENDED_VARS = [
  'NODE_ENV',
  'LOG_LEVEL',
];

function validateConfig() {
  const missing = [];
  const warnings = [];

  // Check required vars
  for (const key of REQUIRED_VARS) {
    if (!process.env[key] || process.env[key].trim() === '') {
      missing.push(key);
    }
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
    logger.fatal('Required vars: ' + REQUIRED_VARS.join(', '));
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
  }, 'Configuration validated successfully');
}

module.exports = { validateConfig };