-- Valid inpatient stays with the same patient's next admission (LEAD) and a 30-day readmission flag.
-- An index stay is "eligible" only if its full follow-up window fits inside the observation period.
with stays as (
    select
        encounter_id,
        patient_id,
        department_id,
        admit_date,
        discharge_date,
        length_of_stay_days,
        lead(admit_date) over (partition by patient_id order by admit_date, encounter_id) as next_admit_date
    from {{ ref('stg_encounters') }}
    where encounter_type = 'inpatient'
      and has_valid_dates
)
select
    *,
    date_diff('day', discharge_date, next_admit_date) as days_to_next_admission,
    coalesce(date_diff('day', discharge_date, next_admit_date)
             between 0 and {{ var('readmission_window_days') }}, false) as is_readmitted_30d,
    discharge_date is not null
      and discharge_date <= date '{{ var("observation_end") }}' - {{ var('readmission_window_days') }}
                                                        as is_eligible_index_stay
from stays
