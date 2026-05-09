from flask import Flask, jsonify, request, abort
import subprocess, json, glob, os, time

app = Flask(__name__)

def load_env(env_id):
    path = f"envs/{env_id}.json"
    if not os.path.exists(path):
        abort(404, f"Env {env_id} not found")
    return json.load(open(path))

@app.post("/envs")
def create():
    data = request.json or {}
    name = data.get("name", "unnamed")
    ttl = data.get("ttl", 1800)
    result = subprocess.run(
        ["bash", "platform/create_env.sh", name, str(ttl)],
        capture_output=True, text=True
    )
    return jsonify({"output": result.stdout, "error": result.stderr}), 201

@app.get("/envs")
def list_envs():
    envs = []
    for f in glob.glob("envs/*.json"):
        e = json.load(open(f))
        e["ttl_remaining"] = max(0, (e["created_at"] + e["ttl"]) - int(time.time()))
        envs.append(e)
    return jsonify(envs)

@app.delete("/envs/<env_id>")
def destroy(env_id):
    load_env(env_id)
    subprocess.run(["bash", "platform/destroy_env.sh", env_id])
    return jsonify({"status": "destroyed"})

@app.get("/envs/<env_id>/logs")
def get_logs(env_id):
    load_env(env_id)
    log_path = f"logs/{env_id}/app.log"
    if not os.path.exists(log_path):
        return jsonify({"lines": []})
    with open(log_path) as f:
        lines = f.readlines()[-100:]
    return jsonify({"lines": lines})

@app.get("/envs/<env_id>/health")
def get_health(env_id):
    load_env(env_id)
    log_path = f"logs/{env_id}/health.log"
    if not os.path.exists(log_path):
        return jsonify({"checks": []})
    with open(log_path) as f:
        lines = f.readlines()[-10:]
    return jsonify({"checks": lines})

@app.post("/envs/<env_id>/outage")
def outage(env_id):
    load_env(env_id)
    mode = request.json.get("mode", "crash")
    subprocess.run(["bash", "platform/simulate_outage.sh", "--env", env_id, "--mode", mode])
    return jsonify({"status": f"simulation '{mode}' triggered"})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
