select
    lab_result_id,
    patient_id,
    test_code,
    result_value,
    cast(taken_at as date) as taken_at,
    case test_code
        when 'HBA1C' then result_value between 3 and 20
        when 'LDL'   then result_value between 20 and 400
        else true
    end                    as is_plausible
from {{ ref('raw_lab_results') }}
