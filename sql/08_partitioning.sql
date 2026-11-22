SET search_path TO youtube;

-- CP4 design: RANGE partition watch events by started_at because retention,
-- archiving, and the largest platform reports are all time based.  This demo
-- table is intentionally separate so the existing measured table is untouched.
DROP TABLE IF EXISTS watch_events_partitioned CASCADE;

CREATE TABLE watch_events_partitioned (
    watch_id INTEGER NOT NULL,
    user_id INTEGER,
    video_id CHAR(11) NOT NULL,
    started_at TIMESTAMPTZ NOT NULL,
    watch_seconds INTEGER NOT NULL,
    device VARCHAR(20) NOT NULL,
    traffic_source VARCHAR(30) NOT NULL,

    -- PostgreSQL requires every partition key column in a partitioned PRIMARY
    -- KEY/UNIQUE constraint; watch_id alone cannot be globally unique here.
    PRIMARY KEY (watch_id, started_at),
    CONSTRAINT watch_events_partitioned_user_fk FOREIGN KEY (user_id)
        REFERENCES users(user_id) ON DELETE SET NULL,
    CONSTRAINT watch_events_partitioned_video_fk FOREIGN KEY (video_id)
        REFERENCES videos(video_id) ON DELETE CASCADE,
    CONSTRAINT watch_events_partitioned_seconds_nonnegative CHECK (watch_seconds >= 0),
    CONSTRAINT watch_events_partitioned_device_allowed
        CHECK (device IN ('ANDROID', 'IOS', 'TV', 'WEB')),
    CONSTRAINT watch_events_partitioned_traffic_source_allowed CHECK (
        traffic_source IN ('EXTERNAL', 'HOME', 'SEARCH', 'SHORTS_FEED',
                           'SUBSCRIPTION', 'SUGGESTED')
    )
) PARTITION BY RANGE (started_at);

CREATE TABLE watch_events_p2025 PARTITION OF watch_events_partitioned
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE watch_events_p2026_01 PARTITION OF watch_events_partitioned
    FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
CREATE TABLE watch_events_p2026_02 PARTITION OF watch_events_partitioned
    FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
CREATE TABLE watch_events_p2026_03 PARTITION OF watch_events_partitioned
    FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');
CREATE TABLE watch_events_p2026_04 PARTITION OF watch_events_partitioned
    FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');
CREATE TABLE watch_events_p2026_05 PARTITION OF watch_events_partitioned
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE watch_events_p2026_06 PARTITION OF watch_events_partitioned
    FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE watch_events_p_default PARTITION OF watch_events_partitioned DEFAULT;

-- PostgreSQL creates matching child indexes on every current/future partition.
CREATE INDEX watch_events_partitioned_user_started
    ON watch_events_partitioned (user_id, started_at DESC)
    INCLUDE (video_id, watch_seconds);
CREATE INDEX watch_events_partitioned_video_started
    ON watch_events_partitioned (video_id, started_at)
    INCLUDE (watch_seconds, user_id, traffic_source, device);
CREATE INDEX watch_events_partitioned_started
    ON watch_events_partitioned (started_at)
    INCLUDE (video_id, watch_seconds, user_id, device);

-- Expected plan: only watch_events_p2026_06 appears.  The other seven
-- partitions are removed during planning.
EXPLAIN (COSTS OFF)
SELECT count(*)
FROM watch_events_partitioned
WHERE started_at >= '2026-06-01'
  AND started_at <  '2026-07-01';

-- Production migration after validation would bulk-copy, briefly lock writes,
-- then rename watch_events to watch_events_unpartitioned and this table to
-- watch_events.  Keeping that destructive swap out of this file makes it safe
-- to run for review.
