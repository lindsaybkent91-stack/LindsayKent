SELECT
    incident_id,
    customer_id,
    detection_rule,
    opened_at,
    severity,
    mttr_hours
FROM {{ ref('stg_incidents') }}