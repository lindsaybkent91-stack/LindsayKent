SELECT
    deal_id,
    customer_id,
    annual_contract_value,
    contract_tier, 
    subscription_start,
    renewal_date,
    account_status,
    CASE 
        WHEN account_status = 'Active' THEN annual_contract_value 
        ELSE 0 
    END as active_acv
FROM {{ ref('stg_subscriptions') }}