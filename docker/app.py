from flask import Flask, jsonify

app = Flask(__name__)

@app.route("/")
def index():
    return jsonify(status="ok", service="demo-app")

@app.route("/healthz")
def healthz():
    return jsonify(status="healthy")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
