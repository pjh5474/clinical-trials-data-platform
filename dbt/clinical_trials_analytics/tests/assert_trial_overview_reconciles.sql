select
    *

from {{ ref('mart_trial_overview') }}

where total_trials
      != (
          interventional_trials
          + observational_trials
          + other_trials
      )