SET search_path TO youtube;

-- R04: a B-tree cannot serve a leading-wildcard ILIKE search.  The partial
-- trigram index stores only public titles, which is exactly R04's predicate.
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX idx_videos_public_title_trgm
    ON videos USING gin (title gin_trgm_ops)
    WHERE visibility = 'PUBLIC';

-- R01/R03: equality columns lead, followed by the requested sort column.
-- Included columns allow the channel-page lookup to avoid extra heap reads.
CREATE INDEX idx_videos_channel_visibility_published
    ON videos (channel_id, visibility, published_at DESC)
    INCLUDE (video_id, title, duration_sec, view_count);

-- R06/W05: scheduled rows are rare, so a small partial index is preferable
-- to indexing visibility for every video.
CREATE INDEX idx_videos_scheduled_published
    ON videos (published_at)
    WHERE visibility = 'SCHEDULED';

-- R05: fetch one user's history in newest-first order and stop after 50 rows.
CREATE INDEX idx_watch_events_user_started
    ON watch_events (user_id, started_at DESC)
    INCLUDE (video_id, watch_seconds);

-- R07/R08/R09/R10/R11/R17/R19: video is the selective join/filter key;
-- started_at second also supports per-video date ranges.
CREATE INDEX idx_watch_events_video_started
    ON watch_events (video_id, started_at)
    INCLUDE (watch_seconds, user_id, traffic_source, device);

-- R07/R10/R11/R16/R20: time-window reports can start from the requested
-- date range instead of scanning all watch events.
CREATE INDEX idx_watch_events_started
    ON watch_events (started_at)
    INCLUDE (video_id, watch_seconds, user_id, device);

-- R13/R24/W04: channel first serves channel-specific reads and lets the
-- nightly per-channel aggregation use an ordered/index-only input.
CREATE INDEX idx_subscriptions_channel_subscribed
    ON subscriptions (channel_id, subscribed_at)
    INCLUDE (user_id);

-- R14: reactions are joined and counted by video and reaction value.
CREATE INDEX idx_video_reactions_video_reaction
    ON video_reactions (video_id, reaction);

-- R15/R18: video and top-level status are filters; pin/likes match the sort.
CREATE INDEX idx_comments_video_top_rank
    ON comments (video_id, parent_comment_id, is_pinned DESC, like_count DESC)
    INCLUDE (comment_id, user_id, body);

-- R23: supports newest-first pagination without sorting the comments table.
CREATE INDEX idx_comments_created_desc
    ON comments (created_at DESC)
    INCLUDE (comment_id, video_id, user_id, body);

-- R16: restrict ad impressions to the requested reporting period first.
CREATE INDEX idx_ad_impressions_shown
    ON ad_impressions (shown_at)
    INCLUDE (watch_id, revenue_inr);

-- R19: supports max(uploaded_at) per channel and the rewritten grouped join.
CREATE INDEX idx_videos_channel_uploaded
    ON videos (channel_id, uploaded_at DESC);

-- R22: provides grouping columns in order and can be read without the heap.
CREATE INDEX idx_videos_title_duration_channel
    ON videos (title, duration_sec, channel_id);

ANALYZE;