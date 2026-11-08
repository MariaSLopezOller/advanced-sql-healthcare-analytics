-- Q05 · How is spending evolving through the year?
-- Techniques: running SUM, LAG for month-over-month growth, 3-month moving average,
--             share of the annual total with an empty OVER (), encounter-type mix with FILTER.
with monthly as (
    select
        admit_month                                                  as month,
        count(*)                                                     as encounters,
        sum(total_cost)                                              as cost,
        sum(total_cost) filter (where encounter_type = 'inpatient')  as inpatient_cost,
        sum(total_cost) filter (where encounter_type = 'emergency')  as emergency_cost,
        sum(total_cost) filter (where encounter_type = 'outpatient') as outpatient_cost
    from {{ ref('stg_encounters') }}
    group by all
)
select
    strftime(month, '%Y-%m')                                                           as month,
    encounters,
    round(cost, 2)                                                                     as cost,
    round(sum(cost) over (order by month rows unbounded preceding), 2)                 as cumulative_cost,
    {{ safe_pct('cost', 'sum(cost) over ()') }}                                        as pct_of_year,
    {{ safe_pct('cost - lag(cost) over (order by month)',
                'lag(cost) over (order by month)') }}                                  as mom_change_pct,
    round(avg(cost) over (order by month rows between 2 preceding and current row), 2) as moving_avg_3m,
    {{ safe_pct('inpatient_cost', 'cost') }}                                           as inpatient_share_pct,
    {{ safe_pct('emergency_cost', 'cost') }}                                           as emergency_share_pct,
    {{ safe_pct('outpatient_cost', 'cost') }}                                          as outpatient_share_pct
from monthly
order by month
