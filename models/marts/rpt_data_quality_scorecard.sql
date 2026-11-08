-- Q14 · Can the numbers above be trusted? Which rules fail, how often, and against what tolerance?
-- Techniques: rule catalogue as UNION ALL of checks across quality dimensions (consistency,
--             referential integrity, completeness, validity, uniqueness), anti-join with NOT EXISTS,
--             PASS / WARN / FAIL status against a per-rule tolerance.
with checks as (
    select 'encounters' as table_name, 'consistency' as dimension,
           'discharge_date on or after admit_date' as rule,
           count_if(not has_valid_dates) as failed_rows, count(*) as total_rows, 0.0 as tolerance_pct
    from {{ ref('stg_encounters') }}

    union all
    select 'encounters', 'referential integrity', 'physician_id exists in physicians',
           count_if(not exists (select 1 from {{ ref('stg_physicians') }} p
                                where p.physician_id = e.physician_id)),
           count(*), 0.0
    from {{ ref('stg_encounters') }} e

    union all
    select 'encounters', 'completeness', 'inpatient stay open for more than 30 days',
           count_if(encounter_type = 'inpatient' and is_open_stay
                    and admit_date < date '{{ var("observation_end") }}' - 30),
           count(*), 0.5
    from {{ ref('stg_encounters') }}

    union all
    select 'diagnoses', 'completeness', 'exactly one primary diagnosis per encounter',
           count_if(coalesce(d.primaries, 0) <> 1), count(*), 0.0
    from {{ ref('stg_encounters') }} e
    left join (select encounter_id, count_if(is_primary) as primaries
               from {{ ref('stg_diagnoses') }}
               group by all) d using (encounter_id)

    union all
    select 'patients', 'validity', 'birth_date not in the future',
           count_if(birth_date > date '{{ var("observation_end") }}'), count(*), 0.0
    from {{ ref('stg_patients') }}

    union all
    select 'lab_results', 'validity', 'lab value within plausible range',
           count_if(not is_plausible), count(*), 0.5
    from {{ ref('stg_lab_results') }}

    union all
    select 'patient_intake', 'completeness', 'email present',
           count_if(email is null), count(*), 10.0
    from {{ ref('stg_patient_intake') }}

    union all
    select 'patient_intake', 'validity', 'email has a valid format',
           count_if(email is not null and not is_valid_email), count(*), 0.0
    from {{ ref('stg_patient_intake') }}

    union all
    select 'patient_intake', 'validity', 'birth_date before submission date',
           count_if(birth_date > submitted_at), count(*), 0.0
    from {{ ref('stg_patient_intake') }}

    union all
    select 'patient_intake', 'uniqueness', 'one form per person (name + birth date)',
           count(*) - count(distinct match_key), count(*), 5.0
    from {{ ref('stg_patient_intake') }}
)
select
    *,
    {{ safe_pct('failed_rows', 'total_rows', 2) }} as failed_pct,
    case
        when failed_rows = 0                                   then 'PASS'
        when 100.0 * failed_rows / total_rows <= tolerance_pct then 'WARN'
        else 'FAIL'
    end                                            as status
from checks
order by case status when 'FAIL' then 1 when 'WARN' then 2 else 3 end, failed_pct desc
