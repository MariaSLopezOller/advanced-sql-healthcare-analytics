-- Q03 · Which departments discharge patients who return as inpatients within 30 days?
-- Techniques: LEAD-based readmission flag (int_inpatient_stays), ROLLUP for the hospital total,
--             GROUPING() to label the total row, a Jinja loop + FILTER to pivot quarters into columns.
select
    case when grouping(d.department_name) = 1 then 'ALL DEPARTMENTS' else d.department_name end as department,
    count(*)                                                    as discharges,
    count_if(s.is_readmitted_30d)                               as readmissions,
    {{ safe_pct('count_if(s.is_readmitted_30d)', 'count(*)') }} as readmission_rate_pct,
{%- for q in [1, 2, 3, 4] %}
    {{ safe_pct('count_if(s.is_readmitted_30d and quarter(s.discharge_date) = ' ~ q ~ ')',
                'count(*) filter (where quarter(s.discharge_date) = ' ~ q ~ ')') }} as rate_q{{ q }}_pct
    {{- ',' if not loop.last }}
{%- endfor %}
from {{ ref('int_inpatient_stays') }} s
join {{ ref('stg_departments') }} d using (department_id)
where s.is_eligible_index_stay
group by rollup (d.department_name)
order by grouping(d.department_name), readmission_rate_pct desc
