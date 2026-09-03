# Phase 02 - Containerization

## Overview

Phase 02 containerizes the Baba App frontend and backend and establishes a secure local container runtime baseline.

The phase began with functional Docker images and evolved into a hardened container implementation using multi-stage builds, distroless runtime images, non-root execution, dependency remediation, and container vulnerability scanning.

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