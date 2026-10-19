-- Project:  E-commerce Customer Churn Analysis
-- Purpose:  Turn the raw text tables into clean, typed tables
-- Input:    raw.customers, raw.customer_metrics, raw.churn_events
-- Output:   clean.customers, clean.customer_metrics, clean.churn_events
-- Author:   Sunidhi Jangid
-- Date:     2026-10-08
 
---Create Schemas

CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS clean;

---Raw Tables
DROP TABLE IF EXISTS raw.customers;

CREATE TABLE raw.customers(
   customer_id    TEXT,
   customer_segment   TEXT,
   customer_country   TEXT,
   customer_city    TEXT,
   subscription_type  TEXT,
   customer_age_month  TEXT,
   Dataset_year  TEXT
);

DROP TABLE IF EXISTS raw.customer_metrics;

CREATE TABLE raw.customer_metrics(
   customer_id  TEXT,
   total_spend_usd  TEXT,
   avg_order_value_usd  TEXT,
   num_purchases  TEXT,
   customer_lifetime_value_usd  TEXT,
   day_since_lasr_purchase  TEXT,
   satisfaction_score  TEXT,
   satisfaction_level  TEXT,
   suspport_tickets  TEXT,
   return_count  TEXT,
   engagement_level   TEXT,
   customer_value_category   TEXT,
   customer_health_score   TEXT,
   customer_health_category   TEXT,
   churn_risk_score  TEXT,
   churn_probability  TEXT,
   churn_risk_category   TEXT,
   is_high_risk_customer   TEXT,
   predicted_churn  TEXT
);

DROP TABLE IF EXISTS raw.churn_events;

CREATE TABLE raw.churn_events(
   churn_id  TEXT,
   customer_id  TEXT,
   is_churned   TEXT,
   churn_flag  TEXT,
   churn_date  TEXT,
   days_since_churn   TEXT,
   churn_reason   TEXT,
   churn_category  TEXT,
   prevention_methods  TEXT,
   support_interactions   TEXT,
   last_support_channel  TEXT,
   feedback_score  TEXT,
   loyality_score  TEXT,
   marketing_emails_sent  TEXT,
   marketing_emails_opened   TEXT,
   marketing_emails_clicked  TEXT,
   marketing_conversions  TEXT,
   social_media_engagemenet  TEXT,
   referral_count  TEXT,
   customer_retention_cost_usd  TEXT,
   recovery_revenue_usd  TEXT,
   churn_rate_indicator  TEXT,
   churn_revenue_impact_usd   TEXT,
   retention_probability TEXT
);

---Load CSV Files (right-click the table > Import/Export Data...)
--   Import | Format: csv | Header: ON | Delimiter:

---confirm the load

SELECT 'raw.customers'  AS table_name, COUNT(*) AS row_count FROM raw.customers
UNION ALL
SELECT 'raw.customer_metrics', COUNT(*) FROM raw.customer_metrics
UNION ALL
SELECT 'raw.churn_events', COUNT(*) FROM raw.churn_events;

SELECT * FROM raw.customers LIMIT 5;
SELECT * FROM raw.customer_metrics LIMIT 5;
SELECT * FROM raw.churn_events LIMIT 5;

-- CHECK 1: How many rows are in each table?
SELECT COUNT(*) AS rows_in_customers FROM raw.customers;
SELECT COUNT(*) AS rows_in_customer_metrics FROM raw.customer_metrics;
SELECT COUNT(*) AS rows_in_churn_events FROM raw.churn_events;

-- CHECK 2: Are the IDs unique?  (If total_rows = unique_ids, there are no duplicates)
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT customer_id) AS unique_ids FROM raw.customers;
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT churn_id) AS unique_ids FROM raw.churn_events;

-- CHECK 3: Why does churn_events have 50000 rows but only 31644 customers?
--(Because one customer can have several records)
SELECT COUNT(DISTINCT customer_id) AS customers_in_events FROM raw.churn_events;

-- CHECK 4: Do all events belong to a real customer? (expect 0)
SELECT COUNT(*) AS events_without_customer
FROM raw.churn_events e
LEFT JOIN raw.customers c
ON c.customer_id = e.customer_id
WHERE c.customer_id IS NULL;

-- CHECK 5: Empty values in important columns (expect 0 for all)
SELECT
    COUNT(*) FILTER (WHERE customer_id IS NULL OR customer_id  = '') AS empty_customer_id,
    COUNT(*) FILTER (WHERE churn_flag IS NULL OR churn_flag  = '') AS empty_churn_flag,
    COUNT(*) FILTER (WHERE churn_date IS NULL OR churn_date  = '') AS empty_churn_date
FROM raw.churn_events;

-- CHECK 6: The "fake missing" values. They are TEXT, not real NULLs.
SELECT subscription_type, COUNT(*) AS customers
FROM raw.customers
GROUP BY subscription_type
ORDER BY customers DESC;
 
SELECT prevention_methods, COUNT(*) AS records
FROM raw.churn_events
GROUP BY prevention_methods
ORDER BY records DESC;
 
SELECT churn_reason, COUNT(*) AS records
FROM raw.churn_events
GROUP BY churn_reason
ORDER BY records DESC;

-- CHECK 7: What do the dates look like?
SELECT churn_date, COUNT(*) AS records
FROM raw.churn_events
GROUP BY churn_date
ORDER BY records DESC
LIMIT 10;

-- CHECK 8: Do the two churn columns agree? (expect 0)
SELECT COUNT(*) AS disagreements
FROM raw.churn_events
WHERE (is_churned = 'Yes' AND churn_flag <> '1')
   OR (is_churned = 'No'  AND churn_flag <> '0');

-- CHECK 9: Spaces hiding at the start or end of text? (expect 0)
SELECT COUNT(*) AS rows_with_extra_spaces
FROM raw.customers
WHERE customer_segment <> btrim(customer_segment)
   OR customer_country <> btrim(customer_country);

-- CHECK 10: Impossible numbers.
-- Clicks cannot be higher than opens, but this dataset has about
-- 22,900 rows like that. We will FLAG them, not delete them.
SELECT COUNT(*) AS clicks_more_than_opens
FROM raw.churn_events
WHERE marketing_emails_clicked::int > marketing_emails_opened::int;

-- CHECK 11: Customers who both churned and did not churn.
SELECT COUNT(*) AS customers_with_mixed_status
FROM (
    SELECT customer_id
    FROM raw.churn_events
    GROUP BY customer_id
    HAVING COUNT(DISTINCT churn_flag) > 1
) AS t;

-- CHECK 12: Smallest and biggest values 
SELECT MIN(total_spend_usd::numeric) AS min_spend,
       MAX(total_spend_usd::numeric) AS max_spend,
       MIN(satisfaction_score::int) AS min_satisfaction,
       MAX(satisfaction_score::int) AS max_satisfaction
FROM raw.customer_metrics;

