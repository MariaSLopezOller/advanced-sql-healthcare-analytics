-- Q13 · How many real people are behind the intake forms, and what is their best contact data?
-- Techniques: entity resolution on a normalised match key, survivorship rules with FIRST_VALUE
--             (name as first written, newest non-null email and phone), QUALIFY to keep one row.
select
    match_key,
    first_value(intake_id)          over newest as golden_intake_id,
    first_value(first_name)         over oldest as first_name,
    first_value(last_name)          over oldest as last_name,
    birth_date,
    first_value(email ignore nulls) over newest as email,
    first_value(phone ignore nulls) over newest as phone,
    min(submitted_at)               over person as first_seen,
    max(submitted_at)               over person as last_seen,
    count(*)                        over person as copies
from {{ ref('stg_patient_intake') }}
window
    person as (partition by match_key),
    newest as (partition by match_key order by submitted_at desc, intake_id desc
               rows between unbounded preceding and unbounded following),
    oldest as (partition by match_key order by submitted_at, intake_id
               rows between unbounded preceding and unbounded following)
qualify row_number() over (partition by match_key order by submitted_at desc, intake_id desc) = 1
order by copies desc, last_name, first_name, birth_date
