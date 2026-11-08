-- Q09 · Are diabetic patients improving? How many reach the <7% HbA1c target by their last test?
-- Techniques: arg_min / arg_max to take first and last values, LAG for test-to-test change,
--             exclusion of implausible lab values, two-level aggregation (patient, then trend group).
with series as (
    select
        patient_id,
        taken_at,
        result_value,
        result_value - lag(result_value) over (partition by patient_id order by taken_at) as delta
    from {{ ref('stg_lab_results') }}
    where test_code = 'HBA1C'
      and is_plausible
),
per_patient as (
    select
        patient_id,
        count(*)                        as n_tests,
        arg_min(result_value, taken_at) as first_hba1c,
        arg_max(result_value, taken_at) as last_hba1c,
        max(delta)                      as worst_single_rise
    from series
    group by patient_id
    having count(*) >= 2
),
classified as (
    select
        *,
        last_hba1c - first_hba1c as total_change,
        case
            when last_hba1c - first_hba1c <= -0.5 then 'improving'
            when last_hba1c - first_hba1c >=  0.5 then 'worsening'
            else 'stable'
        end                      as trend
    from per_patient
)
select
    trend,
    count(*)                                               as patients,
    {{ safe_pct('count(*)', 'sum(count(*)) over ()') }}    as pct_patients,
    round(avg(first_hba1c), 2)                             as avg_first_hba1c,
    round(avg(last_hba1c), 2)                              as avg_last_hba1c,
    round(avg(total_change), 2)                            as avg_change,
    count_if(last_hba1c < 7)                               as at_target_last_test,
    {{ safe_pct('count_if(last_hba1c < 7)', 'count(*)') }} as pct_at_target
from classified
group by trend
order by case trend when 'improving' then 1 when 'stable' then 2 else 3 end
