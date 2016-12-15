create schema gtfs authorization postgres;
comment on schema gtfs is 'Schema for GTFS data';


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