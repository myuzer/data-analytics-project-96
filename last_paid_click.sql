WITH paid_sessions AS (
    SELECT
        visitor_id,
        visit_date,
        source,
        medium,
        campaign
    FROM sessions
    WHERE medium IN ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
),

last_paid_click AS (
    SELECT
        visitor_id,
        source AS utm_source,
        medium AS utm_medium,
        campaign AS utm_campaign,
        MAX(visit_date) AS visit_date
    FROM paid_sessions
    GROUP BY
        visitor_id,
        utm_source,
        utm_medium,
        utm_campaign
    ORDER BY
        visitor_id,
        MAX(visit_date) DESC
),

lead_data AS (
    SELECT
        visitor_id,
        lead_id,
        created_at,
        amount,
        closing_reason,
        status_id
    FROM leads
)

SELECT
    lpc.visitor_id,
    lpc.visit_date,
    lpc.utm_source,
    lpc.utm_medium,
    lpc.utm_campaign,
    ld.lead_id,
    ld.created_at,
    ld.amount,
    ld.closing_reason,
    ld.status_id
FROM last_paid_click AS lpc
LEFT JOIN lead_data AS ld
    ON lpc.visitor_id = ld.visitor_id
ORDER BY
    ld.amount DESC NULLS LAST,
    lpc.visit_date ASC,
    lpc.utm_source ASC,
    lpc.utm_medium ASC,
    lpc.utm_campaign ASC;
