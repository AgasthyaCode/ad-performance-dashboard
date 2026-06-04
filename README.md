# Cross-Channel Advertising Dashboard

Unifies Facebook, Google, and TikTok ad exports (Jan 2024) into one data model
and a single self-contained dashboard page.

## Files

| File | What it is |
|------|------------|
| `index.html` | The live dashboard — **one self-contained file**, no backend, no external JS libraries. Charts are pure SVG/CSS; data is baked in. |
| `unified_ad_performance.csv` | The unified table (330 rows: date × platform × campaign × ad group), with `spend` normalized to `cost` and revenue (`conversion_value`) present for Google only. |
| `bigquery_build.sql` | How the same model stands up on a cloud warehouse (raw tables → unified table → reporting views). Your "how I'd productionize it" reference. |



## Method notes (the judgment, not just the plumbing)

- **Comparable metrics are recomputed from raw counts** (impressions, clicks, cost,
  conversions). Platform-supplied CTR/CPC/engagement-rate columns were discarded so
  every channel is measured the same way.
- **Cross-channel ROAS is deliberately not shown.** Only Google reports revenue;
  ranking channels by ROAS would let Google "win" purely because the others are null.
  CPA is the comparable efficiency metric; Google's ROAS sits in its own fenced panel.
- **Headline finding:** Facebook is the most efficient channel ($7.64 CPA) but the
  smallest budget; TikTok is the largest budget (57%) at the worst CPA ($11.00).
  The dashboard recommends testing a budget shift — with the caveat that CPA
  optimization assumes equal conversion value, which is unverifiable without
  FB/TikTok revenue.
