-- Q06 · What is a typical stay, and how long is the tail, in each department?
-- Techniques: ordered-set aggregates PERCENTILE_CONT / PERCENTILE_DISC (WITHIN GROUP),
--             outliers relative to the group median by joining rows back to their group's statistics.
with stays as (
    select d.department_name as department, s.length_of_stay_days as los
    from {{ ref('int_inpatient_stays') }} s
    join {{ ref('stg_departments') }} d using (department_id)
    where s.discharge_date is not null
),
stats as (
    select
        department,
        count(*)                                         as stays,
        round(avg(los), 2)                               as mean_los,
        percentile_cont(0.5) within group (order by los) as median_los,
        percentile_disc(0.9) within group (order by los) as p90_los,
        max(los)                                         as max_los
    from stays
    group by department
)
select
    st.department,
    st.stays,
    st.mean_los,
    st.median_los,
    st.p90_los,
    st.max_los,
    count(*) filter (where s.los > 2 * st.median_los) as stays_over_2x_median
from stats st
join stays s using (department)
group by all
order by median_los desc, department
