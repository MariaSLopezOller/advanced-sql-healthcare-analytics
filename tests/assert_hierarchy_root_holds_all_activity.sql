-- The root of the hierarchy must carry every encounter and all cost.
select r.*
from {{ ref('rpt_department_cost_rollup') }} r
where r.depth = 0
  and (r.subtree_encounters <> (select count(*) from {{ ref('stg_encounters') }})
       or abs(r.subtree_cost - (select sum(total_cost) from {{ ref('stg_encounters') }})) > 0.01)
