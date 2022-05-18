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
			gtfs.get_time_fraction(startstop.trip_start, startstop.trip_fin, curtime.ct) as fraction,
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
	nextstop.stop_id, nextstop.stop_lon, nextstop.stop_lat, nextstop.stop_name, 
	nextstop.arrival_time, nextstop.departure_time, nextstop.stop_sequence,
	prevstop.stop_id, prevstop.stop_lon, prevstop.stop_lat, prevstop.stop_name, 
	prevstop.arrival_time, prevstop.departure_time, prevstop.stop_sequence,
	trip.trip_headsign, trip.trip_long_name,
	trip.route_short_name, trip.route_long_name,
	'#'||trip.route_color as route_color,
	st_lineinterpolatepoint(shp.shape, trip.fraction) as pos
from shp, trip, nextstop, prevstop
where 
	trip.shape_id = shp.shape_id and 
	nextstop.trip_id = trip.trip_id and
	prevstop.trip_id = trip.trip_id;
