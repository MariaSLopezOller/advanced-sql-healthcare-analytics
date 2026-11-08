select
    department_id,
    name as department_name,
    parent_department_id
from {{ ref('raw_departments') }}
