/** Some tuning/preprocessing. These will have to be wrapped either
* in a db function (so we can call it from datasync.py)
* or alternatively save as plaintext files and let datasync.py
* read them (it) and then execute in a transaction after data sync
* has taken place.
*/


-- drop previous
drop view if exists gtfs.loctable_v2;
drop table if exists gtfs.calcshapes;
drop table if exists gtfs.calcstopnodes;
drop table if exists gtfs.calctrips;

-- and create anew

/** table: gtfs.calcshapes
*
* A table for storing full trip shapes (linestrings) and
* collected nodes, which we'll use afterwards for "snapping"
* stops onto trip shapes.
*/


create table gtfs.calcshapes as
select
    shape_id, st_makeline(array_agg(shape)) as shape,
    st_collect(shape) as nodes
from (
    select
        s.shape_id, st_setsrid(st_makepoint(s.shape_pt_lon, s.shape_pt_lat), 4326) as shape
    from
        gtfs.shapes s
    order by s.shape_id, s.shape_pt_sequence) n
group by shape_id
order by shape_id;

alter table gtfs.calcshapes
    add constraint pk__calcshapes primary key (shape_id);
create index sidx__calcshapes
    on gtfs.calcshapes using gist (shape);
create index sidx__calcshapes_nodes
    on gtfs.calcshapes using gist (shape);
alter table gtfs.calcshapes owner to postgres;


/** table: gtfs:calcstopnodes
*
* Stores closest nodes on trip shapes to respective stops.
*/


create table gtfs.calcstopnodes as
select
    shape_id, st_multi(st_collect(stop_node)) as stop_nodes,
    trip_id, array_agg(stop_seq) as stop_seq
from (
    select
        s.shape_id,
        st_closestpoint(s.nodes, st_setsrid(
            st_point(stops.stop_lon, stops.stop_lat), 4326)) as stop_node,
        t.trip_id, st.stop_sequence as stop_seq
    from
        gtfs.calcshapes s,
        gtfs.stop_times st,
        gtfs.trips t,
        gtfs.stops stops
    where
        st.stop_id = stops.stop_id and
        st.trip_id = t.trip_id and
        s.shape_id = t.shape_id
    order by s.shape_id, t.trip_id, st.stop_sequence) m
group by shape_id, trip_id;

alter table gtfs.calcstopnodes
    add constraint pk__calcstopnodes primary key (trip_id);
create index sidx__calcstopnodes
    on gtfs.calcstopnodes using gist (stop_nodes);
alter table gtfs.calcstopnodes owner to postgres;


/** table: gtfs.calctrips
*
* Break trip shapes up into shorter linestrings based on stops (i.e
* "trip shape closest nodes to stops"). Call these "trip legs".
* A trip leg starts at gtfs.stop_times.departure_time and ends at
* gtfs.stop_times.arrival_time.
*/


create table gtfs.calctrips as
with
    splits as (
        select
            cs.shape_id, sn.trip_id,
            sn.stop_seq,
            (st_dump(split_line_multipoint(cs.shape, sn.stop_nodes))).*
        from
            gtfs.calcshapes cs,
            gtfs.calcstopnodes sn
        where
            cs.shape_id = sn.shape_id
    ),
    inbetween as (
        select
            splits.shape_id, splits.trip_id,
            splits.stop_seq[splits.path[1]] as from_stop,
            splits.stop_seq[splits.path[1]+1] as to_stop,
            splits.geom as shape
        from splits
    ),
    triptimes as (
        select
            trip_id, min(departure_time) as trip_start,
            max(arrival_time) as trip_fin
        from gtfs.stop_times
        group by trip_id
    )
select
    inbetween.shape_id, inbetween.trip_id, inbetween.shape,
    triptimes.trip_start, triptimes.trip_fin,
    inbetween.from_stop as from_stop_seq,
    from_stops.stop_id as from_stop_id,
    from_stops.departure_time as from_stop_time,
    inbetween.to_stop as to_stop_seq,
    to_stops.stop_id as to_stop_id,
    to_stops.arrival_time as to_stop_time
from
    inbetween,
    gtfs.stop_times from_stops,
    gtfs.stop_times to_stops,
    triptimes
where
    inbetween.trip_id = from_stops.trip_id and
    inbetween.trip_id = to_stops.trip_id and
    inbetween.from_stop = from_stops.stop_sequence and
    inbetween.to_stop = to_stops.stop_sequence and
    triptimes.trip_id = inbetween.trip_id
order by inbetween.trip_id, inbetween.from_stop;

--alter table gtfs.calctrips add constraint pk__calcstopnodes primary key (trip_id);
create index sidx__calctrips
    on gtfs.calctrips using gist (shape);
alter table gtfs.calctrips owner to postgres;


/** view: gtfs.loctable_v2
*
* Estimated locations of currently running public transport. This
* is the view that will be queried for current location of public transit
* vehicles.
*/


create or replace view gtfs.loctable_v2 as
with
    curtime as (
        select
            clock_timestamp()::date AS cd,
            to_char(clock_timestamp(), 'hh24:mi:ss'::text) AS ct,
            date_part('dow'::text, clock_timestamp()) + 1 AS d,
            lpad((to_char(clock_timestamp(), 'hh24')::int + 24)::varchar,2,'0')||':'||to_char(clock_timestamp(), 'mi:ss') as plushours
    ),
    cal as (
        select
            c.service_id
        from
            gtfs.calendar c,
            curtime
        where
            curtime.cd >= c.start_date and
            curtime.cd <= c.end_date and
            (array[
                c.monday,
                c.tuesday,
                c.wednesday,
                c.thursday,
                c.friday,
                c.saturday,
                c.sunday])[curtime.d] = true
        ),
        startstop as (
            select
                calctrips.trip_id, calctrips.from_stop_time as leg_start,
                calctrips.to_stop_time as leg_fin, calctrips.from_stop_id,
                calctrips.to_stop_id, calctrips.from_stop_seq,
                calctrips.to_stop_seq, calctrips.shape,
                calctrips.trip_start, calctrips.trip_fin
            from
                gtfs.calctrips, curtime
            where
                (
                    curtime.ct >= calctrips.from_stop_time::text and
                    curtime.ct <= calctrips.to_stop_time::text
                ) or (
                    curtime.plushours >= calctrips.from_stop_time::text and
                    curtime.plushours <= calctrips.to_stop_time::text
                )
        ),
        trip as (
            select
                startstop.trip_id, trips.shape_id,
                startstop.trip_start, startstop.trip_fin,
                startstop.leg_start, startstop.leg_fin,
                curtime.ct as cur, trips.trip_headsign,
                trips.trip_long_name, routes.route_short_name,
                routes.route_long_name, routes.route_color,
                startstop.from_stop_id, startstop.to_stop_id,
                startstop.from_stop_seq, startstop.to_stop_seq,
                startstop.shape
            from
                cal, curtime, startstop, gtfs.trips trips, gtfs.routes routes
            where
                trips.trip_id = startstop.trip_id and
                trips.service_id = cal.service_id and
                trips.route_id::text = routes.route_id::text
        )
select
    trip.trip_id, trip.shape_id, trip.trip_start, trip.trip_fin,
    trip.trip_headsign, trip.trip_long_name, trip.route_short_name,
    trip.route_long_name,
    tostop.stop_id as next_stop_id,
    tostop.stop_name as next_stop,
    trip.leg_fin as next_stop_time,
    fromstop.stop_id as prev_stop_id,
    fromstop.stop_name as prev_stop,
    trip.leg_start as prev_stop_time,
    curtime.ct as current_time,
    '#'::text || trip.route_color::text as route_color,
    /* @tkardi 09.11.2021 st_flipcoordinates to quickly get API geojson
       coors order correct. FIXME: should be a django version gdal version thing.
    */
    st_flipcoordinates(
        st_lineinterpolatepoint(
            trip.shape,
            gtfs.get_time_fraction(
                trip.leg_start,
                trip.leg_fin,
                gtfs.get_current_impeded_time(
                    trip.leg_start,
                    trip.leg_fin,
                    trip.cur::character varying
                )
            )
        )
    ) as pos
from curtime, trip
    left join gtfs.stops tostop on trip.to_stop_id = tostop.stop_id
    left join gtfs.stops fromstop on trip.from_stop_id = fromstop.stop_id;

alter table gtfs.loctable_v2 owner to postgres;
