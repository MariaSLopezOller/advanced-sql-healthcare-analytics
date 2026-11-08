-- Merged coverage periods per patient and drug must never overlap.
select *
from (
    select *, lag(covered_to) over (partition by patient_id, drug_name order by period_number) as prev_to
    from {{ ref('int_medication_coverage_periods') }}
)
where covered_from < prev_to
