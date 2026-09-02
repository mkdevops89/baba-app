# Phase 01 — Application Foundation

## Objective

Establish and validate the Baba App application locally before introducing containerization, AWS infrastructure, Kubernetes, CI/CD, or security automation.

## Components

- `frontend/` — Next.js + React user interface
- `backend/` — Spring Boot REST API
- `docs/` — architecture and migration notes
- `scripts/` — local startup helpers

## Local architecture

```text
Browser (http://localhost:3000)
        |
        v
Baba App Frontend (Next.js)
        |
        | NEXT_PUBLIC_API_URL
        v
Baba App Backend (Spring Boot :8080)
        |
        v
H2 in-memory database (Phase 01 default)
```

Redis and RabbitMQ remain in the codebase for cart/order capabilities, but they are not required to render the product catalog in the Phase 01 local-development path.

## Prerequisites

- Node.js and npm
- Java 17+
- Maven 3.9+

## Run the backend

```bash
cd 01-application/backend
mvn spring-boot:run
```

API: `http://localhost:8080/api/products`

## Run the frontend

In another terminal:

```bash
cd 01-application/frontend
cp .env.example .env.local
npm install
npm run dev
```

Open `http://localhost:3000`.

## Phase completion criteria

- [ ] Backend builds successfully
- [ ] Frontend builds successfully
- [ ] Backend runs locally on port 8080
- [ ] Frontend runs locally on port 3000
- [ ] Frontend loads products from the backend API
- [x] Amazon-specific application branding removed
- [x] Backend Java package renamed to `com.babaapp.backend`
- [x] Environment configuration externalized
- [x] Docker and compiled build artifacts excluded from Phase 01
- [x] Phase documentation created

## Security note

Phase 01 focuses on application functionality. Authentication, secrets management, application security testing, and production-grade authorization are introduced in later phases. Local CORS is restricted to `http://localhost:3000` by default.
