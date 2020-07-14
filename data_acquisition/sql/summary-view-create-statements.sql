CREATE OR REPLACE VIEW fb.summary
 AS
 SELECT date_part('month'::text, a.date) AS month,
    date_part('day'::text, a.date) AS day,
    a.total_spend,
    a.has_all_states,
    a.has_missing_values
   FROM ( SELECT spend.date,
            sum(spend.amt) AS total_spend,
            count(DISTINCT spend.state) = 51 AS has_all_states,
            sum(
                CASE
                    WHEN spend.amt IS NULL THEN 1
                    ELSE 0
                END) <> 0 AS has_missing_values
           FROM fb.spend
          GROUP BY spend.date) a
  ORDER BY (date_part('month'::text, a.date)) DESC, (date_part('day'::text, a.date)) DESC;


CREATE OR REPLACE VIEW predictit.summary
 AS
 SELECT date_part('month'::text, c.day) AS month,
    date_part('day'::text, c.day) AS day,
    c.has_missing_values,
    b.has_all_states
   FROM ( SELECT d.day,
                CASE
                    WHEN sum(d.missing) > 0 THEN true
                    ELSE false
                END AS has_missing_values
           FROM ( SELECT
                        CASE
                            WHEN prices.price IS NULL THEN 1
                            ELSE 0
                        END AS missing,
                    prices."time"::date AS day
                   FROM predictit.prices) d
          GROUP BY d.day) c
     LEFT JOIN ( SELECT a.day,
            sum(
                CASE
                    WHEN a.has_all_states THEN 1
                    ELSE 0
                END) = 2 AS has_all_states
           FROM ( SELECT prices.party,
                    prices."time"::date AS day,
                    count(DISTINCT prices.state) = (( SELECT count(*) AS count
                           FROM reference.juriscodes)) AS has_all_states
                   FROM predictit.prices
                  WHERE prices.party::text = ANY (ARRAY['D'::character varying, 'R'::character varying]::text[])
                  GROUP BY (prices."time"::date), prices.party) a
          GROUP BY a.day) b USING (day)
  ORDER BY (date_part('month'::text, c.day)) DESC, (date_part('day'::text, c.day)) DESC;
