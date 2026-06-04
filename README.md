# Cross-Channel Advertising Dashboard

Unifies Facebook, Google, and TikTok ad exports (Jan 2024) into one data model
and a single self-contained dashboard page.

## Files

| File | What it is |
|------|------------|
| `index.html` | The live dashboard — **one self-contained file**, no backend, no external JS libraries. Charts are pure SVG/CSS; data is baked in. |
| `unified_ad_performance.csv` | The unified table (330 rows: date × platform × campaign × ad group), with `spend` normalized to `cost` and revenue (`conversion_value`) present for Google only. |
| `bigquery_build.sql` | How the same model stands up on a cloud warehouse (raw tables → unified table → reporting views). Your "how I'd productionize it" reference. |

## Publish the live link (GitHub Pages, ~3 minutes)

1. Create a new GitHub repo (public), e.g. `ad-performance-dashboard`.
2. Upload `index.html` to the repo root. (Drag-drop in the web UI is fine.)
3. Repo **Settings → Pages → Build and deployment**: Source = *Deploy from a branch*, Branch = `main`, folder = `/ (root)`. Save.
4. Wait ~1 minute. Your live URL appears at the top of the Pages settings:
   `https://<your-username>.github.io/ad-performance-dashboard/`

That URL is the deliverable. It is static, free, and stays up permanently.

> Note: GitHub Pages serves static files only — it cannot query a live database.
> The dashboard therefore carries an embedded snapshot of the data, which is the
> right choice for a fixed historical export. If a refreshable warehouse-backed
> link is required instead, run `bigquery_build.sql` and connect Looker Studio
> to the `ads.v_*` views.

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
