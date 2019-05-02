import requests
from collections import OrderedDict


class FlightRadar(object):
    def __init__(self, *args, **kwargs):
        self.url = 'https://opensky-network.org/api/states/all?lamin=57.48&lomin=21.6&lamax=59.82&lomax=28.52'
        self.keys = [
            'icao24','callsign','origin_country','time_position',
            'last_contact','longitude','latitude','baro_altitude',
            'on_ground','velocity','true_track','vertical_rate','sensors',
            'geo_altitude','squawk','spi','position_source'
        ]

    def get_flight_radar_data(self):
        r = requests.get(self.url)
        r.raise_for_status()
        return self._to_geojson(r.json())

    def _to_geojson(self, data):
        f = [
            OrderedDict(
                type='Feature',
                id=ac[0],
                geometry=OrderedDict(type='Point', coordinates=[ac[5],ac[6]]),
                properties=OrderedDict(zip(self.keys, ac))
            ) for ac in data.get('states', [])
        ]

        return dict(
            type='FeatureCollection',
            features=f
        )

class TrainGPS(object):
    def __init__(self, *args, **kwargs):
        self.url = 'http://elron.ee/api/v1/map'

    def _to_float(self, string):
        try:
            return float(string)
        except:
            return string

    def get_train_gps_data(self):
        r = requests.get(self.url)
        r.raise_for_status()
        return self._to_geojson(r.json())

    def _to_geojson(self, data):
        f = [
            OrderedDict(
                type='Feature',
                id=ac['reis'],
                geometry=OrderedDict(type='Point', coordinates=[
                    self._to_float(ac.get('longitude', "0")),
                    self._to_float(ac.get('latitude', "0"))]
                ),
                properties=OrderedDict(ac.copy())
            ) for ac in data.get('data', [])
        ]

        return dict(
            type='FeatureCollection',
            features=f
        )

flightradar = FlightRadar()
traingps = TrainGPS()
