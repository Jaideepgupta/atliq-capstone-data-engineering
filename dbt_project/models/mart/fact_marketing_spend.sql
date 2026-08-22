select
    spend_date,
    channel,
    campaign,
    cast(spend_amount as decimal(14,2)) as spend_amount,
    clicks
from {{ ref('stg_marketing_spend') }}