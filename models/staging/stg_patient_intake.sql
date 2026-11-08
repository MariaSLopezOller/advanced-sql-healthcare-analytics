-- Raw intake forms, normalised. match_key groups copies of the same person:
-- same name (ignoring case and spaces) and same birth date.
select
    intake_id,
    source_system,
    trim(first_name)                                  as first_name,
    trim(last_name)                                   as last_name,
    try_cast(birth_date as date)                      as birth_date,
    nullif(lower(trim(email)), '')                    as email,
    phone,
    cast(submitted_at as date)                        as submitted_at,
    lower(trim(first_name)) || '|' || lower(trim(last_name)) || '|' || coalesce(birth_date, '?') as match_key,
    regexp_full_match(lower(trim(email)), '[^@\s]+@[^@\s]+\.[a-z]{2,}') as is_valid_email
from {{ ref('raw_patient_intake') }}
