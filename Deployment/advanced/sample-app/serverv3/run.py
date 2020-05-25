from flask import Flask
from flask import request
from datetime import datetime, date
import time
import socket

app = Flask(__name__)


t0= time.time()



@app.route("/api/v1/time", methods=["GET"])
def test():
    uptime = time.time() - t0
    now = datetime.now()
    current_time = now.strftime("%H:%M:%S")
    if (uptime > 12):
        return {"version": 3, "time": current_time, "hostname": socket.gethostname(), "uptime": uptime}, 500
    return {"version": 3, "time": current_time, "hostname": socket.gethostname(), "uptime": uptime}, 200

