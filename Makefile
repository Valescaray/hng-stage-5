.PHONY: up down create destroy logs health simulate clean

up:
	docker run -d --name nginx-proxy -p 80:80 \
	  -v $(PWD)/nginx/nginx.conf:/etc/nginx/nginx.conf:ro \
	  -v $(PWD)/nginx/conf.d:/etc/nginx/conf.d:ro \
	  --add-host host.docker.internal:host-gateway nginx:alpine
	nohup bash platform/cleanup_daemon.sh &
	python3 platform/api.py &

down:
	for f in envs/*.json; do bash platform/destroy_env.sh $$(jq -r '.id' $$f); done
	docker stop nginx-proxy && docker rm nginx-proxy
	pkill -f cleanup_daemon.sh || true
	pkill -f api.py || true

create:
	@read -p "Env name: " NAME; read -p "TTL (seconds, default 1800): " TTL; \
	bash platform/create_env.sh "$$NAME" "$${TTL:-1800}"

destroy:
	bash platform/destroy_env.sh $(ENV)

logs:
	tail -f logs/$(ENV)/app.log

health:
	@for f in envs/*.json; do \
	  ID=$$(jq -r '.id' $$f); STATUS=$$(jq -r '.status' $$f); \
	  echo "$$ID => $$STATUS"; done

simulate:
	bash platform/simulate_outage.sh --env $(ENV) --mode $(MODE)

clean:
	rm -rf logs/* envs/* nginx/conf.d/*.conf
