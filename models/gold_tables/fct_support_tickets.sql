SELECT
    ticket_id,
    customer_id,
    CAST(csat_score AS FLOAT64) as csat_score,
    resolution_hours,
    CASE 
        WHEN resolution_hours <= 1 THEN TRUE 
        ELSE FALSE 
    END as is_quick_fix
FROM {{ ref('stg_support_tickets') }}