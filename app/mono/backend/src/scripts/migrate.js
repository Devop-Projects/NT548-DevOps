#!/usr/bin/env node
/**
 * Database migration script.
 *
 * Why separate from app.js?
 *
 * 12-factor #12 — Admin processes:
 *   "Run admin/management tasks as one-off processes"
 *
 * Bad pattern (old code):
 *   app.js does sequelize.sync({alter: true}) on every start
 *   - Race condition: 3 pods start → 3 ALTER TABLE concurrent → corruption
 *   - Slow startup: every pod runs migration unnecessarily
 *   - Dangerous: alter:true can drop columns silently
 *
 * Good pattern (this file):
 *   Run separately as one-off:
 *     npm run migrate           # Apply schema
 *     npm run migrate:undo      # Rollback last
 *
 * In K8s:
 *   Use Job (one-off) or initContainer to run migrations BEFORE web pods start.
 *
 * Production note:
 *   For real apps, use sequelize-cli or Flyway/Liquibase for proper migration history.
 *   This is simplified for thesis scope.
 */

require('dotenv').config();

const { validateConfig } = require('../config/validate');
const sequelize = require('../config/database');
const logger = require('../config/logger');

// Import all models so Sequelize knows about them
require('../models/User');
require('../models/Task');

async function migrate() {
  logger.info('Starting database migration...');

  validateConfig();

  try {
    await sequelize.testConnection();

    // For thesis simplicity: use sync without alter (safe default)
    // Production: use actual migration files with version tracking
    await sequelize.sync({
      // alter: false (default) — only create missing tables, don't modify existing
      // force: false (default) — don't drop existing tables
    });

    logger.info('Migration completed successfully');
    process.exit(0);
  } catch (err) {
    logger.fatal({ err }, 'Migration failed');
    process.exit(1);
  }
}

migrate();