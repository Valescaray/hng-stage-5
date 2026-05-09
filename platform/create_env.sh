#!/bin/bash
set -e

NAME=${1:-"unnamed"}
TTL=${2:-1800}  # 30 min default

ENV_ID="env-$(cat /proc/sys/kernel/random/uuid | cut -c1-8)"
PORT=$(shuf -i 3000-9000 -n 1)
CREATED_AT=$(date +%s)
NETWORK="net-$ENV_ID"

echo "[+] Creating environment: $ENV_ID (name=$NAME, TTL=${TTL}s)"

# 1. Docker network
docker network create "$NETWORK"

# 2. Start container
docker run -d \
  --name "$ENV_ID" \
  --network "$NETWORK" \
  --label "sandbox.env=$ENV_ID" \
  -e "SANDBOX_ENV_ID=$ENV_ID" \
  -p "$PORT:5000" \
  sandbox-app

# 3. Write state file atomically
cat > "/tmp/$ENV_ID.json" <<EOF
{
  "id": "$ENV_ID",
  "name": "$NAME",
  "port": $PORT,
  "created_at": $CREATED_AT,
  "ttl": $TTL,
  "status": "running",
  "network": "$NETWORK"
}
EOF
mv "/tmp/$ENV_ID.json" "envs/$ENV_ID.json"

# 4. Write Nginx config
cat > "nginx/conf.d/$ENV_ID.conf" <<EOF
server {
    listen 80;
    server_name $ENV_ID.sandbox.local;
    location / {
        proxy_pass http://host.docker.internal:$PORT;
    }
}
EOF

# 5. Reload Nginx
docker exec nginx-proxy nginx -s reload

# 6. Log shipping (Approach A)
mkdir -p "logs/$ENV_ID"
docker logs -f "$ENV_ID" >> "logs/$ENV_ID/app.log" 2>&1 &
echo $! > "logs/$ENV_ID/log_pid"

echo "[+] Done! URL: http://$ENV_ID.sandbox.local | TTL: ${TTL}s"
