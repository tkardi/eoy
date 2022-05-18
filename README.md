# eoy
Estonia looking for public transit.

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

An example "real-time dashboard"-style preview can be checked out [here](
https://tkardi.github.io/eoy/example/current.html)

The name of the project is a word play on an Estonian television talent show
title.

# How to get up and running
The process of getting this thing up and running is currently a bit tedious,
but we'll live with that for now.

## Database
Expects presence of PostgreSQL (9.4+) / PostGIS (2.1+). As a privileged user run
[db/init.sql](db/init.sql). This will create a database schema called `gtfs`,
a few tables into it (`gtfs.agency`, `gtfs.calendar`, `gtfs.routes`,
`gtfs.shapes`, `gtfs.stop_times`, `gtfs.stops`, `gtfs.trips`) and three
functions for dealing with location calculation (`gtfs.get_current_impeded_time`,
`gtfs.get_time_fraction`, `public.split_line_multipoint`). Credit for the
last function goes to [rcoup](http://gis.stackexchange.com/users/564/rcoup)'s
[StackExchange answer](http://gis.stackexchange.com/a/112317). With PostGIS 2.2
this function will not be necessary anymore and `st_split(geometry, geometry)`
can be used instead.

**NOTE:** Tested also on PostgreSQL 14 / PostGIS 3.2 and seems to be running
fine (@tkardi, 18.05.2022)

**NB! Before running the sql file, please read carefully what it does. A sane
mind should not run whatever things in a database ;)**

Once the database tables and functions have been set up, data can be inserted.

## web API
Is based on Flask (Used to be Django, but not any more).

### Configuration
Configuration is loaded in the following order:
- [resources/global.params.json](/src/resources/global.params.json): this should
contain all app specific settings, regardless of the env we're running in.
- [resources/environment/${APP_ENV}.params.json](/src/resources/environment/dev.params.json):
should contain all environment specific configuration (like db connection params).
The file will selected based on the available `APP_ENV` environment variable
value (case does not matter), and will default to `DEV` if not set. So if you
call your environment `THIS-IS-IT`, then be sure to have a file called
`resources/environment/this-is-it.params.json` present aswell.
- Override parameters should be mounted to `/main/app/resources/override` path.
Expected filename is `params.json`.

Missing any of these files will not raise an exception during configuration
loading but may hurt afterwards when a specific value that is needed is not
found.

### Using Docker engine for web API
The Flask app maybe run manually in terminal but the least-dependency-hell-way
seems to be via docker (official latest python:3 image). In the project root
(assuming your database connection is correctly configured in
[resources/environment/dev.params.json](/src/resources/dev.params.json)):

```
$ source build.sh
  [..]
Successfully tagged localhost/eoy:latest
$ docker run -it --rm --network=host -e APP_ENV=DEV --name eoy localhost/eoy:latest
* Serving Flask app 'server' (lazy loading)
* Environment: production
  WARNING: This is a development server. Do not use it in a production deployment.
  Use a production WSGI server instead.
* Debug mode: off
* Running on http://127.0.0.1:5000 (Press CTRL+C to quit)
  [..]
```

## Loading data
The configuration that is necessary for loading the data is described in
[api/conf/settings.py](api/conf/settings.py). To start the loading procedure
you need to run [api/sync/datasync.py](api/sync/datasync.py)

`$ python datasync.py`

And after the loading has finished, again, as a privileged user run
[db/preprocess.sql](db/preprocess.sql). Then we can fire up Django's
development server with

`$ python manage.py runserver`

Point your browser to http://127.0.0.1:5000/ and you should see a
response:

`{"message":"Nobody expects the spanish inquisition!"}`

# How to
HTTP GET queries

### Current locations
http://127.0.0.1:5000/current/locations/
Returns currently active vehicles and their locations together
with data on previous and next stops, and routes.

### Current trips
http://127.0.0.1:5000/current/trips/
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
