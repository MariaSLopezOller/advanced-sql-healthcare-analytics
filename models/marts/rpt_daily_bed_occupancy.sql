-- Q02 · How many inpatient beds were occupied each day of 2025, and which days were monthly peaks?
-- Techniques: date spine with generate_series, interval (range) join, open intervals
--             (NULL discharge = still admitted), 7-day moving average, peak flag with window MAX.
with calendar as (
    select cast(g.day as date) as day
    from generate_series(date '{{ var("observation_start") }}',
                         date '{{ var("observation_end") }}', interval 1 day) as g(day)
),
daily as (
    -- a bed counts for each night before discharge
    select c.day, count(s.encounter_id) as occupied_beds
    from calendar c
    left join {{ ref('int_inpatient_stays') }} s
           on s.admit_date <= c.day
          and (s.discharge_date > c.day or s.discharge_date is null)
    group by c.day
)
select
    day,
    dayofweek(day) in (0, 6)                                                                  as is_weekend,
    occupied_beds,
    round(avg(occupied_beds) over (order by day rows between 6 preceding and current row), 1) as moving_avg_7d,
    occupied_beds = max(occupied_beds) over (partition by date_trunc('month', day))           as is_month_peak
from daily
order by day
