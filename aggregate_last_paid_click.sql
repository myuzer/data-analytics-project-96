WITH paid_sessions AS (
    SELECT
        *,
        ROW_NUMBER()
            OVER (PARTITION BY visitor_id ORDER BY visit_date DESC)
        AS rn
    FROM sessions
    WHERE medium IN ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
),

last_paid_click AS (
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
        utm_campaign ASC
),

vk AS (
    SELECT
        ad_id,
        campaign_id,
        campaign_name,
        utm_source,
        utm_medium,
        utm_campaign,
        utm_content,
        campaign_date,
        daily_spent
    FROM vk_ads
),

all_ads AS (
    SELECT *
    FROM vk

    UNION ALL

    SELECT *
    FROM ya_ads
),

group_ads AS (
    SELECT
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS total_cost
    FROM all_ads
    GROUP BY
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign
    ORDER BY campaign_date ASC
)

SELECT
    lpc.utm_source,
    lpc.utm_medium,
    lpc.utm_campaign,
    TO_CHAR(lpc.visit_date, 'DD-MM-YYYY') AS visit_date,
    COUNT(lpc.visitor_id) AS visitors_count,
    SUM(gad.total_cost) AS total_cost,
    COUNT(lpc.lead_id) AS leads_count,
    COUNT(
        CASE
            WHEN
                lpc.closing_reason = 'Успешно реализовано'
                OR lpc.status_id = 142
                THEN 1
        END
    ) AS purchase_count,
    SUM(lpc.amount) AS revenue
FROM last_paid_click AS lpc
LEFT JOIN group_ads AS gad
    ON
        lpc.utm_source = gad.utm_source
        AND lpc.utm_medium = gad.utm_medium
        AND lpc.utm_campaign = gad.utm_campaign
GROUP BY
    lpc.visit_date,
    lpc.utm_source,
    lpc.utm_medium,
    lpc.utm_campaign
ORDER BY
    revenue DESC NULLS LAST,
    visit_date ASC,
    visitors_count DESC,
    lpc.utm_source ASC,
    lpc.utm_medium ASC,
    lpc.utm_campaign ASC;
