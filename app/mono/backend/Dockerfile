# syntax=docker/dockerfile:1.7

# ============================================================================
# Stage 1: Dependencies — cài node_modules (production only)
# ============================================================================
FROM node:18.19.0-alpine3.19 AS deps

WORKDIR /app

# Copy lock file + package.json
COPY package*.json ./

# Cài production dependencies với cache mount (BuildKit feature)
# Cache mount: /root/.npm được persist giữa các build → npm install nhanh hơn
RUN --mount=type=cache,target=/root/.npm \
    npm ci --omit=dev


# ============================================================================
# Stage 2: Runtime — image cuối, chỉ chứa những gì cần để chạy
# ============================================================================
FROM node:18.19.0-alpine3.19 AS runtime


# Production environment
ENV NODE_ENV=production \
    PORT=3000 \
    NPM_CONFIG_LOGLEVEL=warn

WORKDIR /app

# Copy node_modules từ stage deps (đã được install ở stage trước)
# --chown đảm bảo file thuộc user "node"
COPY --from=deps --chown=node:node /app/node_modules ./node_modules

# Copy package.json (cần cho Node để biết "type": "commonjs"/"module")
COPY --chown=node:node package*.json ./

# Copy source code
COPY --chown=node:node src/ ./src/

# Switch sang non-root user (UID 1000)
USER node

# Document port
EXPOSE 3000

# Healthcheck
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health/live || exit 1

# Exec form — signal forwarding
CMD ["node", "src/app.js"]

