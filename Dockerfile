FROM debian:bookworm-slim
WORKDIR /app
ENV APP_DIR=/app
COPY slack-org-chart .
COPY config.example.yaml .
COPY .env.example .
COPY LICENSE .
COPY docs/ docs/
CMD ["./slack-org-chart"]
