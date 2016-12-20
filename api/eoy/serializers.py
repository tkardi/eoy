from rest_framework_gis.serializers import GeoFeatureModelSerializer

from models import LocationTable

class LocationTableSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = LocationTable
        lookup_field = 'trip_id'
        geo_field = 'location'
