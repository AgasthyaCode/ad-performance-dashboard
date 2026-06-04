-- =====================================================================
--  Cross-Channel Ad Performance — Cloud Warehouse Build (BigQuery)
-- =====================================================================
--  This is the "how I'd stand it up in a cloud DB" companion to the
--  static dashboard. It mirrors the exact logic used to build the
--  unified table behind the dashboard, in BigQuery Standard SQL.
--
--  Pattern: 3 raw tables (as-loaded) -> 1 conformed unified table
--           -> reporting views the dashboard/BI tool reads from.
--
--  Run order: (0) load CSVs  (1) unified table  (2) reporting views
-- =====================================================================


-- ---------------------------------------------------------------------
-- 0. LOAD THE RAW CSVs  (run these in your shell, not in the SQL editor)
-- ---------------------------------------------------------------------
-- bq mk --dataset --location=US your_project:ads
--
-- bq load --autodetect --skip_leading_rows=1 --source_format=CSV \
--     ads.raw_facebook ./01_facebook_ads.csv
-- bq load --autodetect --skip_leading_rows=1 --source_format=CSV \
--     ads.raw_google   ./02_google_ads.csv
-- bq load --autodetect --skip_leading_rows=1 --source_format=CSV \
--     ads.raw_tiktok   ./03_tiktok_ads.csv
--
-- (--autodetect infers the schema. For production you'd pin an explicit
--  schema instead so a malformed file can't silently change column types.)


-- ---------------------------------------------------------------------
-- 1. UNIFIED TABLE
--    Reconciles the three different platform schemas into one grain:
--    date x platform x campaign x ad group.
--
--    Key reconciliations:
--      * Facebook "spend"  ==  Google/TikTok "cost"   -> cost
--      * Facebook ad_set / Google ad_group / TikTok adgroup -> adgroup
--      * conversion_value (revenue) exists for GOOGLE ONLY -> NULL elsewhere
--      * platform-specific metrics kept nullable, used only in fenced panels
--    Derived rates are intentionally NOT stored here; they are computed
--    in the reporting views so they can never drift from the raw counts.
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE ads.unified_ad_performance AS

SELECT
  DATE(date)              AS date,
  'Facebook'              AS platform,
  campaign_id,
  campaign_name,
  ad_set_id               AS adgroup_id,
  ad_set_name             AS adgroup_name,
  impressions,
  clicks,
  spend                   AS cost,          -- normalize spend -> cost
  conversions,
  CAST(NULL AS FLOAT64)   AS conversion_value,
  video_views,
  CAST(NULL AS INT64)     AS video_watch_100
FROM ads.raw_facebook

UNION ALL
SELECT
  DATE(date), 'Google',
  campaign_id, campaign_name,
  ad_group_id, ad_group_name,
  impressions, clicks, cost, conversions,
  conversion_value,                          -- revenue: Google only
  CAST(NULL AS INT64),                       -- no video_views
  CAST(NULL AS INT64)
FROM ads.raw_google

UNION ALL
SELECT
  DATE(date), 'TikTok',
  campaign_id, campaign_name,
  adgroup_id, adgroup_name,
  impressions, clicks, cost, conversions,
  CAST(NULL AS FLOAT64),                      -- no revenue
  video_views,
  video_watch_100
FROM ads.raw_tiktok;


-- ---------------------------------------------------------------------
-- 2a. REPORTING VIEW — channel scorecard
--     Every rate recomputed from raw counts so all channels are
--     measured identically (platform-supplied CTR/CPC are ignored).
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW ads.v_channel_summary AS
SELECT
  platform,
  SUM(impressions)                                  AS impressions,
  SUM(clicks)                                        AS clicks,
  ROUND(SUM(cost), 2)                                AS cost,
  SUM(conversions)                                   AS conversions,
  ROUND(SUM(clicks)      / SUM(impressions) * 100, 2) AS ctr_pct,
  ROUND(SUM(cost)        / SUM(clicks),          2)   AS cpc,
  ROUND(SUM(cost)        / SUM(impressions)*1000,2)   AS cpm,
  ROUND(SUM(cost)        / SUM(conversions),     2)   AS cpa,
  ROUND(SUM(conversions) / SUM(clicks) * 100,    2)   AS cvr_pct,
  ROUND(SUM(cost)        / SUM(SUM(cost))      OVER () * 100, 1) AS spend_share_pct,
  ROUND(SUM(conversions) / SUM(SUM(conversions)) OVER () * 100, 1) AS conv_share_pct
FROM ads.unified_ad_performance
GROUP BY platform;


-- ---------------------------------------------------------------------
-- 2b. REPORTING VIEW — daily trend
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW ads.v_daily_trend AS
SELECT date, platform,
       ROUND(SUM(cost),2) AS cost,
       SUM(conversions)   AS conversions
FROM ads.unified_ad_performance
GROUP BY date, platform
ORDER BY date, platform;


-- ---------------------------------------------------------------------
-- 2c. REPORTING VIEW — Google-only ROAS
--     Fenced off deliberately: revenue exists for Google alone, so a
--     cross-channel ROAS would be structurally misleading.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW ads.v_google_roas AS
SELECT
  ROUND(SUM(conversion_value), 2)               AS revenue,
  ROUND(SUM(cost), 2)                           AS cost,
  ROUND(SUM(conversion_value) / SUM(cost), 2)   AS roas
FROM ads.unified_ad_performance
WHERE platform = 'Google';


-- ---------------------------------------------------------------------
-- 2d. REPORTING VIEW — campaign efficiency ranking (by CPA)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW ads.v_campaign_efficiency AS
SELECT
  platform, campaign_name,
  ROUND(SUM(cost),2)                              AS cost,
  SUM(conversions)                                AS conversions,
  ROUND(SUM(cost)/SUM(conversions),2)             AS cpa,
  ROUND(SUM(clicks)/SUM(impressions)*100,2)       AS ctr_pct
FROM ads.unified_ad_performance
GROUP BY platform, campaign_name
ORDER BY cpa;
-- =====================================================================
