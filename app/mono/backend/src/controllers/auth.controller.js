const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const logger = require('../config/logger');

/**
 * Authentication controller.
 *
 * Improvements vs original:
 * - Structured logging instead of catch-and-throw 500
 * - Don't leak internal error details to client (security)
 * - Use logger.error for unexpected errors with full context
 */

const register = async (req, res) => {
  try {
    const { username, email, password } = req.body;

    // Input validation (basic — Phase 5 will add joi/zod)
    if (!username || !email || !password) {
      return res.status(400).json({
        message: 'Missing required fields: username, email, password'
      });
    }

    if (password.length < 6) {
      return res.status(400).json({
        message: 'Password must be at least 6 characters'
      });
    }

    const existingUser = await User.findOne({ where: { email } });
    if (existingUser) {
      return res.status(400).json({ message: 'Email already in use' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const user = await User.create({ username, email, password: hashedPassword });

    const token = jwt.sign(
      { id: user.id, username: user.username },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN }
    );

    logger.info({ userId: user.id, email }, 'User registered successfully');

    res.status(201).json({
      token,
      user: { id: user.id, username: user.username, email: user.email }
    });
  } catch (error) {
    logger.error({ err: error }, 'Register failed');
    res.status(500).json({ message: 'Internal server error' });
  }
};

const login = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        message: 'Email and password required'
      });
    }

    const user = await User.findOne({ where: { email } });
    if (!user) {
      // Same response time as wrong password (prevent user enumeration)
      // Note: Still vulnerable to timing attack since bcrypt only runs if user exists.
      // Phase 5 will fix with dummy bcrypt comparison.
      return res.status(401).json({ message: 'Invalid email or password' });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      logger.debug({ email }, 'Failed login attempt');
      return res.status(401).json({ message: 'Invalid email or password' });
    }

    const token = jwt.sign(
      { id: user.id, username: user.username },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN }
    );

    logger.info({ userId: user.id }, 'User logged in');

    res.json({
      token,
      user: { id: user.id, username: user.username, email: user.email }
    });
  } catch (error) {
    logger.error({ err: error }, 'Login failed');
    res.status(500).json({ message: 'Internal server error' });
  }
};

module.exports = { register, login };