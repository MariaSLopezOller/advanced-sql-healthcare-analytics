-- Every (ancestor, descendant) pair in the department hierarchy, self included,
-- with the ancestor's depth and full path. Built with recursive CTEs.
with recursive
tree as (
    select department_id, department_name, 0 as depth, department_name as path
    from {{ ref('stg_departments') }}
    where parent_department_id is null
    union all
    select d.department_id, d.department_name, t.depth + 1, t.path || ' > ' || d.department_name
    from {{ ref('stg_departments') }} d
    join tree t on d.parent_department_id = t.department_id
),
closure as (
    select department_id as ancestor_id, department_id as descendant_id
    from {{ ref('stg_departments') }}
    union all
    select c.ancestor_id, d.department_id
    from closure c
    join {{ ref('stg_departments') }} d on d.parent_department_id = c.descendant_id
)
select
    c.ancestor_id,
    t.department_name as ancestor_name,
    t.depth           as ancestor_depth,
    t.path            as ancestor_path,
    c.descendant_id
from closure c
join tree t on t.department_id = c.ancestor_id
