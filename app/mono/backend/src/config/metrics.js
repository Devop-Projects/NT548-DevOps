/**
 * Prometheus metrics setup.
 *
 * Exposes 4 categories of metrics:
 * 1. Default Node.js metrics (memory, GC, event loop lag, etc.)
 * 2. HTTP request counter (rate)
 * 3. HTTP request duration histogram (latency p50/p95/p99)
 * 4. DB pool gauge (saturation)
 *
 * Aligned with RED method:
 *   R(ate)     → http_requests_total counter
 *   E(rrors)   → http_requests_total with status_code label
 *   D(uration) → http_request_duration_seconds histogram
 */

const promClient = require('prom-client');

// Default registry (singleton)
const register = new promClient.Registry();

// Add default labels (applied to ALL metrics)
register.setDefaultLabels({
  app: 'backend',
  service: 'task-manager-backend',
});

// ─── Collect default Node.js metrics ───
// Includes: process_cpu_seconds_total, nodejs_heap_size_bytes,
// nodejs_eventloop_lag_seconds, nodejs_gc_duration_seconds, etc.
promClient.collectDefaultMetrics({
  register,
  prefix: '',                 // No prefix → standard Prometheus names
  gcDurationBuckets: [0.001, 0.01, 0.1, 1, 2, 5],
});

// ─── Custom: HTTP request counter ───
// Used for: Rate (req/s), Errors (% by status_code)
const httpRequestsTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register],
});

// ─── Custom: HTTP request duration histogram ───
// Used for: Duration (p50/p95/p99 latency)
const httpRequestDurationSeconds = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'route', 'status_code'],
  // Buckets aligned with SLO (300ms target)
  // Wide range để cover both fast cache hits and slow DB queries
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10],
  registers: [register],
});

// ─── Custom: DB pool active connections gauge ───
// Used for: Saturation (DB pool exhaustion = leading indicator)
const dbPoolConnectionsActive = new promClient.Gauge({
  name: 'db_pool_connections_active',
  help: 'Active database connections in pool',
  registers: [register],
});

const tasksCreatedTotal = new promClient.Counter({
  name: 'tasks_created_total',
  help: 'Total tasks created',
  registers: [register],
});

const authFailuresTotal = new promClient.Counter({
  name: 'auth_failures_total',
  help: 'Total auth failures',
  labelNames: ['reason'],
  registers: [register],
});

module.exports = {
  register,
  httpRequestsTotal,
  httpRequestDurationSeconds,
  dbPoolConnectionsActive,
  tasksCreatedTotal,    // ← thêm
  authFailuresTotal,    // ← thêm
};
