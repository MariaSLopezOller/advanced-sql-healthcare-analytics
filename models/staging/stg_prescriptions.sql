-- A fill covers [start_date, end_date): end_date is exclusive.
select
    prescription_id,
    patient_id,
    drug_name,
    cast(start_date as date)                                 as start_date,
    days_supply,
    cast(start_date as date) + days_supply                   as end_date
from {{ ref('raw_prescriptions') }}
