import json
import os

from flask import Flask, request, send_file, make_response
from flask import Response
from flask import jsonify
from flask_compress import Compress

from app.server.gtfs import LocTableRequestHandler
from app.server.gtfs import TripTableRequestHandler
from app.server.exceptions import ToHTTPError

app = Flask(__name__)
Compress(app)

app.config['COMPRESS_MIMETYPES'].append('application/json')

@app.errorhandler(ToHTTPError)
def handle_tohttperror(error):
    response = jsonify(error.to_dict())
    response.status_code = error.status_code
    response.headers = {'Access-Control-Allow-Origin':'*'}
    return response

@app.route("/")
def root():
    return Response(
        json.dumps({"message":"Nobody expects the Spanish inquisition!"}),
        mimetype='application/json',
        headers={
            'Access-Control-Allow-Origin':'*',
            'Content-Encoding':'UTF-8'
        }
    )

@app.route('/current/locations/')
def loc_table_request():
    return Response(
        LocTableRequestHandler().serve_request(),
        mimetype='application/json',
        headers={
            'Access-Control-Allow-Origin':'*',
            'Content-Encoding':'UTF-8'
        }
    )

@app.route('/current/trips/')
def trip_table_request():
    return Response(
        TripTableRequestHandler().serve_request(),
        mimetype='application/json',
        headers={
            'Access-Control-Allow-Origin':'*',
            'Content-Encoding':'UTF-8'
        }
    )

if __name__ == '__main__':
    app.run()
