# eoy
Estonia looking for public transit.

This is a summary in English, kuid võid vabalt lugeda ka
[eestikeelsena seda sama juttu](README.md)

# Purpose
The purpose of this project is to offer a possibility for tracking
public transit vehicles in "pseudo-real-time". The locations are
calculated from [the Estonian Road Administration's compiled GTFS static](
https://transitfeeds.com/p/maanteeamet/510) [open data](
https://www.mnt.ee/eng/public-transportation/public-transport-information-system)
(or similar time-table data) and have no meaning whatsoever in reality.

Nevertheless (web-)map-makers might be interested in the current whereabouts of
public transit at any given time. As these locations are based on calculations
not GPS data they should under no circumstances be used as part of a critical
decision process. But maybe it's still interesting to see buses-trains rattle
along on the map.

Current locations are returned as a [GeoJSON](
https://datatracker.ietf.org/doc/rfc7946/) `FeatureCollection` using a HTTP GET
query to the web API.

The name of the project is a word play on an Estonian television talent show
title.

# How to get up and running
The process of getting this thing up and running is currently a bit tedious,
but we'll live with that for now.

## Database
Expect presence of PostgreSQL (9.4) / PostGIS (2.1). As a privileged user run
[db/init.sql](db/init.sql). This will create a database schema called `gtfs`,
a few tables into it (`gtfs.agency`, `gtfs.calendar`, `gtfs.routes`,
`gtfs.shapes`, `gtfs.stop_times`, `gtfs.stops`, `gtfs.trips`) and three
functions for dealing with location calculation (`gtfs.get_current_impeded_time`,
`gtfs.get_time_fraction`, `public.split_line_multipoint`). Credit for the
last function goes to [rcoup](http://gis.stackexchange.com/users/564/rcoup)'s
[StackExchange answer](http://gis.stackexchange.com/a/112317). With PostGIS 2.2
this function will not be necessary anymore and `st_split(geometry, geometry)`
can be used instead.

**NB! Before running the sql file, please read carefully what it does. A sane
mind should not run whatever things in a database ;)**

Once the database tables and functions have been set up, data can be inserted.

## web API
But still, before data can be loaded to the database, Django (1.8 is the
current LTS version), Django Rest Framework ja Django Rest Framework GIS
should be installed. We need Django for data loading as we'll use Django's
db connection factory.

You can simply `pip` them

`$ pip install django==1.8`

`$ pip install rest_framework`

`$ pip install rest_framework_gis`

## Loading data
The configuration that is necessary for loading the data is described in
[api/conf/settings.py](api/conf/settings.py). To start the loading procedure
you need to run [api/sync/datasync.py](api/sync/datasync.py)

`$ python datasync.py`

_FIXME: describe the necessary steps for data pre-processing. We need to move
all pre-processing activities from db/init.sql aswell (a separate file that
we could execute from datasync.py? or a function in the database?)_

Start up Django's development server with

`$ python manage.py runserver`

Point your browser to http://127.0.0.1:8000?format=json and you should see a
response:

`{"message":"Nobody expects the spanish inquisition!"}`

# How to
HTTP GET queries

### Current locations
http://127.0.0.1:8000/current/locations?format=json
Returns currently active vehicles and their locations together
with data on previous and next stops, and routes.

### Current trips
http://127.0.0.1:8000/current/trips?format=json
Returns currently active trips as linestrings from the first stop of the
trip to the last.

### something else ???
_FIXME: more queries?_

# License
The code for this project is freely usable under the [Unlicense](
http://unlicense.org). The data it uses has it's own license terms - you need to
keep track of that yourself.
_FIXME: need to set things straight with `public.split_line_multipoint` -
this is work done by somebody else! Can we use it at all?_
