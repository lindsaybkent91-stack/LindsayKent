SELECT
    ticket_id,
    customer_id,
    ticket_status,
    opened_at,
    closed_at,
    -- Calculating how long it took to solve the ticket
    TIMESTAMP_DIFF(closed_at, opened_at, HOUR) as resolution_hours,
    csat_score
FROM {{ source('raw_data', 'support_tickets') }}