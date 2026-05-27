# syntax=docker/dockerfile:1.7

FROM node:18.19.0-alpine3.19 AS deps

WORKDIR /app

COPY package*.json ./

RUN --mount=type=cache,target=/root/.npm \
    npm ci --omit=dev

FROM node:18.19.0-alpine3.19 AS runtime

ENV NODE_ENV=production \
    PORT=3000 \
    NPM_CONFIG_LOGLEVEL=warn

WORKDIR /app

COPY --from=deps --chown=node:node /app/node_modules ./node_modules

COPY --chown=node:node package*.json ./

COPY --chown=node:node src/ ./src/

USER node

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health/live || exit 1

CMD ["node", "src/app.js"]

