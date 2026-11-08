-- Q04 · Who carries the workload in each department, and what share of it?
-- Techniques: top-N per group with DENSE_RANK (ties kept) filtered with QUALIFY,
--             a named WINDOW reused by several functions, share of group with a partitioned SUM.
with physician_load as (
    select
        d.department_name                as department,
        p.physician_id,
        p.full_name,
        count(*)                         as encounters,
        count(distinct e.patient_id)     as patients,
        round(sum(e.total_cost), 2)      as billed
    from {{ ref('stg_encounters') }} e
    join {{ ref('stg_physicians') }} p  using (physician_id)
    join {{ ref('stg_departments') }} d on d.department_id = p.department_id
    group by all
)
select
    department,
    dense_rank() over w                                                            as rank_in_department,
    full_name,
    encounters,
    patients,
    billed,
    {{ safe_pct('encounters', 'sum(encounters) over (partition by department)') }} as pct_of_department,
    encounters - lead(encounters) over w                                           as lead_over_next
from physician_load
window w as (partition by department order by encounters desc)
qualify dense_rank() over w <= 3
order by department, rank_in_department, full_name
