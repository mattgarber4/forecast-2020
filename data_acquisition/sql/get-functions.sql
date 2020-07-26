DROP FUNCTION predictit.getdays(date, date);
CREATE OR REPLACE FUNCTION predictit.getDays(date, date) 
RETURNS TABLE(state text, date date, dem float, rep float)
  AS $$ SELECT state, date, avg(dem::float) as dem, avg(rep::float) as rep
	  		FROM (
				(
					SELECT state, time::date as date, price as dem
					FROM predictit.prices 
					WHERE time::date >= $1 and time::date <= $2 AND party = 'D'
				) a
	  			LEFT JOIN (		
					SELECT state, time::date as date, price as rep
					FROM predictit.prices 
					WHERE time::date >= $1 and time::date <= $2 AND party = 'R'
				) b
	  			USING(state, date)
  			)
	  		GROUP BY state, date
	  		ORDER BY date asc
	 $$ LANGUAGE sql;

DROP FUNCTION fb.getdays(date, date);
CREATE OR REPLACE FUNCTION fb.getDays(date, date) 
RETURNS TABLE(state text, date date, dem float, rep float)
	AS $$ SELECT state, date, avg(dem::float) as dem, avg(rep::float) as rep FROM (
			(
				SELECT state, date, amt::int as dem
				FROM fb.spend 
				WHERE date >= $1 and date <= $2 AND party = 'D'
			) a
			LEFT JOIN (		
				SELECT state, date, amt::int as rep
				FROM fb.spend 
				WHERE date >= $1 and date <= $2 AND party = 'R'
			) b
			USING(state, date)
		)
		GROUP BY date, state
		ORDER BY date asc
	$$ LANGUAGE sql;
