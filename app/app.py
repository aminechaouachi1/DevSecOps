import hashlib

from flask import Flask, jsonify, request

app = Flask(__name__)


@app.get("/")
def index():
    return "DevSecOps demo app - OK"


@app.get("/health")
def health():
    return jsonify(status="ok")


@app.get("/hash")
def hash_password():
    # Faiblesse volontaire (MD5) : Semgrep (phase 1) doit la detecter.
    pw = request.args.get("pw", "")
    return jsonify(md5=hashlib.md5(pw.encode()).hexdigest())


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
