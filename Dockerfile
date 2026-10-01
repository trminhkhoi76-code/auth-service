# syntax=docker/dockerfile:1

# --- Build stage ---
FROM maven:3.9.9-eclipse-temurin-21 AS builder
WORKDIR /build

COPY pom.xml .
RUN mvn -B -q dependency:go-offline

COPY src ./src
RUN mvn -B -q package -DskipTests \
    && java -Djarmode=tools -jar target/auth-service-*.jar extract --layers --launcher --destination extracted

# --- Runtime stage ---
FROM eclipse-temurin:21-jre-alpine AS runtime
WORKDIR /app

RUN addgroup -g 1001 spring && adduser -D -u 1001 -G spring spring
USER spring

# One layer per Spring Boot layer: dependencies rarely change, so pushes only ship the app layer
COPY --from=builder --chown=spring:spring /build/extracted/dependencies/ ./
COPY --from=builder --chown=spring:spring /build/extracted/spring-boot-loader/ ./
COPY --from=builder --chown=spring:spring /build/extracted/snapshot-dependencies/ ./
COPY --from=builder --chown=spring:spring /build/extracted/application/ ./

EXPOSE 8080

# Local `docker run` only: ECS uses the task definition health check (same probe)
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD wget -qO /dev/null http://localhost:8080/actuator/health/liveness || exit 1

ENV JAVA_OPTS="-XX:MaxRAMPercentage=75.0 -XX:+ExitOnOutOfMemoryError"
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS org.springframework.boot.loader.launch.JarLauncher"]
