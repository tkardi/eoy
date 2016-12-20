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
alter table gtfs.routes add constraint
    fk__routes__agency foreign key (agency_id) references gtfs.agency (agency_id)
    on update cascade on delete no action
    deferrable initially deferred;


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
alter table gtfs.stop_times add constraint
    fk__stop_times__stops foreign key (stop_id) references gtfs.stops (stop_id)
    on update cascade on delete no action
    deferrable initially deferred;



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
	totalsecs integer;
	fractionsecs integer;
begin
	a_fin := string_to_array(trip_fin, ':');
	a_strt := string_to_array(trip_fin, ':');
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
comment on function gtfs.get_time_fraction(varchar, varchar, varchar) is 'Calculates the relative fraction that current time represents in between start and finish timestamps.';

--select gtfs.get_time_fraction ('23:00:00', '24:00:00', '23:01:00');
--0.01666666666666666667

--select gtfs.get_time_fraction ('23:00:00', '23:01:00', '23:01:00');
--1.00000000000000000000

--select gtfs.get_time_fraction ('23:00:00', '23:01:00', '23:00:00');
--0.00000000000000000000