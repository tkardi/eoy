# -*- coding: utf-8 -*-
from rest_framework import generics
from rest_framework.decorators import api_view
from rest_framework.response import Response

from models import CurrentLocations
import serializers

from proxy import flightradar as f
from proxy import traingps as t

# Create your views here.
@api_view(('GET', ))
def index(request, *args, **kwargs):
    """Yes-yes-yes,... I'm up and running."""
    return Response({"message":"Nobody expects the spanish inquisition!"})

class LocTableAsList(generics.ListAPIView):
    queryset = CurrentLocations.objects.all()
    serializer_class = serializers.LocationTableSerializer

@api_view(('GET', ))
def flightradar(request, *args, **kwargs):
    return Response(f.get_flight_radar_data())

@api_view(('GET', ))
def traingps(request, *args, **kwargs):
    return Response(t.get_train_gps_data())
