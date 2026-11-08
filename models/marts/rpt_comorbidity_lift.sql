-- Q10 · Which chronic conditions appear together more often than chance would predict?
-- Techniques: market-basket analysis in SQL: self-join with a < b for unique pairs,
--             support, confidence and lift = P(A and B) / (P(A) * P(B)).
with population as (
    select count(distinct patient_id) as n from {{ ref('stg_encounters') }}
),
condition_counts as (
    select condition_code, count(*) as patients
    from {{ ref('int_patient_conditions') }}
    group by all
),
pairs as (
    select a.condition_code as condition_a, b.condition_code as condition_b, count(*) as both_patients
    from {{ ref('int_patient_conditions') }} a
    join {{ ref('int_patient_conditions') }} b
      on a.patient_id = b.patient_id
     and a.condition_code < b.condition_code
    group by all
)
select
    p.condition_a,
    p.condition_b,
    ca.patients                                      as patients_a,
    cb.patients                                      as patients_b,
    p.both_patients,
    {{ safe_pct('p.both_patients', 'pop.n', 2) }}    as support_pct,
    {{ safe_pct('p.both_patients', 'ca.patients') }} as confidence_a_to_b_pct,
    round((p.both_patients / pop.n) / ((ca.patients / pop.n) * (cb.patients / pop.n)), 2) as lift
from pairs p
join condition_counts ca on ca.condition_code = p.condition_a
join condition_counts cb on cb.condition_code = p.condition_b
cross join population pop
order by lift desc, both_patients desc
