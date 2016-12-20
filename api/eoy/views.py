# -*- coding: utf-8 -*-
from rest_framework import generics
from rest_framework.decorators import api_view
from rest_framework.response import Response

from models import LocationTable
import serializers

# Create your views here.
@api_view(('GET', ))
def index(request, *args, **kwargs):
    """Yes-yes-yes,... I'm up and running."""
    return Response({"message":"Nobody expects the spanish inquisition!"})

class LocTableAsList(generics.ListAPIView):
    queryset = LocationTable.objects.all()
    serializer_class = serializers.LocationTableSerializer
