from rest_framework_gis.serializers import GeoFeatureModelSerializer

from models import CurrentLocations

class LocationTableSerializer(GeoFeatureModelSerializer):
    class Meta:
        fields = ['trip_id', 'shape_id', 'trip_start_time',
            'trip_end_time', 'current_time',
            'prevstop_name', 'prevstop_depart',
            'nextstop_name', 'nextstop_arrive', 'trip_headsign',
            'trip_long_name', 'route_short_name', 'route_long_name',
            'route_color']
        model = CurrentLocations
        lookup_field = 'trip_id'
        geo_field = 'location'
