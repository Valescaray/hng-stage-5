#!/bin/bash

LOG="logs/cleanup.log"
mkdir -p logs

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }

log "Cleanup daemon started"

while true; do
  for state_file in envs/*.json; do
    [ -f "$state_file" ] || continue
    ENV_ID=$(jq -r '.id' "$state_file")
    CREATED_AT=$(jq -r '.created_at' "$state_file")
    TTL=$(jq -r '.ttl' "$state_file")
    NOW=$(date +%s)
    EXPIRES=$((CREATED_AT + TTL))

    if [ "$NOW" -gt "$EXPIRES" ]; then
      log "TTL expired for $ENV_ID — destroying"
      bash platform/destroy_env.sh "$ENV_ID" >> "$LOG" 2>&1
    fi
  done
  sleep 60
done
