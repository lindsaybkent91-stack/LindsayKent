WITH base_data AS (
    SELECT 
        *,
        -- Find the absolute earliest churned renewal date
        MIN(CASE WHEN account_status = 'Churned' THEN renewal_date END) 
            OVER (PARTITION BY customer_id) as raw_earliest_churn
    FROM {{ source('raw_data', 'subscription_sales') }}
),

final_churn_logic AS (
    SELECT
        *,
        -- If churned renewal is in the future, use Today. Otherwise use the renewal date.
        CASE 
            WHEN account_status = 'Churned' THEN 
                CASE 
                    WHEN raw_earliest_churn < CURRENT_DATE() THEN raw_earliest_churn
                    ELSE CURRENT_DATE()
                END
            ELSE NULL 
        END as calculated_churn_date
    FROM base_data
)

SELECT
TO_HEX(MD5(CONCAT(CAST(customer_id AS STRING), '|', CAST(renewal_date AS STRING)))) AS deal_id,
    customer_id,
    customer_name,
    industry,
    original_signup_date,
    account_status,
    DATE_SUB(renewal_date, INTERVAL 1 YEAR) as subscription_start,
    renewal_date, 
    calculated_churn_date as churn_date,
    -- Tenure Months: Use Churn Date if it exists, otherwise Today
    DATE_DIFF(
        COALESCE(calculated_churn_date, CURRENT_DATE()), 
        original_signup_date, 
        MONTH
    ) as tenure_months,
    -- Tenure Years: Rounded to 1 decimal
    ROUND(
        DATE_DIFF(
            COALESCE(calculated_churn_date, CURRENT_DATE()), 
            original_signup_date, 
            MONTH
        ) / 12.0, 
        1
    ) as tenure_years,
    annual_contract_value,
    CASE 
        WHEN annual_contract_value >= 100000 THEN 'Enterprise'
        WHEN annual_contract_value >= 50000  THEN 'Mid-Market High'
        WHEN annual_contract_value >= 25000  THEN 'Mid-Market Low'
        WHEN annual_contract_value > 0       THEN 'SMB'
        ELSE 'Trial/Free'
    END as contract_tier,
    IF(account_status = 'Churned', 'Lost', IF(renewal_date>CURRENT_DATE(),'Upcoming Renewal','Completed Subscription')) as deal_status
FROM final_churn_logic