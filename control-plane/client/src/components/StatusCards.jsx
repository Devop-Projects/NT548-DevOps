import { useEffect, useMemo, useState } from 'react';
import {
  Boxes,
  Database,
  GitBranch,
  Loader2,
  RefreshCw,
  Server,
  TriangleAlert,
} from 'lucide-react';
import { getStatus, refreshStatus } from '../api';

const STATUS_TYPE = {
  healthy: 'success',
  available: 'success',
  Synced: 'success',
  unreachable: 'danger',
  down: 'danger',
  failed: 'danger',
  stopped: 'warning',
  Unknown: 'muted',
  unknown: 'muted',
  'not-found': 'muted',
};

const BAR_COLOR = {
  success: 'var(--success)',
  warning: 'var(--warning)',
  danger: 'var(--danger)',
  info: 'var(--accent)',
  muted: 'var(--text-muted)',
};

function StatusCard({ Icon, label, value, sublabel, statusType, loading }) {
  const color = BAR_COLOR[statusType] || BAR_COLOR.muted;

  return (
    <div className="dt-card relative min-h-[148px] overflow-hidden p-4">
      <div
        className="absolute left-0 right-0 top-0 h-0.5"
        style={{
          background: color,
          boxShadow: statusType === 'muted' ? 'none' : `0 0 8px ${color}`,
        }}
      />

      <div className="mb-4 flex items-start justify-between gap-3">
        <div
          className="flex h-10 w-10 items-center justify-center rounded-md"
          style={{
            background: 'var(--bg-primary)',
            border: '1px solid var(--border)',
            color: 'var(--accent)',
          }}
        >
          <Icon size={20} />
        </div>
        <span className={`dt-status-dot ${statusType} ${loading ? 'dt-pulse' : ''}`} />
      </div>

      <p className="text-xs font-bold uppercase tracking-[0.11em]" style={{ color: 'var(--text-secondary)' }}>
        {label}
      </p>
      <p
        className="mt-1 truncate font-mono text-2xl font-bold"
        style={{ color: 'var(--accent)', textShadow: '0 0 8px var(--accent-glow)' }}
      >
        {value}
      </p>
      {sublabel && (
        <p className="mt-1 truncate text-xs" style={{ color: 'var(--text-muted)' }}>
          {sublabel}
        </p>
      )}
    </div>
  );
}

export default function StatusCards() {
  const [status, setStatus] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  async function loadStatus({ force = false } = {}) {
    setLoading(true);
    try {
      if (force) await refreshStatus();
      const data = await getStatus();
      setStatus(data);
      setError(null);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadStatus();
    const interval = setInterval(() => loadStatus(), 30000);
    return () => clearInterval(interval);
  }, []);

  const derived = useMemo(() => {
    if (!status) return null;
    const argoTotal = status.argocdApps?.length || 0;
    const argoSynced = status.argocdApps?.filter((app) => app.sync === 'Synced').length || 0;
    const argoHealthy =
      argoTotal > 0 && status.argocdApps.every((app) => app.health === 'Healthy');
    const nodesReady = status.nodes?.ready || 0;
    const nodesTotal = status.nodes?.total || 0;

    return {
      argoTotal,
      argoSynced,
      argoHealthy,
      nodesReady,
      nodesTotal,
    };
  }, [status]);

  if (error && !status) {
    return (
      <div
        className="flex items-start gap-3 rounded-lg p-4 text-sm"
        style={{
          background: 'rgba(239, 68, 68, 0.1)',
          border: '1px solid var(--danger)',
          color: '#fca5a5',
        }}
      >
        <TriangleAlert size={18} className="mt-0.5 flex-none" />
        <span>{error}</span>
      </div>
    );
  }

  if (!status || !derived) {
    return (
      <section>
        <h2 className="heading-sub mb-3">Cluster Status</h2>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
          {[Server, Boxes, GitBranch, Database].map((Icon, index) => (
            <div key={index} className="dt-card-static min-h-[148px] p-4">
              <div className="mb-4 flex items-center justify-between">
                <div className="flex h-10 w-10 items-center justify-center rounded-md dt-card-inner">
                  <Icon size={18} style={{ color: 'var(--text-muted)' }} />
                </div>
                <Loader2 size={16} className="animate-spin" style={{ color: 'var(--accent)' }} />
              </div>
              <div className="h-3 w-24 rounded" style={{ background: 'var(--border)' }} />
              <div className="mt-3 h-7 w-28 rounded" style={{ background: 'var(--border)' }} />
            </div>
          ))}
        </div>
      </section>
    );
  }

  const nodesHealthy = derived.nodesTotal > 0 && derived.nodesReady === derived.nodesTotal;
  const argoValue = derived.argoTotal > 0 ? `${derived.argoSynced}/${derived.argoTotal}` : '-';
  const rdsStatus = status.rds?.status || 'unknown';

  return (
    <section>
      <div className="mb-3 flex items-center justify-between gap-3">
        <h2 className="heading-sub">Cluster Status</h2>
        <button
          type="button"
          onClick={() => loadStatus({ force: true })}
          className="inline-flex h-8 items-center gap-2 rounded-md border px-3 text-xs transition"
          style={{
            borderColor: 'var(--border)',
            color: 'var(--text-secondary)',
            background: 'rgba(15, 23, 42, 0.65)',
          }}
          title="Refresh status"
        >
          <RefreshCw size={14} className={loading ? 'animate-spin' : ''} />
          {status.cached ? 'cached' : 'live'}
        </button>
      </div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatusCard
          Icon={Server}
          label="EKS Cluster"
          value={status.cluster?.status || 'unknown'}
          sublabel={status.cluster?.name || 'devops-dev'}
          statusType={STATUS_TYPE[status.cluster?.status] || 'muted'}
          loading={loading}
        />
        <StatusCard
          Icon={Boxes}
          label="Worker Nodes"
          value={`${derived.nodesReady}/${derived.nodesTotal}`}
          sublabel={nodesHealthy ? 'all nodes ready' : 'check node group'}
          statusType={nodesHealthy ? 'success' : 'warning'}
          loading={loading}
        />
        <StatusCard
          Icon={GitBranch}
          label="ArgoCD Apps"
          value={argoValue}
          sublabel={derived.argoHealthy ? 'healthy and synced' : 'sync check needed'}
          statusType={
            derived.argoTotal === 0
              ? 'muted'
              : derived.argoSynced === derived.argoTotal && derived.argoHealthy
                ? 'success'
                : 'warning'
          }
          loading={loading}
        />
        <StatusCard
          Icon={Database}
          label="RDS Database"
          value={rdsStatus}
          sublabel={`${status.alb?.count || 0} load balancer(s)`}
          statusType={STATUS_TYPE[rdsStatus] || 'muted'}
          loading={loading}
        />
      </div>
    </section>
  );
}
