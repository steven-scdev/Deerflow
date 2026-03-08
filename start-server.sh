#!/bin/bash
# DeerFlow Local Server Startup Script
# Starts all services: LangGraph server, Gateway API, Frontend, and Nginx

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

# Load environment variables
set -a
source .env
set +a

# Create logs directory
mkdir -p logs

# Cleanup function
cleanup() {
    echo "Shutting down services..."
    kill $(cat logs/langgraph.pid 2>/dev/null) 2>/dev/null || true
    kill $(cat logs/gateway.pid 2>/dev/null) 2>/dev/null || true
    kill $(cat logs/frontend.pid 2>/dev/null) 2>/dev/null || true
    nginx -s stop -c "$PROJECT_DIR/docker/nginx/nginx.local.conf" -p "$PROJECT_DIR" 2>/dev/null || true
    rm -f logs/*.pid
    echo "All services stopped."
}
trap cleanup EXIT

echo "=== Starting DeerFlow Services ==="

# 1. Start LangGraph Server (port 2025)
# Note: Port 2024 may be in use; nginx.local.conf is configured for 2025
echo "[1/4] Starting LangGraph server on port 2025..."
cd backend
uv run -p python3.12 langgraph dev --no-browser --allow-blocking --host 0.0.0.0 --port 2025 > "$PROJECT_DIR/logs/langgraph.log" 2>&1 &
echo $! > "$PROJECT_DIR/logs/langgraph.pid"
cd "$PROJECT_DIR"

# 2. Start Gateway API (port 8001)
echo "[2/4] Starting Gateway API on port 8001..."
cd backend
uv run -p python3.12 uvicorn src.gateway.app:app --host 0.0.0.0 --port 8001 > "$PROJECT_DIR/logs/gateway.log" 2>&1 &
echo $! > "$PROJECT_DIR/logs/gateway.pid"
cd "$PROJECT_DIR"

# 3. Start Frontend (port 3000)
echo "[3/4] Starting Frontend on port 3000..."
cd frontend
pnpm dev > "$PROJECT_DIR/logs/frontend.log" 2>&1 &
echo $! > "$PROJECT_DIR/logs/frontend.pid"
cd "$PROJECT_DIR"

# 4. Start Nginx reverse proxy (port 2026)
echo "[4/4] Starting Nginx reverse proxy on port 2026..."
nginx -c "$PROJECT_DIR/docker/nginx/nginx.local.conf" -p "$PROJECT_DIR"

echo ""
echo "=== DeerFlow is starting up ==="
echo "Access the web UI at: http://localhost:2026"
echo ""
echo "Service logs:"
echo "  LangGraph: logs/langgraph.log"
echo "  Gateway:   logs/gateway.log"
echo "  Frontend:  logs/frontend.log"
echo "  Nginx:     logs/nginx-access.log / logs/nginx-error.log"
echo ""
echo "Press Ctrl+C to stop all services."

# Wait for all background processes
wait
