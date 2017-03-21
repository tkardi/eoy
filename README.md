# eoy
Eesti otsib ühistransporti.

See on eestikeelne kokkuvõte but You can also [read me in English](README_EN.md)

# Eesmärk
Selle projekti eesmärgiks on pakkuda võimalust ühistranspordivahendite
kuvamiseks kaardil pseudo-reaalajas. Asukohad on arvutatavad [Maanteeameti GTFS](
https://transitfeeds.com/p/maanteeamet/510) [avaandmete](
https://www.mnt.ee/et/uhistransport/uhistranspordi-infosusteem) (või sarnaste)
andmete põhjal ning ei oma tegelikkuses mingisugust seost reaalse situatsiooniga.

Sellegipoolest võivad (veebi-)kaardikoostajatele huvi pakkuda just hetkel liikumas
olevate ühistranspordivahedite asukohad. Kuna tegu on arvutuslike, mitte GPS-põhiste
asukohtadega, siis ei sobi see kindlasti mõne kriitilise otsustusprotsessi osaks,
aga võib-olla on sellegipoolest huvitav busse-ronge mööda kaarti ringi
vuramas näha :)

Viimase ajahetke teadaolevad ühistranspordivahedite asukohad tagastakse veebi-API
HTTP GET päringu peale. Päringu vastuseks on [GeoJSONi spetsifikatsioonile](
https://datatracker.ietf.org/doc/rfc7946/) vastav `FeatureCollection`.

# Paigaldus
## Andmebaas
Eeldame PostgreSQL (9.4) / PostGIS (2.1) olemasolu. Käivita admin-kasutajana
andmebaasis [db/init.sql](db/init.sql). See loob andmebaasi `gtfs`-nimelise
schema ning sellesse hunniku tabeleid, mis vajalikud vajalike GTFS andmete
hoidmiseks (`gtfs.agency`, `gtfs.calendar`, `gtfs.routes`, `gtfs.shapes`,
`gtfs.stop_times`, `gtfs.stops`, `gtfs.trips`), ning mõned funktsioonid
aegade ja ruumikujudega ümberkäimiseks (`gtfs.get_current_impeded_time`,
`gtfs.get_time_fraction`, `public.split_line_multipoint`).

**NB! Enne käivitamist loe siiski läbi, mida see sql fail sisaldab. Terve
mõistus ei käivita oma andmebaasis suvalisi sql faile ;)**

Kui andmestruktuurid ja funktsioonid on andmedbaasis loodud, võib sisse
laadida andmed.

## Veebi-API
Kuid enne andmete laadimist paigalda Django (1.8 on LTS, suuremate versioonidega
pole käitatud), Django Rest Framework ja Django Rest Framework GIS. Django
olemasolu vajalik andmete laadimiseks. (miks?)

Need on paigaldatavad `pip`iga

`$ pip install django==1.8`

`$ pip install rest_framework`

`$ pip install rest_framework_gis`

## Andmete laadimine
Andmete laadimiseks vajalikud seadistused on kirjeldatud
[api/conf/settings.py](api/conf/settings.py) failis. Laadimiseks käivita
[api/sync/datasync.py](api/sync/datasync.py)

`$ python datasync.py`

_FIXME: siin on vaja lahti kirjeldada ka andmete eeltöötluseks vajalikud sammud.
Selleks vajalik kama on vaja db/init.sql failist ka välja tõsta (eraldi failiks,
mille saaks datasync.py kaudu käivitada? Või siis andmebaasi funktsiooniks?)._

Pane käima Django arendusserver

`$ python manage.py runserver`

ning suuna veebibrauser aadressile http://127.0.0.1:8000?format=json vastuseks
peaks tulema

`{"message":"Nobody expects the spanish inquisition!"}`

# Kasutusjuhised
HTTP GET päringud

### Hetkel sõidusolev ühistransport
http://127.0.0.1:8000/current/locations?format=json
Tagastab hetkel sõidusolevad ühistranspordi vahendid ja nende asukohad
koos eelnenud ja järgnevate peatuste ning liiniinfoga.

### Hetkel sõidusolevad marsruudid
http://127.0.0.1:8000/current/trips?format=json
Tagastab hetkel sõidusolevate marsruutide trajektoorid algpeatusest
lõpp-peatusesse.

### Veel midagi ???
_FIXME: lisa veel päringuid_


# Litsents
Selle projekti kood on vabalt kasutatav [Unlicense](http://unlicense.org) litsentsi
alusel. Kasutatavatel andmetel on oma kasutustingimused - jälgi neid ise. Antud
projekt andmeid endid ei jaga.
