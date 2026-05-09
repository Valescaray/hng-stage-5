#!/bin/bash
set -e

ENV_ID=$1
[ -z "$ENV_ID" ] && echo "Usage: $0 <env-id>" && exit 1
[ ! -f "envs/$ENV_ID.json" ] && echo "Env not found: $ENV_ID" && exit 1

NETWORK=$(jq -r '.network' "envs/$ENV_ID.json")

echo "[+] Destroying: $ENV_ID"

# Kill log-shipping process
if [ -f "logs/$ENV_ID/log_pid" ]; then
  kill "$(cat logs/$ENV_ID/log_pid)" 2>/dev/null || true
fi

# Stop and remove container
docker stop "$ENV_ID" 2>/dev/null || true
docker rm "$ENV_ID" 2>/dev/null || true

# Remove network
docker network rm "$NETWORK" 2>/dev/null || true

# Remove Nginx config and reload
rm -f "nginx/conf.d/$ENV_ID.conf"
docker exec nginx-proxy nginx -s reload

# Archive logs
mkdir -p "logs/archived/$ENV_ID"
mv "logs/$ENV_ID/"* "logs/archived/$ENV_ID/" 2>/dev/null || true
rmdir "logs/$ENV_ID" 2>/dev/null || true

# Delete state file
rm -f "envs/$ENV_ID.json"

echo "[+] Destroyed: $ENV_ID"
