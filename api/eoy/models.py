# -*- coding: utf-8 -*-
from django.contrib.gis.db import models

class Stops(models.Model):
    stop_id = models.IntegerField(primary_key=True)
    stop_name = models.CharField(max_length=250)
    stop_lat = models.DecimalField(max_digits=12, decimal_places=9)
    stop_lon = models.DecimalField(max_digits=12, decimal_places=9)

    class Meta:
        managed = False
        db_table = 'gtfs\".\"stops'

class LocationTable(models.Model):
    trip_id = models.IntegerField(primary_key=True)
    shape_id = models.IntegerField()
    trip_start_time = models.CharField(max_length=8, db_column='strt')
    trip_end_time = models.CharField(max_length=8, db_column='fin')
    current_time = models.CharField(max_length=8, db_column='cur')
    prevstop_id = models.ForeignKey(
        'Stops', related_name='prevstop', db_column='prevstop_id')
    prevstop_name = models.CharField(max_length=250)
    prevstop_depart = models.CharField(max_length=8)
    prevstop_seq = models.IntegerField()
    nextstop_id = models.ForeignKey(
        'Stops', related_name='nextstop', db_column='nextstop_id')
    nextstop_name = models.CharField(max_length=250)
    nextstop_arrive = models.CharField(max_length=8)
    nextstop_seq = models.IntegerField()
    trip_headsign = models.CharField(max_length=250)
    trip_long_name = models.CharField(max_length=250)
    route_short_name = models.CharField(max_length=100)
    route_color = models.CharField(max_length=10)
    location = models.PointField(srid=4326, db_column='pos')

    class Meta:
        managed = False
        db_table = 'gtfs\".\"loctable'
