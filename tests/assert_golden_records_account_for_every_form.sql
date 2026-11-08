-- Deduplication must not lose or invent forms: copies across golden records = raw rows.
select g.forms, r.forms
from (select sum(copies) as forms from {{ ref('dim_patient_intake_golden') }}) g
cross join (select count(*) as forms from {{ ref('stg_patient_intake') }}) r
where g.forms <> r.forms
