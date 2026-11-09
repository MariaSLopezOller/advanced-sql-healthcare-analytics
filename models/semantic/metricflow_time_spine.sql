-- One row per day. MetricFlow joins metrics to this table to group them by day, week, month or year.
select cast(g.day as date) as date_day
from generate_series(date '2024-01-01', date '2026-12-31', interval 1 day) as g(day)
