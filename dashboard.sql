-- 1. Сколько пользователей заходит на сайт?

SELECT COUNT(DISTINCT visitor_id) AS visitors_count
FROM sessions;

SELECT
    TO_CHAR(visit_date, 'YYYY-MM-DD') AS v_date,
    COUNT(DISTINCT visitor_id) AS visitors_count
FROM sessions
GROUP BY v_date;


-- 2. Какие каналы их приводят на сайт? Хочется видеть по дням/неделям/месяцам

SELECT
    LOWER(source) AS source,
    TO_CHAR(visit_date, 'YYYY-MM-DD') AS v_date,
    COUNT(DISTINCT visitor_id) AS visitor_count
FROM sessions
GROUP BY source, v_date
ORDER BY v_date;

SELECT
    LOWER(source) AS source,
    COUNT(DISTINCT visitor_id) AS visitor_count
FROM sessions
GROUP BY source
ORDER BY visitor_count DESC;


-- 3. Сколько лидов к нам приходят?

SELECT COUNT(DISTINCT lead_id)
FROM leads;

SELECT
    TO_CHAR(created_at, 'YYYY-MM-DD') AS created_date,
    COUNT(DISTINCT lead_id) AS lead_count
FROM leads
GROUP BY created_date;


-- 4.1. Какая конверсия из клика в лид? А из лида в оплату? (по платным каналам)

WITH paid_sessions AS (
    SELECT
        *,
        ROW_NUMBER()
            OVER (PARTITION BY visitor_id ORDER BY visit_date DESC)
        AS rn
    FROM sessions
    WHERE medium IN ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
),

paid_clicks AS (
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

count_conversion AS (
    SELECT
        COUNT(DISTINCT visitor_id) AS paid_click_count,
        COUNT(DISTINCT lead_id) AS lead_count,
        SUM(
            CASE
                WHEN
                    closing_reason = 'Успешная продажа'
                    THEN 1
                ELSE 0
            END
        ) AS successful_sales_count
    FROM paid_clicks
)

SELECT
    *,
    ROUND(lead_count / paid_click_count::NUMERIC * 100, 2) AS click_to_lead,
    ROUND(successful_sales_count / lead_count::NUMERIC * 100, 2) AS lead_to_sale
FROM count_conversion;

-- 4.2. Какая конверсия из клика в лид? А из лида в оплату? (по бесплатным каналам)

WITH free_sessions AS (
    SELECT
        *,
        ROW_NUMBER()
            OVER (PARTITION BY visitor_id ORDER BY visit_date DESC)
        AS rn
    FROM sessions
    WHERE medium IN ('organic')
),

free_clicks AS (
    SELECT
        fs.visitor_id,
        fs.visit_date,
        fs.source AS utm_source,
        fs.medium AS utm_medium,
        fs.campaign AS utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id
    FROM free_sessions AS fs
    LEFT JOIN leads AS l
        ON fs.visitor_id = l.visitor_id
    WHERE
        (
            fs.rn = 1
            AND fs.visit_date <= l.created_at
        )
        OR (
            fs.rn = 1
            AND l.created_at IS NULL
        )
    ORDER BY
        l.amount DESC NULLS LAST,
        fs.visit_date ASC,
        utm_source ASC,
        utm_medium ASC,
        utm_campaign ASC
),

count_conversion AS (
    SELECT
        COUNT(DISTINCT visitor_id) AS free_click_count,
        COUNT(DISTINCT lead_id) AS lead_count,
        SUM(
            CASE
                WHEN
                    closing_reason = 'Успешная продажа'
                    THEN 1
                ELSE 0
            END
        ) AS successful_sales_count
    FROM free_clicks
)

SELECT
    *,
    ROUND(lead_count / free_click_count::NUMERIC * 100, 2) AS click_to_lead,
    ROUND(successful_sales_count / lead_count::NUMERIC * 100, 2) AS lead_to_sale
FROM count_conversion;

-- 5. Сколько мы тратим по разным каналам в динамике?

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
),

t1 AS (
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
)

SELECT
    visit_date,
    utm_source,
    SUM(total_cost) AS overall_cost,
    SUM(revenue) AS overall_revenue
FROM t1
WHERE utm_source IN ('yandex', 'vk')
GROUP BY
	visit_date,
	utm_source;

-- 6.1. Окупаются ли каналы (vk и yandex)?

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
),

t1 AS (
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
)

SELECT
    utm_source,
    SUM(visitors_count) AS visitors_count,
    SUM(total_cost) AS total_cost,
    SUM(revenue) AS total_revenue
FROM t1
WHERE utm_source IN ('yandex', 'vk')
GROUP BY utm_source;

-- 6.2. Какие показатели у бесплатных каналов?

WITH paid_sessions AS (
    SELECT
        *,
        ROW_NUMBER()
            OVER (PARTITION BY visitor_id ORDER BY visit_date DESC)
        AS rn
    FROM sessions
    WHERE medium IN ('organic')
),

t1 AS (
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
)

SELECT
    utm_source AS source,
    COUNT(DISTINCT visitor_id) AS visitors_count,
    SUM(amount) AS overall_revenue
FROM t1
GROUP BY source
ORDER BY overall_revenue DESC NULLS LAST;

-- CPU, CPL, CPPU, ROI

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
),

t1 AS (
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
),

t2 AS (
    SELECT
        SUM(total_cost) AS total_cost,
        SUM(revenue) AS total_revenue,
        SUM(purchases_count) AS total_purchases
    FROM t1
)

SELECT
    ROUND((total_cost / 169140), 2) AS cpu,
    ROUND((total_cost / 1300), 2) AS cpl,
    ROUND((total_cost / total_purchases), 2) AS cppu,
    ROUND(((total_revenue - total_cost) / total_cost * 100.0), 2) AS roi
FROM t2;

