WITH all_ads AS (
    SELECT
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS total_cost,
        TO_CHAR(campaign_date, 'YYYY-MM-DD') AS campaign_date
    FROM vk_ads
    WHERE utm_medium IN ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
    GROUP BY
        utm_source,
        utm_medium,
        utm_campaign,
        campaign_date

    UNION ALL

    SELECT
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS total_cost,
        TO_CHAR(campaign_date, 'YYYY-MM-DD') AS campaign_date
    FROM ya_ads
    WHERE utm_medium IN ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
    GROUP BY
        utm_source,
        utm_medium,
        utm_campaign,
        campaign_date
),

last_paid_click AS (
    SELECT
        s.medium AS utm_medium,
        s.campaign AS utm_campaign,
        s.visitor_id,
        l.lead_id,
        l.closing_reason,
        l.status_id,
        l.amount,
        ROW_NUMBER()
        OVER (PARTITION BY s.visitor_id ORDER BY s.visit_date DESC)
        AS rn,
        TO_CHAR(s.visit_date, 'YYYY-MM-DD') AS visit_date,
        LOWER(s.source) AS utm_source,
        TO_CHAR(l.created_at, 'YYYY-MM-DD') AS created_at
    FROM sessions AS s
    LEFT JOIN leads AS l
        ON
            s.visitor_id = l.visitor_id
            AND s.visit_date <= l.created_at
    WHERE s.medium IN ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
),

aggregate_last_paid_click AS (
    SELECT
        lpc.rn,
        lpc.visit_date,
        lpc.utm_source,
        lpc.utm_medium,
        lpc.utm_campaign,
        aad.total_cost,
        COUNT(lpc.visitor_id) AS visitors_count,
        COUNT(lpc.lead_id) AS leads_count,
        COUNT(
            CASE
                WHEN
                    lpc.closing_reason = 'Успешная продажа'
                    OR
                    lpc.status_id = '142'
                    THEN 1
            END
        ) AS purchases_count,
        SUM(
            CASE
                WHEN
                    lpc.status_id = '142'
                    THEN lpc.amount
                ELSE 0
            END
        ) AS revenue
    FROM last_paid_click AS lpc
    LEFT JOIN all_ads AS aad
        ON
            lpc.utm_campaign = aad.utm_campaign
            AND lpc.utm_medium = aad.utm_medium
            AND lpc.utm_source = aad.utm_source
            AND lpc.visit_date = aad.campaign_date
    WHERE lpc.rn = 1
    GROUP BY
        lpc.rn,
        lpc.visit_date,
        lpc.utm_source,
        lpc.utm_medium,
        lpc.utm_campaign,
        aad.total_cost
)

SELECT
    visit_date,
    visitors_count,
    utm_source,
    utm_medium,
    utm_campaign,
    total_cost,
    leads_count,
    purchases_count,
    revenue
FROM aggregate_last_paid_click
ORDER BY
    revenue DESC NULLS LAST,
    visit_date ASC,
    visitors_count DESC,
    utm_source ASC,
    utm_medium ASC,
    utm_campaign ASC
LIMIT 15;
