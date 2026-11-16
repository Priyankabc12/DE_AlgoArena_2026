-- =============================================================
-- Phase 2: Load seed data into the youtube schema
--
-- Run AFTER sql/01_schema.sql, from the project root:
--   psql -d <your_db> -f sql/02_load_data.sql
--
-- What this file does:
--   1. Sets search_path to youtube.
--   2. Loads tables in parent-before-child order so FK checks pass.
--   3. Runs ANALYZE to update statistics.
--   4. Runs integrity checks to verify the data loaded correctly.
--
-- IMPORTANT:
-- Place all CSV files inside:
--   seed_data/
--
-- Run this file from the project root:
--
--   cd /path/to/YouTube_Project
--   psql -d youtube_db -f sql/02_load_data.sql
-- =============================================================

SET search_path TO youtube;

-- ---------------------------------------------------------------
-- Load order
--
-- 1. users              (no FK)
-- 2. channels           (FK → users)
-- 3. videos             (FK → channels)
-- 4. subscriptions      (FK → users, channels)
-- 5. watch_events       (FK → users, videos)
-- 6. video_reactions    (FK → users, videos)
-- 7. comments           (FK → users, videos, comments)
-- 8. playlists          (FK → users)
-- 9. playlist_items     (FK → playlists, videos)
--10. ad_impressions     (FK → watch_events)
-- ---------------------------------------------------------------

\copy users             FROM 'seed_data/users.csv'             WITH (FORMAT csv, HEADER true)
\copy channels          FROM 'seed_data/channels.csv'          WITH (FORMAT csv, HEADER true)
\copy videos            FROM 'seed_data/videos.csv'            WITH (FORMAT csv, HEADER true)
\copy subscriptions     FROM 'seed_data/subscriptions.csv'     WITH (FORMAT csv, HEADER true)
\copy watch_events      FROM 'seed_data/watch_events.csv'      WITH (FORMAT csv, HEADER true)
\copy video_reactions   FROM 'seed_data/video_reactions.csv'   WITH (FORMAT csv, HEADER true)
\copy comments          FROM 'seed_data/comments.csv'          WITH (FORMAT csv, HEADER true)
\copy playlists         FROM 'seed_data/playlists.csv'         WITH (FORMAT csv, HEADER true)
\copy playlist_items    FROM 'seed_data/playlist_items.csv'    WITH (FORMAT csv, HEADER true)
\copy ad_impressions    FROM 'seed_data/ad_impressions.csv'    WITH (FORMAT csv, HEADER true)

-- ---------------------------------------------------------------
-- Update planner statistics
-- ---------------------------------------------------------------

ANALYZE users;
ANALYZE channels;
ANALYZE videos;
ANALYZE subscriptions;
ANALYZE watch_events;
ANALYZE video_reactions;
ANALYZE comments;
ANALYZE playlists;
ANALYZE playlist_items;
ANALYZE ad_impressions;

-- ---------------------------------------------------------------
-- Row Count Verification
--
-- Replace the expected counts with your actual dataset values
-- after generating/loading your CSV files.
-- ---------------------------------------------------------------

SELECT 'users' AS table_name, COUNT(*) FROM users
UNION ALL
SELECT 'channels', COUNT(*) FROM channels
UNION ALL
SELECT 'videos', COUNT(*) FROM videos
UNION ALL
SELECT 'subscriptions', COUNT(*) FROM subscriptions
UNION ALL
SELECT 'watch_events', COUNT(*) FROM watch_events
UNION ALL
SELECT 'video_reactions', COUNT(*) FROM video_reactions
UNION ALL
SELECT 'comments', COUNT(*) FROM comments
UNION ALL
SELECT 'playlists', COUNT(*) FROM playlists
UNION ALL
SELECT 'playlist_items', COUNT(*) FROM playlist_items
UNION ALL
SELECT 'ad_impressions', COUNT(*) FROM ad_impressions
ORDER BY table_name;

-- ---------------------------------------------------------------
-- Integrity Check 1
--
-- Every video must belong to an existing channel.
-- Result should be 0.
-- ---------------------------------------------------------------

SELECT
'IC1: videos without valid channel' AS check_name,
COUNT(*) AS violations
FROM videos v
WHERE NOT EXISTS (
    SELECT 1
    FROM channels c
    WHERE c.channel_id = v.channel_id
);

-- ---------------------------------------------------------------
-- Integrity Check 2
--
-- Every subscription must reference an existing user
-- and an existing channel.
-- Result should be 0.
-- ---------------------------------------------------------------

SELECT
'IC2: invalid subscriptions' AS check_name,
COUNT(*) AS violations
FROM subscriptions s
WHERE NOT EXISTS (
    SELECT 1
    FROM users u
    WHERE u.user_id = s.user_id
)
OR NOT EXISTS (
    SELECT 1
    FROM channels c
    WHERE c.channel_id = s.channel_id
);

-- ---------------------------------------------------------------
-- Integrity Check 3
--
-- Every comment must reference an existing video.
-- Result should be 0.
-- ---------------------------------------------------------------

SELECT
'IC3: comments without video' AS check_name,
COUNT(*) AS violations
FROM comments c
WHERE NOT EXISTS (
    SELECT 1
    FROM videos v
    WHERE v.video_id = c.video_id
);

-- ---------------------------------------------------------------
-- Integrity Check 4
--
-- Every playlist item must reference a valid video.
-- Result should be 0.
-- ---------------------------------------------------------------

SELECT
'IC4: playlist items without video' AS check_name,
COUNT(*) AS violations
FROM playlist_items p
WHERE NOT EXISTS (
    SELECT 1
    FROM videos v
    WHERE v.video_id = p.video_id
);

-- ---------------------------------------------------------------
-- Integrity Check 5
--
-- Ensure there are no duplicate reactions
-- for the same (user_id, video_id) pair.
--
-- Result should be 0.
-- ---------------------------------------------------------------

SELECT
'IC5: duplicate user reactions' AS check_name,
COUNT(*) AS violations
FROM (
    SELECT
        user_id,
        video_id,
        COUNT(*) AS cnt
    FROM video_reactions
    GROUP BY user_id, video_id
    HAVING COUNT(*) > 1
) dup;

-- ---------------------------------------------------------------
-- Integrity Check 6
--
-- Every advertisement impression must belong
-- to a valid watch event.
--
-- Result should be 0.
-- ---------------------------------------------------------------

SELECT
'IC6: ad impressions without watch event' AS check_name,
COUNT(*) AS violations
FROM ad_impressions a
WHERE NOT EXISTS (
    SELECT 1
    FROM watch_events w
    WHERE w.watch_id = a.watch_id
);

-- ---------------------------------------------------------------
-- Integrity Check 7
--
-- Playlist positions should be unique within
-- each playlist.
--
-- Result should be 0.
-- ---------------------------------------------------------------

SELECT
'IC7: duplicate playlist positions' AS check_name,
COUNT(*) AS violations
FROM (
    SELECT
        playlist_id,
        position,
        COUNT(*) AS cnt
    FROM playlist_items
    GROUP BY playlist_id, position
    HAVING COUNT(*) > 1
) dup;