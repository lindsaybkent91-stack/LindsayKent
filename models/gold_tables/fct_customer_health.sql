WITH base_customers AS (
    SELECT DISTINCT 
        customer_id, 
        customer_name 
    FROM {{ ref('dim_customers') }}
),

incident_metrics AS (
    SELECT 
        customer_id,
        AVG(mttr_hours) as avg_mttr
    FROM {{ ref('fct_incidents') }}
    GROUP BY customer_id
),

support_metrics AS (
    SELECT 
        customer_id,
        AVG(csat_score) as avg_csat
    FROM {{ ref('fct_support_tickets') }}
    GROUP BY customer_id
),

subscription_metrics AS (
    SELECT 
        customer_id,
        account_status,
        renewal_date,
        CASE 
            WHEN renewal_date >= CURRENT_DATE() 
            AND renewal_date <= DATE_ADD(CURRENT_DATE(), INTERVAL 3 MONTH) 
            THEN TRUE 
            ELSE FALSE 
        END as is_upcoming_renewal
    FROM {{ ref('fct_subscriptions') }}
    QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY renewal_date DESC) = 1
)

SELECT
    bc.customer_id,
    bc.customer_name,
    COALESCE(i.avg_mttr, 0) as avg_mttr,
    COALESCE(s.avg_csat, 5.0) as avg_csat,
    COALESCE(sub.is_upcoming_renewal, FALSE) as has_upcoming_renewal,
    COALESCE(sub.account_status, 'Unknown') as latest_account_status,

    -- RAG SCORING COLUMNS
    -- Scoring MTTR (Max 50 pts): Under 4h is Elite, Under 24h is OK.
    CASE 
        WHEN COALESCE(i.avg_mttr, 0) <= 4 THEN 50
        WHEN COALESCE(i.avg_mttr, 0) <= 24 THEN 25
        ELSE 0 
    END +
    -- Scoring CSAT (Max 50 pts): Based on 10-point scale
    CASE 
        WHEN COALESCE(s.avg_csat, 0) >= 8.5 THEN 50
        WHEN COALESCE(s.avg_csat, 0) >= 7.0 THEN 25
        ELSE 0 
    END as health_score,

    -- RAG Status Label
    CASE 
        WHEN (CASE WHEN COALESCE(i.avg_mttr, 0) <= 4 THEN 50 WHEN COALESCE(i.avg_mttr, 0) <= 24 THEN 25 ELSE 0 END +
              CASE WHEN COALESCE(s.avg_csat, 0) >= 8.5 THEN 50 WHEN COALESCE(s.avg_csat, 0) >= 7.0 THEN 25 ELSE 0 END) >= 75 THEN 'Green'
        WHEN (CASE WHEN COALESCE(i.avg_mttr, 0) <= 4 THEN 50 WHEN COALESCE(i.avg_mttr, 0) <= 24 THEN 25 ELSE 0 END +
              CASE WHEN COALESCE(s.avg_csat, 0) >= 8.5 THEN 50 WHEN COALESCE(s.avg_csat, 0) >= 7.0 THEN 25 ELSE 0 END) >= 50 THEN 'Amber'
        ELSE 'Red'
    END as health_rag_status

FROM base_customers bc
LEFT JOIN incident_metrics i ON bc.customer_id = i.customer_id
LEFT JOIN support_metrics s ON bc.customer_id = s.customer_id
LEFT JOIN subscription_metrics sub ON bc.customer_id = sub.customer_id