---EDA 

--- How big is the data and how much churn is there?
---1. Total records, churned records and churn rate (%)
-- Finding:  41.3% of the 50,000 records are churn (20,653 records).
-- Action:   Use as the headline KPI card.
SELECT
    COUNT(*)  AS total_records,
    SUM(churn_flag) AS churned_records,
    ROUND(100.0 * SUM(churn_flag) / COUNT(*), 2) AS churn_rate_pct
FROM clean.churn_events;

---2. Total Customers, churned customers and customer churn rate (%)
-- Finding:  About 50.4% of customers (15,959 of 31,644) churned at least once.
-- Action:   Always say whether a churn rate is by record or by customer.
SELECT
    COUNT(*) AS total_customers,
    COUNT(*) FILTER (WHERE ever_churned) AS customers_who_churned,
    ROUND(100.0 * COUNT(*) FILTER (WHERE ever_churned) / COUNT(*), 2) AS customer_churn_rate_pct
FROM clean.customer_status;

--- Who are our customers? 
---3. Customers per segment, with % of the total
---[The (SELECT COUNT(*) ...) in brackets returns the grand total]
SELECT customer_segment,
       COUNT(*) AS customers,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM clean.customers), 2) AS pct
FROM clean.customers
GROUP BY customer_segment
ORDER BY customers DESC;

---4. Customers per country
SELECT customer_country, COUNT(*) AS customers
FROM clean.customers
GROUP BY customer_country
ORDER BY customers DESC;

---5. Customers per subscription type
SELECT subscription_type, COUNT(*) AS customers
FROM clean.customers
GROUP BY subscription_type
ORDER BY customers DESC;

---6. Customers by tenure group (how long they have been with us)
SELECT
    CASE WHEN customer_age_months < 12 THEN '1) under 1 year'
         WHEN customer_age_months < 24 THEN '2) 1-2 years'
         WHEN customer_age_months < 36 THEN '3) 2-3 years'
         ELSE '4) 3+ years' END AS tenure_group,
    COUNT(*) AS customers
FROM clean.customers
GROUP BY tenure_group
ORDER BY tenure_group;

--- Numbers summary (min, average, median, max)

---7. Mean much bigger than median = a few huge values pull the average up.
SELECT
    MIN(total_spend_usd) AS min_spend,
    ROUND(AVG(total_spend_usd), 2) AS avg_spend,
    ROUND(percentile_cont(0.5) WITHIN GROUP (ORDER BY total_spend_usd)::numeric, 2) AS median_spend,
    MAX(total_spend_usd) AS max_spend
FROM clean.customer_metrics;
 
SELECT
    MIN(num_purchases) AS min_purchases,
    ROUND(AVG(num_purchases), 1) AS avg_purchases,
    MAX(num_purchases) AS max_purchases,
    ROUND(AVG(days_since_last_purchase), 1) AS avg_days_since_last_purchase,
    ROUND(AVG(satisfaction_score), 2) AS avg_satisfaction
FROM clean.customer_metrics;

--- Churn events (record grain)

---8. Why do customers leave?
SELECT churn_reason, COUNT(*) AS churned_records
FROM clean.churn_events
WHERE churn_flag = 1
GROUP BY churn_reason
ORDER BY churned_records DESC;

---9. Reason groups
SELECT churn_category, COUNT(*) AS churned_records
FROM clean.churn_events
WHERE churn_flag = 1
GROUP BY churn_category
ORDER BY churned_records DESC;
 
---10. Churn per month
SELECT DATE_TRUNC('month', churn_date)::date AS churn_month,
       COUNT(*) AS churned_records
FROM clean.churn_events
WHERE churn_flag = 1
GROUP BY churn_month
ORDER BY churn_month;
 
---11. Which retention actions were used?
SELECT prevention_method, COUNT(*) AS records
FROM clean.churn_events
GROUP BY prevention_method
ORDER BY records DESC;

---12. Which groups churn MORE? 

--- By segment
-- Finding:  Consumer is highest (43.6%) and Premium lowest (38.5%), a small gap.
-- Action:   Segment is not the main driver; check engagement and satisfaction.
SELECT customer_segment,
       COUNT(*) AS records,
       SUM(churn_flag) AS churned,
       ROUND(100.0 * SUM(churn_flag) / COUNT(*), 2) AS churn_rate_pct
FROM clean.churn_base
GROUP BY customer_segment
ORDER BY churn_rate_pct DESC;
 
--- By country
-- Finding:  All countries are close together, about 39-43%.
-- Action:   Do not plan country-specific campaigns from churn rate alone.
SELECT customer_country,
       COUNT(*) AS records,
       ROUND(100.0 * SUM(churn_flag) / COUNT(*), 2) AS churn_rate_pct
FROM clean.churn_base
GROUP BY customer_country
ORDER BY churn_rate_pct DESC;
 
--- By subscription type
-- Finding:  No subscription churns at 48.3%, paid plans at about 38-39%.
-- Action:   Encourage free users to take a subscription.
SELECT subscription_type,
       COUNT(*) AS records,
       ROUND(100.0 * SUM(churn_flag) / COUNT(*), 2) AS churn_rate_pct
FROM clean.churn_base
GROUP BY subscription_type
ORDER BY churn_rate_pct DESC;
 
--- By engagement level
-- Finding:  Low engagement churns at 61.9%; medium and high at about 32.7%.
-- Action:   Make low engagement the first target group.
SELECT engagement_level,
       COUNT(*) AS records,
       ROUND(100.0 * SUM(churn_flag) / COUNT(*), 2) AS churn_rate_pct
FROM clean.churn_base
GROUP BY engagement_level
ORDER BY churn_rate_pct DESC;
 
--- By satisfaction score (1 = very unhappy, 5 = very happy)
-- Finding:  Scores 1-2 churn at about 59-60%; scores 3-5 at about 29-30%.
-- Action:   Contact unhappy customers (score 1-2) early.
SELECT satisfaction_score,
       COUNT(*) AS records,
       ROUND(100.0 * SUM(churn_flag) / COUNT(*), 2) AS churn_rate_pct
FROM clean.churn_base
GROUP BY satisfaction_score
ORDER BY satisfaction_score;
 
--- By how long since the last purchase
-- Finding:  Bought within 30 days: 35.7% churn; over 180 days: about 46%.
-- Action:   Start win-back messages after about 90 days of silence.
SELECT
    CASE WHEN days_since_last_purchase <= 30  THEN '1) 0-30 days'
         WHEN days_since_last_purchase <= 90  THEN '2) 31-90 days'
         WHEN days_since_last_purchase <= 180 THEN '3) 91-180 days'
         ELSE '4) over 180 days' END AS recency_group,
    COUNT(*) AS records,
    ROUND(100.0 * SUM(churn_flag) / COUNT(*), 2) AS churn_rate_pct
FROM clean.churn_base
GROUP BY recency_group
ORDER BY recency_group;
 
--- By customer value category
-- Finding:  Churn is about 41% in every value category.
-- Action:   Value category does not explain churn.
SELECT customer_value_category,
       COUNT(*) AS records,
       ROUND(100.0 * SUM(churn_flag) / COUNT(*), 2) AS churn_rate_pct
FROM clean.churn_base
GROUP BY customer_value_category
ORDER BY churn_rate_pct DESC;

---13. Churned vs active customers (side by side averages)
SELECT
    churn_flag,                                   -- 1 = churned, 0 = active
    COUNT(*) AS records,
    ROUND(AVG(customer_age_months), 1)  AS avg_tenure_months,
    ROUND(AVG(total_spend_usd), 0) AS avg_total_spend,
    ROUND(AVG(num_purchases), 1) AS avg_purchases,
    ROUND(AVG(days_since_last_purchase),1) AS avg_days_since_purchase,
    ROUND(AVG(satisfaction_score), 2) AS avg_satisfaction,
    ROUND(AVG(support_tickets), 2) AS avg_tickets,
    ROUND(AVG(returns_count), 2) AS avg_returns,
    ROUND(AVG(loyalty_score), 1) AS avg_loyalty
FROM clean.churn_base
GROUP BY churn_flag
ORDER BY churn_flag;
 

---14. Correlation with churn (-1 to +1, near 0 = no relation)
--corr() needs numbers only. A positive value means "more of this, more churn". Correlation does NOT prove cause.
SELECT
    ROUND(corr(churn_flag, satisfaction_score)::numeric, 3) AS satisfaction,
    ROUND(corr(churn_flag, days_since_last_purchase)::numeric, 3) AS days_since_purchase,
    ROUND(corr(churn_flag, customer_age_months)::numeric, 3) AS tenure,
    ROUND(corr(churn_flag, support_tickets)::numeric, 3) AS tickets,
    ROUND(corr(churn_flag, loyalty_score)::numeric, 3) AS loyalty
FROM clean.churn_base;
 
---15. Money
SELECT
    ROUND(SUM(churn_revenue_impact_usd), 0) AS revenue_lost,
    ROUND(SUM(customer_retention_cost_usd), 0) AS retention_cost,
    ROUND(SUM(recovery_revenue_usd), 0) AS recovered_revenue
FROM clean.churn_events;
