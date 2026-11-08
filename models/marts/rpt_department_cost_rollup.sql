-- Q01 · How much activity and cost does each level of the organisation carry,
--       including everything in its sub-departments?
-- Techniques: recursive CTE closure table (int_department_tree), roll-up through the hierarchy,
--             share of grand total with a window over the whole result.
with activity as (
    select department_id, count(*) as encounters, sum(total_cost) as cost
    from {{ ref('stg_encounters') }}
    group by all
)
select
    repeat('    ', t.ancestor_depth) || t.ancestor_name                           as department,
    t.ancestor_depth                                                             as depth,
    t.ancestor_path                                                              as path,
    coalesce(sum(a.encounters) filter (where t.descendant_id = t.ancestor_id), 0) as direct_encounters,
    coalesce(sum(a.encounters), 0)                                               as subtree_encounters,
    round(coalesce(sum(a.cost), 0), 2)                                           as subtree_cost,
    {{ safe_pct('coalesce(sum(a.cost), 0)', 'max(sum(a.cost)) over ()') }}       as pct_of_hospital_cost
from {{ ref('int_department_tree') }} t
left join activity a on a.department_id = t.descendant_id
group by t.ancestor_id, t.ancestor_name, t.ancestor_depth, t.ancestor_path
order by path
