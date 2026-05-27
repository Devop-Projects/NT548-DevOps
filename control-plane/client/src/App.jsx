import { useEffect, useMemo, useState } from 'react';
import { Clock3, ServerCog } from 'lucide-react';
import ActionButtons from './components/ActionButtons';
import JobHistory from './components/JobHistory';
import LogViewer from './components/LogViewer';
import StatusCards from './components/StatusCards';
import { ToastContainer } from './components/Toast';
import { getCurrentJob, getHealth } from './api';
import { useLogStream } from './useLogStream';

export default function App() {
  const [activeJobId, setActiveJobId] = useState(null);
  const [activeJobType, setActiveJobType] = useState(null);
  const [runningJobId, setRunningJobId] = useState(null);
  const [backendState, setBackendState] = useState('checking');
  const [currentTime, setCurrentTime] = useState(() =>
    new Date().toLocaleTimeString('vi-VN', { hour12: false }),
  );
  const { logs, status } = useLogStream(activeJobId);

  const headerState = useMemo(() => {
    if (runningJobId) return { label: 'JOB RUNNING', dotType: 'info' };
    if (backendState === 'online') return { label: 'IDLE', dotType: 'success' };
    return { label: 'BACKEND OFFLINE', dotType: 'danger' };
  }, [backendState, runningJobId]);

  useEffect(() => {
    const interval = setInterval(() => {
      setCurrentTime(new Date().toLocaleTimeString('vi-VN', { hour12: false }));
    }, 1000);
    return () => clearInterval(interval);
  }, []);

  useEffect(() => {
    let cancelled = false;

    async function refreshBackend() {
      try {
        await getHealth();
        if (!cancelled) setBackendState('online');
      } catch (_) {
        if (!cancelled) setBackendState('offline');
      }
    }

    refreshBackend();
    const interval = setInterval(refreshBackend, 5000);
    return () => {
      cancelled = true;
      clearInterval(interval);
    };
  }, []);

  useEffect(() => {
    let cancelled = false;

    async function refreshCurrentJob() {
      try {
        const job = await getCurrentJob();
        if (cancelled) return;

        setRunningJobId(job ? job.id : null);
        if (job && !activeJobId) {
          setActiveJobId(job.id);
          setActiveJobType(job.type);
        }
      } catch (err) {
        console.error(err);
      }
    }

    refreshCurrentJob();
    const interval = setInterval(refreshCurrentJob, 3000);
    return () => {
      cancelled = true;
      clearInterval(interval);
    };
  }, [activeJobId]);

  function handleJobStart(jobId, jobType) {
    setActiveJobId(jobId);
    setActiveJobType(jobType);
    setRunningJobId(jobId);
  }

  function handleSelectJob(job) {
    setActiveJobId(job.id);
    setActiveJobType(job.type);
  }

  return (
    <div className="min-h-screen">
      <ToastContainer />

      <header className="border-b px-4 sm:px-6" style={{ borderColor: 'var(--border)' }}>
        <div className="mx-auto flex h-16 max-w-7xl items-center justify-between gap-4">
          <div className="flex min-w-0 items-center gap-3">
            <div
              className="flex h-10 w-10 flex-none items-center justify-center rounded-md"
              style={{
                border: '1px solid var(--accent)',
                boxShadow: '0 0 16px var(--accent-shadow)',
                color: 'var(--accent)',
              }}
            >
              <ServerCog size={22} />
            </div>
            <div className="min-w-0">
              <h1 className="heading-glow truncate text-lg sm:text-xl">NT548 Control Plane</h1>
              <p className="hidden text-sm md:block" style={{ color: 'var(--text-secondary)' }}>
                Internal Developer Platform · DevOps Self-Service
              </p>
            </div>
          </div>

          <div className="flex flex-none items-center gap-2 sm:gap-3">
            <span
              className="inline-flex h-9 items-center gap-2 rounded-md border px-3 text-xs font-bold tracking-wide"
              style={{
                borderColor:
                  headerState.dotType === 'success'
                    ? 'var(--success)'
                    : headerState.dotType === 'danger'
                      ? 'var(--danger)'
                      : 'var(--accent)',
                color:
                  headerState.dotType === 'success'
                    ? 'var(--success)'
                    : headerState.dotType === 'danger'
                      ? 'var(--danger)'
                      : 'var(--accent)',
                background: 'rgba(15, 23, 42, 0.75)',
              }}
            >
              <span className={`dt-status-dot ${headerState.dotType} ${runningJobId ? 'dt-pulse' : ''}`} />
              <span className="hidden sm:inline">{headerState.label}</span>
            </span>
            <span
              className="hidden h-9 items-center gap-2 rounded-md px-3 font-mono text-sm font-bold sm:inline-flex"
              style={{ background: 'var(--accent)', color: '#001018' }}
            >
              <Clock3 size={15} />
              {currentTime}
            </span>
          </div>
        </div>
      </header>

      <main className="mx-auto max-w-7xl space-y-6 px-4 py-6 sm:px-6">
        <StatusCards />

        <section className="dt-card-static p-4 sm:p-5">
          <ActionButtons currentJobId={runningJobId} onJobStart={handleJobStart} />
        </section>

        <div className="grid grid-cols-1 gap-6 lg:grid-cols-[minmax(0,1fr)_360px]">
          <section className="min-w-0">
            <h2 className="heading-sub mb-3">Job Output</h2>
            <LogViewer
              logs={logs}
              status={status}
              jobId={activeJobId}
              jobType={activeJobType}
            />
          </section>

          <aside className="min-w-0">
            <h2 className="heading-sub mb-3">Recent Jobs</h2>
            <div className="dt-card-static p-3">
              <JobHistory currentJobId={activeJobId} onSelectJob={handleSelectJob} />
            </div>
          </aside>
        </div>
      </main>
    </div>
  );
}
