#!/bin/bash

ENV=""
MODE=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --env) ENV="$2"; shift 2;;
    --mode) MODE="$2"; shift 2;;
    *) shift;;
  esac
done

[ -z "$ENV" ] || [ -z "$MODE" ] && echo "Usage: $0 --env <id> --mode <crash|pause|network|recover>" && exit 1

# GUARD: never simulate against platform containers
if [[ "$ENV" == "nginx-proxy" || "$ENV" == "cleanup-daemon" || "$ENV" == "api" ]]; then
  echo "[ERROR] Refusing to simulate against a platform container!" && exit 1
fi

case $MODE in
  crash)   docker kill "$ENV" ;;
  pause)   docker pause "$ENV" ;;
  network)
    NETWORK=$(jq -r '.network' "envs/$ENV.json")
    docker network disconnect "$NETWORK" "$ENV" ;;
  recover)
    docker unpause "$ENV" 2>/dev/null || true
    docker start "$ENV" 2>/dev/null || true
    NETWORK=$(jq -r '.network' "envs/$ENV.json")
    docker network connect "$NETWORK" "$ENV" 2>/dev/null || true ;;
  stress)  docker exec "$ENV" stress-ng --cpu 2 --timeout 30s ;;
  *) echo "Unknown mode: $MODE" && exit 1 ;;
esac

echo "[+] Simulation '$MODE' applied to $ENV"
