WITH paid_sessions AS (
    SELECT
        *,
        ROW_NUMBER()
            OVER (PARTITION BY visitor_id ORDER BY visit_date DESC)
        AS rn
    FROM sessions
    WHERE medium IN ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
)

SELECT
    ps.visitor_id,
    ps.visit_date,
    ps.source AS utm_source,
    ps.medium AS utm_medium,
    ps.campaign AS utm_campaign,
    l.lead_id,
    l.created_at,
    l.amount,
    l.closing_reason,
    l.status_id
FROM paid_sessions AS ps
LEFT JOIN leads AS l
    ON ps.visitor_id = l.visitor_id
WHERE
    (
        ps.rn = 1
        AND ps.visit_date <= l.created_at
    )
    OR (
        ps.rn = 1
        AND l.created_at IS NULL
    )
ORDER BY
    l.amount DESC NULLS LAST,
    ps.visit_date ASC,
    utm_source ASC,
    utm_medium ASC,
    utm_campaign ASC;



