# -*- coding: utf-8 -*-
DEBUG = True

SECRET_KEY = '<super_secret>'

ALLOWED_HOSTS = []

DB_USER = '<username>'
DB_PASSWORD = '<password>'
DB_NAME = '<dbname>'
SYNC_USER = '<sync_username>'
SYNC_PASSWORD = '<sync_password>'

DBTABLES = [
    'shapes',
    'stop_times',
    'trips',
    'stops',
    'routes',
    'calendar',
    'agency'
    ]
DBSCHEMA = 'gtfs'
