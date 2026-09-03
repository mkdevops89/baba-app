# Baba App - Containerization

## Overview

This directory contains the containerization setup for the Baba App frontend and backend.

The goal of this stage was to create secure, optimized, and repeatable container images that can run locally with Docker Compose and later be promoted to AWS container and Kubernetes environments.

The final implementation uses:

- Multi-stage Docker builds
- Distroless runtime images
- Non-root container execution
- Next.js standalone output
- Spring Boot 3.5.16
- Docker Compose
- Docker Scout vulnerability scanning
- Dependency and attack-surface reduction

---

## Architecture

```text
Browser
   |
   v
Next.js Frontend
Port 3000
   |
   v
Spring Boot Backend
Port 8080
   |
   v
JPA / H2
```

The local container environment currently runs only the services required by the application:

```text
frontend
backend
```

Redis and RabbitMQ are not included in the current runtime because they are not required by the active application workflow.

They may be reintroduced later for defined use cases such as caching, session management, and asynchronous order processing.

---

## Directory Structure

```text
02-containerization/
├── backend/
│   └── Dockerfile
├── frontend/
│   └── Dockerfile
├── docker-compose.yml
├── README.md
└── docs/
    ├── container-security-remediation.md
    └── validation-checklist.md
```

---

## Frontend Container

The frontend is built with:

- Next.js 16
- React 19
- Node.js 24
- Next.js standalone output
- Multi-stage Docker build
- Distroless Node.js runtime
- Non-root execution

Final runtime image:

```text
gcr.io/distroless/nodejs24-debian13:nonroot
```

The frontend listens on:

```text
3000
```

---

## Backend Container

The backend is built with:

- Java 17
- Spring Boot 3.5.16
- Maven
- Multi-stage Docker build
- Distroless Java runtime
- Non-root execution
- JPA
- H2 local database

Final runtime image:

```text
gcr.io/distroless/java17-debian12:nonroot
```

The backend listens on:

```text
8080
```

---

## Container Security

Both container images were scanned and hardened before being considered complete.

Security improvements included:

- Migration to distroless runtime images
- Non-root execution
- Removal of unnecessary runtime tooling
- Removal of unused Redis dependencies
- Removal of unused RabbitMQ dependencies
- Spring Boot framework upgrade
- Jackson dependency remediation
- Log4j dependency remediation
- Image-size reduction
- Docker Scout rescanning

Final Docker Scout results:

### Frontend

```text
Critical: 0
High:     0
Medium:   0
Low:      0
```

### Backend

```text
Critical: 0
High:     0
Medium:   0
Low:      0
```

Both final images reported:

```text
No vulnerable packages detected
```

Detailed remediation information is available in:

```text
docs/container-security-remediation.md
```

---

## Image Optimization

The frontend image was reduced from approximately:

```text
926 MB
```

to:

```text
68 MB
```

The backend image was reduced from approximately:

```text
605 MB
```

to:

```text
136 MB
```

These reductions were achieved through:

- Multi-stage builds
- Standalone application output
- Distroless runtimes
- Removal of unnecessary packages
- Removal of unused application dependencies

---

## Build the Containers

From the containerization directory:

```bash
cd ~/baba-app/02-containerization
```

Build both images:

```bash
docker compose build --pull
```

For a completely fresh build:

```bash
docker compose build --pull --no-cache
```

---

## Start the Application

Start the containers:

```bash
docker compose up -d
```

Check container status:

```bash
docker compose ps
```

Expected services:

```text
backend
frontend
```

---

## Access the Application

Frontend:

```text
http://localhost:3000/home
```

Backend API:

```text
http://localhost:8080/api/products
```

Test the backend API:

```bash
curl -i http://localhost:8080/api/products
```

Expected result:

```text
HTTP/1.1 200
```

---

## Stop the Application

Stop and remove the containers:

```bash
docker compose down
```

If orphaned containers remain:

```bash
docker compose down --remove-orphans
```

---

## Security Scanning

Scan the frontend image:

```bash
docker scout cves baba-app-frontend:dev
```

Scan the backend image:

```bash
docker scout cves baba-app-backend:dev
```

Expected security baseline:

```text
0 Critical
0 High
0 Medium
0 Low
```

---

## Application Validation

The containerized application was validated for:

- Frontend startup
- Backend startup
- Product catalog loading
- 12-product inventory
- Product search
- Product detail pages
- Add-to-cart functionality
- Cart count updates
- Cart page functionality
- Backend API response
- JPA persistence
- H2 database functionality
- Docker Compose networking
- Container vulnerability scanning

The detailed validation checklist is available in:

```text
docs/validation-checklist.md
```

---

## Security Design Decisions

### Why Distroless?

Distroless images contain only the runtime components required to execute the application.

This reduces:

- Package count
- Shell access
- Package-manager availability
- Unnecessary operating-system utilities
- Container attack surface

### Why Non-Root?

The frontend and backend containers execute as non-root users to reduce the potential impact of a container compromise.

### Why Remove Redis and RabbitMQ?

Redis and RabbitMQ were inherited from earlier application versions but were not required by the active application workflow.

Unused dependencies increase:

- Attack surface
- Vulnerability exposure
- Maintenance overhead
- Operational complexity

They were therefore removed until a defined use case requires them.

---

## Future Improvements

Later stages of the Baba App project will extend the container security baseline with:

- Amazon ECR
- Amazon Inspector
- ECR enhanced scanning
- Trivy
- CI/CD vulnerability gates
- SBOM generation
- Container image signing
- Build provenance
- Amazon EKS deployment
- Kubernetes readiness and liveness probes
- Runtime security controls

---

## Current Status

```text
Frontend
--------
Distroless
Non-root
68 MB
0 detected vulnerabilities

Backend
-------
Distroless
Non-root
136 MB
0 detected vulnerabilities
```

The containerized application is ready to progress into Infrastructure as Code and AWS deployment.