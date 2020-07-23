CREATE OR REPLACE FUNCTION predictit.getDays(date, date) 
RETURNS TABLE(state text, date date, dem int, rep int)
  AS $$ SELECT state, date, dem, rep FROM (
	  		SELECT state, time::date as date, price as dem
  			FROM predictit.prices 
			WHERE time::date >= $1 and time::date <= $2 AND party = 'D') a
		
			LEFT JOIN (		
			SELECT state, time::date as date, price as rep
  			FROM predictit.prices 
			WHERE time::date >= $1 and time::date <= $2 AND party = 'R'
			) b
			USING(state, date)
			ORDER BY date asc
	 $$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION fb.getDays(date, date) 
RETURNS TABLE(state text, date date, dem int, rep int)
	AS $$ SELECT state, date, dem, rep FROM (
	  		SELECT state, date, amt::int as dem
  			FROM fb.spend 
			WHERE date >= $1 and date <= $2 AND party = 'D') a
		
			LEFT JOIN (		
			SELECT state, date, amt::int as rep
  			FROM fb.spend 
			WHERE date >= $1 and date <= $2 AND party = 'R'
			) b
			USING(state, date)
			ORDER BY date asc
	 $$ LANGUAGE sql;