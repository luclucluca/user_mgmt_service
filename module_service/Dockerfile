FROM python:3.12-alpine AS builder
WORKDIR /app
# Falls fuer eine Dependency (z.B. cryptography, Transitive von pymysql[rsa]) kein
# vorgebautes musllinux-Wheel existiert, braucht uv einen C-Compiler zum Bauen.
RUN apk add --no-cache gcc musl-dev libffi-dev
RUN pip install --no-cache-dir uv
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --no-install-project
COPY app/ app/
RUN uv sync --frozen --no-dev

FROM python:3.12-alpine AS runtime
WORKDIR /app
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

COPY --from=builder /app/.venv .venv
COPY --from=builder /app/app app

RUN chown -R appuser:appgroup /app

USER appuser

ENV PATH="/app/.venv/bin:${PATH}"
ENV DATABASE_URL=""
ENV MYSQL_SSL_DISABLED="true"
ENV LOG_LEVEL="INFO"

EXPOSE 8080

ENTRYPOINT ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
