import requests
from collections import OrderedDict

url = 'https://opensky-network.org/api/states/all?lamin=57.48&lomin=21.6&lamax=59.82&lomax=28.52'
keys = ['icao24','callsign','origin_country','time_position','last_contact','longitude','latitude','baro_altitude','on_ground','velocity','true_track','vertical_rate','sensors','geo_altitude','squawk','spi','position_source']

def get_flight_radar_data():
    r = requests.get(url)
    r.raise_for_status()
    #return r.json()
    return _to_geojson(r.json())

def _to_geojson(data):
    f = [
        OrderedDict(
            type='Feature',
            id=ac[0],
            geometry=OrderedDict(type='Point', coordinates=[ac[5],ac[6]]),
            properties=OrderedDict(zip(keys, ac))
        ) for ac in data.get('states', [])
    ]

    return dict(
        type='FeatureCollection',
        features=f
    )
