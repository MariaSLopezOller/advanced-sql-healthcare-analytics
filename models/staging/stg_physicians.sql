select
    physician_id,
    full_name,
    department_id,
    cast(hire_date as date) as hire_date
from {{ ref('raw_physicians') }}
