-- The occupancy calendar must have exactly one row for every day in the observation period.
select count(*) as days
from {{ ref('rpt_daily_bed_occupancy') }}
having count(*) <> date_diff('day', date '{{ var("observation_start") }}', date '{{ var("observation_end") }}') + 1
