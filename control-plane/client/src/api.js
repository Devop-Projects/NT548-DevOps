const BASE = '/api';

async function readJson(res) {
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(data.error || `Request failed with HTTP ${res.status}`);
  }
  return data;
}

export async function getHealth() {
  const res = await fetch(`${BASE}/health`);
  return readJson(res);
}

export async function getStatus() {
  const res = await fetch(`${BASE}/status`);
  return readJson(res);
}

export async function refreshStatus() {
  const res = await fetch(`${BASE}/status/refresh`, { method: 'POST' });
  return readJson(res);
}

export async function triggerAction(name, payload = {}) {
  const res = await fetch(`${BASE}/actions/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  return readJson(res);
}

export async function getCurrentJob() {
  const res = await fetch(`${BASE}/jobs/current`);
  return readJson(res);
}

export async function getJobs() {
  const res = await fetch(`${BASE}/jobs`);
  return readJson(res);
}

export async function getJob(jobId) {
  const res = await fetch(`${BASE}/jobs/${jobId}`);
  return readJson(res);
}

export async function abortJob(jobId) {
  const res = await fetch(`${BASE}/jobs/${jobId}/abort`, { method: 'POST' });
  return readJson(res);
}
