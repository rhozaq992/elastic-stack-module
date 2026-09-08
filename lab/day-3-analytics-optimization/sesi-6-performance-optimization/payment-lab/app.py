import time

from flask import Flask, jsonify

app = Flask(__name__)


@app.route("/pay/<order_id>", methods=["POST"])
def pay(order_id):
    # Simulasi pemanggilan payment gateway pihak ketiga yang lambat.
    time.sleep(0.6)
    return jsonify({"order_id": order_id, "status": "approved"})


@app.route("/health")
def health():
    return "OK"


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
