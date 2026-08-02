# syntax=docker/dockerfile:1.7
FROM maven:3.9.11-eclipse-temurin-21 AS build
WORKDIR /workspace
COPY pom.xml .
RUN --mount=type=cache,target=/root/.m2 mvn -q -DskipTests dependency:go-offline
COPY src ./src
RUN --mount=type=cache,target=/root/.m2 mvn -q -DskipTests package

FROM eclipse-temurin:21-jre-jammy AS runtime
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system safefleet \
    && useradd --system --gid safefleet --home-dir /app safefleet \
    && mkdir -p /data/evidence \
    && chown -R safefleet:safefleet /data/evidence
WORKDIR /app
COPY --from=build /workspace/target/safefleet-backend-0.0.1-SNAPSHOT.jar app.jar
USER safefleet
EXPOSE 8080
ENV SPRING_PROFILES_ACTIVE=docker
HEALTHCHECK --interval=15s --timeout=5s --start-period=45s --retries=5 \
  CMD curl --fail --silent http://127.0.0.1:8080/actuator/health >/dev/null || exit 1
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75.0", "-jar", "/app/app.jar"]
