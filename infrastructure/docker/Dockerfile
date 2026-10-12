# Multi-stage Dockerfile for ReMarket Backend (NestJS)
FROM node:20-alpine AS builder

WORKDIR /usr/src/app

COPY apps/backend/package*.json ./
RUN npm ci

COPY apps/backend/ .
RUN npm run build

FROM node:20-alpine AS production

ENV NODE_ENV=production
WORKDIR /usr/src/app

COPY apps/backend/package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

COPY --from=builder /usr/src/app/dist ./dist

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:5000/api/v1/health || exit 1

CMD ["node", "dist/main.js"]
