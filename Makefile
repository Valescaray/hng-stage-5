.PHONY: up down create destroy logs health simulate clean

up:
	docker stop nginx-proxy 2>/dev/null || true
	docker rm nginx-proxy 2>/dev/null || true
	docker run -d --name nginx-proxy -p 80:80 \
	  -v $(PWD)/nginx/nginx.conf:/etc/nginx/nginx.conf:ro \
	  -v $(PWD)/nginx/conf.d:/etc/nginx/conf.d:ro \
	  --add-host host.docker.internal:host-gateway nginx:alpine
	fuser -k 8080/tcp 2>/dev/null || true
	nohup bash platform/cleanup_daemon.sh &
	nohup venv/bin/python monitor/health_poller.py &
	nohup venv/bin/python platform/api.py &

down:
	-for f in envs/*.json; do \
	  [ -f "$$f" ] && bash platform/destroy_env.sh $$(jq -r '.id' $$f); \
	done
	docker stop nginx-proxy 2>/dev/null || true
	docker rm nginx-proxy 2>/dev/null || true
	pkill -f cleanup_daemon.sh 2>/dev/null || true
	pkill -f health_poller.py 2>/dev/null || true
	pkill -f api.py 2>/dev/null || true

create:
	@read -p "Env name: " NAME; \
	read -p "TTL (seconds, default 1800): " TTL; \
	bash platform/create_env.sh "$$NAME" "$${TTL:-1800}"

destroy:
	bash platform/destroy_env.sh $(ENV)

logs:
	tail -f logs/$(ENV)/app.log

health:
	@for f in envs/*.json; do \
	  [ -f "$$f" ] || continue; \
	  ID=$$(jq -r '.id' $$f); \
	  STATUS=$$(jq -r '.status' $$f); \
	  TTL_LEFT=$$(python3 -c "import json,time; e=json.load(open('$$f')); print(max(0, e['created_at']+e['ttl']-int(time.time())))"); \
	  echo "$$ID | status=$$STATUS | ttl_remaining=$${TTL_LEFT}s"; \
	done

simulate:
	bash platform/simulate_outage.sh --env $(ENV) --mode $(MODE)

clean:
	rm -rf logs/* envs/* nginx/conf.d/*.conf
	mkdir -p logs envs nginx/conf.d