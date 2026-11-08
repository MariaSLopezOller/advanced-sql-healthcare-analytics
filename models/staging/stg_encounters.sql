-- One row per visit. Data-quality defects are flagged here, not silently dropped,
-- so downstream models choose what to exclude and the scorecard can count them.
select
    encounter_id,
    patient_id,
    physician_id,
    department_id,
    encounter_type,
    cast(admit_date as date)                                     as admit_date,
    cast(discharge_date as date)                                 as discharge_date,
    total_cost,
    date_trunc('month', cast(admit_date as date))::date          as admit_month,
    date_diff('day', cast(admit_date as date), cast(discharge_date as date)) as length_of_stay_days,
    discharge_date is null                                       as is_open_stay,
    coalesce(discharge_date >= admit_date, true)                 as has_valid_dates
from {{ ref('raw_encounters') }}
