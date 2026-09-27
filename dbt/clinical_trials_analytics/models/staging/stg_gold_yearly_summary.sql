select
    study_year,
    study_type,
    phase_label,
    overall_status,
    study_count,
    total_enrollment,
    avg_enrollment

from {{ source(
    'clinical_trials_gold',
    'gold_yearly_summary'
) }}

where study_year is not null