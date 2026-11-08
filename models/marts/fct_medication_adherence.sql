-- Q07 · Which chronic patients have treatment gaps, and who falls below the 80% PDC threshold?
-- Techniques: gaps and islands (int_medication_coverage_periods), proportion of days covered
--             (PDC) over each patient's own observation window, threshold taken from a dbt var.
with by_drug as (
    select
        patient_id,
        drug_name,
        min(covered_from)                                                            as first_fill,
        count(*)                                                                     as coverage_periods,
        count(gap_days_before)                                                       as gaps,
        coalesce(max(gap_days_before), 0)                                            as longest_gap_days,
        sum(covered_days)                                                            as days_covered,
        date_diff('day', min(covered_from), date '{{ var("observation_end") }}' + 1) as days_observed
    from {{ ref('int_medication_coverage_periods') }}
    group by all
)
select
    *,
    round(days_covered / days_observed, 3)                       as pdc,
    case when days_covered / days_observed >= {{ var('pdc_adherence_threshold') }}
         then 'adherent' else 'non-adherent' end                 as adherence_status
from by_drug
order by pdc, longest_gap_days desc, patient_id, drug_name
