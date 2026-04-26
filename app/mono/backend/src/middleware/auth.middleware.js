const jwt = require('jsonwebtoken');
const logger = require('../config/logger');

/**
 * JWT authentication middleware.
 *
 * Improvements vs original:
 * - Use structured logger (not console.error)
 * - Distinguish error types: missing token vs expired vs invalid
 * - Don't leak stack traces to client
 * - Add request context to logs (requestId, path)
 */

const authMiddleware = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({
      message: 'Authentication required',
      code: 'NO_TOKEN'
    });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    next();
  } catch (err) {
    // Differentiate error types for better client UX
    if (err.name === 'TokenExpiredError') {
      logger.debug({
        path: req.path,
        expiredAt: err.expiredAt,
      }, 'Token expired');

      return res.status(401).json({
        message: 'Token expired',
        code: 'TOKEN_EXPIRED'
      });
    }

    if (err.name === 'JsonWebTokenError') {
      logger.warn({
        path: req.path,
        reason: err.message,
      }, 'Invalid token attempt');

      return res.status(401).json({
        message: 'Invalid token',
        code: 'INVALID_TOKEN'
      });
    }

    // Unexpected error
    logger.error({ err, path: req.path }, 'JWT verification error');
    return res.status(500).json({
      message: 'Authentication error',
      code: 'AUTH_ERROR'
    });
  }
};

module.exports = authMiddleware;