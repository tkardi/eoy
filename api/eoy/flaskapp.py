import json
from flask import Flask
from flask import Response

from proxy import flightradar
from proxy import traingps



app = Flask(__name__)

@app.route('/flightradar')
def flightradar_get():
    return Response(
        response=json.dumps(flightradar.get_flight_radar_data()),
        status=200,
        mimetype='application/json'
    )

@app.route('/traingps')
def traingps_get():
    return Response(
        response=json.dumps(traingps.get_train_gps_data()),
        status=200,
        mimetype='application/json'
    )
