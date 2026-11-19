# Phase 3 – Baseline Query Timings

**Team:** T0106 | **Lead:** Priyanka Tiwari | **Members:** Abhimanyu, Kushagra Kaushik | **Database:** de_algoarena_cp2 (PostgreSQL 14.20) | **Machine:** MacBook Pro (M4)

**Method:** `EXPLAIN (ANALYZE, BUFFERS)` · 3 runs each · average reported · write queries inside `BEGIN … ROLLBACK`

**Data:** 30,000 users · 3,000 channels · 30,000 videos · 129,253 subscriptions · 200,000 watch events · 60,000 comments · 8,000 playlists · 57,014 ad impressions

**Indexes present:** Only those automatically created by PRIMARY KEY and UNIQUE constraints. No additional indexes.

Raw plan files: `benchmarks/results/baseline/R01.txt` … `W05.txt`

Summary CSV: `benchmarks/results/baseline/summary.csv`

---

# Timing Table (all 30 queries)

| Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|-------|------|-----------:|-----------:|-----------:|-------------:|
| R01 | READ | 4.541 | 2.517 | 2.579 | 3.212 |
| R02 | READ | 0.049 | 0.082 | 0.041 | 0.057 |
| R03 | READ | 3.547 | 3.774 | 3.708 | 3.676 |
| R04 | READ | 6.290 | 6.132 | 6.154 | 6.192 |
| R05 | READ | 10.352 | 6.360 | 7.345 | 8.019 |
| R06 | READ | 2.381 | 2.765 | 2.862 | 2.669 |
| R07 | READ | 10.958 | 12.206 | 12.140 | 11.768 |
| R08 | READ | 7.922 | 10.581 | 11.002 | 9.835 |
| R09 | READ | 17.349 | 19.627 | 11.924 | 16.300 |
| R10 | READ | 11.492 | 14.945 | 11.664 | 12.700 |
| R11 | READ | 21.461 | 20.123 | 21.626 | 21.070 |
| R12 | READ | 16.606 | 18.355 | 14.573 | 16.511 |
| R13 | READ | 18.100 | 17.604 | 17.717 | 17.807 |
| R14 | READ | 11.258 | 10.919 | 10.280 | 10.819 |
| R15 | READ | 4.307 | 4.379 | 3.402 | 4.029 |
| R16 | READ | 21.284 | 16.379 | 16.382 | 18.015 |
| R17 | READ | 17.573 | 16.787 | 16.214 | 16.858 |
| R18 | READ | 11.165 | 11.626 | 11.797 | 11.529 |
| R19 | READ | 15424.963 | 15378.310 | 15406.854 | 15403.376 |
| R20 | READ | 11.813 | 12.435 | 11.538 | 11.929 |
| R21 | READ | 0.101 | 0.063 | 0.069 | 0.078 |
| R22 | READ | 19.340 | 21.004 | 21.530 | 20.625 |
| R23 | READ | 19.265 | 23.890 | 17.913 | 20.356 |
| R24 | READ | 2.443 | 1.738 | 1.962 | 2.048 |
| R25 | READ | 43.208 | 38.285 | 38.635 | 40.043 |
| W01 | WRITE | 0.549 | 0.501 | 0.472 | 0.507 |
| W02 | WRITE | 0.520 | 0.880 | 0.474 | 0.625 |
| W03 | WRITE | 0.342 | 0.231 | 0.249 | 0.274 |
| W04 | WRITE | 28.615 | 33.289 | 30.466 | 30.790 |
| W05 | WRITE | 3.480 | 4.238 | 3.016 | 3.578 |
| **Total** | | **15751.274** | **15710.025** | **15714.588** | **15725.295 ms** |

---

# Scan Type and Why Each Query is Slow or Fast

| Query | Observed Scan Type | Why slow / fast |
|-------|--------------------|-----------------|
| R01 | Seq Scan on videos | No composite index on `(channel_id, visibility, published_at)`. Needs filtering then sorting. |
| R02 | Index Scan on videos + channels | Uses PK lookup on `videos.video_id` and PK lookup on `channels.channel_id`. Very fast. |
| R03 | Seq Scan on videos + Index Only Scan on subscriptions | The subscriptions PK serves `user_id`, but videos still need filtering and sorting by `published_at`. |
| R04 | Seq Scan on videos | `ILIKE '%tutorial%'` cannot use a normal B-tree index because of the leading wildcard. |
| R05 | Seq Scan on watch_events | No index on `(user_id, started_at)`. Entire watch history scanned then sorted. |
| R06 | Seq Scan on videos | No index on `(visibility, published_at)`. Full scan to find scheduled videos. |
| R07 | Seq Scan on watch_events + videos | Large join between `watch_events` and `videos`; grouping by date requires scanning many rows. |
| R08 | Seq Scan on watch_events | No index on `video_id`. Full scan before aggregation. |
| R09 | Seq Scan on watch_events + videos | Joins `videos` and `watch_events`; average watch percentage is computed after scanning matching rows. |
| R10 | Seq Scan on watch_events + videos | No supporting date/video index; it filters and groups many watch records. |
| R11 | Seq Scan on watch_events + videos | Ranking within each category requires scanning and sorting grouped results. |
| R12 | Seq Scan on watch_events | Aggregates all watch events grouped by device. |
| R13 | Index Scan on subscriptions + Seq Scan on watch_events/videos | `NOT IN` scans watch history because no supporting index exists. |
| R14 | Seq Scan on video_reactions + videos | Scans reactions for every video in the channel. |
| R15 | Seq Scan on comments | No index on `(video_id, parent_comment_id, is_pinned, like_count)`. Requires filtering then sorting. |
| R16 | Seq Scan on watch_events/ad_impressions + Index Scan on videos | Three-table join and aggregation over ad impressions. |
| R17 | Seq Scan on watch_events + videos + channels | Aggregates watch hours for monetized channel eligibility. |
| R18 | Seq Scan on comments + videos | Checks every kids video against the comments table. |
| R19 | Repeated Seq Scans on channels/videos/watch_events | Correlated subqueries rescan videos and watch events per eligible channel, making this the 15.4-second outlier. |
| R20 | Seq Scan on watch_events | Reads all June watch events before grouping and window aggregation. |
| R21 | Index Scan on playlist_items + videos PKs | Composite PK `(playlist_id, position)` allows efficient ordered retrieval. |
| R22 | Seq Scan on videos | Groups all videos to detect duplicate uploads across channels. |
| R23 | Seq Scan on comments | OFFSET pagination forces PostgreSQL to process and sort many rows before returning 25. |
| R24 | Index Scan on subscriptions PK | The PK starts with `user_id`, so filtering on `channel_id` still scans much of the index. |
| R25 | Seq Scan on watch_events/ad_impressions/users | Joins three tables without supporting indexes for this access pattern. |
| W01 | No scan (INSERT) | Direct insert into videos. Fast unless constraints fail. |
| W02 | No scan (INSERT) | Inserts one watch event; minimal overhead. |
| W03 | Index Scan on videos PK | PK lookup on `video_id`, then updates one row. |
| W04 | Seq Scan on channels + subscriptions | Aggregates every subscription before updating channels. |
| W05 | Seq Scan on videos | Updates every scheduled video because no index on `(visibility, published_at)`. |

---

# Key Observations

1. **Most read queries perform sequential scans** because only PRIMARY KEY and UNIQUE indexes exist.

2. **Watch Events is expected to become the largest table**, making queries R05, R07, R08, R09, R10, R12, R16, R20, and R25 slower as the dataset grows.

3. **R19 is the dominant bottleneck at 15,403.376 ms**, because its correlated subqueries repeatedly scan videos and watch events for every monetized channel.

4. **R23 uses OFFSET pagination**, which becomes increasingly expensive for deeper pages since PostgreSQL must skip thousands of rows before returning results.

5. **W04 and W05 are full-table update operations** and are expected to have the highest write costs before optimization.

6. **Queries R02 and R21 should already be very fast** because they rely on PRIMARY KEY lookups and automatically created indexes.

7. **Phase 4 will focus on reducing sequential scans** by introducing carefully chosen indexes and rewriting expensive queries where appropriate.
