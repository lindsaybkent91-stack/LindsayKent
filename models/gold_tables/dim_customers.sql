WITH subs AS (
    SELECT * FROM {{ ref('stg_subscriptions') }}
)

SELECT
    customer_id,
    customer_name,
    industry,
    original_signup_date,
    tenure_years
FROM subs
QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY original_signup_date DESC) = 1
