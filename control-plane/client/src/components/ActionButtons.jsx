import { useState } from 'react';
import {
  Activity,
  AlertTriangle,
  CloudSun,
  PauseCircle,
  RefreshCw,
  Rocket,
  ShieldAlert,
  Trash2,
} from 'lucide-react';
import { triggerAction } from '../api';
import { toast } from './Toast';

const ACTIONS = [
  {
    name: 'deploy',
    label: 'Deploy',
    Icon: Rocket,
    color: '#10b981',
    glow: 'rgba(16, 185, 129, 0.42)',
    description: 'Full stack rollout',
  },
  {
    name: 'hibernate',
    label: 'Hibernate',
    Icon: PauseCircle,
    color: '#0ea5e9',
    glow: 'rgba(14, 165, 233, 0.42)',
    description: 'Scale down compute',
  },
  {
    name: 'wake',
    label: 'Wake',
    Icon: CloudSun,
    color: '#f59e0b',
    glow: 'rgba(245, 158, 11, 0.42)',
    description: 'Resume cluster',
  },
  {
    name: 'destroy',
    label: 'Destroy',
    Icon: Trash2,
    color: '#ef4444',
    glow: 'rgba(239, 68, 68, 0.42)',
    description: 'Delete resources',
    confirm: true,
  },
  {
    name: 'status',
    label: 'Status',
    Icon: Activity,
    color: '#a78bfa',
    glow: 'rgba(167, 139, 250, 0.42)',
    description: 'Read-only check',
  },
  {
    name: 'verify',
    label: 'Verify',
    Icon: RefreshCw,
    color: '#00f7f7',
    glow: 'rgba(0, 247, 247, 0.42)',
    description: 'End-to-end check',
  },
];

export default function ActionButtons({ currentJobId, onJobStart }) {
  const [pendingAction, setPendingAction] = useState(null);
  const [confirmText, setConfirmText] = useState('');
  const [error, setError] = useState(null);

  const isBusy = currentJobId !== null;

  async function executeAction(actionName, payload = {}) {
    setError(null);
    try {
      const { jobId } = await triggerAction(actionName, payload);
      onJobStart(jobId, actionName);
      toast.success(`Job started: make ${actionName}`);
    } catch (err) {
      setError(err.message);
      toast.error(`Failed: ${err.message}`);
    }
  }

  function handleClick(action) {
    if (isBusy) return;
    if (action.confirm) {
      setPendingAction(action);
      setConfirmText('');
      setError(null);
      return;
    }
    executeAction(action.name);
  }

  function handleConfirm() {
    if (!pendingAction) return;
    if (confirmText !== pendingAction.name) {
      setError(`Type "${pendingAction.name}" exactly to confirm.`);
      return;
    }
    executeAction(pendingAction.name, { confirm: confirmText });
    setPendingAction(null);
    setConfirmText('');
  }

  return (
    <div>
      <div className="mb-4 flex items-center justify-between gap-3">
        <h2 className="heading-sub">Actions</h2>
        {isBusy && (
          <span className="font-mono text-xs font-bold" style={{ color: 'var(--accent)' }}>
            LOCKED WHILE JOB RUNS
          </span>
        )}
      </div>

      <div className="grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-6">
        {ACTIONS.map((action) => {
          const Icon = action.Icon;
          return (
            <button
              key={action.name}
              type="button"
              onClick={() => handleClick(action)}
              disabled={isBusy}
              className="action-tile flex min-h-[128px] flex-col items-center justify-center gap-2 rounded-lg p-4 text-center"
              style={{ '--action-color': action.color, '--action-glow': action.glow }}
            >
              <Icon size={28} strokeWidth={1.8} />
              <span className="text-base font-bold">{action.label}</span>
              <span className="text-xs leading-tight opacity-75">{action.description}</span>
            </button>
          );
        })}
      </div>

      {error && (
        <div
          className="mt-4 flex items-start gap-2 rounded p-3 text-sm"
          style={{
            background: 'rgba(239, 68, 68, 0.1)',
            border: '1px solid var(--danger)',
            color: '#fca5a5',
          }}
        >
          <AlertTriangle size={16} className="mt-0.5 flex-none" />
          <span>{error}</span>
        </div>
      )}

      {pendingAction && (
        <div
          className="mt-4 rounded-lg p-4"
          style={{
            background: 'rgba(90, 29, 29, 0.88)',
            border: '1px solid var(--danger)',
          }}
        >
          <div className="flex items-start gap-3">
            <ShieldAlert size={22} className="mt-0.5 flex-none" style={{ color: '#fca5a5' }} />
            <div className="min-w-0 flex-1">
              <p className="font-bold uppercase tracking-wide" style={{ color: '#fca5a5' }}>
                Confirm {pendingAction.label}
              </p>
              <div className="mt-3 flex flex-col gap-2 sm:flex-row">
                <input
                  type="text"
                  value={confirmText}
                  onChange={(event) => setConfirmText(event.target.value)}
                  placeholder="destroy"
                  className="h-10 min-w-0 flex-1 rounded px-3 font-mono text-sm outline-none"
                  style={{
                    background: 'var(--bg-primary)',
                    border: '1px solid var(--danger)',
                    color: '#fca5a5',
                  }}
                  autoFocus
                />
                <button
                  type="button"
                  onClick={handleConfirm}
                  className="inline-flex h-10 items-center justify-center gap-2 rounded px-4 text-sm font-bold transition"
                  style={{ background: 'var(--danger)', color: 'white' }}
                >
                  <Trash2 size={16} />
                  Confirm
                </button>
                <button
                  type="button"
                  onClick={() => {
                    setPendingAction(null);
                    setError(null);
                  }}
                  className="h-10 rounded px-4 text-sm transition"
                  style={{ background: 'var(--bg-tertiary)', color: 'var(--text-primary)' }}
                >
                  Cancel
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
