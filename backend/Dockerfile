# Build stage: compile the Spring Boot jar with Maven.
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn -q dependency:go-offline
COPY src ./src
RUN mvn -q package -DskipTests

# Run stage: just a JRE and the jar. The host (e.g. Render) provides PORT and the DB_* / JWT_SECRET env vars.
FROM eclipse-temurin:17-jre
WORKDIR /app
COPY --from=build /app/target/stepup-hub-backend.jar app.jar
# Keep memory within small free-tier instances (512 MB).
ENV JAVA_OPTS="-XX:MaxRAMPercentage=75 -XX:+UseSerialGC"
EXPOSE 8080
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
