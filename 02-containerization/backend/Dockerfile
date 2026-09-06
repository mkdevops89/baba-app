# =========================
# Build
# =========================
FROM maven:3.9.12-eclipse-temurin-17 AS builder

WORKDIR /app

COPY 01-application/backend/pom.xml .

RUN mvn dependency:go-offline -B

COPY 01-application/backend/src ./src

RUN mvn clean package


# =========================
# Production runtime
# =========================
FROM gcr.io/distroless/java17-debian13:nonroot

WORKDIR /app

COPY --from=builder \
    /app/target/baba-app-backend-0.0.1-SNAPSHOT.jar \
    app.jar

EXPOSE 8080

CMD ["-jar", "app.jar"]