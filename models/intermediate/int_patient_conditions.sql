-- One row per patient and chronic condition ever recorded on any of their encounters.
select distinct
    e.patient_id,
    d.icd10_category as condition_code
from {{ ref('stg_diagnoses') }} d
join {{ ref('stg_encounters') }} e using (encounter_id)
where d.is_chronic_condition
