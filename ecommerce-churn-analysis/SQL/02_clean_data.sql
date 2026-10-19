---DATA CLEANING

DROP TABLE IF EXISTS clean.customers;

---Clean customers Table
CREATE TABLE clean.customers AS
SELECT
    btrim(customer_id) AS customer_id,
    btrim(customer_segment) AS customer_segment,
    btrim(customer_country) AS customer_country,
    btrim(customer_city) AS customer_city,
    CASE WHEN btrim(subscription_type) = 'None'
         THEN 'No Subscription'
         ELSE btrim(subscription_type)
    END AS subscription_type,
    customer_age_month::int AS customer_age_months,
    dataset_year::int AS dataset_year
FROM raw.customers;

ALTER TABLE clean.customers ADD PRIMARY KEY (customer_id);

---Clean customer_metrics Table

DROP TABLE IF EXISTS clean.customer_metrics;

CREATE TABLE clean.customer_metrics AS
SELECT 
    btrim(customer_id) AS customer_id,
    total_spend_usd::numeric AS total_spend_usd,
    avg_order_value_usd::numeric AS avg_order_value_usd,
    num_purchases::int AS num_purchases,
    customer_lifetime_value_usd::numeric AS customer_lifetime_value_usd,
    day_since_lasr_purchase ::int AS days_since_last_purchase,
    satisfaction_score::int AS satisfaction_score,
    btrim(satisfaction_level) AS satisfaction_level,
    suspport_tickets::int AS support_tickets,
    return_count::int AS returns_count,
    btrim(engagement_level) AS engagement_level,
    btrim(customer_value_category) AS customer_value_category,
    customer_health_score::int AS customer_health_score,
    btrim(customer_health_category) AS customer_health_category,
    churn_risk_score::int AS churn_risk_score,
    churn_probability::numeric AS churn_probability,
    btrim(churn_risk_category) AS churn_risk_category,
    (is_high_risk_customer = 'Yes') AS is_high_risk_customer,
    (predicted_churn = 'Yes') AS predicted_churn,
    (customer_lifetime_value_usd::numeric < total_spend_usd::numeric) AS clv_below_spend_flag
FROM raw.customer_metrics;

ALTER TABLE clean.customer_metrics ADD PRIMARY KEY (customer_id);
ALTER TABLE clean.customer_metrics
    ADD FOREIGN KEY (customer_id) REFERENCES clean.customers (customer_id);

---Clean Churn_events Table

DROP TABLE IF EXISTS clean.churn_events;

CREATE TABLE clean.churn_events AS
SELECT
    btrim(churn_id) AS churn_id,
    btrim(customer_id) AS customer_id,
    (is_churned = 'Yes')  AS is_churned,
    churn_flag::int AS churn_flag,
    NULLIF(churn_date, 'Not Applicable')::timestamp::date AS churn_date,
    CASE WHEN churn_flag::int = 1 THEN days_since_churn::int END AS days_since_churn,
    NULLIF(btrim(churn_reason), 'Not Applicable') AS churn_reason,
    NULLIF(btrim(churn_category), 'Not Applicable') AS churn_category,
    CASE WHEN btrim(prevention_methods) = 'None'
         THEN 'No Intervention' ELSE btrim(prevention_methods)
    END AS prevention_method,
    support_interactions::int AS support_interactions,
    btrim(last_support_channel) AS last_support_channel,
    feedback_score::int AS feedback_score,
    loyality_score::numeric AS loyalty_score,
    marketing_emails_sent::int AS marketing_emails_sent,
    marketing_emails_opened::int AS marketing_emails_opened,
    marketing_emails_clicked::int AS marketing_emails_clicked,
    marketing_conversions::int AS marketing_conversions,
    CASE WHEN btrim(social_media_engagemenet) = 'None'
         THEN 'No Engagement' ELSE btrim(social_media_engagemenet)
    END AS social_media_engagement,
    referral_count::int AS referral_count,
    customer_retention_cost_usd::numeric AS customer_retention_cost_usd,
    recovery_revenue_usd::numeric AS recovery_revenue_usd,
    btrim(churn_rate_indicator) AS churn_rate_indicator,
    churn_revenue_impact_usd::numeric AS churn_revenue_impact_usd,
    retention_probability::numeric AS retention_probability,
    (marketing_emails_clicked::int > marketing_emails_opened::int) AS email_click_anomaly_flag
FROM raw.churn_events;

ALTER TABLE clean.churn_events ADD PRIMARY KEY (churn_id);
ALTER TABLE clean.churn_events
    ADD FOREIGN KEY (customer_id) REFERENCES clean.customers (customer_id);

---Indexes

CREATE INDEX idx_events_customer ON clean.churn_events (customer_id);
CREATE INDEX idx_events_date     ON clean.churn_events (churn_date);

---Helper tables

DROP TABLE IF EXISTS clean.customer_status;

CREATE TABLE clean.customer_status AS
SELECT
    customer_id,
    COUNT(*) AS n_records,
    SUM(churn_flag) AS n_churn_records,
    BOOL_OR(churn_flag = 1) AS ever_churned
FROM clean.churn_events
GROUP BY customer_id;

ALTER TABLE clean.customer_status ADD PRIMARY KEY (customer_id);

DROP TABLE IF EXISTS clean.churn_base;

CREATE TABLE clean.churn_base AS
SELECT
    e.*,
    c.customer_segment, c.customer_country, c.customer_city,
    c.subscription_type, c.customer_age_months,
    m.total_spend_usd, m.avg_order_value_usd, m.num_purchases,
    m.customer_lifetime_value_usd, m.days_since_last_purchase,
    m.satisfaction_score, m.satisfaction_level, m.support_tickets,
    m.returns_count, m.engagement_level, m.customer_value_category,
    m.customer_health_score, m.customer_health_category,
    m.churn_risk_score, m.churn_probability, m.churn_risk_category,
    m.is_high_risk_customer, m.predicted_churn
FROM clean.churn_events e
JOIN clean.customers c 
ON c.customer_id = e.customer_id
JOIN clean.customer_metrics m 
ON m.customer_id = e.customer_id;

SELECT 'customers' AS tbl, COUNT(*) AS n FROM clean.customers
UNION ALL SELECT 'customer_metrics', COUNT(*) FROM clean.customer_metrics
UNION ALL SELECT 'churn_events',     COUNT(*) FROM clean.churn_events
UNION ALL SELECT 'customer_status',  COUNT(*) FROM clean.customer_status
UNION ALL SELECT 'churn_base',       COUNT(*) FROM clean.churn_base;

---Nulls should exist only for active customers

SELECT
    COUNT(*) FILTER (WHERE churn_date IS NULL) AS null_dates,
    COUNT(*) FILTER (WHERE churn_reason IS NULL) AS null_reasons,
    COUNT(*) FILTER (WHERE churn_flag = 0) AS active_rows
FROM clean.churn_events;

---The old placeholder words must be gone 

SELECT
    (SELECT COUNT(*) FROM clean.customers WHERE subscription_type = 'None') AS none_subscription,
    (SELECT COUNT(*) FROM clean.churn_events WHERE prevention_method = 'None') AS none_prevention,
    (SELECT COUNT(*) FROM clean.churn_events WHERE social_media_engagement = 'None') AS none_social;


---Every event must belong to a customer

SELECT COUNT(*) AS orphan_events
FROM clean.churn_events e
LEFT JOIN clean.customers c 
ON c.customer_id = e.customer_id
WHERE c.customer_id IS NULL;

---Flag counts 

SELECT COUNT(*) FILTER (WHERE email_click_anomaly_flag) AS email_anomalies
FROM clean.churn_events;

SELECT COUNT(*) FILTER (WHERE clv_below_spend_flag) AS clv_below_spend
FROM clean.customer_metrics;