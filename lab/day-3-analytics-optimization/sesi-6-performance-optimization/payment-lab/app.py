import os
import random
import time

from flask import Flask, jsonify, request
from elasticapm.contrib.flask import ElasticAPM

app = Flask(__name__)
app.config["ELASTIC_APM"] = {
    "SERVICE_NAME": "payment-lab",
    "SERVER_URL": os.getenv("ELASTIC_APM_SERVER_URL", "http://apm-server:8200"),
    "ENVIRONMENT": os.getenv("ELASTIC_APM_ENVIRONMENT", "training"),
}
apm = ElasticAPM(app)


@app.route("/pay/<order_id>", methods=["POST"])
def pay(order_id):
    # Simulasi pemanggilan payment gateway pihak ketiga yang lambat.
    # ?degraded=1 mensimulasikan gateway yang SEDANG bermasalah --
    # tanpa parameter ini, delay tetap normal 0.6 detik seperti semula.
    if request.args.get("degraded") == "1":
        time.sleep(random.uniform(2.5, 3.5))
    else:
        time.sleep(0.6)
    return jsonify({"order_id": order_id, "status": "approved"})


@app.route("/health")
def health():
    return "OK"


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
