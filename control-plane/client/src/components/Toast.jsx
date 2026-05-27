import { useEffect, useState } from 'react';
import { AlertTriangle, CheckCircle2, Info, X } from 'lucide-react';

const listeners = new Set();
let idCounter = 0;

function emit(type, message) {
  const payload = { id: ++idCounter, type, message };
  listeners.forEach((listener) => listener(payload));
}

export const toast = {
  success: (message) => emit('success', message),
  error: (message) => emit('error', message),
  info: (message) => emit('info', message),
};

const CONFIG = {
  success: { color: '#10b981', Icon: CheckCircle2, label: 'Success' },
  error: { color: '#ef4444', Icon: AlertTriangle, label: 'Error' },
  info: { color: '#00f7f7', Icon: Info, label: 'Info' },
};

export function ToastContainer() {
  const [toasts, setToasts] = useState([]);

  useEffect(() => {
    function addToast(payload) {
      setToasts((current) => [...current, payload]);
      setTimeout(() => {
        setToasts((current) => current.filter((toastItem) => toastItem.id !== payload.id));
      }, 4000);
    }

    listeners.add(addToast);
    return () => listeners.delete(addToast);
  }, []);

  return (
    <div className="fixed right-4 top-20 z-50 w-[min(380px,calc(100vw-32px))] space-y-2">
      {toasts.map((toastItem) => {
        const config = CONFIG[toastItem.type] || CONFIG.info;
        const Icon = config.Icon;

        return (
          <div
            key={toastItem.id}
            role="status"
            className="flex items-start gap-3 rounded-lg px-4 py-3 shadow-xl backdrop-blur"
            style={{
              background: 'rgba(30, 41, 59, 0.96)',
              border: `1px solid ${config.color}`,
              boxShadow: `0 0 20px ${config.color}40`,
            }}
          >
            <Icon size={20} className="mt-0.5 flex-none" style={{ color: config.color }} />
            <div className="min-w-0 flex-1">
              <p className="text-xs font-bold uppercase tracking-[0.12em]" style={{ color: config.color }}>
                {config.label}
              </p>
              <p className="mt-1 text-sm" style={{ color: 'var(--text-primary)' }}>
                {toastItem.message}
              </p>
            </div>
            <button
              type="button"
              onClick={() => {
                setToasts((current) => current.filter((item) => item.id !== toastItem.id));
              }}
              className="rounded p-0.5 transition"
              style={{ color: 'var(--text-muted)' }}
              title="Dismiss"
            >
              <X size={14} />
            </button>
          </div>
        );
      })}
    </div>
  );
}
