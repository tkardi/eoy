import psycopg2
import json

from app.server.exceptions import ToHTTPError
from app.load_resources import settings

SQL_TEMPLATE = """select row_to_json(f.*)::jsonb from (select jsonb_agg(st_asgeojson(z.*)::jsonb)::jsonb as "features", 'FeatureCollection' as "type" from %s z) f"""
SQL_GET_LOCS = """gtfs.loctable_v2"""
SQL_GET_TRIPS = """(select t.*, s.shape as geom from gtfs.trips t, gtfs.calcshapes s where exists (select 1 from gtfs.loctable_v2 l where l.trip_id = t.trip_id) and s.shape_id = t.shape_id)"""


class AbstractTableRequestHandler(object):
    DATABASE_CONNECTION=None
    def __init__(self):
        self.partial_sql = None

    def get_data(self):
        if not self.DATABASE_CONNECTION or self.DATABASE_CONNECTION.closed == 1:
            try:
                self.DATABASE_CONNECTION = psycopg2.connect(**settings.DATABASE)
            except (Exception, psycopg2.Error) as error:
                raise ToHTTPError(
                    message=f"cannot connect to database",
                    status_code=500
                )
        with self.DATABASE_CONNECTION.cursor() as cur:
            sql = SQL_TEMPLATE % self.partial_sql
            cur.execute(sql)
            if not cur:
                raise ToHTTPError(
                    message=f"SQL query failed: {sql}",
                    status_code=404
                )
            return cur.fetchone()[0]

    def serve_request(self):
        try:
            return json.dumps(self.get_data())
        except ToHTTPError:
            raise
        except Exception as e:
            raise ToHTTPError(
                message=str(e),
                status_code=500
            )

class LocTableRequestHandler(AbstractTableRequestHandler):
    def __init__(self):
        self.partial_sql = SQL_GET_LOCS


class TripTableRequestHandler(AbstractTableRequestHandler):
    def __init__(self):
        self.partial_sql = SQL_GET_TRIPS
