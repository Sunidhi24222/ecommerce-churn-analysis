---Buisness Queries

---Q1. What are the headline numbers (KPIs) for the dashboard cards?
-- Finding:  50,000 records, 31,644 customers, 41.3% churn by record, about $207M revenue lost.
-- Action:   Use these as the KPI cards on the dashboard overview page.
SELECT
    COUNT(*) AS total_records,
    COUNT(DISTINCT customer_id) AS total_customers,
    ROUND(100.0 * SUM(churn_flag) / COUNT(*), 2) AS churn_rate_pct,
    ROUND(SUM(churn_revenue_impact_usd), 0) AS revenue_lost_usd
FROM clean.churn_base;

---Q2. Which segment has the highest churn rate?
-- Finding:  Consumer is highest (43.6%), Premium lowest (38.5%), a small gap.
-- Action:   Segment alone is not the main driver; look at engagement and satisfaction.
SELECT customer_segment,
       COUNT(*) AS records,
       ROUND(100.0 * SUM(churn_flag) / COUNT(*), 2) AS churn_rate_pct
FROM clean.churn_base
GROUP BY customer_segment
ORDER BY churn_rate_pct DESC;

---Q3. Which 5 countries have the highest churn rate?
-- Finding:  All countries are within about 39-43%. (India, Singapore, Australia, Italy, Japan)
-- Action:   Do not build country-specific campaigns on churn rate alone.
SELECT customer_country,
       ROUND(100.0 * SUM(churn_flag) / COUNT(*), 2) AS churn_rate_pct
FROM clean.churn_base
GROUP BY customer_country
ORDER BY churn_rate_pct DESC
LIMIT 5;

---Q4. Where do we lose the most MONEY? (rate and money are not the same thing)
-- Finding:  (Singapore)
-- Action:   Prioritise countries with the biggest money loss, not only the highest rate.
SELECT customer_country,
       ROUND(SUM(churn_revenue_impact_usd), 0) AS revenue_lost_usd
FROM clean.churn_base
GROUP BY customer_country
ORDER BY revenue_lost_usd DESC
LIMIT 10;

---Q5. What are the top 5 reasons customers leave, and what % does each cause?
-- Finding:  Poor Customer Service is the top reason (about 18%), price-related reasons together are about 20%.
-- Action:   Improve customer service and review pricing.
SELECT churn_reason,
       COUNT(*) AS churned_records,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM clean.churn_events WHERE churn_flag = 1), 2) AS pct_of_churn
FROM clean.churn_events
WHERE churn_flag = 1
GROUP BY churn_reason
ORDER BY churned_records DESC
LIMIT 5;

---Q6. Does low satisfaction lead to more churn?
-- Finding:  Scores 1-2 churn at about 59-60%; scores 3-5 at about 29-30%.
-- Action:   Contact unhappy customers (score 1-2) early.
SELECT satisfaction_score,
       COUNT(*) AS records,
       ROUND(100.0 * SUM(churn_flag) / COUNT(*), 2) AS churn_rate_pct
FROM clean.churn_base
GROUP BY satisfaction_score
ORDER BY satisfaction_score;

---Q7. Do our retention actions work?
-- Compare the churn rate of each action with 'No Intervention'.
-- ROI = (money recovered - money spent) / money spent
-- Finding:  About 31-34% churn with any action vs 44.7% with none; the actions perform almost the same.
-- Action:   Keep the programme and test it with an A/B test.
SELECT prevention_method,
       COUNT(*) AS records,
       ROUND(100.0 * SUM(churn_flag) / COUNT(*), 2) AS churn_rate_pct,
       ROUND(SUM(customer_retention_cost_usd), 0) AS cost_usd,
       ROUND(SUM(recovery_revenue_usd), 0) AS recovered_usd,
       ROUND((SUM(recovery_revenue_usd) - SUM(customer_retention_cost_usd))
             / SUM(customer_retention_cost_usd), 2) AS ROI
FROM clean.churn_events
GROUP BY prevention_method
ORDER BY churn_rate_pct;

---Q8. Which valuable customers did we lose? (top 20 by lifetime value)
-- Finding:  (The 20 most valuable churned records are worth about $62.9K-$64.3K each.
--           12 of 20 are Consumer, 5 Premium and 3 Small Business.
--           Poor Customer Service is the top reason (5 of 20), then Found Alternative (4).
--           Countries are spread out (Mexico appears most, 4 times).)
-- Action:   Assign account managers to the most valuable customers.
SELECT customer_id, customer_segment, customer_country,
       customer_lifetime_value_usd, churn_date, churn_reason
FROM clean.churn_base
WHERE churn_flag = 1
ORDER BY customer_lifetime_value_usd DESC
LIMIT 20;

---Q9. High-risk customers who have NOT churned yet.
-- Finding:  452 high-risk customers who have not churned hold about $12.1M in lifetime value
-- Action:   Sales team contacts them, most valuable first.
SELECT c.customer_id, c.customer_segment, c.customer_country,
       m.customer_lifetime_value_usd, m.churn_risk_score, m.days_since_last_purchase
FROM clean.customer_metrics m
JOIN clean.customers c 
ON c.customer_id = m.customer_id
JOIN clean.customer_status s 
ON s.customer_id = m.customer_id
WHERE m.is_high_risk_customer = TRUE
  AND s.ever_churned = FALSE
ORDER BY m.customer_lifetime_value_usd DESC;

---Q10. Is churn going up or down month by month? 
-- Step 1 (the WITH part) counts churn per month.
-- Step 2 uses LAG() to bring the PREVIOUS month onto the same row, so we can calculate the change in %.
-- Finding:  Monthly churn is flat, about 1,600-1,800 records a month, with no clear trend.
-- Action:   No seasonal campaign needed; churn is steady all year.
WITH monthly AS (
    SELECT DATE_TRUNC('month', churn_date)::date AS churn_month,
           COUNT(*) AS churned_records
    FROM clean.churn_events
    WHERE churn_flag = 1
    GROUP BY churn_month
)
SELECT churn_month,
       churned_records,
       LAG(churned_records) OVER (ORDER BY churn_month) AS previous_month,
       ROUND(100.0 * (churned_records - LAG(churned_records) OVER (ORDER BY churn_month))
             / LAG(churned_records) OVER (ORDER BY churn_month), 1) AS change_pct,
       SUM(churned_records) OVER (ORDER BY churn_month) AS running_total
FROM monthly
ORDER BY churn_month;

---Q11. Which country + segment combinations are the worst?
-- Finding:  (The overall churn rate is 41.3%. The worst pair is Canada-Consumer
--           (46.2%, 600 of 1,300 records), then Japan-Small Business (45.8%),
--           Pakistan-Consumer (45.4%), Spain-Consumer (45.2%) and
--           India-Consumer (44.9%). 7 of the top 10 pairs are Consumer.
--           The best pairs are Premium: Canada-Premium (33.5%) and
--           Japan-Premium (34.8%). The gap between best and worst is about 12.6 points.)
-- Action:   Focus retention budget on Consumer customers in Canada, Pakistan,
--           Spain and India, and on Small Business in Japan. 
SELECT customer_country, customer_segment
       COUNT(*) AS records,
       ROUND(100.0 * SUM(churn_flag) / COUNT(*), 2) AS churn_rate_pct
FROM clean.churn_base
GROUP BY customer_country, customer_segment
HAVING COUNT(*) >= 200
ORDER BY churn_rate_pct DESC
LIMIT 10;

---Q12. Which health groups churn most, and which lose the most revenue?
-- Finding:  Churn rises as health falls: Excellent 33.1%, Good 59.4% Fair 72.2%, Poor 76.4% (overall 41.3%).
--           But the money tells a different story: Excellent customers are 74% of all records and account for $122.3M (59%) of the revenue
--           lost, simply because there are so many of them.
-- Action:   Run two tracks: a rescue programme for Poor, Fair and Good customers (high rates), 
--           and a check on why a third of Excellent customers still leave (high money).
SELECT customer_health_category,
       COUNT(*) AS records,
       ROUND(100.0 * SUM(churn_flag) / COUNT(*), 2) AS churn_rate_pct,
       ROUND(SUM(churn_revenue_impact_usd), 0) AS revenue_lost_usd,
       ROUND(100.0 * SUM(churn_revenue_impact_usd)
             / (SELECT SUM(churn_revenue_impact_usd) FROM clean.churn_base), 1) AS pct_of_total_loss
FROM clean.churn_base            
GROUP BY customer_health_category
ORDER BY churn_rate_pct DESC;

