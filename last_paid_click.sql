WITH LastPaidClick AS (
	SELECT
		visitor_id,
		MAX(visit_date) AS visit_date,
		source,
		medium,
		campaign
	FROM sessions AS s
	WHERE
		source LIKE '%cpc%'
		OR source LIKE '%cpm%'
		OR source LIKE '%cpa%'
		OR source LIKE '%youtube%'
		OR source LIKE '%cpp%'
		OR source LIKE '%tg%'
		OR source LIKE '%social%'
		OR medium LIKE '%cpc%'
		OR medium LIKE '%cpm%'
		OR medium LIKE '%cpa%'
		OR medium LIKE '%youtube%'
		OR medium LIKE '%cpp%'
		OR medium LIKE '%tg%'
		OR medium LIKE '%social%'
		OR campaign LIKE '%cpc%'
		OR campaign LIKE '%cpm%'
		OR campaign LIKE '%cpa%'
		OR campaign LIKE '%youtube%'
		OR campaign LIKE '%cpp%'
		OR campaign LIKE '%tg%'
		OR campaign LIKE '%social%'
	GROUP BY 1, 3, 4, 5
)
SELECT
	l.visitor_id,
	lpc.visit_date,
	lpc.source AS utm_source,
	lpc.medium AS utm_medium,
	lpc.campaign AS utm_campaign,
	l.lead_id,
	l.created_at,
	l.amount,
	l.closing_reason,
	l.status_id
FROM leads AS l
INNER JOIN LastPaidClick AS lpc
USING (visitor_id)
ORDER BY
	amount DESC NULLS LAST,
	visit_date ASC,
	utm_source ASC,
	utm_medium ASC,
	utm_campaign ASC;