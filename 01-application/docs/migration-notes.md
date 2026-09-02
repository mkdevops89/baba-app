# Phase 01 Migration Notes

The application source was selectively migrated from the original Amazon Clone project into the new Baba App repository.

## Retained

- Next.js frontend application
- Spring Boot backend application
- Product, cart, order, Redis, RabbitMQ, and database application logic
- Existing product seed data and product images

## Removed from Phase 01

- Backend and frontend Dockerfiles (Phase 02)
- Maven `target/` compiled output
- Original infrastructure/runbook files
- Nexus distribution management configuration
- Sonar Maven plugin configuration

## Renamed

- `Amazon Clone` → `Baba App`
- Java package `com.amazonlike.backend` → `com.babaapp.backend`
- Maven group ID `com.amazonlike` → `com.babaapp`
- Maven artifact ID `backend` → `baba-app-backend`
- npm package `frontend` → `baba-app-frontend`

## Local-development improvement

The backend now uses an H2 in-memory database by default for Phase 01. This keeps the application independently runnable before Docker and AWS-managed data services are introduced. A production-like Spring profile remains available for external MySQL, Redis, and RabbitMQ configuration.
