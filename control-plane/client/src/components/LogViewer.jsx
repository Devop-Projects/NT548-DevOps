import { useEffect, useRef, useState } from 'react';
import { Square, Terminal } from 'lucide-react';
import { abortJob } from '../api';
import { toast } from './Toast';

const STATUS_CONFIG = {
  idle: { color: '#64748b', label: 'IDLE', glow: 'transparent' },
  running: { color: '#00f7f7', label: 'RUNNING', glow: 'rgba(0, 247, 247, 0.5)' },
  success: { color: '#10b981', label: 'SUCCESS', glow: 'rgba(16, 185, 129, 0.5)' },
  failed: { color: '#ef4444', label: 'FAILED', glow: 'rgba(239, 68, 68, 0.5)' },
  cancelled: { color: '#f59e0b', label: 'CANCELLED', glow: 'rgba(245, 158, 11, 0.5)' },
};

export default function LogViewer({ logs, status, jobId, jobType }) {
  const containerRef = useRef(null);
  const [autoScroll, setAutoScroll] = useState(true);
  const config = STATUS_CONFIG[status] || STATUS_CONFIG.idle;

  useEffect(() => {
    if (!autoScroll || !containerRef.current) return;
    const element = containerRef.current;
    element.scrollTop = element.scrollHeight;
  }, [logs, autoScroll]);

  function handleScroll() {
    if (!containerRef.current) return;
    const element = containerRef.current;
    const atBottom = element.scrollHeight - element.scrollTop - element.clientHeight < 50;
    setAutoScroll(atBottom);
  }

  async function handleAbort() {
    if (!jobId) return;
    const ok = window.confirm('Abort current job? This can leave Terraform state locked.');
    if (!ok) return;
    try {
      await abortJob(jobId);
      toast.info(`Abort signal sent for job ${jobId}`);
    } catch (err) {
      toast.error(`Failed to abort job ${jobId}: ${err.message}`);
    }
  }

  return (
    <div
      className="flex h-[520px] min-h-0 flex-col overflow-hidden rounded-lg"
      style={{
        background: '#050a13',
        border: '1px solid var(--border)',
        boxShadow: status === 'running' ? '0 0 24px var(--accent-shadow)' : 'none',
        transition: 'box-shadow 180ms ease',
      }}
    >
      <div
        className="flex h-12 flex-none items-center justify-between gap-3 px-4"
        style={{ background: 'var(--bg-secondary)', borderBottom: '1px solid var(--border)' }}
      >
        <div className="flex min-w-0 items-center gap-3">
          <Terminal size={18} className="flex-none" style={{ color: 'var(--accent)' }} />
          <span className="truncate font-mono text-sm" style={{ color: 'var(--text-secondary)' }}>
            $ {jobType ? `make ${jobType}` : 'no active job'}
          </span>
        </div>

        <div className="flex items-center gap-2">
          <span
            className="inline-flex h-7 items-center rounded px-3 text-xs font-bold tracking-[0.12em]"
            style={{
              border: `1px solid ${config.color}`,
              color: config.color,
              textShadow: `0 0 8px ${config.glow}`,
              boxShadow: status === 'running' ? `0 0 12px ${config.glow}` : 'none',
            }}
          >
            {config.label}
          </span>

          {status === 'running' && jobId && (
            <button
              type="button"
              onClick={handleAbort}
              className="inline-flex h-7 items-center gap-1.5 rounded border px-2 text-xs font-semibold transition"
              style={{ borderColor: 'var(--danger)', color: 'var(--danger)' }}
            >
              <Square size={12} />
              Abort
            </button>
          )}
        </div>
      </div>

      <div
        ref={containerRef}
        onScroll={handleScroll}
        className="log-terminal min-h-0 flex-1 overflow-y-auto whitespace-pre-wrap break-words p-4"
      >
        {logs || (
          <span style={{ color: 'var(--text-muted)', fontStyle: 'italic' }}>
            {jobId ? '> connecting to log stream...' : '> idle'}
          </span>
        )}
      </div>

      <div
        className="flex h-9 flex-none items-center justify-between px-4 font-mono text-xs"
        style={{
          background: 'var(--bg-secondary)',
          borderTop: '1px solid var(--border)',
          color: 'var(--text-muted)',
        }}
      >
        <span>{logs ? `${logs.split('\n').length} lines` : '0 lines'}</span>
        <label className="flex items-center gap-2">
          <input
            type="checkbox"
            checked={autoScroll}
            onChange={(event) => setAutoScroll(event.target.checked)}
            style={{ accentColor: 'var(--accent)' }}
          />
          auto-follow
        </label>
      </div>
    </div>
  );
}
