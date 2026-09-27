with yearly as (

    select *
    from {{ ref('stg_gold_yearly_summary') }}

),

overview as (

    select
        'current' as overview_key,

        sum(study_count) as total_trials,

        sum(
            case
                when study_type = 'INTERVENTIONAL'
                then study_count
                else 0
            end
        ) as interventional_trials,

        sum(
            case
                when study_type = 'OBSERVATIONAL'
                then study_count
                else 0
            end
        ) as observational_trials,

        sum(
            case
                when study_type not in (
                    'INTERVENTIONAL',
                    'OBSERVATIONAL'
                )
                or study_type is null
                then study_count
                else 0
            end
        ) as other_trials,

        max(
            case
                when study_year
                     <= extract(year from current_date())
                then study_year
                else null
            end
        ) as latest_year

    from yearly

)

select *
from overview