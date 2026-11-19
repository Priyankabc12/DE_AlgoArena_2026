# Phase 4 – Query Optimization Report

**Team:** T0106 | **Database:** de_algoarena_cp2 (PostgreSQL 14.20) | **Machine:** MacBook Pro (M4)

**Method:** The verified CP2 averages are the before values. After applying
`sql/05_indexes.sql`, every query in `sql/06_optimized_queries.sql` was run five
times with `EXPLAIN (ANALYZE, BUFFERS)`; writes ran inside `BEGIN … ROLLBACK`.
Raw plans are in `benchmarks/results/optimized/`.

## Result correctness

The optimized file retains all 30 query markers. Twenty-six queries are
textually unchanged. The four rewrites were compared with `EXCEPT ALL` in both
directions:

| Query | Before rows | After rows | Differences | Conclusion |
|---|---:|---:|---:|---|
| R07 | 7 | 7 | 0 | Same result |
| R13 | 0 (wrong) | 88 | 0 vs null-safe reference | Correctness fix |
| R19 | 1,087 | 1,087 | 0 | Same result |
| R20 | 30 | 30 | 0 | Same result |

R13 used `NOT IN` against a nullable `watch_events.user_id`. The subquery
returned 24 `NULL` rows, so SQL's three-valued logic made every candidate
comparison unknown and the original query returned no subscribers. Rewriting
it as a correlated `NOT EXISTS` returns the correct 88 rows and exactly matches
a `NOT IN` reference that explicitly excludes `NULL`.

## Before/after results

Improvement = `(before - after) / before × 100`. Negative values mean the
optimized run was slower.

| Query | Before (ms) | Problem found in plan | Optimization applied | After (ms) | Improvement | Same result? |
|---|---:|---|---|---:|---:|:---:|
| R01 | 3.212 | Video Seq Scan + sort | Covering `(channel_id, visibility, published_at DESC)` index | 0.051 | 98.41% | ✅ |
| R02 | 0.057 | Already PK lookups | No change needed | 0.119 | -108.77% | ✅ |
| R03 | 3.676 | Video Seq Scan in subscription feed | Reused covering channel/video index | 0.179 | 95.13% | ✅ |
| R04 | 6.192 | Leading-wildcard `ILIKE` forced Seq Scan | Partial trigram GIN index | 1.889 | 69.49% | ✅ |
| R05 | 8.019 | Watch-event Seq Scan + sort | Covering `(user_id, started_at DESC)` index | 0.652 | 91.87% | ✅ |
| R06 | 2.669 | Video Seq Scan for rare scheduled rows | Partial scheduled/published index | 0.120 | 95.50% | ✅ |
| R07 | 11.768 | Non-sargable `DATE()` and two Seq Scans | Half-open timestamp range + covering join indexes | 0.114 | 99.03% | ✅ |
| R08 | 9.835 | Full watch-event scan for one video | Covering `(video_id, started_at)` index | 0.104 | 98.94% | ✅ |
| R09 | 16.300 | Full video/watch join | Channel/video and video/watch index-only scans | 0.202 | 98.76% | ✅ |
| R10 | 12.700 | Date filtering over all events | Started-at covering index | 3.541 | 72.12% | ✅ |
| R11 | 21.070 | Broad June aggregation + ranking | Started-at covering index | 14.753 | 29.98% | ✅ |
| R12 | 16.511 | Must aggregate every watch event | No query rewrite; planner correctly keeps Seq Scan | 14.774 | 10.52% | ✅ |
| R13 | 17.807 | `NOT IN` null bug + full scans | Null-safe `NOT EXISTS` + three covering indexes | 0.135 | 99.24% | Fixed |
| R14 | 10.819 | Full reactions/videos join | `(video_id, reaction)` plus channel/video index | 0.581 | 94.63% | ✅ |
| R15 | 4.029 | Comment Seq Scan + sort | Covering top-comment rank index | 0.118 | 97.07% | ✅ |
| R16 | 18.015 | Broad three-table revenue join | Covering ad date index | 13.009 | 27.79% | ✅ |
| R17 | 16.858 | Broad eligibility aggregation | Video/channel and video/watch index-only scans | 11.072 | 34.32% | ✅ |
| R18 | 11.529 | Correlated comment existence checks | Comment index makes each existence probe cheap | 5.919 | 48.66% | ✅ |
| R19 | 15403.376 | Two correlated scans repeated 1,087 times | Pre-aggregate once and join; uploaded-at index | 30.172 | 99.80% | ✅ |
| R20 | 11.929 | Non-sargable date cast | Half-open range + started-at covering index | 2.070 | 82.65% | ✅ |
| R21 | 0.078 | Already uses two PK indexes | No change needed | 0.188 | -141.03% | ✅ |
| R22 | 20.625 | Seq Scan + group/sort | Covering `(title, duration_sec, channel_id)` index | 7.588 | 63.21% | ✅ |
| R23 | 20.356 | Full sort before deep OFFSET | Covering `created_at DESC` index | 3.171 | 84.42% | ✅ |
| R24 | 2.048 | PK order unsuitable for `channel_id` | Covering channel/subscribed-at index | 0.096 | 95.31% | ✅ |
| R25 | 40.043 | Cross-table premium/date predicate is not selective | No forced index; retain correct hash/Seq Scan plan | 42.577 | -6.33% | ✅ |
| W01 | 0.507 | Single insert | No rewrite; index maintenance is measured | 1.427 | -181.46% | ✅ |
| W02 | 0.625 | Single insert | No rewrite; index maintenance is measured | 0.954 | -52.64% | ✅ |
| W03 | 0.274 | PK update | No rewrite; covering-index maintenance is measured | 1.296 | -372.99% | ✅ |
| W04 | 30.790 | Full subscription aggregation | Channel-first subscription index | 27.841 | 9.58% | ✅ |
| W05 | 3.578 | Video Seq Scan for scheduled rows | Partial scheduled/published index | 1.174 | 67.19% | ✅ |
| **Total** | **15725.295** | | | **185.886** | **98.82% (84.60×)** | |

R02 and R21 operate below 0.2 ms; their negative percentages are timing noise,
not meaningful regressions. R13's percentage compares runtime only—its output
changed intentionally because the baseline result was incorrect.

## Five largest plan improvements

The complete five-run plans are retained in the corresponding raw files. These
excerpts show the decisive plan change.

### R19 – partner report

```text
Before: Seq Scan on watch_events, loops=1087; shared hits=3,536,050
        Execution Time: 15,424.963 ms (run 1)
After:  one grouped hash join over watch_events plus
        Index Only Scan on idx_videos_channel_uploaded; shared hits=3,427
        Execution Time: 30.172 ms average
```

### R13 – subscribers who never watched

```text
Before: Seq Scan on watch_events + videos; returned 0 incorrect rows
        Execution Time: 18.100 ms (run 1)
After:  Hash Anti Join fed by three Index Only Scans; returned 88 rows
        Execution Time: 0.135 ms average
```

### R07 – channel daily analytics

```text
Before: Parallel Seq Scan on watch_events, Rows Removed by Filter=94,506/worker
        plus Seq Scan on videos; Execution Time: 10.958 ms (run 1)
After:  nested loop with Index Only Scans on channel videos and each video's
        timestamp range; Heap Fetches=0; Execution Time: 0.114 ms average
```

### R08 – traffic sources for one video

```text
Before: Parallel Seq Scan on 200,000 watch events; shared hits=2,028
        Execution Time: 7.922 ms (run 1)
After:  Index Only Scan on idx_watch_events_video_started; shared hits=7,
        Heap Fetches=0; Execution Time: 0.104 ms average
```

### R09 – average percentage watched

```text
Before: Parallel Seq Scan on watch_events + Seq Scan on videos;
        shared hits=3,305; Execution Time: 17.349 ms (run 1)
After:  nested Index Only Scans; shared hits=54, Heap Fetches=0;
        Execution Time: 0.202 ms average
```

## Write overhead

The extra indexes make single-row writes more expensive:

| Query | Before | After | Added time | Assessment |
|---|---:|---:|---:|---|
| W01 video insert | 0.507 ms | 1.427 ms | 0.920 ms | Acceptable; uploads are far less frequent than reads |
| W02 watch insert | 0.625 ms | 0.954 ms | 0.329 ms | Acceptable for sub-millisecond index maintenance |
| W03 counter update | 0.274 ms | 1.296 ms | 1.022 ms | Acceptable, but batch counters if write volume becomes high |

W04 improved by 2.949 ms and W05 improved by 2.404 ms. The absolute write
latencies remain below 1.5 ms except the intentionally full-table nightly W04.

## Index storage

| Index | Size | Table | Table size | Index/table |
|---|---:|---|---:|---:|
| idx_ad_impressions_shown | 2,264 kB | ad_impressions | 3,360 kB | 67.4% |
| idx_comments_created_desc | 4,264 kB | comments | 5,248 kB | 81.3% |
| idx_comments_video_top_rank | 4,776 kB | comments | 5,248 kB | 91.0% |
| idx_subscriptions_channel_subscribed | 5,144 kB | subscriptions | 7,112 kB | 72.3% |
| idx_video_reactions_video_reaction | 1,576 kB | video_reactions | 3,968 kB | 39.7% |
| idx_videos_channel_uploaded | 936 kB | videos | 5,080 kB | 18.4% |
| idx_videos_channel_visibility_published | 2,808 kB | videos | 5,080 kB | 55.3% |
| idx_videos_public_title_trgm | 1,656 kB | videos | 5,080 kB | 32.6% |
| idx_videos_scheduled_published | 16 kB | videos | 5,080 kB | 0.3% |
| idx_videos_title_duration_channel | 1,640 kB | videos | 5,080 kB | 32.3% |
| idx_watch_events_started | 10 MB | watch_events | 16 MB | 67.3% |
| idx_watch_events_user_started | 9,704 kB | watch_events | 16 MB | 61.0% |
| idx_watch_events_video_started | 14 MB | watch_events | 16 MB | 88.4% |

The three watch-event indexes are the largest cost. They serve different access
paths (user history, video analytics, and global date ranges), so none is a
left-prefix duplicate of another.

## Queries not materially improved

- **R02 and R21** already use primary-key indexes and complete in under 0.2 ms.
- **R12** must inspect every watch event to compute platform-wide device shares;
  an index cannot avoid reading the population.
- **R25** compares a user's premium date with each impression timestamp across
  three tables. The correct plan still reads much of each table; its 6.33%
  slowdown is within run-to-run variation and no index was forced.
- **W04** must aggregate every subscription. The channel-first index helps only
  modestly; a maintained summary would trade read speed for extra write logic
  and is not justified at this dataset size.