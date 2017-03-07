create schema gtfs authorization postgres;
comment on schema gtfs is 'Schema for GTFS data';

/* Tables */

create table if not exists gtfs.agency (
    agency_id integer,
    agency_name character varying(250),
    agency_url character varying(250),
    agency_timezone character varying(100),
    agency_phone character varying(100),
    agency_lang character varying(3)
);

alter table gtfs.agency owner to postgres;
alter table gtfs.agency add constraint 
    pk__agency primary key (agency_id);


create table if not exists gtfs.calendar(
    service_id integer,
    monday boolean,
    tuesday boolean,
    wednesday boolean,
    thursday boolean,
    friday boolean,
    saturday boolean,
    sunday boolean,
    start_date date,
    end_date date
);
alter table gtfs.calendar owner to postgres;
alter table gtfs.calendar add constraint 
    pk__calendar primary key (service_id);


create table if not exists gtfs.routes(
    route_id character varying(32),
    agency_id integer,
    route_short_name character varying(100),
    route_long_name character varying(250),
    route_type smallint,
    route_color character varying(10),
    competent_authority character varying(100)
);
alter table gtfs.routes owner to postgres;
alter table gtfs.routes add constraint 
    pk__routes primary key (route_id);
--alter table gtfs.routes add constraint
--    fk__routes__agency foreign key (agency_id) references gtfs.agency (agency_id)
--    on update cascade on delete no action
--    deferrable initially deferred;


create table if not exists gtfs.shapes(
    shape_id integer,
    shape_pt_lat numeric,
    shape_pt_lon numeric,
    shape_pt_sequence smallint
);
alter table gtfs.shapes owner to postgres;
create unique index uidx__shapes on gtfs.shapes (shape_id, shape_pt_sequence);

create table if not exists gtfs.stops (
    stop_id integer,
    stop_code character varying(100),
    stop_name character varying(250),
    stop_lat numeric,
    stop_lon numeric,
    zone_id integer,
    alias character varying(250),
    stop_area character varying(250),
    stop_desc character varying(250),
    lest_x numeric,
    lest_y numeric,
    zone_name character varying(250)
);
alter table gtfs.stops owner to postgres;
alter table gtfs.stops add constraint
    pk__stops primary key (stop_id);


create table if not exists gtfs.trips (
    route_id character varying(32),
    service_id integer,
    trip_id integer,
    trip_headsign character varying(250),
    trip_long_name character varying(250),
    direction_code character varying(10),
    shape_id integer,
    wheelchair_accessible boolean
);
alter table gtfs.trips owner to postgres;


create table if not exists gtfs.stop_times(
    trip_id integer,
    arrival_time character varying(8),
    departure_time character varying(8),
    stop_id integer,
    stop_sequence smallint,
    pickup_type smallint,
    drop_off_type smallint
);
alter table gtfs.stop_times owner to postgres;
--alter table gtfs.stop_times add constraint
--    fk__stop_times__stops foreign key (stop_id) references gtfs.stops (stop_id)
--    on update cascade on delete no action
--    deferrable initially deferred;



create or replace function gtfs.get_time_fraction(
	trip_start varchar, trip_fin varchar, curtime varchar) 
returns numeric as
$$
declare 
	a_cur varchar[];
	a_strt varchar[];
	a_fin varchar[];
	strt time;
	fin interval;
	totalsecs numeric;
	fractionsecs numeric;
begin
	a_fin := string_to_array(trip_fin, ':');
	a_strt := string_to_array(trip_start, ':');
	a_cur := string_to_array(curtime, ':');
	if a_fin[1]::smallint >= 24 then
		fin := ((a_fin[1]::smallint - 24)::varchar||':'||(a_fin)[2]||':'||(a_fin)[3])::time;
		totalsecs := extract(epoch from (('24:00:00'::time - trip_start::time) + fin));
	else
		totalsecs := extract(epoch from trip_fin::time - trip_start::time);
	end if;

	if a_cur[1]::smallint < a_strt[1]::smallint then
		fin := '24:00:00'::time - trip_start::time;
		fractionsecs := extract(epoch from (curtime::time + fin));
	else
		fractionsecs := extract(epoch from curtime::time - trip_start::time);
	end if;
--	raise notice 'Fraction %', fractionsecs;
--	raise notice 'Total %', totalsecs;
return fractionsecs::numeric / totalsecs::numeric;
end;
$$
language plpgsql
security invoker;
alter function gtfs.get_time_fraction(varchar, varchar, varchar) owner to postgres;
comment on function gtfs.get_time_fraction(varchar, varchar, varchar) is 'Calculates the relative fraction that current time represents in between start and finish timestamps.';


/*
------------------------------------------------------------------
-- TESTS fro gtfs.get_time_fraction (varchar, varchar, varchar) --
------------------------------------------------------------------


select f.*, gtfs.get_time_fraction (f.str, f.fin, f.cur) as fraction, gtfs.get_time_fraction (f.str, f.fin, f.cur) = f.expected as test 
from (
select '23:00:00' as str, '24:00:00' as fin, '23:01:00' as cur, 1::numeric/60::numeric as expected
union all
select '23:00:00', '24:00:00', '23:30:00', 0.5
union all
select '23:00:00', '25:00:00', '00:30:00', 0.75
union all
select '23:00:00', '23:01:00', '23:01:00', 1.0
union all
select '23:00:00', '23:01:00', '23:00:00', 0.0
) f;
*/


create or replace function gtfs.get_current_impeded_time(
	laststop varchar, nextstop varchar, curtime varchar, 
	stoptime integer default 10, acctime integer default 10)
returns varchar as 
$$
declare
	a_cur varchar[];
	a_prev varchar[];
	a_next varchar[];
	prv numeric;
	nxt numeric;
	cur numeric;
	dt numeric;
	X numeric;
	M numeric;
	nxt_nextday boolean;
	prv_nextday boolean;
begin
	a_cur := string_to_array(curtime, ':');
	a_prev := string_to_array(laststop, ':');
	a_next := string_to_array(nextstop, ':');

	if a_cur[1]::smallint < a_prev[1]::smallint then
		-- means curtime is past midnight
		cur := extract(epoch from '24:00:00'::time) + extract(epoch from curtime::time);
	else
		-- we are still in the same day as previous stop was
		cur := extract(epoch from curtime::time);
	end if;

	if a_prev[1]::smallint >= 24 then
		-- previous stop was in fact tomorrow
		prv := extract(epoch from '24:00:00'::time) + extract(epoch from ((a_prev[1]::smallint - 24)::varchar||':'||(a_prev)[2]||':'||(a_prev)[3])::time);
		prv_nextday := true;
	else
		-- previous stop was today
		prv := extract(epoch from laststop::time);
		prv_nextday := false;
	end if; 

	if a_next[1]::smallint >= 24 then
		-- next stop will be tomorrow
		nxt := extract(epoch from '24:00:00'::time) + extract(epoch from ((a_next[1]::smallint - 24)::varchar||':'||(a_next)[2]||':'||(a_next)[3])::time);
		nxt_nextday := true;
	else
		-- next stop will be today
		nxt := extract(epoch from nextstop::time);
		nxt_nextday := false;
	end if;

	/* Check whether we are currently: a. stopped, b. speeding up, c. slowing down, d. going full speed */
	if (cur - prv < stoptime) then
		-- stop at the prev station ->> return time at previous station as current time, 
		-- but check whether hours are correct and justify
		if prv_nextday = false then
			return laststop;
		else
			return ((a_prev[1]::smallint - 24)::varchar||':'||(a_prev)[2]||':'||(a_prev)[3])::time::varchar;
		end if;
	elsif (nxt - cur < stoptime) then
		-- stop at the next station ->> return time at next station as current time, 
		-- but check whether hours are correct and justify
		if nxt_nextday = false then
			return nextstop;
		else
			return ((a_next[1]::smallint - 24)::varchar||':'||(a_next)[2]||':'||(a_next)[3])::time::varchar;
		end if;
	elsif ((cur - prv) < (stoptime + acctime)) then
		-- gathering speed ->> return time with 1:1 ratio
		dt := prv + (tan(radians(45)) * (cur - prv - stoptime));
	elsif ((nxt - cur) < (stoptime + acctime)) then
		-- slowing down ->> return time with 1:1 ratio
		X := nxt - prv;
		dt := nxt - (tan(radians(45)) * (nxt - cur - stoptime));
	else
		-- doing full speed ->> return whatever timespan we need to cover
		X := nxt - prv;
		M := acctime + stoptime;
		dt := ((X - 2 * acctime)::numeric / (X - 2 * M)::numeric) * (cur - prv - M)::numeric;
		dt := prv + acctime + dt;
	end if;
	return (timestamp 'epoch' + dt * interval '1 second')::time::varchar;
end;
$$
language plpgsql
security invoker;
alter function gtfs.get_current_impeded_time(varchar, varchar, varchar, integer, integer) owner to postgres;
comment on function gtfs.get_current_impeded_time(
	varchar, varchar, varchar, integer, integer
) is 'Calculates current "impeded time" based on last and next stoptimes and current real time as described in https://github.com/tkardi/eoy/issues/2';


/*

------------------------------------------------------------------
-- TESTS fro gtfs.get_current_impeded_time (varchar, varchar, varchar, integer, integer) --
------------------------------------------------------------------

select t.*, gtfs.get_current_impeded_time(t.strt, t.fin, t.cur, 10, 10), 
gtfs.get_current_impeded_time(t.strt, t.fin, t.cur, 10, 10) = t.expected as test
from (
	select 
		'23:59:30'::varchar as strt, 
		'24:00:30'::varchar as fin, 
		'stopped' as state,
		('23:59:'||lpad(generate_series(30, 39)::varchar, 2, '0' ))::varchar as cur,
		'23:59:30'::varchar as expected
union all
	select 
		'23:59:30'::varchar as strt, 
		'24:00:30'::varchar as fin, 
		'accelerating' as state,
		('23:59:'||lpad(generate_series(40, 49)::varchar, 2, '0' ))::varchar as cur,
		('23:59:'||lpad(generate_series(30, 39)::varchar, 2, '0' ))::varchar as expected
union all
	select 
		'23:59:30'::varchar as strt, 
		'24:00:30'::varchar as fin, 
		'fullspeed day 1' as state,
		('23:59:'||lpad(generate_series(50, 59)::varchar, 2, '0' ))::varchar as cur,
		('23:59:'||lpad(generate_series(40, 59, 2)::varchar, 2, '0' ))::varchar as expected
union all
	select 
		'23:59:30'::varchar as strt, 
		'24:00:30'::varchar as fin, 
		'fullspeed day 2' as state,
		('00:00:'||lpad(generate_series(0, 9)::varchar, 2, '0' ))::varchar as cur,
		('00:00:'||lpad(generate_series(0, 19, 2)::varchar, 2, '0' ))::varchar as expected
union all
	select 
		'23:59:30'::varchar as strt, 
		'24:00:30'::varchar as fin, 
		'stopping' as state,
		('00:00:'||lpad(generate_series(10, 19)::varchar, 2, '0' ))::varchar as cur,
		('00:00:'||lpad(generate_series(20, 29)::varchar, 2, '0' ))::varchar as expected
union all
	select 
		'23:59:30'::varchar as strt, 
		'24:00:30'::varchar as fin, 
		'stopped' as state,
		('00:00:'||lpad(generate_series(20, 29)::varchar, 2, '0' ))::varchar as cur,
		'00:00:30'::varchar as expected

) t;
*/


create or replace view gtfs.loctable as
with 
	startstop as (
		select trip_id, min(arrival_time) as trip_start, max(departure_time) as trip_fin
		from gtfs.stop_times 
		group by trip_id
	),
	curtime as (
		select clock_timestamp()::date as cd, 
		to_char(clock_timestamp(), 'hh24:mi:ss') as ct, 
		extract (dow from clock_timestamp()) as d
	),
	cal as (
		select c.service_id
		from gtfs.calendar c, curtime 
		where 
			curtime.cd between c.start_date and c.end_date and
			(array[c.monday, c.tuesday, c.wednesday, c.thursday, c.friday, c.saturday, c.sunday])[extract (dow from cd)] = true
	),
	trip as (
		select 
			startstop.trip_id, 
			trips.shape_id,
			--gtfs.get_time_fraction(startstop.trip_start, startstop.trip_fin, curtime.ct) as fraction,
			startstop.trip_start as strt,
			startstop.trip_fin as fin,
			curtime.ct as cur,
			trips.trip_headsign,
			trips.trip_long_name,
			routes.route_short_name,
			routes.route_long_name, 
			routes.route_color
		from cal, curtime, startstop, gtfs.trips trips, gtfs.routes routes
		where 
			startstop.trip_start < curtime.ct and
			startstop.trip_fin > curtime.ct and 
			trips.trip_id = startstop.trip_id and 
			trips.service_id = cal.service_id and
			trips.route_id = routes.route_id
	), 
	nextstop as (
		select 
			n.trip_id, s.stop_id, s.stop_lon, s.stop_lat, s.stop_name, 
			st.arrival_time, st.departure_time, st.stop_sequence
		from 
			gtfs.stops s, gtfs.stop_times st,
			(select 
				trip.trip_id, min(st.stop_sequence) as seq
			from 
				gtfs.stop_times st, trip, curtime
			where 
				st.trip_id = trip.trip_id and
				st.arrival_time > curtime.ct
			group by trip.trip_id) n
		where 
			s.stop_id = st.stop_id and 
			n.trip_id = st.trip_id and
			n.seq = st.stop_sequence
	),
	prevstop as (
		select 
			n.trip_id, s.stop_id, s.stop_lon, s.stop_lat, s.stop_name, 
			st.arrival_time, st.departure_time, st.stop_sequence
		from 
			gtfs.stops s, gtfs.stop_times st,
			(select 
				trip.trip_id, max(st.stop_sequence) as seq
			from 
				gtfs.stop_times st, trip, curtime
			where 
				st.trip_id = trip.trip_id and
				st.arrival_time < curtime.ct
			group by trip.trip_id) n
		where 
			s.stop_id = st.stop_id and 
			n.trip_id = st.trip_id and
			n.seq = st.stop_sequence
	),	
	shp as (
		select shape_id, st_makeline(array_agg(shape)) as shape 
		from (
			select s.shape_id, st_setsrid(st_makepoint(s.shape_pt_lon, s.shape_pt_lat), 4326) as shape
			from gtfs.shapes s, trip t
			where t.shape_id = s.shape_id
			order by s.shape_id, s.shape_pt_sequence) n
		group by shape_id
	)
select 
	trip.trip_id, trip.shape_id, trip.strt, trip.fin, trip.cur,
	nextstop.stop_id as nextstop_id, 
	nextstop.stop_name as nextstop_name, 
	nextstop.arrival_time as nextstop_arrive, nextstop.departure_time as nextstop_depart, nextstop.stop_sequence nextstop_seq,
	prevstop.stop_id as prevstop_id,
	prevstop.stop_name as prevstop_name, 
	prevstop.arrival_time as prevstop_arrive, prevstop.departure_time as prevstop_depart, prevstop.stop_sequence as prevstop_seq,
	trip.trip_headsign, trip.trip_long_name,
	trip.route_short_name, trip.route_long_name,
	'#'||trip.route_color as route_color,
	--st_lineinterpolatepoint(shp.shape, trip.fraction) as pos
	st_lineinterpolatepoint(
		shp.shape, 
		gtfs.get_time_fraction(trip.strt, trip.fin, 
			gtfs.get_current_impeded_time(prevstop.departure_time, nextstop.arrival_time, trip.cur::varchar))) as pos
from shp, trip, nextstop, prevstop
where 
	trip.shape_id = shp.shape_id and 
	nextstop.trip_id = trip.trip_id and
	prevstop.trip_id = trip.trip_id;
alter view gtfs.loctable owner to postgres;



