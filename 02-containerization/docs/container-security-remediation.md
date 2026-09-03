# Container Security Remediation Report

## 1. Purpose

This document records the container security assessment and remediation activities completed during Phase 02 of the Baba App project.

The objective was to identify, analyze, and remediate vulnerabilities in the frontend and backend container images before progressing to AWS infrastructure, Amazon ECR, Kubernetes, and Amazon EKS.

The remediation effort focused on:

- Container image hardening
- Dependency vulnerability remediation
- Removal of unused components
- Runtime minimization
- Non-root container execution
- Framework modernization
- Attack-surface reduction
- Vulnerability rescanning
- Functional validation after security changes

---

## 2. Scope

The security assessment covered the following components.

### Frontend

- Next.js application
- Node.js runtime
- npm dependencies
- Frontend Docker image

### Backend

- Spring Boot application
- Java runtime
- Maven dependencies
- Backend Docker image

### Container Runtime

- Dockerfiles
- Docker Compose
- Runtime users
- Base images
- Package footprint
- Application services

---

## 3. Security Tools Used

### Docker Scout

Docker Scout was used to scan the container images for known vulnerabilities.

```bash
docker scout cves baba-app-frontend:dev
docker scout cves baba-app-backend:dev
```

### npm audit

npm audit was used to validate frontend application dependencies.

```bash
npm audit
```

### Maven Dependency Tree

Maven dependency analysis was used to determine which Spring Boot starters and transitive dependencies were introducing vulnerable packages.

Examples:

```bash
mvn dependency:tree -Dincludes=com.rabbitmq:amqp-client
mvn dependency:tree -Dincludes=io.netty:netty-codec
mvn dependency:tree -Dincludes=com.fasterxml.jackson.core:jackson-databind
mvn dependency:tree -Dincludes=org.apache.logging.log4j:log4j-api
```

---

## 4. Frontend Security Assessment

### 4.1 Initial Frontend State

The initial frontend container used:

```text
node:24-alpine
```

The application was functional, but Docker Scout identified vulnerabilities in operating-system and Node.js-related packages.

Initial findings:

```text
Critical: 2
High:     11
Medium:    6
Low:       0

Total:    19
```

The initial frontend image size was approximately:

```text
926 MB
```

### 4.2 Initial Frontend Findings

Docker Scout identified vulnerable packages including:

```text
openssl
brace-expansion
ip-address
tar
undici
```

OpenSSL accounted for some of the most severe findings.

---

## 5. Frontend Remediation Actions

### 5.1 Update Base Image Packages

The Alpine operating-system packages were upgraded.

```dockerfile
RUN apk upgrade --no-cache
```

This removed several operating-system vulnerabilities, including Critical OpenSSL findings.

The frontend vulnerability count decreased from:

```text
19 vulnerabilities
```

to:

```text
9 vulnerabilities
```

### 5.2 Enable Next.js Standalone Output

Next.js standalone mode was enabled.

```ts
output: "standalone"
```

Standalone mode reduced the number of files and dependencies required in the production runtime image.

### 5.3 Migrate to a Distroless Runtime

The frontend runtime was migrated from:

```text
node:24-alpine
```

to:

```text
gcr.io/distroless/nodejs24-debian13:nonroot
```

The distroless runtime provides several security benefits:

- No interactive shell
- No package manager
- No unnecessary npm runtime tooling
- Reduced package count
- Reduced attack surface
- Non-root execution

### 5.4 Update the Distroless Node Runtime

An earlier distroless runtime contained an older Node.js version that still generated vulnerability findings.

The image was updated to the current Debian 13-based Node.js 24 distroless runtime.

After rebuilding and rescanning, Docker Scout reported:

```text
Critical: 0
High:     0
Medium:   0
Low:      0
```

---

## 6. Final Frontend Security State

Final frontend image:

```text
Image size: 68 MB
Packages:   88
Critical:   0
High:       0
Medium:     0
Low:        0
```

Docker Scout reported:

```text
No vulnerable packages detected
```

The frontend image was reduced from approximately:

```text
926 MB
```

to:

```text
68 MB
```

This represents an approximate 93% reduction in image size.

---

## 7. Backend Security Assessment

### 7.1 Initial Backend State

The backend initially used a general-purpose Java runtime image based on Ubuntu Jammy.

The application also used:

```text
Spring Boot 3.2.1
Java 17
```

The initial backend image was approximately:

```text
605 MB
```

Docker Scout initially reported:

```text
Critical: 7
High:     43
Medium:   72
Low:      30

Total:   152
```

### 7.2 Major Backend Findings

Vulnerabilities were identified across several backend packages and transitive dependencies, including:

- Apache Tomcat
- Spring Security
- Spring Framework
- Netty
- RabbitMQ Java Client
- Jackson Databind
- Log4j
- MySQL Connector
- Spring Boot-managed dependencies

Apache Tomcat 10.1.17 accounted for several Critical and High findings.

---

## 8. Backend Runtime Hardening

### 8.1 Migrate to Distroless Java

The backend runtime was migrated from a general-purpose Java runtime to:

```text
gcr.io/distroless/java17-debian12:nonroot
```

This reduced the runtime attack surface by removing:

- Shell utilities
- Package managers
- General-purpose operating-system tools
- Unnecessary packages

The application also runs as a non-root user.

### 8.2 Configure the Distroless Java Startup Command

The distroless Java runtime already provides Java as its entrypoint.

The backend Dockerfile therefore uses:

```dockerfile
CMD ["-jar", "app.jar"]
```

This starts the application as:

```text
java -jar app.jar
```

### 8.3 Remove Shell-Based Health Checks

The original Docker Compose health check depended on:

```text
wget
```

Distroless containers intentionally do not contain wget, curl, or a shell.

The internal health check was removed and the backend was validated externally.

```bash
curl -i http://localhost:8080/api/products
```

The backend successfully returned:

```text
HTTP/1.1 200
```

Future Kubernetes deployments will use HTTP-based readiness and liveness probes.

---

## 9. Spring Boot Upgrade

The backend was upgraded from:

```text
Spring Boot 3.2.1
```

to:

```text
Spring Boot 3.5.16
```

This refreshed the Spring-managed dependency baseline and removed a significant number of vulnerabilities across:

- Spring Framework
- Spring Security
- Apache Tomcat
- Jackson
- Logging libraries
- Other transitive dependencies

After this upgrade, the number of backend vulnerabilities dropped significantly.

---

## 10. Removal of Unused Dependencies

### 10.1 RabbitMQ

Maven dependency analysis showed the following dependency chain:

```text
spring-boot-starter-amqp
  -> spring-rabbit
     -> amqp-client
```

RabbitMQ was not actively required by the current Baba App runtime.

Legacy RabbitMQ-related components included:

```text
RabbitMQConfig.java
OrderService RabbitTemplate logic
```

The following remediation actions were completed:

- Removed `spring-boot-starter-amqp`
- Removed `RabbitMQConfig.java`
- Removed RabbitMQ publishing logic from `OrderService`
- Preserved JPA-based order persistence

Removing RabbitMQ eliminated unnecessary vulnerable dependencies and reduced the application attack surface.

### 10.2 Redis

Maven dependency analysis showed:

```text
spring-boot-starter-data-redis
  -> lettuce-core
     -> Netty
```

Redis was running in Docker Compose, but the active cart functionality used:

```text
CartController
  -> CartRepository
     -> JPA / H2
```

Redis was therefore not required by the current cart workflow.

The following actions were completed:

- Removed `spring-boot-starter-data-redis`
- Removed `RedisConfig.java`
- Removed unused `CartService.java`
- Removed Redis from Docker Compose
- Removed Redis environment configuration
- Removed Redis container dependencies

Removing Redis also eliminated Netty vulnerabilities introduced by the Lettuce Redis client.

---

## 11. Final Dependency Remediation

### 11.1 Jackson

Docker Scout identified:

```text
jackson-databind 2.21.4
```

The fixed version was:

```text
2.21.5
```

Maven dependency analysis confirmed that Spring Boot was managing Jackson through:

```text
jackson-bom.version
```

The Maven property was updated to:

```xml
<jackson-bom.version>2.21.5</jackson-bom.version>
```

After rebuilding, Maven resolved:

```text
jackson-databind 2.21.5
```

### 11.2 Log4j

Docker Scout identified:

```text
log4j-api 2.24.3
```

The fixed version was:

```text
2.25.5
```

The Spring Boot managed version was updated to:

```xml
<log4j2.version>2.25.5</log4j2.version>
```

The application was rebuilt and rescanned successfully.

---

## 12. Backend Vulnerability Reduction

The backend vulnerability remediation progressed through several stages.

```text
152 vulnerabilities
        |
        v
113 vulnerabilities
        |
        v
11 vulnerabilities
        |
        v
4 vulnerabilities
        |
        v
3 vulnerabilities
        |
        v
0 vulnerabilities
```

Final Docker Scout results:

```text
Critical: 0
High:     0
Medium:   0
Low:      0
```

Final backend image:

```text
Image size: 136 MB
Packages:   110
```

Docker Scout reported:

```text
No vulnerable packages detected
```

---

## 13. Final Container Security Baseline

### Frontend

```text
Image size: 68 MB

Critical: 0
High:     0
Medium:   0
Low:      0
```

### Backend

```text
Image size: 136 MB

Critical: 0
High:     0
Medium:   0
Low:      0
```

Both final application images returned:

```text
No vulnerable packages detected
```

during the final Docker Scout security scans.

---

## 14. Security Engineering Principles Demonstrated

### Vulnerability Management

Known vulnerabilities were identified, analyzed, prioritized, remediated, and rescanned.

### Attack-Surface Reduction

Unnecessary operating-system packages, runtime tools, and application dependencies were removed.

### Least Functionality

Redis and RabbitMQ were removed because they did not currently perform necessary functions in the application architecture.

### Minimal Runtime Images

Distroless runtime images reduced unnecessary software included in production containers.

### Non-Root Execution

Both frontend and backend containers execute as non-root users.

### Secure Dependency Management

Spring Boot-managed dependency properties and BOMs were used to update vulnerable dependency families.

### Continuous Validation

The application was tested after major security changes to confirm that remediation did not break functionality.

---

## 15. Future Security Automation

Phase 02 remediation was performed interactively to understand the vulnerabilities, dependency relationships, and remediation process.

Future DevSecOps phases will automate these controls.

Target CI/CD security workflow:

```text
Git Push
   |
   v
Build Application
   |
   v
Run Tests
   |
   v
Build Container
   |
   v
Generate SBOM
   |
   v
Container Vulnerability Scan
   |
   +------ Critical / High Found ------+
   |                                    |
   v                                    v
Fail Pipeline                       Continue
                                        |
                                        v
                                   Push to ECR
                                        |
                                        v
                               Amazon Inspector
                                        |
                                        v
                                    Amazon EKS
```

Planned security technologies may include:

- Trivy
- Docker Scout
- GitHub Dependabot
- SBOM generation
- Amazon ECR enhanced scanning
- Amazon Inspector
- Container image signing
- Build provenance
- CI/CD security gates

### Security Gate Example

Future pipelines can enforce vulnerability thresholds.

```bash
trivy image \
  --severity CRITICAL,HIGH \
  --exit-code 1 \
  baba-app-backend:${IMAGE_TAG}
```

Expected behavior:

```text
Critical or High vulnerability detected
        |
        v
Pipeline fails
        |
        v
Image cannot be promoted
```

A compliant image will continue through the deployment pipeline.

---

## 16. Phase 02 Security Outcome

Phase 02 established a hardened container baseline for Baba App.

Final frontend state:

```text
Frontend
--------
68 MB
Distroless runtime
Non-root execution
0 Critical
0 High
0 Medium
0 Low
```

Final backend state:

```text
Backend
-------
136 MB
Distroless runtime
Non-root execution
0 Critical
0 High
0 Medium
0 Low
```

The container security work demonstrates:

- Vulnerability assessment
- Container hardening
- Software composition analysis
- Dependency remediation
- Attack-surface reduction
- Least-functionality principles
- Secure runtime configuration
- Non-root execution
- Functional validation
- Security rescanning

The Baba App container baseline is now ready to progress to Infrastructure as Code, AWS container registry, Kubernetes, and later cloud security automation.