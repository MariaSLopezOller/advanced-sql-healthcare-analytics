-- Each patient with an encounter belongs to exactly one cohort.
select c.patients, e.patients
from (select sum(cohort_size) as patients from {{ ref('rpt_cohort_retention') }}) c
cross join (select count(distinct patient_id) as patients from {{ ref('stg_encounters') }}) e
where c.patients <> e.patients
