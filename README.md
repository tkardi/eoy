# eoy
Eesti otsib ühistransporti

Eesmärk
-------
Selle projekti eesmärgiks on pakkuda võimalust ühistranspordivahendite 
kuvamiseks kaardil pseudo-reaalajas. Asukohad on arvutatavad [Maanteeameti GTFS(
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

Kasutusjuhised
--------------
TODO

Paigaldus
---------
TODO

Andmete laadimine ja uuendamine
-------------------------------
TODO

Litsents
--------
Selle projekti kood on vabalt kasutatav [Unlicense](http://unlicense.org) litsentsi 
alusel. Kasutatavatel andmetel on oma kasutustingimused - jälgi neid ise. Antud 
projekt andmeid endid ei jaga.
