from flask import Flask
from flask import request
from datetime import datetime, date
import socket

app = Flask(__name__)


@app.route("/api/v1/time", methods=["GET"])
def test():
    now = datetime.now()
    current_time = now.strftime("%H:%M:%S")
    return {"version": 1, "time": current_time, "hostname": socket.gethostname()}, 200

