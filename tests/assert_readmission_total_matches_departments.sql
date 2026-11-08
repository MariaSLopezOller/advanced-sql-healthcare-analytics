-- The hospital total row must equal the sum of the department rows.
with t as (select * from {{ ref('rpt_readmission_rates') }})
select *
from (select sum(discharges) as d, sum(readmissions) as r from t where department <> 'ALL DEPARTMENTS') parts
cross join (select discharges as d, readmissions as r from t where department = 'ALL DEPARTMENTS') total
where parts.d <> total.d or parts.r <> total.r
