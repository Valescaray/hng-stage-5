import os, time, json, requests, glob
from datetime import datetime

FAIL_THRESHOLD = 3
fail_counts = {}

def poll():
    for f in glob.glob("envs/*.json"):
        env = json.load(open(f))
        env_id = env["id"]
        port = env["port"]
        url = f"http://localhost:{port}/health"

        start = time.time()
        try:
            r = requests.get(url, timeout=5)
            status = r.status_code
            latency = round((time.time() - start) * 1000, 2)
            fail_counts[env_id] = 0
        except Exception:
            status = 0
            latency = -1
            fail_counts[env_id] = fail_counts.get(env_id, 0) + 1

        ts = datetime.now().isoformat()
        log_line = f"{ts} | status={status} | latency={latency}ms\n"
        os.makedirs(f"logs/{env_id}", exist_ok=True)
        with open(f"logs/{env_id}/health.log", "a") as lf:
            lf.write(log_line)

        if fail_counts.get(env_id, 0) >= FAIL_THRESHOLD:
            print(f"[WARNING] {env_id} is DEGRADED ({FAIL_THRESHOLD} consecutive failures)")
            # Update status in state file
            env["status"] = "degraded"
            with open(f, "w") as sf:
                json.dump(env, sf, indent=2)

while True:
    poll()
    time.sleep(30)
