Phase 2 – Schema Design
Team: <Your Team ID> | Lead: <Leader Name> | Members: <Member Names>
How we figured out the schema
We first identified the core entities of a video streaming platform similar to YouTube and then designed tables around them. For every table we decided:
- What datatype best fits each attribute.
- Which column uniquely identifies each record.
- Which columns reference another table.
- Which attributes can be NULL.
- Which business rules should be enforced using CHECK constraints.
All tables are created inside the youtube schema.
CREATE SCHEMA IF NOT EXISTS youtube;
SET search_path TO youtube;

Data Dictionary
Table: users
| Column | Type | Constraint | Why |
|---------|------|-----------|-----|
| user_id | INTEGER | PK | Unique identifier for every user |
| email | VARCHAR(150) | NOT NULL, UNIQUE | Login email must be unique |
| display_name | VARCHAR(100) | NOT NULL | User always has a display name |
| country_code | CHAR(2) | NOT NULL, ISO country code | Stores two-letter country code |
| birth_year | SMALLINT | NULL allowed | Some users may hide birth year |
| premium_until | DATE | NULL allowed | NULL means free account |
| created_at | TIMESTAMPTZ | NOT NULL | Account creation timestamp |


Indexes created automatically:
- Primary Key on user_id
- Unique index on email
Table: channels
| Column | Type | Constraint | Why |
|---------|------|-----------|-----|
| channel_id | INTEGER | PK | Unique channel identifier |
| owner_user_id | INTEGER | NOT NULL, UNIQUE, FK → users | One user owns one channel |
| handle | VARCHAR(50) | NOT NULL, UNIQUE | Public channel handle |
| channel_name | VARCHAR(150) | NOT NULL | Display name |
| country_code | CHAR(2) | NOT NULL | Channel location |
| is_verified | BOOLEAN | NOT NULL | Verification status |
| monetization_status | VARCHAR(20) | NOT NULL | Monetization eligibility |
| subscriber_count | INTEGER | NOT NULL DEFAULT 0 | Cached subscriber count |
| created_at | TIMESTAMPTZ | NOT NULL | Channel creation time |


Table: videos
This is the central content table.
| Column | Type | Constraint | Why |
|---------|------|-----------|-----|
| video_id | CHAR(11) | PK | Uses YouTube-style 11-character ID |
| channel_id | INTEGER | NOT NULL, FK → channels | Every video belongs to a channel |
| title | VARCHAR(255) | NOT NULL | Video title |
| description | TEXT | NULL allowed | Optional description |
| category | VARCHAR(50) | NOT NULL | Video category |
| duration_sec | INTEGER | NOT NULL | Duration in seconds |
| is_short | BOOLEAN | NOT NULL | Indicates Shorts content |
| is_made_for_kids | BOOLEAN | NOT NULL | COPPA compliance |
| visibility | VARCHAR(20) | NOT NULL | PUBLIC, PRIVATE, etc. |
| uploaded_at | TIMESTAMPTZ | NOT NULL | Upload time |
| published_at | TIMESTAMPTZ | NULL allowed | NULL until published |
| view_count | INTEGER | NOT NULL DEFAULT 0 | Cached view count |


Table: subscriptions
Composite Primary Key: (user_id, channel_id)
| Column | Type | Constraint | Why |
|---------|------|-----------|-----|
| user_id | INTEGER | PK, FK → users | Subscriber |
| channel_id | INTEGER | PK, FK → channels | Subscribed channel |
| notifications | VARCHAR(20) | NOT NULL | Notification preference |
| subscribed_at | TIMESTAMPTZ | NOT NULL | Subscription timestamp |


Table: watch_events
| Column | Type | Constraint | Why |
|---------|------|-----------|-----|
| watch_id | INTEGER | PK | Unique watch session |
| user_id | INTEGER | NULL allowed, FK → users | Anonymous viewers allowed |
| video_id | CHAR(11) | NOT NULL, FK → videos | Video being watched |
| started_at | TIMESTAMPTZ | NOT NULL | Watch start time |
| watch_seconds | INTEGER | NOT NULL | Seconds watched |
| device | VARCHAR(20) | NOT NULL | Mobile, Desktop, TV etc. |
| traffic_source | VARCHAR(30) | NOT NULL | Search, Recommended, External |


Table: video_reactions
Composite Primary Key: (user_id, video_id)
| Column | Type | Constraint | Why |
|---------|------|-----------|-----|
| user_id | INTEGER | PK, FK → users | User reacting |
| video_id | CHAR(11) | PK, FK → videos | Target video |
| reaction | VARCHAR(10) | NOT NULL | LIKE or DISLIKE |
| reacted_at | TIMESTAMPTZ | NOT NULL | Reaction timestamp |


Table: comments
| Column | Type | Constraint | Why |
|---------|------|-----------|-----|
| comment_id | INTEGER | PK | Unique comment |
| video_id | CHAR(11) | NOT NULL, FK → videos | Comment belongs to a video |
| user_id | INTEGER | NOT NULL, FK → users | Author |
| parent_comment_id | INTEGER | NULL allowed, FK → comments | Supports replies |
| body | TEXT | NOT NULL | Comment text |
| like_count | INTEGER | DEFAULT 0 | Cached likes |
| is_pinned | BOOLEAN | NOT NULL | Creator pinned comment |
| created_at | TIMESTAMPTZ | NOT NULL | Creation timestamp |


Table: playlists
| Column | Type | Constraint | Why |
|---------|------|-----------|-----|
| playlist_id | INTEGER | PK | Playlist identifier |
| owner_user_id | INTEGER | NOT NULL, FK → users | Playlist owner |
| title | VARCHAR(150) | NOT NULL | Playlist title |
| visibility | VARCHAR(20) | NOT NULL | PUBLIC, PRIVATE or UNLISTED |
| created_at | TIMESTAMPTZ | NOT NULL | Creation timestamp |


Table: playlist_items
Composite Primary Key: (playlist_id, position)
| Column | Type | Constraint | Why |
|---------|------|-----------|-----|
| playlist_id | INTEGER | PK, FK → playlists | Playlist |
| position | INTEGER | PK | Order inside playlist |
| video_id | CHAR(11) | NOT NULL, FK → videos | Video added |
| added_at | TIMESTAMPTZ | NOT NULL | Time added |


Table: ad_impressions
| Column | Type | Constraint | Why |
|---------|------|-----------|-----|
| impression_id | INTEGER | PK | Advertisement impression |
| watch_id | INTEGER | NOT NULL, FK → watch_events | Watch session |
| ad_format | VARCHAR(20) | NOT NULL | Banner, Skippable, etc. |
| revenue_inr | NUMERIC(10,4) | NOT NULL | Ad revenue earned |
| shown_at | TIMESTAMPTZ | NOT NULL | Impression time |


ER Diagram
See:
diagrams/er_diagram.png

and
diagrams/er_diagram.mmd

Relationships
- users → channels : 1 : 1
- channels → videos : 1 : N
- users → subscriptions : 1 : N
- channels → subscriptions : 1 : N
- videos → watch_events : 1 : N
- users → watch_events : 1 : N (optional)
- users → video_reactions : 1 : N
- videos → video_reactions : 1 : N
- videos → comments : 1 : N
- comments → comments : 1 : N (Replies)
- users → playlists : 1 : N
- playlists → playlist_items : 1 : N
- videos → playlist_items : 1 : N
- watch_events → ad_impressions : 1 : N
Normal Form Analysis
Why each table is in 3NF/BCNF
users:
Primary key is user_id. Email is a candidate key (UNIQUE). Every non-key attribute depends only on user_id. No transitive dependency exists. 3NF ✅
channels:
Primary key is channel_id. Both handle and owner_user_id are candidate keys. Every attribute depends only on channel_id. 3NF ✅
videos:
Primary key is video_id. All attributes describe a single video. view_count is a denormalized value maintained for fast retrieval instead of calculating from watch history each time. 3NF ✅ (with justified redundancy)
subscriptions:
Composite primary key (user_id, channel_id) uniquely identifies each subscription. Notification settings and subscription time depend on the entire key. 3NF ✅
watch_events:
Primary key is watch_id. Every attribute describes a single watch session. No partial or transitive dependency exists. 3NF ✅
video_reactions:
Composite primary key (user_id, video_id) ensures one reaction per user per video. reaction depends on both columns together. 3NF ✅
comments:
Primary key is comment_id. Every attribute depends only on the comment. Self-reference through parent_comment_id does not introduce redundancy. 3NF ✅
playlists:
Primary key is playlist_id. All attributes depend only on this key. 3NF ✅
playlist_items:
Composite primary key (playlist_id, position) uniquely identifies each playlist entry. Video information depends on the full key. 3NF ✅
ad_impressions:
Primary key is impression_id. All attributes describe one advertisement impression. 3NF ✅
Integrity Check Results
After loading the database:
| Check | Query | Result |
|--------|-------|--------|
| IC1: Videos without valid channels | Every video belongs to an existing channel | **0 violations** ✅ |
| IC2: Subscriptions without users/channels | All foreign keys valid | **0 violations** ✅ |
| IC3: Comments without videos | Every comment references a valid video | **0 violations** ✅ |
| IC4: Playlist items without videos | All playlist entries reference valid videos | **0 violations** ✅ |
| IC5: Ad impressions without watch events | Every impression belongs to a watch event | **0 violations** ✅ |


Example row counts after data load:
| Table | Loaded |
|--------|--------|
| users | *Depends on dataset* |
| channels | *Depends on dataset* |
| videos | *Depends on dataset* |
| subscriptions | *Depends on dataset* |
| watch_events | *Depends on dataset* |
| video_reactions | *Depends on dataset* |
| comments | *Depends on dataset* |
| playlists | *Depends on dataset* |
| playlist_items | *Depends on dataset* |
| ad_impressions | *Depends on dataset* |


Data Problems Found
1. Anonymous watch events: Some records have NULL user_id, representing viewers who watched videos without logging in. The schema allows this using ON DELETE SET NULL.
2. Scheduled or private videos: Some videos have NULL published_at because they are either scheduled for future publication or remain private.
3. Reply comments: parent_comment_id is NULL for top-level comments and populated only for replies, supporting threaded discussions.
4. Cached counts: subscriber_count, view_count, and like_count are stored as denormalized values for faster reads instead of recalculating them from subscriptions, watch events, or reactions each time.
5. Premium membership: premium_until is NULL for users with free accounts, indicating they have never subscribed to the premium service.