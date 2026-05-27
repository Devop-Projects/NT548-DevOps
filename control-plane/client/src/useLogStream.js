import { useEffect, useState } from 'react';

const ANSI_PATTERN = /\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])/g;

function cleanLogText(value) {
  return value.replace(/\\n/g, '\n').replace(ANSI_PATTERN, '');
}

export function useLogStream(jobId) {
  const [logs, setLogs] = useState('');
  const [status, setStatus] = useState('idle');

  useEffect(() => {
    if (!jobId) {
      setLogs('');
      setStatus('idle');
      return undefined;
    }

    setLogs('');
    setStatus('running');

    const eventSource = new EventSource(`/api/jobs/${jobId}/stream`);

    eventSource.onmessage = (event) => {
      setLogs((current) => current + cleanLogText(event.data));
    };

    eventSource.addEventListener('status', (event) => {
      const data = JSON.parse(event.data);
      setStatus(data.status);
      eventSource.close();
    });

    eventSource.onerror = () => {
      if (eventSource.readyState === EventSource.CLOSED) {
        return;
      }
    };

    return () => {
      eventSource.close();
    };
  }, [jobId]);

  return { logs, status };
}
