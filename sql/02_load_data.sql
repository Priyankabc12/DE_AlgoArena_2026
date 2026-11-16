-- Run from the repository root after sql/01_schema.sql.
SET search_path TO youtube;

-- Parent tables are loaded before the tables that reference them.
\copy users           FROM 'seed_data/users.csv'           WITH (FORMAT csv, HEADER true)
\copy channels        FROM 'seed_data/channels.csv'        WITH (FORMAT csv, HEADER true)
\copy videos          FROM 'seed_data/videos.csv'          WITH (FORMAT csv, HEADER true)
\copy subscriptions   FROM 'seed_data/subscriptions.csv'   WITH (FORMAT csv, HEADER true)
\copy watch_events    FROM 'seed_data/watch_events.csv'    WITH (FORMAT csv, HEADER true)
\copy video_reactions FROM 'seed_data/video_reactions.csv' WITH (FORMAT csv, HEADER true)
\copy comments        FROM 'seed_data/comments.csv'        WITH (FORMAT csv, HEADER true)
\copy playlists       FROM 'seed_data/playlists.csv'       WITH (FORMAT csv, HEADER true)
\copy playlist_items  FROM 'seed_data/playlist_items.csv'  WITH (FORMAT csv, HEADER true)
\copy ad_impressions  FROM 'seed_data/ad_impressions.csv'  WITH (FORMAT csv, HEADER true)

ANALYZE;

-- Each row should report matches_expected = true.
WITH actual (table_name, actual_rows) AS (
    SELECT 'users', COUNT(*) FROM users
    UNION ALL SELECT 'channels', COUNT(*) FROM channels
    UNION ALL SELECT 'videos', COUNT(*) FROM videos
    UNION ALL SELECT 'subscriptions', COUNT(*) FROM subscriptions
    UNION ALL SELECT 'watch_events', COUNT(*) FROM watch_events
    UNION ALL SELECT 'video_reactions', COUNT(*) FROM video_reactions
    UNION ALL SELECT 'comments', COUNT(*) FROM comments
    UNION ALL SELECT 'playlists', COUNT(*) FROM playlists
    UNION ALL SELECT 'playlist_items', COUNT(*) FROM playlist_items
    UNION ALL SELECT 'ad_impressions', COUNT(*) FROM ad_impressions
),
expected (table_name, expected_rows) AS (
    VALUES
        ('users', 30000::bigint),
        ('channels', 3000),
        ('videos', 30000),
        ('subscriptions', 129253),
        ('watch_events', 200000),
        ('video_reactions', 67417),
        ('comments', 60000),
        ('playlists', 8000),
        ('playlist_items', 56005),
        ('ad_impressions', 57014)
)
SELECT e.table_name, e.expected_rows, a.actual_rows,
       e.expected_rows = a.actual_rows AS matches_expected
FROM expected e
JOIN actual a USING (table_name)
ORDER BY e.table_name;

-- IC1: nobody watched a video before it was uploaded. Expected: 0.
SELECT 'IC1: watch before upload' AS check_name, COUNT(*) AS violations
FROM watch_events w
JOIN videos v ON v.video_id = w.video_id
WHERE w.started_at < v.uploaded_at;

-- IC2: a watch does not exceed the video's duration. Expected: 0.
SELECT 'IC2: watch exceeds duration' AS check_name, COUNT(*) AS violations
FROM watch_events w
JOIN videos v ON v.video_id = w.video_id
WHERE w.watch_seconds > v.duration_sec;

-- IC3: replies belong to the same video as their parent. Expected: 0.
SELECT 'IC3: reply belongs to another video' AS check_name,
       COUNT(*) AS violations
FROM comments reply
JOIN comments parent ON parent.comment_id = reply.parent_comment_id
WHERE reply.video_id <> parent.video_id;

-- IC4: the same video is not repeated in one playlist. Expected: 0.
SELECT 'IC4: duplicate video in playlist' AS check_name,
       COUNT(*) AS violations
FROM (
    SELECT playlist_id, video_id
    FROM playlist_items
    GROUP BY playlist_id, video_id
    HAVING COUNT(*) > 1
) duplicates;
