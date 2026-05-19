# Run Book

Operational runbook for the `smart-air` server stack under `server/`.

This file covers manual start and stop, health verification, common operator actions, and first-response troubleshooting. It does not replace architecture or protocol documentation.

## Scope

- Stack location: `server/`
- Compose file: `server/docker-compose.yml`
- Main verification script: `scripts/check-server-connections.sh`
- Architecture and contracts live elsewhere:
  - `docs/ARCHITECTURE.md`
  - `docs/API_REFERENCE.md`
  - `docs/MQTT_PROTOCOL.md`

## Current Operating Model

- Docker does not need to auto-start on boot.
- The `smart-air` stack does not auto-start when Docker starts.
- Compose services do not use `restart: unless-stopped`.
- Operators start Docker and the stack manually when needed.

## Service Inventory

Core services:

- `postgres`: primary database
- `redis`: cache and command queue
- `emqx`: MQTT broker
- `api`: Fastify API
- `nginx`: public reverse proxy
- `cloudflared`: Cloudflare Tunnel connector
- `grafana`: dashboards

Optional admin services:

- `pgadmin`: database UI
- `portainer`: Docker UI

Notes:

- `pgadmin` and `portainer` are optional and may be absent during normal runtime.
- `grafana` is part of the compose stack but is operational rather than control-plane critical.

## Prerequisites

Before startup, ensure `server/.env` exists and required secrets are populated.

Required at runtime for `server/api`:

- `JWT_SECRET`
- `POSTGRES_PASSWORD`
- `REDIS_PASSWORD`
- `EMQX_API_KEY`
- `EMQX_API_SECRET`
- `EMQX_MQTT_PASSWORD`

Common service credentials and settings:

- `POSTGRES_DB`
- `POSTGRES_USER`
- `GRAFANA_PASSWORD`
- `PGADMIN_EMAIL`
- `PGADMIN_PASSWORD`
- `EMQX_NODE_COOKIE`
- `MQTT_LAN_BIND_IP`

Cloudflare Tunnel:

- `CLOUDFLARE_TUNNEL_TOKEN` is required before starting `cloudflared`.
- The public entrypoint terminates at `nginx`.

## Manual Lifecycle

Start Docker manually:

```bash
sudo systemctl start docker
```

Start the full local stack, including admin services:

```bash
cd /home/nhat/Working_Space/my-project/smart-air/server
rtk proxy docker compose --profile admin up -d
```

This is the default local-ops startup path when you want the full environment:

- core services
- `pgadmin` on `http://127.0.0.1:5050/`
- `portainer` on `http://127.0.0.1:9000/`

Start the core stack only:

```bash
cd /home/nhat/Working_Space/my-project/smart-air/server
rtk proxy docker compose up -d
```

Stop the stack:

```bash
cd /home/nhat/Working_Space/my-project/smart-air/server
rtk proxy docker compose down --remove-orphans
```

Stop Docker after the stack is down:

```bash
sudo systemctl stop docker.socket docker.service containerd.service
```

Disable Docker auto-start after reboot or login:

```bash
sudo systemctl disable --now docker.service docker.socket containerd.service
```

## Health Verification

Quick status:

```bash
cd /home/nhat/Working_Space/my-project/smart-air/server
rtk proxy docker compose ps
```

Read-only runtime verification:

```bash
cd /home/nhat/Working_Space/my-project/smart-air
./scripts/check-server-connections.sh
```

What the verification script checks:

- Compose runtime state for `postgres`, `redis`, `api`, `nginx`, `cloudflared`, `emqx`, `grafana`, `pgadmin`, `portainer`
- `postgres` accepts `SELECT 1`
- `redis` responds to `PING`
- API live endpoint: `http://127.0.0.1:3000/api/health/live`
- API ready endpoint: `http://127.0.0.1:3000/api/health/ready`
- Nginx health endpoint: `http://127.0.0.1/nginx/health`
- EMQX broker status via `emqx ctl status`
- EMQX admin API on `http://127.0.0.1:18083/api/v5/status`
- `grafana`, `pgadmin`, and `portainer` availability when declared and running

Healthy API readiness must report:

- `status = ok`
- `postgres = ok`
- `redis = ok`
- `mqtt = ok`

## Common Operations

View stack logs:

```bash
cd /home/nhat/Working_Space/my-project/smart-air/server
rtk proxy docker compose logs --tail=200
```

View logs for one service:

```bash
cd /home/nhat/Working_Space/my-project/smart-air/server
rtk proxy docker compose logs --tail=200 api
```

Restart one service:

```bash
cd /home/nhat/Working_Space/my-project/smart-air/server
rtk proxy docker compose restart api
```

Rebuild and start the API:

```bash
cd /home/nhat/Working_Space/my-project/smart-air/server
rtk proxy docker compose up -d --build api
```

Run database migrations:

```bash
cd /home/nhat/Working_Space/my-project/smart-air/server/api
rtk npm run migrate
```

Render the final compose config:

```bash
cd /home/nhat/Working_Space/my-project/smart-air/server
rtk docker compose config
```

## First-Response Troubleshooting

### API live is healthy, API ready is failing

Likely meaning:

- API process is up
- One dependency is not ready, usually `postgres`, `redis`, or `mqtt`

Check:

```bash
cd /home/nhat/Working_Space/my-project/smart-air
./scripts/check-server-connections.sh
cd server
rtk proxy docker compose logs --tail=200 api
```

Focus on:

- readiness JSON fields
- connection failures to `postgres`
- connection failures to `redis`
- MQTT bridge failures

### API ready reports `mqtt = fail`

Likely meaning:

- `api` cannot connect its MQTT bridge to `emqx`
- EMQX credentials or broker state are wrong

Check:

```bash
cd /home/nhat/Working_Space/my-project/smart-air/server
rtk proxy docker compose logs --tail=200 api
rtk proxy docker compose logs --tail=200 emqx
```

Focus on:

- `Connection refused`
- `Not authorized`
- `authentication_failure`
- `sa-api-bridge`
- `sa-server`

Verify:

- `EMQX_API_KEY` and `EMQX_API_SECRET` match the bootstrap config
- `EMQX_MQTT_PASSWORD` matches what the API bridge expects
- `emqx` is healthy before `api` is considered ready

### Nginx health fails

Likely meaning:

- `nginx` is up but misconfigured
- `api` upstream is not healthy

Check:

```bash
cd /home/nhat/Working_Space/my-project/smart-air/server
rtk proxy docker compose logs --tail=200 nginx
rtk proxy docker compose logs --tail=200 api
```

### Cloudflared is not running or public ingress is down

Likely meaning:

- `CLOUDFLARE_TUNNEL_TOKEN` missing or wrong
- tunnel not registered correctly in Cloudflare
- `nginx` upstream is unhealthy

Check:

```bash
cd /home/nhat/Working_Space/my-project/smart-air/server
rtk proxy docker compose logs --tail=200 cloudflared
rtk proxy docker compose ps
```

Focus on confirmed tunnel-registration success, not just container uptime.

### Postgres is healthy but API still fails

Likely meaning:

- migration not applied
- API config mismatch
- another dependency is failing while Postgres is fine

Check:

```bash
cd /home/nhat/Working_Space/my-project/smart-air/server/api
rtk npm run migrate
cd ../
rtk proxy docker compose logs --tail=200 api
```

## Safety Notes

- `docker compose down` removes containers and networks, but keeps named volumes and bind-mounted data.
- Do not use `docker compose down -v` unless you intentionally want to destroy persisted state.
- Persistent data paths under `server/` include at least:
  - `postgres/data`
  - `redis/data`
  - `grafana/data`
  - `pgadmin/data`
  - `portainer/data`
- Treat `.env`, database state, Redis state, and EMQX credentials as operational data.

## References

- `server/docker-compose.yml`
- `server/.env.example`
- `scripts/check-server-connections.sh`
- `docs/ARCHITECTURE.md`
- `docs/API_REFERENCE.md`
- `docs/MQTT_PROTOCOL.md`
