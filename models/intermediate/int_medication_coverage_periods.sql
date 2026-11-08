-- Gaps and islands: merge overlapping or back-to-back pharmacy fills into continuous
-- coverage periods per patient and drug, and measure the gap before each period.
with flagged as (
    select
        *,
        -- a fill starts a new island when it begins after every earlier fill has run out
        case
            when start_date <= max(end_date) over (
                     partition by patient_id, drug_name
                     order by start_date, prescription_id
                     rows between unbounded preceding and 1 preceding)
            then 0 else 1
        end as starts_new_period
    from {{ ref('stg_prescriptions') }}
),
numbered as (
    select
        *,
        sum(starts_new_period) over (partition by patient_id, drug_name
                                     order by start_date, prescription_id) as period_number
    from flagged
),
periods as (
    select
        patient_id,
        drug_name,
        period_number,
        min(start_date)                                                         as covered_from,
        least(max(end_date), date '{{ var("observation_end") }}' + 1)          as covered_to,
        count(*)                                                                as fills
    from numbered
    group by all
)
select
    *,
    date_diff('day', covered_from, covered_to) as covered_days,
    date_diff('day', lag(covered_to) over (partition by patient_id, drug_name order by period_number),
              covered_from)                    as gap_days_before
from periods
