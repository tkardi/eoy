# -*- coding: utf-8 -*-
from rest_framework import generics
from rest_framework.decorators import api_view
from rest_framework.response import Response

from eoy.models import CurrentLocations
from eoy import serializers

from eoy.proxy import flightradar as f
from eoy.proxy import traingps as t

# Create your views here.
@api_view(('GET', ))
def index(request, *args, **kwargs):
    """Yes-yes-yes,... I'm up and running."""
    return Response({"message":"Nobody expects the spanish inquisition!"})

class LocTableAsList(generics.ListAPIView):
    model = CurrentLocations
    queryset = model.objects.all()
    serializer_class = serializers.LocationTableSerializer

    def get_fields_for_model(self):
        return self.model._meta.get_fields()

    def get(self, request, *args, **kwargs):
        if request.accepted_renderer.format == 'html':
            data = {
                'data' : self.get_queryset(),
                'fields': dict((field.name, field.get_internal_type()) for field in self.get_fields_for_model())
            }
            return Response(data, template_name='list_rows.html')
        return super(LocTableAsList, self).get(request, *args, **kwargs)

@api_view(('GET', ))
def flightradar(request, *args, **kwargs):
    return Response(f.get_flight_radar_data())

@api_view(('GET', ))
def traingps(request, *args, **kwargs):
    return Response(t.get_train_gps_data())
