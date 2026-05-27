# NT548 Control Plane

Internal Developer Platform UI for operating the NT548 DevOps thesis stack.

## Architecture

```text
React UI :5173  -- HTTP/SSE -->  Express API :3001  -- spawn -->  Makefile
                                           |
                                           +-- kubectl/aws CLI status reads
```

The Makefile remains the source of truth for deploy, hibernate, wake, destroy,
status, and verify. The web UI is a control layer over those existing targets.

## Run

Start the backend:

```bash
cd control-plane/server
npm install
npm run dev
```

Start the frontend:

```bash
cd control-plane/client
npm install
npm run dev
```

Open:

```text
http://localhost:5173
```

## Features

- Action buttons for `make deploy`, `make hibernate`, `make wake`, and `make destroy`.
- Read-only utility actions for `make status` and `make verify`.
- Realtime log streaming through Server-Sent Events.
- Recent job history stored in backend memory.
- Status cards for EKS nodes, ArgoCD apps, RDS, and load balancers.
- Typed confirmation before `destroy`.

## Demo Scope

This is a local IDP demo, not a production service.

- No authentication yet.
- Job state is in memory and resets when the backend restarts.
- Only one job runs at a time.
- Backend must run on a machine with AWS credentials and kubeconfig access.

Production hardening would add authentication, RBAC, persistent job storage,
audit logs, and a safer runtime outside the cluster it manages.
