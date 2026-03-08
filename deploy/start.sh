#!/bin/bash
# DeerFlow Production Startup Script
# Starts all services in a single container

set -e

PORT="${PORT:-2026}"

echo "=== DeerFlow Production Server ==="
echo "Port: $PORT"

# Generate config.yaml from environment if not present
if [ ! -f config.yaml ]; then
    cp config.example.yaml config.yaml
    # Uncomment the Anthropic model config
    cat > config.yaml << 'YAML'
models:
  - name: claude-sonnet-4
    display_name: Claude Sonnet 4
    use: langchain_anthropic:ChatAnthropic
    model: claude-sonnet-4-20250514
    api_key: $ANTHROPIC_API_KEY
    max_tokens: 8192
    supports_vision: true

tool_groups:
  - name: web
  - name: file:read
  - name: file:write
  - name: bash

tools:
  - name: web_search
    group: web
    use: src.community.tavily.tools:web_search_tool
    max_results: 5

  - name: web_fetch
    group: web
    use: src.community.jina_ai.tools:web_fetch_tool
    timeout: 10

  - name: image_search
    group: web
    use: src.community.image_search.tools:image_search_tool
    max_results: 5

  - name: ls
    group: file:read
    use: src.sandbox.tools:ls_tool

  - name: read_file
    group: file:read
    use: src.sandbox.tools:read_file_tool

  - name: write_file
    group: file:write
    use: src.sandbox.tools:write_file_tool

  - name: str_replace
    group: file:write
    use: src.sandbox.tools:str_replace_tool

  - name: bash
    group: bash
    use: src.sandbox.tools:bash_tool

sandbox:
  use: src.sandbox.local:LocalSandboxProvider

skills:
  container_path: /mnt/skills

title:
  enabled: true
  max_words: 6
  max_chars: 60
  model_name: null

summarization:
  enabled: true
  model_name: null
  trigger:
    - type: tokens
      value: 15564
  keep:
    type: messages
    value: 10
  trim_tokens_to_summarize: 15564
  summary_prompt: null

memory:
  enabled: true
  storage_path: memory.json
  debounce_seconds: 30
  model_name: null
  max_facts: 100
  fact_confidence_threshold: 0.7
  injection_enabled: true
  max_injection_tokens: 2000
YAML
    echo "Generated config.yaml"
fi

# Create directories
mkdir -p logs backend/.deer-flow/threads

# Configure nginx with the correct port
sed "s/LISTEN_PORT/$PORT/g" /etc/nginx/nginx-prod.conf.template > /tmp/nginx.conf

# Cleanup function
cleanup() {
    echo "Shutting down..."
    kill "$LANGGRAPH_PID" "$GATEWAY_PID" "$FRONTEND_PID" 2>/dev/null || true
    nginx -s stop -c /tmp/nginx.conf 2>/dev/null || true
    exit 0
}
trap cleanup SIGTERM SIGINT

# 1. Start LangGraph Server (port 2024)
echo "[1/4] Starting LangGraph server..."
cd backend
uv run langgraph dev --no-browser --allow-blocking --host 0.0.0.0 --port 2024 > /app/logs/langgraph.log 2>&1 &
LANGGRAPH_PID=$!
cd /app

# 2. Start Gateway API (port 8001)
echo "[2/4] Starting Gateway API..."
cd backend
uv run uvicorn src.gateway.app:app --host 0.0.0.0 --port 8001 > /app/logs/gateway.log 2>&1 &
GATEWAY_PID=$!
cd /app

# 3. Start Frontend (port 3000)
echo "[3/4] Starting Frontend..."
cd frontend
SKIP_ENV_VALIDATION=1 NODE_ENV=production pnpm start -p 3000 > /app/logs/frontend.log 2>&1 &
FRONTEND_PID=$!
cd /app

# Wait for services to be ready
echo "Waiting for services to start..."
sleep 5

# 4. Start Nginx (main entry point)
echo "[4/4] Starting Nginx on port $PORT..."
nginx -c /tmp/nginx.conf -g 'daemon off;' &
NGINX_PID=$!

echo ""
echo "=== DeerFlow is running ==="
echo "All services started successfully."
echo ""

# Wait for any process to exit
wait -n "$LANGGRAPH_PID" "$GATEWAY_PID" "$FRONTEND_PID" "$NGINX_PID" 2>/dev/null || true

# If any process died, log it and exit
echo "A service has stopped. Shutting down..."
cleanup
