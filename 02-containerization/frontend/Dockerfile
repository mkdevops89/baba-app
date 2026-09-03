# =========================
# Dependencies
# =========================
FROM node:24-alpine AS deps

WORKDIR /app

COPY 01-application/frontend/package.json .
COPY 01-application/frontend/package-lock.json .

RUN npm ci


# =========================
# Build
# =========================
FROM node:24-alpine AS builder

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY 01-application/frontend/ .

RUN npm run build


# =========================
# Production runtime
# =========================
FROM gcr.io/distroless/nodejs24-debian13:nonroot AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000
ENV HOSTNAME=0.0.0.0

COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

EXPOSE 3000

CMD ["server.js"]