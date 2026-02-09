SELECT
    incident_id,
    customer_id,
    opened_at,
    closed_at,
    severity,
    detection_rule,
    TIMESTAMP_DIFF(closed_at, opened_at, HOUR) as mttr_hours,
    TIMESTAMP_DIFF(closed_at, opened_at, MINUTE) as mttr_minutes
FROM {{ source('raw_data', 'incidents') }}