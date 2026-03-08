# DeerFlow All-in-One Production Dockerfile
# Bundles: LangGraph Server + Gateway API + Next.js Frontend + Nginx
#
# Required env vars at runtime:
#   ANTHROPIC_API_KEY - Your Anthropic API key
#   TAVILY_API_KEY    - Your Tavily API key (for web search)
#
# Optional env vars:
#   PORT              - Main listening port (default: 2026, Railway sets this)

# ── Stage 1: Build Frontend ──────────────────────────────────────────────
FROM node:22-alpine AS frontend-build

RUN corepack enable && corepack install -g pnpm@10.26.2

WORKDIR /app/frontend
COPY frontend/package.json frontend/pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

COPY frontend/ ./
# Frontend connects through nginx at same origin, no direct backend URLs needed
ENV SKIP_ENV_VALIDATION=1
RUN pnpm build

# ── Stage 2: Production Runtime ──────────────────────────────────────────
FROM python:3.12-slim

# Install system dependencies: Node.js 22, nginx, curl
RUN apt-get update && apt-get install -y \
    curl \
    build-essential \
    nginx \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && corepack enable && corepack install -g pnpm@10.26.2 \
    && rm -rf /var/lib/apt/lists/*

# Install uv (Python package manager)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

WORKDIR /app

# ── Install Backend Dependencies ─────────────────────────────────────────
COPY backend/ ./backend/
RUN cd backend && uv sync

# ── Install Frontend Production Dependencies ─────────────────────────────
COPY frontend/package.json frontend/pnpm-lock.yaml ./frontend/
RUN cd frontend && pnpm install --frozen-lockfile --prod

# Copy built frontend from Stage 1
COPY --from=frontend-build /app/frontend/.next ./frontend/.next
COPY --from=frontend-build /app/frontend/public ./frontend/public
COPY frontend/next.config.js ./frontend/next.config.js
COPY frontend/src/env.js ./frontend/src/env.js

# ── Copy Project Files ───────────────────────────────────────────────────
COPY config.example.yaml ./config.example.yaml
COPY skills/ ./skills/
COPY deploy/nginx-prod.conf /etc/nginx/nginx-prod.conf.template
COPY deploy/start.sh ./start.sh
RUN chmod +x ./start.sh

# Create necessary directories
RUN mkdir -p logs backend/.deer-flow/threads

# Default port (Railway overrides via $PORT)
ENV PORT=2026

EXPOSE 2026

CMD ["./start.sh"]
