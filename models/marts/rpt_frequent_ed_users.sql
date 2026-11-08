-- Q11 · Which patients had 3+ emergency visits in any rolling 90-day window (case-management list)?
-- Techniques: RANGE window frame with an INTERVAL (a true calendar window, not N rows),
--             QUALIFY + ROW_NUMBER to keep each patient's peak window.
with ed_visits as (
    select
        patient_id,
        admit_date,
        count(*) over (
            partition by patient_id
            order by admit_date
            range between interval 89 days preceding and current row
        )                                       as visits_in_90d,
        count(*) over (partition by patient_id) as ed_visits_in_year
    from {{ ref('stg_encounters') }}
    where encounter_type = 'emergency'
)
select
    v.patient_id,
    p.age_at_year_end                              as age,
    v.visits_in_90d                                as peak_visits_90d,
    cast(v.admit_date - interval 89 days as date)  as peak_window_start,
    v.admit_date                                   as peak_window_end,
    v.ed_visits_in_year
from ed_visits v
join {{ ref('stg_patients') }} p using (patient_id)
where v.visits_in_90d >= 3
qualify row_number() over (partition by v.patient_id order by v.visits_in_90d desc, v.admit_date) = 1
order by peak_visits_90d desc, ed_visits_in_year desc, v.patient_id
