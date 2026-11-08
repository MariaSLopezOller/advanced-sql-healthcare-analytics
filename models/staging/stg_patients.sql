select
    patient_id,
    cast(birth_date as date)                                              as birth_date,
    sex,
    postal_code,
    cast(registered_at as date)                                           as registered_at,
    date_diff('year', cast(birth_date as date), date '{{ var("observation_end") }}') as age_at_year_end
from {{ ref('raw_patients') }}
