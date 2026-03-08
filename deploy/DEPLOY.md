# Deploying DeerFlow to the Cloud

This guide covers deploying DeerFlow as a single container to cloud platforms, giving you a public URL accessible from any device (including iPad/mobile).

## Prerequisites

You'll need:
- **ANTHROPIC_API_KEY** - Get one at https://console.anthropic.com
- **TAVILY_API_KEY** - Get one at https://tavily.com (for web search)

## Option 1: Railway (Recommended)

Railway is the easiest option with generous free credits.

1. **Sign up** at https://railway.app (GitHub login works)
2. **Create a new project** → "Deploy from GitHub repo"
3. **Connect your fork** of this repository
4. **Add environment variables** in the Railway dashboard:
   - `ANTHROPIC_API_KEY` = your key
   - `TAVILY_API_KEY` = your key
5. **Set the config**:
   - In Settings → Build, set the Root Directory to `/` (default)
   - Railway will auto-detect `deploy/railway.toml`
   - Or manually set Dockerfile path to `deploy/Dockerfile`
6. **Deploy** — Railway will build and give you a public URL like `https://deerflow-production.up.railway.app`

## Option 2: Render

1. **Sign up** at https://render.com
2. **New Web Service** → Connect your GitHub repo
3. **Configure**:
   - Environment: Docker
   - Dockerfile Path: `deploy/Dockerfile`
   - Plan: Starter ($7/mo) or Free (sleeps after 15min inactivity)
4. **Add environment variables**: `ANTHROPIC_API_KEY`, `TAVILY_API_KEY`
5. **Deploy** — You'll get a URL like `https://deerflow.onrender.com`

## Option 3: Fly.io

```bash
# Install flyctl
curl -L https://fly.io/install.sh | sh

# Login
fly auth login

# Launch (from project root)
fly launch --dockerfile deploy/Dockerfile --name deerflow

# Set secrets
fly secrets set ANTHROPIC_API_KEY=sk-ant-...
fly secrets set TAVILY_API_KEY=tvly-...

# Deploy
fly deploy
```

## Option 4: Docker (Any Server)

If you have a VPS (DigitalOcean, AWS, etc.):

```bash
# Build
docker build -f deploy/Dockerfile -t deerflow .

# Run
docker run -d \
  -p 2026:2026 \
  -e ANTHROPIC_API_KEY=sk-ant-... \
  -e TAVILY_API_KEY=tvly-... \
  --name deerflow \
  deerflow
```

Then access at `http://your-server-ip:2026`

## Architecture

The deployment bundles all services into a single container:

```
                    ┌─────────────────────────────────────┐
                    │         Nginx (port $PORT)          │
                    │         Reverse Proxy               │
                    ├──────────┬──────────┬───────────────┤
                    │          │          │               │
              /api/langgraph  /api/*    /health    / (everything else)
                    │          │          │               │
                    ▼          ▼          ▼               ▼
              ┌──────────┐ ┌──────────┐         ┌──────────────┐
              │ LangGraph│ │ Gateway  │         │   Next.js    │
              │  :2024   │ │  :8001   │         │    :3000     │
              └──────────┘ └──────────┘         └──────────────┘
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `ANTHROPIC_API_KEY` | Yes | Anthropic API key for Claude |
| `TAVILY_API_KEY` | Yes | Tavily API key for web search |
| `PORT` | No | Listening port (default: 2026, auto-set by Railway/Render) |
| `OPENAI_API_KEY` | No | OpenAI key (if using GPT models) |
| `DEEPSEEK_API_KEY` | No | DeepSeek key (if using DeepSeek models) |
| `GEMINI_API_KEY` | No | Google key (if using Gemini models) |
