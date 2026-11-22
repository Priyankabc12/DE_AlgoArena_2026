# Phase 5 – Scalability Report

**Team:** T0106 | **Database:** de_algoarena_cp4 (PostgreSQL 14.20) | **Machine:** MacBook Pro (M4)

## Method and faculty dataset

This report uses the faculty `large_data` CSVs supplied on 22 November 2026.
The database was rebuilt from `sql/01_schema.sql`, loaded in foreign-key order,
and validated with the following actual row counts:

| Table | Seed rows | Faculty large rows |
|---|---:|---:|
| users | 30,000 | 600,000 |
| channels | 3,000 | 60,000 |
| videos | 30,000 | 600,000 |
| subscriptions | 129,253 | 2,598,598 |
| watch_events | 200,000 | 4,000,000 |
| video_reactions | 67,417 | 1,350,452 |
| comments | 60,000 | 1,200,000 |
| playlists | 8,000 | 160,000 |
| playlist_items | 56,005 | 1,120,003 |
| ad_impressions | 57,014 | 1,139,137 |

The existing CP3 indexes were applied unchanged, followed by `ANALYZE`. Only
`sql/06_optimized_queries.sql` was benchmarked. Each query ran three times with
`EXPLAIN (ANALYZE, BUFFERS)`; writes ran inside `BEGIN … ROLLBACK`. Raw plans
and averages are in `benchmarks/results/large/`.

## Results and targets

Growth is `faculty large average ÷ optimized seed average`.

| Query | Seed (ms) | Large (ms) | Growth | Target | Met? | Action |
|---|---:|---:|---:|---:|:---:|---|
| R01 | 0.051 | 0.118 | 2.31× | <5 ms | ✅ | None |
| R02 | 0.119 | 0.195 | 1.64× | <5 ms | ✅ | None |
| R03 | 0.179 | 0.638 | 3.56× | <5 ms | ✅ | None |
| R04 | 1.889 | 34.983 | 18.52× | <250 ms | ✅ | None |
| R05 | 0.652 | 0.480 | 0.74× | <5 ms | ✅ | None |
| R06 | 0.120 | 0.638 | 5.32× | <250 ms | ✅ | None |
| R07 | 0.114 | 3.801 | 33.34× | <250 ms | ✅ | None |
| R08 | 0.104 | 0.143 | 1.38× | <250 ms | ✅ | None |
| R09 | 0.202 | 2.627 | 13.00× | <250 ms | ✅ | None |
| R10 | 3.541 | 25.231 | 7.13× | <5,000 ms | ✅ | None |
| R11 | 14.753 | 249.686 | 16.92× | <5,000 ms | ✅ | None |
| R12 | 14.774 | 231.474 | 15.67× | <5,000 ms | ✅ | None |
| R13 | 0.135 | 0.607 | 4.50× | <250 ms | ✅ | None |
| R14 | 0.581 | 1.662 | 2.86× | <250 ms | ✅ | None |
| R15 | 0.118 | 0.321 | 2.72× | <5 ms | ✅ | None |
| R16 | 13.009 | 212.653 | 16.35× | <5,000 ms | ✅ | None |
| R17 | 11.072 | 931.048 | 84.09× | <5,000 ms | ✅ | None |
| R18 | 5.919 | 84.676 | 14.31× | <5,000 ms | ✅ | None |
| R19 | 30.172 | 650.493 | 21.56× | <5,000 ms | ✅ | None |
| R20 | 2.070 | 56.658 | 27.37× | <5,000 ms | ✅ | None |
| R21 | 0.188 | 0.283 | 1.51× | <5 ms | ✅ | None |
| R22 | 7.588 | 97.730 | 12.88× | <5,000 ms | ✅ | None |
| R23 | 3.171 | 2.594 | 0.82× | <5,000 ms | ✅ | None |
| R24 | 0.096 | 0.257 | 2.68× | <250 ms | ✅ | None |
| R25 | 42.577 | 541.810 | 12.73× | <5,000 ms | ✅ | None |
| W01 | 1.427 | 1.672 | 1.17× | <5 ms | ✅ | None |
| W02 | 0.954 | 0.857 | 0.90× | <5 ms | ✅ | None |
| W03 | 1.296 | 0.786 | 0.61× | <5 ms | ✅ | None |
| W04 | 27.841 | 932.244 | 33.48× | <2,000 ms | ✅ | None |
| W05 | 1.174 | 7.036 | 5.99× | <250 ms | ✅ | None |

All 30 queries met their assigned targets, so no CP3 query or index was changed
after the faculty large-data run.

## Growth analysis

### Stayed approximately constant (0.5×–3×)

R01, R02, R05, R08, R14, R15, R21, R23, R24, W01, W02, and W03 use
primary-key/selective index lookups or touch a fixed number of rows. B-tree
depth grows slowly, so multiplying unrelated rows does not multiply their
work. R23 remains stable because its covering index reads only the first 30,025
entries required by the fixed `OFFSET 30000` page.

### Sublinear growth (3×–10×)

R03, R06, R10, R13, and W05 use selective or partial indexes. Their index
structures grew approximately 20×, but each query reads a much smaller share.

### Approximately proportional growth (10×–30×)

R04, R09, R11, R12, R16, R18, R19, R20, R22, and R25 read or aggregate a
stable share of one or more scaled tables. Their 12.7×–27.4× growth is
consistent with a roughly 20× dataset plus cache and sort effects.

### More than 30× growth

- **R07 (33.34×):** channel 217 has 60 videos in the faculty dataset rather
  than 15 in the seed. The first large run read 131 pages and took 10.777 ms;
  warm runs took 0.310 and 0.316 ms. The required average retains that cold
  cache cost.
- **R17 (84.09×):** the nested loop performs 58,849 video probes and 391,244
  joined watch rows. Its first run read 126,442 pages and took 1,959.962 ms;
  warm runs took 413.382 and about 420 ms.
- **W04 (33.48×):** aggregating 2,598,598 subscriptions produced 60,000
  channel groups. The hash aggregate used five batches and about 20 MB of
  temporary disk before updating all 60,000 channels.

These queries grew superlinearly because their seed working sets fit in memory
while the faculty dataset introduced cold reads or temporary spills. They still
met their targets, so no PostgreSQL setting was changed to hide the effect.

## What broke at scale

No correctness check, query execution, or performance target failed. The raw
plans expose two future limits rather than current failures:

- R20 groups 219,780 June events and spills a 3.8 MB external merge sort.
- W04 spills its subscription hash aggregate and rewrites every channel.

At 100×, R20 should read a monthly partition or daily summary, and W04 should
maintain subscriber counts incrementally instead of recomputing the entire
table nightly.

R23 still uses `OFFSET` because its measured 2.594 ms is well within the report
target. If a deeper moderation page later misses its target, use keyset
pagination ordered by `(created_at DESC, comment_id DESC)` and pass the previous
page's last pair as the cursor.

## Storage growth

| Measurement | Seed | Faculty large | Growth |
|---|---:|---:|---:|
| Total database | 131.76 MiB | 2.38 GiB | 18.53× |
| Table heap data | 46.27 MiB | 926.67 MiB | 20.03× |
| Index data | 76.09 MiB | 1.47 GiB | 19.78× |

The remaining database size is PostgreSQL catalogs, TOAST data, and free-space
and visibility maps. Storage grew close to the expected 20× row growth.

## Architecture for 100× volume

At 100× the seed workload implies roughly 20 million watch events, 12.9
million subscriptions, 5.7 million ad impressions, and 3 million videos. The
largest append-only table needs explicit data-lifecycle boundaries.

### Range partitioning

`sql/08_partitioning.sql` defines monthly `RANGE (started_at)` partitions for
`watch_events`, plus a 2025 historical partition and a default safety
partition. Time is the correct boundary because R07, R10, R11, R20, retention,
and archival all use date ranges. At 20 million events across 18 months, each
monthly partition would hold about 1.1 million rows rather than sharing one
20-million-row heap.

PostgreSQL requires every partition key column in a partitioned `PRIMARY KEY`
or `UNIQUE` constraint. Therefore the table uses
`PRIMARY KEY (watch_id, started_at)`; `PRIMARY KEY (watch_id)` alone cannot be
enforced across independent partitions.

The DDL was re-executed successfully on the faculty-data database. Its June
query pruned every other partition:

```text
Aggregate
  -> Bitmap Heap Scan on watch_events_p2026_06
       -> Bitmap Index Scan on watch_events_p2026_06_started_at_..._idx
            Index Cond: started_at >= '2026-06-01' AND started_at < '2026-07-01'
```

Only `watch_events_p2026_06` appears in the plan. The file creates a separate
demonstration table and deliberately omits the destructive production swap.

### Sharding

If one server no longer holds the write rate, hash-shard watch events by
`video_id`. R08 and the per-video work in R07/R09/R10/R11/R17/R19 route to a
known shard. A channel report fans out only across shards containing that
channel's videos. R05 watch history becomes cross-shard, so maintain a small
asynchronous `user_watch_history` projection keyed by `user_id`. Sharding by
user would make R05 easy but scatter every creator and trending report;
sharding by time would hotspot the current partition.

### Read replicas and caching

- Keep W01–W05 and session-sensitive counter reads on the primary.
- Send analytical R07–R12, R14, R16–R20, R22, R24, and R25 to a replica when
  seconds of replication lag are acceptable.
- Cache R01/R02/R04/R06/R10/R11/R15/R21 with short TTLs and invalidate video,
  channel, comment, or playlist keys after their writes.
- Do not cache personalized R03/R05/R13 without user-scoped keys. R05 should
  normally read the primary or the history projection so a new view is visible.

### Maintenance

- Start with `autovacuum_vacuum_scale_factor = 0.02` and
  `autovacuum_analyze_scale_factor = 0.01` for `watch_events`; tune from
  dead-tuple and analyze-lag metrics rather than disabling autovacuum.
- Create next month's partition before month-end. Detach and archive old
  partitions instead of issuing massive deletes; drop them only after retention
  and backup checks pass.
- Refresh daily channel/video summaries incrementally after ingestion. Use them
  for R07, R10, R11, R17, R19, and R20 at 100×.
- Run `VACUUM (ANALYZE)` after bulk loads and monitor index bloat, temporary
  bytes, replica lag, cache hit rate, and partition size.

## Conclusion

The optimized database is ready for the measured faculty large dataset: every
query met its target and storage grew close to linearly. The primary 100× risks
are temporary-file spills in global aggregates, the nightly full subscriber
count rewrite, and maintaining 1.47 GiB of indexes at the current scale.
Monthly range partitioning, incremental summaries, disciplined archiving, and
read replicas for analytics are the next steps before 100× production traffic.
