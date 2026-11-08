-- Q12 · Does the 80/20 rule hold? How much of total spending comes from the costliest patients?
-- Techniques: NTILE deciles, window functions over grouped rows (sum(sum(x)) over ...) for
--             share of total and cumulative share in a single pass.
with patient_cost as (
    select patient_id, sum(total_cost) as cost, count(*) as encounters
    from {{ ref('stg_encounters') }}
    group by all
),
deciles as (
    select *, ntile(10) over (order by cost desc) as cost_decile
    from patient_cost
)
select
    cost_decile,
    count(*)                                                                    as patients,
    round(sum(cost), 2)                                                         as cost,
    {{ safe_pct('sum(cost)', 'sum(sum(cost)) over ()') }}                       as pct_of_total,
    {{ safe_pct('sum(sum(cost)) over (order by cost_decile)',
                'sum(sum(cost)) over ()') }}                                    as cumulative_pct,
    round(avg(encounters), 1)                                                   as avg_encounters,
    round(min(cost), 2)                                                         as min_patient_cost,
    round(max(cost), 2)                                                         as max_patient_cost
from deciles
group by cost_decile
order by cost_decile
