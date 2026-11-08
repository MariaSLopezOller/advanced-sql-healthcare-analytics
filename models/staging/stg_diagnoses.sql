select
    encounter_id,
    icd10_code,
    left(icd10_code, 3)          as icd10_category,
    is_primary = 1               as is_primary,
    left(icd10_code, 3) in ('E11', 'I10', 'I50', 'J44', 'J45') as is_chronic_condition
from {{ ref('raw_diagnoses') }}
