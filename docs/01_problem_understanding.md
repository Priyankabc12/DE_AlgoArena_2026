Phase 1 – Problem Understanding
Team: (Your Team Number) | Lead: Priyanka Tiwari | Members: Abhimanyu, Kushagra Kaushik, Mani Amar Sehgal | Date: November 2026
What is the system?
YouTube allows anyone to create a channel, upload videos or Shorts, and interact with viewers around the world. Every day, millions of users watch videos, subscribe to channels, like or dislike content, leave comments, create playlists, and generate advertising revenue. Some users are Premium members and therefore should never be shown advertisements.

The current database was built quickly and only raw CSV exports remain. There is no documented database schema, making it difficult to maintain the system efficiently. Product teams have reported slow queries, incorrect query results, and poor scalability as the platform continues to grow.

Our objective is to:
1. Design a clean and well-constrained PostgreSQL schema from the provided CSV data.
2. Measure the performance of the 30 given SQL queries to establish a baseline.
3. Improve query performance without changing the returned results.
4. Ensure that the database design remains efficient even when the dataset grows to around twenty times its current size.    Pasted text(4)
Problem-by-Problem Analysis
P1 — Channel pages, watch pages and playlists load slowly
- Queries: R01, R02, R15, R21
- Stakeholder: Viewers
- Business need: Opening a channel page, watching a video, or viewing a playlist should feel instant. These are among the most frequently used features on YouTube, and delays directly affect the viewing experience.
- Type: Customer-facing / Real-time
- Performance target: Under 5 ms on the large dataset.
- Likely root cause: The required videos, comments, and playlist items are probably retrieved using sequential scans instead of indexed lookups on frequently searched columns such as channel_id, video_id, or playlist_id.
P2 — Subscription feed and watch history are slow
- Queries: R03, R05
- Stakeholder: Signed-in viewers
- Business need: Users expect their subscriptions feed and watch history to update immediately. Slow loading makes the application feel unresponsive, especially for users who watch many videos every day.
- Type: Customer-facing / Real-time
- Performance target: Under 5 ms on the large dataset.
- Likely root cause: Retrieving recent subscriptions or watch history requires scanning large portions of the subscriptions and watch_events tables without suitable indexes on user and timestamp columns.
P3 — Searching videos by title is slow
- Queries: R04
- Stakeholder: Search team and viewers
- Business need: Search is one of YouTube's primary features. Users expect relevant videos to appear instantly when searching by keywords.
- Type: Customer-facing / Real-time
- Performance target: Under 250 ms on the large dataset.
- Likely root cause: Searching using ILIKE '%keyword%' cannot efficiently use a normal B-tree index. Without a specialized text-search index such as pg_trgm, PostgreSQL performs a sequential scan of the videos table.
P4 — YouTube Studio analytics are slow
- Queries: R07, R08, R09, R14, R24
- Stakeholder: Content creators and YouTube Studio
- Business need: Creators regularly monitor views, watch time, audience retention, likes, and subscriber growth. Slow dashboards reduce the usefulness of analytics for managing channels.
- Type: Reporting / Analytics
- Performance target: Under 250 ms on the large dataset.
- Likely root cause: These reports aggregate large numbers of watch events and reactions. Without indexes on commonly grouped or filtered columns, PostgreSQL must repeatedly scan large tables.
P5 — Creator report returns incorrect results
- Queries: R13
- Stakeholder: Content creators
- Business need: Creators need to identify subscribers who have never watched their content so they can better understand audience engagement.
- Type: Reporting / Analytics
- Performance target: Under 250 ms on the large dataset.
- Likely root cause: The query uses NOT IN, which can produce incorrect results when the subquery contains NULL values. Rewriting it using NOT EXISTS avoids this SQL behaviour while improving performance.
P6 — Shorts and Trending recommendations update too slowly
- Queries: R10, R11
- Stakeholder: Recommendations team
- Business need: Trending videos and Shorts should reflect recent user activity. Slow recomputation means viewers may not see the latest popular content.
- Type: Reporting / Analytics
- Performance target: Under 5,000 ms on the large dataset.
- Likely root cause: These queries aggregate huge numbers of watch events over recent time periods. Large table scans become increasingly expensive as the database grows.
P7 — Publishing operations become slow under heavy traffic
- Queries: R06, W01, W02, W03, W05
- Stakeholder: Publishing service
- Business need: Uploading videos, recording views, updating view counts, and publishing scheduled videos must happen quickly because these operations occur continuously throughout the day.
- Type: Customer-facing / Real-time
- Performance target: Under 5 ms for write operations and 250 ms for scheduled publishing queries.
- Likely root cause: Frequent inserts and updates compete with read-heavy workloads. Missing indexes on scheduling and upload-related columns increase processing time.
P8 — Finance and Partner Program reports time out
- Queries: R16, R17, R19, R25, W04
- Stakeholder: Finance team and Partner Program
- Business need: Accurate advertising revenue, monetization eligibility, and Premium subscription audits are essential for paying creators correctly and maintaining trust in the platform.
- Type: Reporting / Analytics
- Performance target: Under 5,000 ms on the large dataset.
- Likely root cause: Revenue calculations combine multiple large tables including watch events, videos, channels, users, and advertisement impressions. Without suitable indexes and optimized joins, execution time increases significantly.
P9 — Trust, moderation and growth analytics do not scale
- Queries: R12, R18, R20, R22, R23
- Stakeholder: Trust & Safety, Moderation, Growth teams
- Business need: The platform must quickly detect policy violations, copyright issues, child safety concerns, moderation queues, and viewing trends. These reports become even more important as YouTube continues to grow.
- Type: Reporting / Analytics
- Performance target: Under 5,000 ms on the large dataset.
- Likely root cause: These analytical queries examine large portions of the database. As data volume increases, techniques such as partitioning, better indexing, and optimized query execution become necessary to maintain acceptable performance.

Classification Summary
| # | Problem | Type | Stakeholder |
|---|---------|------|-------------|
| P1 | Channel pages, watch pages and playlists | Customer-facing / Real-time | Viewers |
| P2 | Subscription feed and watch history | Customer-facing / Real-time | Signed-in Viewers |
| P3 | Video search | Customer-facing / Real-time | Search Team, Viewers |
| P4 | YouTube Studio analytics | Reporting / Analytics | Creators, Studio |
| P5 | Creator engagement report | Reporting / Analytics | Creators |
| P6 | Shorts and Trending recommendations | Reporting / Analytics | Recommendations Team |
| P7 | Publishing operations | Customer-facing / Real-time | Publishing Service |
| P8 | Finance and Partner Program reports | Reporting / Analytics | Finance, Partner Program |
| P9 | Trust, moderation and growth analytics | Reporting / Analytics | Trust & Safety, Moderation, Growth |


Assumptions
1. Every channel belongs to exactly one registered user, while a user may own multiple channels.
2. Every video is uploaded by one channel and has a unique 11-character video_id.
3. Anonymous viewers are represented by a NULL value in the user_id column of watch_events, indicating that signing in is optional before watching videos.
4. Scheduled videos have a future published_at timestamp and become publicly visible only after that time.
5. Premium members should never receive advertisements, so any matching records in the Premium audit query represent data inconsistencies that need investigation.
6. Playlist items preserve their display order using the position column, and duplicate positions within the same playlist should not exist.
7. subscriber_count in channels and view_count in videos are stored summary values maintained for faster retrieval, while the detailed subscription and watch event tables remain the source of truth.
8. A video marked as Made for Kids should not have active comments, making such records valid candidates for moderation reports.
9. All timestamps are stored with timezone information to support users, creators, and viewers across different regions

