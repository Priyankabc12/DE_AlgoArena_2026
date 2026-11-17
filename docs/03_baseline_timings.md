# Phase 3 – Baseline Query Timings

**Team:** <Your Team ID> | **Lead:** <Leader Name> | **Members:** <Member Names> | **Database:** youtube_db (PostgreSQL 16.x) | **Machine:** <Your Machine>

**Method:** `EXPLAIN (ANALYZE, BUFFERS)` · 3 runs each · average reported · write queries inside `BEGIN … ROLLBACK`

**Data:** <Number of users> users · <Number of channels> channels · <Number of videos> videos · <Number of subscriptions> subscriptions · <Number of watch_events> watch events · <Number of comments> comments · <Number of playlists> playlists · <Number of ad_impressions> ad impressions

**Indexes present:** Only those automatically created by PRIMARY KEY and UNIQUE constraints. No additional indexes.

Raw plan files: `benchmarks/results/baseline/R01.txt` … `W05.txt`

Summary CSV: `benchmarks/results/baseline/summary.csv`

---

# Timing Table (all 30 queries)

| Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|-------|------|-----------:|-----------:|-----------:|-------------:|
| R01 | READ | -- | -- | -- | -- |
| R02 | READ | -- | -- | -- | -- |
| R03 | READ | -- | -- | -- | -- |
| R04 | READ | -- | -- | -- | -- |
| R05 | READ | -- | -- | -- | -- |
| R06 | READ | -- | -- | -- | -- |
| R07 | READ | -- | -- | -- | -- |
| R08 | READ | -- | -- | -- | -- |
| R09 | READ | -- | -- | -- | -- |
| R10 | READ | -- | -- | -- | -- |
| R11 | READ | -- | -- | -- | -- |
| R12 | READ | -- | -- | -- | -- |
| R13 | READ | -- | -- | -- | -- |
| R14 | READ | -- | -- | -- | -- |
| R15 | READ | -- | -- | -- | -- |
| R16 | READ | -- | -- | -- | -- |
| R17 | READ | -- | -- | -- | -- |
| R18 | READ | -- | -- | -- | -- |
| R19 | READ | -- | -- | -- | -- |
| R20 | READ | -- | -- | -- | -- |
| R21 | READ | -- | -- | -- | -- |
| R22 | READ | -- | -- | -- | -- |
| R23 | READ | -- | -- | -- | -- |
| R24 | READ | -- | -- | -- | -- |
| R25 | READ | -- | -- | -- | -- |
| W01 | WRITE | -- | -- | -- | -- |
| W02 | WRITE | -- | -- | -- | -- |
| W03 | WRITE | -- | -- | -- | -- |
| W04 | WRITE | -- | -- | -- | -- |
| W05 | WRITE | -- | -- | -- | -- |
| **Total** | | | | | **-- ms** |

---

# Scan Type and Why Each Query is Slow or Fast

| Query | Expected Scan Type | Why slow / fast |
|-------|--------------------|-----------------|
| R01 | Seq Scan on videos | No composite index on `(channel_id, visibility, published_at)`. Needs filtering then sorting. |
| R02 | Index Scan | Uses PK lookup on `videos.video_id` and PK lookup on `channels.channel_id`. Very fast. |
| R03 | Seq Scan on subscriptions + videos | No index on `(user_id, channel_id)` beyond PK order and no index for sorting by `published_at`. |
| R04 | Seq Scan on videos | `ILIKE '%tutorial%'` cannot use a normal B-tree index because of the leading wildcard. |
| R05 | Seq Scan on watch_events | No index on `(user_id, started_at)`. Entire watch history scanned then sorted. |
| R06 | Seq Scan on videos | No index on `(visibility, published_at)`. Full scan to find scheduled videos. |
| R07 | Seq Scan + Hash Join | Large join between `watch_events` and `videos`; grouping by date requires scanning many rows. |
| R08 | Seq Scan on watch_events | No index on `video_id`. Full scan before aggregation. |
| R09 | Seq Scan + Aggregate | Joins `videos` and `watch_events`; average watch percentage computed after scanning matching rows. |
| R10 | Seq Scan | No index on `(is_short, started_at)`. Filters and groups many watch records. |
| R11 | Seq Scan + Window Function | Ranking within each category requires scanning and sorting grouped results. |
| R12 | Seq Scan on watch_events | Aggregates all watch events grouped by device. |
| R13 | Seq Scan + Subquery | `NOT IN` subquery scans watch history because no supporting index. |
| R14 | Seq Scan + LEFT JOIN | Scans reactions for every video in the channel. |
| R15 | Seq Scan on comments | No index on `(video_id, parent_comment_id, is_pinned, like_count)`. Requires filtering then sorting. |
| R16 | Seq Scan + Hash Join | Three-table join and aggregation over ad impressions. |
| R17 | Seq Scan | Aggregates watch hours for monetized channel eligibility. |
| R18 | Seq Scan + EXISTS | Checks every kids video against the comments table. |
| R19 | Correlated Subqueries | Each monetized channel executes separate subqueries, increasing execution time as channels grow. |
| R20 | Seq Scan | Reads all June watch events before grouping and window aggregation. |
| R21 | Index Scan on PK | Composite PK `(playlist_id, position)` allows efficient ordered retrieval. |
| R22 | Seq Scan | Groups all videos to detect duplicate uploads across channels. |
| R23 | Seq Scan + Sort | OFFSET pagination forces PostgreSQL to process many rows before returning 25. |
| R24 | Seq Scan | Aggregates subscriptions by month for one channel. |
| R25 | Seq Scan + Join | Joins ad impressions, watch events, and users without supporting indexes on premium dates. |
| W01 | INSERT | Direct insert into videos. Fast unless constraints fail. |
| W02 | INSERT | Inserts one watch event; minimal overhead. |
| W03 | Index Scan | PK lookup on `video_id`, then updates one row. |
| W04 | Seq Scan | Aggregates every subscription before updating channels. |
| W05 | Seq Scan | Updates every scheduled video because no index on `(visibility, published_at)`. |

---

# Key Observations

1. **Most read queries perform sequential scans** because only PRIMARY KEY and UNIQUE indexes exist.

2. **Watch Events is expected to become the largest table**, making queries R05, R07, R08, R09, R10, R12, R16, R20, and R25 slower as the dataset grows.

3. **R19 is likely one of the slowest queries** because it uses correlated subqueries that execute once for every monetized channel.

4. **R23 uses OFFSET pagination**, which becomes increasingly expensive for deeper pages since PostgreSQL must skip thousands of rows before returning results.

5. **W04 and W05 are full-table update operations** and are expected to have the highest write costs before optimization.

6. **Queries R02 and R21 should already be very fast** because they rely on PRIMARY KEY lookups and automatically created indexes.

7. **Phase 4 will focus on reducing sequential scans** by introducing carefully chosen indexes and rewriting expensive queries where appropriate.