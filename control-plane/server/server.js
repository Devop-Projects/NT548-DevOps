// ============================================================================
// control-plane/server/server.js
// ============================================================================
// Internal Developer Platform backend.
//
// This server is a thin control layer over the repo Makefile:
// - spawn allowlisted make targets
// - capture stdout/stderr
// - stream logs to the browser via Server-Sent Events
// - keep simple in-memory job state for the demo
// ============================================================================

const express = require('express');
const cors = require('cors');
const { execFile, spawn } = require('child_process');
const path = require('path');
const { promisify } = require('util');

const app = express();
const execFileAsync = promisify(execFile);
const PORT = Number(process.env.PORT || 3001);
const REPO_ROOT = path.resolve(__dirname, '../..');
const AWS_REGION = process.env.AWS_REGION || process.env.REGION || 'ap-southeast-1';
const CLUSTER_NAME = process.env.CLUSTER_NAME || 'devops-dev';
const STATUS_TTL_MS = 30 * 1000;

console.log('[startup] REPO_ROOT =', REPO_ROOT);

app.use(cors());
app.use(express.json());

let currentJob = null;
const jobs = [];
const sseClients = new Map();
let statusCache = { data: null, timestamp: 0 };

const ALLOWED_ACTIONS = ['deploy', 'hibernate', 'wake', 'destroy', 'status', 'verify'];

function serializeJob(job, includeLogs = false) {
  const payload = {
    id: job.id,
    type: job.type,
    status: job.status,
    startedAt: job.startedAt,
    finishedAt: job.finishedAt,
    exitCode: job.exitCode,
    logLineCount: job.logs.length,
  };

  if (includeLogs) {
    payload.logs = job.logs.join('');
  }

  return payload;
}

function writeSse(res, eventName, data) {
  if (eventName) {
    res.write(`event: ${eventName}\n`);
  }

  const text = typeof data === 'string' ? data : JSON.stringify(data);
  res.write(`data: ${text.replace(/\n/g, '\\n')}\n\n`);
}

function broadcastLog(jobId, line) {
  const clients = sseClients.get(jobId);
  if (!clients) return;

  clients.forEach((res) => {
    try {
      writeSse(res, null, line);
    } catch (_) {
      // The close handler removes disconnected clients.
    }
  });
}

function broadcastStatus(jobId, status) {
  const clients = sseClients.get(jobId);
  if (!clients) return;

  clients.forEach((res) => {
    try {
      writeSse(res, 'status', status);
    } catch (_) {
      // The close handler removes disconnected clients.
    }
  });
}

function finishJob(job, status, exitCode) {
  job.finishedAt = new Date().toISOString();
  job.exitCode = exitCode;
  job.status = status;

  console.log(`[job ${job.id}] finished: ${status} (exit code ${exitCode})`);
  broadcastStatus(job.id, { status, exitCode });

  const clients = sseClients.get(job.id);
  if (clients) {
    clients.forEach((res) => res.end());
    sseClients.delete(job.id);
  }

  if (currentJob && currentJob.id === job.id) {
    currentJob = null;
  }
}

function runMakeCommand(target) {
  if (currentJob && currentJob.status === 'running') {
    throw new Error(`Job ${currentJob.id} (${currentJob.type}) is still running`);
  }

  const job = {
    id: Date.now(),
    type: target,
    status: 'running',
    startedAt: new Date().toISOString(),
    finishedAt: null,
    exitCode: null,
    logs: [],
    process: null,
  };

  currentJob = job;
  jobs.unshift(job);
  if (jobs.length > 50) jobs.pop();

  console.log(`[job ${job.id}] starting: make ${target}`);
// Spawn the make command as a child process and capture its output
  const proc = spawn('make', [target], {
    cwd: REPO_ROOT,
    shell: false,
    env: {
      ...process.env,
      GIT_PAGER: 'cat',
      PAGER: 'cat',
    },
  });

  job.process = proc;

  if (target === 'destroy') {
    proc.stdin.write('destroy\n');
    proc.stdin.end();
  }

  proc.stdout.on('data', (chunk) => {
    const text = chunk.toString();
    job.logs.push(text);
    broadcastLog(job.id, text);
  });

  proc.stderr.on('data', (chunk) => {
    const text = chunk.toString();
    job.logs.push(text);
    broadcastLog(job.id, text);
  });

  proc.on('exit', (code, signal) => {
    if (signal === 'SIGTERM') {
      finishJob(job, 'cancelled', code);
    } else if (code === 0) {
      finishJob(job, 'success', code);
    } else {
      finishJob(job, 'failed', code);
    }
  });

  proc.on('error', (err) => {
    const message = `\n[ERROR] ${err.message}\n`;
    job.logs.push(message);
    broadcastLog(job.id, message);
    finishJob(job, 'failed', -1);
  });

  return { jobId: job.id };
}

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', uptime: process.uptime() });
});

function logStatusFailure(command, args, message) {
  if (process.env.DEBUG_STATUS !== '1') return;
  console.error(`[status] ${command} ${args.join(' ')} failed: ${message}`);
}

async function tryExecFile(command, args, timeoutMs = 8000, options = {}) {
  try {
    const { stdout } = await execFileAsync(command, args, {
      timeout: timeoutMs,
      encoding: 'utf8',
      env: {
        ...process.env,
        AWS_PAGER: '',
        PAGER: 'cat',
      },
    });
    return stdout;
  } catch (err) {
    if (!options.quiet) {
      logStatusFailure(command, args, err.message);
    }
    return null;
  }
}

function parseJson(value) {
  if (!value) return null;
  try {
    return JSON.parse(value);
  } catch (_) {
    return null;
  }
}

async function readClusterStatus() {
  const result = {
    cluster: { status: 'unknown', name: CLUSTER_NAME },
    nodes: { ready: 0, total: 0 },
    argocdApps: [],
    rds: { status: 'unknown', endpoint: null },
    alb: { count: 0, hostnames: [] },
    timestamp: new Date().toISOString(),
  };

  const [nodesJson, appCrdJson, rdsJson, loadBalancersJson] = await Promise.all([
    tryExecFile('kubectl', ['get', 'nodes', '--request-timeout=5s', '-o', 'json'], 6000, {
      quiet: true,
    }),
    tryExecFile(
      'kubectl',
      ['get', 'crd', 'applications.argoproj.io', '--request-timeout=5s', '-o', 'json'],
      6000,
      { quiet: true },
    ),
    tryExecFile('aws', ['rds', 'describe-db-instances', '--region', AWS_REGION, '--output', 'json']),
    tryExecFile('aws', ['elbv2', 'describe-load-balancers', '--region', AWS_REGION, '--output', 'json']),
  ]);

  const nodes = parseJson(nodesJson);
  if (nodes?.items) {
    result.nodes.total = nodes.items.length;
    result.nodes.ready = nodes.items.filter((node) =>
      node.status?.conditions?.some((condition) =>
        condition.type === 'Ready' && condition.status === 'True',
      ),
    ).length;
    result.cluster.status = result.nodes.ready > 0 ? 'healthy' : 'down';
  } else {
    result.cluster.status = 'unreachable';
  }

  if (appCrdJson) {
    const appsJson = await tryExecFile(
      'kubectl',
      ['get', 'applications.argoproj.io', '-n', 'argocd', '--request-timeout=5s', '-o', 'json'],
      6000,
      { quiet: true },
    );
    const apps = parseJson(appsJson);
    if (apps?.items) {
      result.argocdApps = apps.items.map((app) => ({
        name: app.metadata?.name || 'unknown',
        sync: app.status?.sync?.status || 'Unknown',
        health: app.status?.health?.status || 'Unknown',
      }));
    }
  }

  const rds = parseJson(rdsJson);
  if (rds?.DBInstances) {
    const instance = rds.DBInstances.find((item) =>
      item.DBInstanceIdentifier?.includes('devops'),
    );
    if (instance) {
      result.rds.status = instance.DBInstanceStatus || 'unknown';
      result.rds.endpoint = instance.Endpoint?.Address || null;
    } else {
      result.rds.status = 'not-found';
    }
  }

  const loadBalancers = parseJson(loadBalancersJson);
  if (loadBalancers?.LoadBalancers) {
    result.alb.count = loadBalancers.LoadBalancers.length;
    result.alb.hostnames = loadBalancers.LoadBalancers
      .map((loadBalancer) => loadBalancer.DNSName)
      .filter(Boolean);
  }

  return result;
}

app.get('/api/status', async (req, res) => {
  const now = Date.now();
  if (statusCache.data && now - statusCache.timestamp < STATUS_TTL_MS) {
    return res.json({ ...statusCache.data, cached: true });
  }

  if (process.env.DEBUG_STATUS === '1') {
    console.log('[status] refreshing cache');
  }
  const data = await readClusterStatus();
  statusCache = { data, timestamp: Date.now() };
  return res.json({ ...data, cached: false });
});

app.post('/api/status/refresh', (req, res) => {
  statusCache = { data: null, timestamp: 0 };
  res.json({ message: 'Cache invalidated' });
});

app.post('/api/actions/:name', (req, res) => {
  const { name } = req.params;

  if (!ALLOWED_ACTIONS.includes(name)) {
    return res.status(400).json({
      error: `Invalid action. Allowed: ${ALLOWED_ACTIONS.join(', ')}`,
    });
  }

  if (name === 'destroy' && req.body?.confirm !== 'destroy') {
    return res.status(400).json({ error: 'Destroy requires confirmation text' });
  }

  try {
    return res.json(runMakeCommand(name));
  } catch (err) {
    return res.status(409).json({ error: err.message });
  }
});

app.get('/api/jobs', (req, res) => {
  res.json(jobs.map((job) => serializeJob(job)));
});

app.get('/api/jobs/current', (req, res) => {
  if (!currentJob) return res.json(null);
  return res.json(serializeJob(currentJob));
});

app.get('/api/jobs/:id', (req, res) => {
  const jobId = Number(req.params.id);
  const job = jobs.find((candidate) => candidate.id === jobId);

  if (!job) return res.status(404).json({ error: 'Job not found' });
  return res.json(serializeJob(job, true));
});

app.get('/api/jobs/:id/stream', (req, res) => {
  const jobId = Number(req.params.id);
  const job = jobs.find((candidate) => candidate.id === jobId);

  if (!job) return res.status(404).json({ error: 'Job not found' });

  res.writeHead(200, {
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache',
    Connection: 'keep-alive',
    'X-Accel-Buffering': 'no',
  });

  if (job.logs.length > 0) {
    writeSse(res, null, job.logs.join(''));
  }

  if (job.status !== 'running') {
    writeSse(res, 'status', { status: job.status, exitCode: job.exitCode });
    return res.end();
  }

  if (!sseClients.has(jobId)) {
    sseClients.set(jobId, new Set());
  }
  sseClients.get(jobId).add(res);

  req.on('close', () => {
    const clients = sseClients.get(jobId);
    if (!clients) return;

    clients.delete(res);
    if (clients.size === 0) {
      sseClients.delete(jobId);
    }
  });
});

app.post('/api/jobs/:id/abort', (req, res) => {
  const jobId = Number(req.params.id);
  const job = jobs.find((candidate) => candidate.id === jobId);

  if (!job) return res.status(404).json({ error: 'Job not found' });
  if (job.status !== 'running') {
    return res.status(400).json({ error: 'Job is not running' });
  }

  job.process.kill('SIGTERM');
  return res.json({ message: 'Abort signal sent' });
});

const server = app.listen(PORT, () => {
  console.log('╔════════════════════════════════════════════════╗');
  console.log('║  NT548 Control Plane - Backend                ║');
  console.log('╠════════════════════════════════════════════════╣');
  console.log(`║  Listening:  http://localhost:${String(PORT).padEnd(20)}║`);
  console.log(`║  Repo root:  ${REPO_ROOT.padEnd(34)}║`);
  console.log(`║  Health:     curl localhost:${PORT}/api/health    ║`);
  console.log('╚════════════════════════════════════════════════╝');
});

function shutdown(signal) {
  console.log(`\n[shutdown] ${signal} received`);
  if (currentJob && currentJob.process) {
    console.log(`[shutdown] killing running job ${currentJob.id}`);
    currentJob.process.kill('SIGTERM');
  }
  server.close(() => process.exit(0));
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
