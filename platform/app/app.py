from flask import Flask, jsonify
import os

app = Flask(__name__)

@app.route("/")
def index():
    return f"Hello from env: {os.environ.get('SANDBOX_ENV_ID', 'unknown')}"

@app.route("/health")
def health():
    return jsonify({"status": "ok", "env": os.environ.get('SANDBOX_ENV_ID')})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
