const { httpRequestsTotal, httpRequestDuration } = require('../config/metrics');

/**
 * Middleware đo metrics cho mọi HTTP request.
 *
 * Quan trọng — Express trick:
 * - req.route.path = "/api/tasks/:id" (parameterized) ← muốn cái này
 * - req.path       = "/api/tasks/abc-123" (raw)        ← KHÔNG dùng
 *
 * Khi req.route chưa có (vd: 404, error trước routing), fallback "unmatched"
 * để tránh cardinality explosion từ random URLs.
 */
function metricsMiddleware(req, res, next) {
  // Skip /metrics endpoint itself để tránh self-monitoring loop
  if (req.path === '/metrics' || req.path.startsWith('/health')) {
    return next();
  }

  // Start timer
  const endTimer = httpRequestDuration.startTimer();

  // Hook vào response finish event
  res.on('finish', () => {
    // route pattern, fallback nếu không match
    const route = req.route?.path
      ? `${req.baseUrl || ''}${req.route.path}`
      : 'unmatched';

    const labels = {
      method: req.method,
      route,
      status_code: res.statusCode,
    };

    httpRequestsTotal.inc(labels);
    endTimer(labels);   // Đóng timer với labels
  });

  next();
}

module.exports = metricsMiddleware;