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

class CurrentLocations(models.Model):
    trip_id = models.IntegerField(
        primary_key=True)
    shape_id = models.IntegerField()
    trip_start_time = models.CharField(
        max_length=8, db_column='trip_start')
    trip_end_time = models.CharField(
        max_length=8, db_column='trip_fin')
    current_time = models.CharField(
        max_length=8, db_column='current_time')
    #prevstop_id = models.ForeignKey(
    #    'Stops', related_name='prevstop', db_column='prev_stop_id')
    prevstop_name = models.CharField(
        max_length=250, db_column='prev_stop')
    prevstop_depart = models.CharField(
        max_length=8, db_column='prev_stop_time')
    #prevstop_seq = models.IntegerField()
    #nextstop_id = models.ForeignKey(
    #    'Stops', related_name='nextstop', db_column='next_stop_id')
    nextstop_name = models.CharField(
        max_length=250, db_column='next_stop')
    nextstop_arrive = models.CharField(
        max_length=8, db_column='next_stop_time')
    #nextstop_seq = models.IntegerField()
    trip_headsign = models.CharField(max_length=250)
    trip_long_name = models.CharField(max_length=250)
    route_short_name = models.CharField(max_length=100)
    route_long_name = models.CharField(max_length=255)
    route_color = models.CharField(max_length=10)
    location = models.PointField(srid=4326, db_column='pos')

    class Meta:
        managed = False
        db_table = 'gtfs\".\"loctable_v2'


#class CurrentTrips(models.Model):
#
#    class Meta:
#        managed = False
#        db_table = 'gtfs\".\"calctrips'
