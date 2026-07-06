FROM eclipse-temurin:25-jdk-alpine AS builder

WORKDIR /app

COPY build.gradle settings.gradle ./
COPY gradle/ gradle/
COPY gradlew ./

RUN ./gradlew dependencies --no-daemon

COPY src/ src/
RUN ./gradlew bootJar --no-daemon -x test

FROM eclipse-temurin:25-jre-alpine AS runtime

WORKDIR /app

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

COPY --from=builder /app/build/libs/*.jar app.jar

RUN chown appuser:appgroup app.jar

USER appuser

ENV SPRING_DATASOURCE_URL=""
ENV SPRING_DATASOURCE_USERNAME=""
ENV SPRING_DATASOURCE_PASSWORD=""
ENV SPRING_JPA_HIBERNATE_DDL_AUTO="validate"
ENV JWT_ISSUER=""
ENV JWT_SECRET=""
ENV JWT_EXPIRATION_MILLIS="3600000"

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]