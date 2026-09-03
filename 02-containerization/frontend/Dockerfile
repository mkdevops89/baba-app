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

ARG NEXT_PUBLIC_API_URL=http://localhost:8080/api
ENV NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}

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

COPY --from=builder --chown=65532:65532 /app/public ./public
COPY --from=builder --chown=65532:65532 /app/.next/standalone ./
COPY --from=builder --chown=65532:65532 /app/.next/static ./.next/static

EXPOSE 3000

CMD ["server.js"]