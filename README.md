# devops-sandbox

A self-contained ephemeral environment platform — spin up isolated Docker-based sandboxes with automatic TTL expiry, Nginx reverse-proxy routing, health monitoring, and chaos engineering support.

## Architecture

```
                          ┌──────────────────────────────┐
                          │        Control Plane         │
                          │  platform/api.py  :8080      │
                          └──────────┬───────────────────┘
                                     │ REST calls
               ┌─────────────────────┼──────────────────────┐
               │                     │                      │
    ┌──────────▼──────────┐ ┌────────▼────────┐ ┌──────────▼──────────┐
    │  create_env.sh      │ │ destroy_env.sh  │ │ cleanup_daemon.sh   │
    │  (spawn containers) │ │ (teardown)      │ │ (TTL watcher/60s)   │
    └──────────┬──────────┘ └────────┬────────┘ └──────────┬──────────┘
               │                     │                      │
               ▼                     ▼                      ▼
       ┌───────────────┐     ┌───────────────┐     ┌───────────────┐
       │  Docker Net   │     │  Docker Net   │     │  envs/*.json  │
       │  + sandbox-   │     │  removed      │     │  state files  │
       │  app:5000     │     │               │     └───────────────┘
       └───────┬───────┘     └───────────────┘
               │ proxy_pass
       ┌───────▼───────┐
       │  nginx-proxy  │  :80  →  env-XXXXXX.sandbox.local
       │  conf.d/*.conf│
       └───────────────┘
               ▲
       ┌───────┴───────┐
       │ health_poller │  every 30s → logs/{env}/health.log
       │ monitor/      │  marks degraded after 3 failures
       └───────────────┘
```

## Prerequisites

- Docker Desktop (running)
- Python 3.x — `pip install flask requests`
- `jq` — for JSON parsing in shell scripts
- `curl` — for API testing
- WSL2 or Git Bash (Windows users — required for Makefile / shell scripts)

## Quick Start (5 commands)

```bash
git clone <your-repo-url>
cd devops-sandbox
pip install flask requests
make up
make create
```

## Demo Walkthrough

```bash
# 1. Start the platform (Nginx proxy + cleanup daemon + control API)
make up

# 2. Create a sandbox environment (name=myapp, TTL=300s)
make create
# → prompts: Env name: myapp | TTL: 300

# 3. Hit the environment
curl http://env-abc12345.sandbox.local/health
# → {"status": "ok", "env": "env-abc12345"}

# 4. Check all running envs
make health
# → env-abc12345 => running

# 5. Simulate a crash
make simulate ENV=env-abc12345 MODE=crash

# 6. Watch the health monitor catch it (~90s, 3 polls)
tail -f logs/env-abc12345/health.log

# 7. Recover the environment
make simulate ENV=env-abc12345 MODE=recover

# 8. Let the TTL expire — cleanup daemon auto-destroys at T+300s
# Or force destroy manually:
make destroy ENV=env-abc12345
```

## API Reference

| Method   | Endpoint                        | Description                     |
|----------|---------------------------------|---------------------------------|
| `POST`   | `/envs`                         | Create a new environment        |
| `GET`    | `/envs`                         | List all environments + TTL     |
| `DELETE` | `/envs/<env_id>`                | Destroy an environment          |
| `GET`    | `/envs/<env_id>/logs`           | Last 100 lines of app logs      |
| `GET`    | `/envs/<env_id>/health`         | Last 10 health check results    |
| `POST`   | `/envs/<env_id>/outage`         | Trigger chaos simulation        |

### Example API calls

```bash
# Create via API
curl -X POST http://localhost:8080/envs \
  -H "Content-Type: application/json" \
  -d '{"name": "myapp", "ttl": 300}'

# List envs
curl http://localhost:8080/envs

# Simulate outage
curl -X POST http://localhost:8080/envs/env-abc12345/outage \
  -H "Content-Type: application/json" \
  -d '{"mode": "pause"}'
```

## Outage Simulation Modes

| Mode        | Effect                                           |
|-------------|--------------------------------------------------|
| `crash`     | `docker kill` — immediate container termination  |
| `pause`     | `docker pause` — freezes all container processes |
| `network`   | Disconnects container from its Docker network    |
| `recover`   | Unpauses / restarts / reconnects container       |
| `stress`    | Runs `stress-ng --cpu 2 --timeout 30s` inside    |

## Project Structure

```
devops-sandbox/
├── platform/
│   ├── app/
│   │   ├── app.py            # Flask demo app
│   │   └── Dockerfile
│   ├── api.py                # Control REST API (port 8080)
│   ├── create_env.sh         # Provision a new environment
│   ├── destroy_env.sh        # Teardown an environment
│   ├── cleanup_daemon.sh     # TTL expiry watcher
│   └── simulate_outage.sh    # Chaos engineering
├── monitor/
│   └── health_poller.py      # HTTP health checker (every 30s)
├── nginx/
│   ├── nginx.conf            # Main Nginx config
│   └── conf.d/               # Per-env server blocks (auto-managed)
├── logs/                     # App + health logs (gitignored)
├── envs/                     # State JSON files (gitignored)
├── Makefile                  # Top-level control interface
├── .env                      # Environment variables (gitignored)
└── README.md
```

## Known Limitations

- Nginx uses `host.docker.internal` — may need adjustment on some Linux setups (replace with `172.17.0.1` or use `--network host`)
- No TLS — HTTP only
- Log shipping uses Approach A (simple `docker logs -f` redirect)
- Shell scripts require WSL2 or Git Bash on Windows
- `stress` mode requires `stress-ng` installed inside the container
