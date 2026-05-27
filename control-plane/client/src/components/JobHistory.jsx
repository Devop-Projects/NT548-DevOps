import { useEffect, useState } from 'react';
import { getJobs } from '../api';

const STATUS_CONFIG = {
  running: { dot: 'info', color: '#00f7f7' },
  success: { dot: 'success', color: '#10b981' },
  failed: { dot: 'danger', color: '#ef4444' },
  cancelled: { dot: 'warning', color: '#f59e0b' },
};

function formatTime(value) {
  if (!value) return '-';
  return new Date(value).toLocaleTimeString('vi-VN', { hour12: false });
}

function formatDuration(start, end) {
  if (!start) return '-';
  const startMs = new Date(start).getTime();
  const endMs = end ? new Date(end).getTime() : Date.now();
  const seconds = Math.max(0, Math.round((endMs - startMs) / 1000));
  if (seconds < 60) return `${seconds}s`;
  return `${Math.floor(seconds / 60)}m ${seconds % 60}s`;
}

export default function JobHistory({ currentJobId, onSelectJob }) {
  const [jobs, setJobs] = useState([]);

  useEffect(() => {
    let cancelled = false;

    async function refresh() {
      try {
        const data = await getJobs();
        if (!cancelled) setJobs(data);
      } catch (err) {
        console.error('Failed to fetch jobs:', err);
      }
    }

    refresh();
    const interval = setInterval(refresh, 5000);
    return () => {
      cancelled = true;
      clearInterval(interval);
    };
  }, [currentJobId]);

  if (jobs.length === 0) {
    return (
      <div className="dt-card-inner flex h-32 items-center justify-center text-sm" style={{ color: 'var(--text-muted)' }}>
        No jobs yet
      </div>
    );
  }

  return (
    <div className="space-y-1.5">
      {jobs.slice(0, 10).map((job) => {
        const config = STATUS_CONFIG[job.status] || { dot: 'muted', color: 'var(--text-muted)' };
        const isActive = job.id === currentJobId;

        return (
          <button
            key={job.id}
            type="button"
            onClick={() => onSelectJob(job)}
            className="w-full rounded px-3 py-2.5 text-left transition"
            style={{
              background: isActive ? 'rgba(0, 247, 247, 0.08)' : 'var(--bg-primary)',
              border: isActive ? '1px solid var(--accent)' : '1px solid var(--border)',
              boxShadow: isActive ? '0 0 12px var(--accent-shadow)' : 'none',
            }}
          >
            <div className="flex items-center gap-3">
              <span className={`dt-status-dot ${config.dot} ${job.status === 'running' ? 'dt-pulse' : ''}`} />
              <div className="min-w-0 flex-1">
                <p className="truncate font-mono text-sm font-semibold" style={{ color: 'var(--text-primary)' }}>
                  make {job.type}
                </p>
                <p className="mt-0.5 text-xs" style={{ color: 'var(--text-muted)' }}>
                  {formatTime(job.startedAt)} · {formatDuration(job.startedAt, job.finishedAt)}
                </p>
              </div>
              <span
                className="text-xs font-bold uppercase tracking-wider"
                style={{ color: config.color }}
              >
                {job.status}
              </span>
            </div>
          </button>
        );
      })}
    </div>
  );
}
