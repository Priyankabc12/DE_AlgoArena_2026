# Phase 2 — Schema Design

**Team:** T0106 · **Lead:** Priyanka Tiwari · **Members:** Abhimanyu, Kushagra Kaushik, Mani Amar Sehgal

The schema is derived from the ten supplied CSV exports. All tables are created in the `youtube` schema, and Phase 2 contains constraints only—no tuning indexes.

## Data dictionary

### `users`

| Column | Type | Constraints | Reason |
|---|---|---|---|
| `user_id` | `INTEGER` | PK | Exported user identifier. |
| `email` | `VARCHAR(150)` | NOT NULL, UNIQUE, email-format CHECK | Login email is present and unique. |
| `display_name` | `VARCHAR(100)` | NOT NULL, non-blank CHECK | Displayed user name. |
| `country_code` | `CHAR(2)` | NOT NULL, two-uppercase-letter CHECK | Two-letter country code. |
| `birth_year` | `SMALLINT` | NULL allowed | 4,433 users do not provide it. |
| `premium_until` | `DATE` | NULL allowed | NULL represents no recorded Premium expiry. |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | Account creation instant with offset. |

### `channels`

| Column | Type | Constraints | Reason |
|---|---|---|---|
| `channel_id` | `INTEGER` | PK | Exported channel identifier. |
| `owner_user_id` | `INTEGER` | NOT NULL, UNIQUE, FK → `users.user_id`, ON DELETE CASCADE | Every exported channel has one distinct owner. |
| `handle` | `VARCHAR(50)` | NOT NULL, UNIQUE, `@`-handle CHECK | Public candidate key. |
| `channel_name` | `VARCHAR(150)` | NOT NULL, non-blank CHECK | Public display name. |
| `country_code` | `CHAR(2)` | NOT NULL, format CHECK | Channel country. |
| `is_verified` | `BOOLEAN` | NOT NULL | Verification flag. |
| `monetization_status` | `VARCHAR(20)` | NOT NULL, allowed-value CHECK | `ELIGIBLE`, `NOT_ELIGIBLE`, or `SUSPENDED`. |
| `subscriber_count` | `INTEGER` | NOT NULL, DEFAULT 0, non-negative CHECK | Stored count used by the workload. |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | Channel creation instant. |

### `videos`

| Column | Type | Constraints | Reason |
|---|---|---|---|
| `video_id` | `CHAR(11)` | PK, 11-character ID CHECK | Workload uses YouTube-style fixed-length IDs. |
| `channel_id` | `INTEGER` | NOT NULL, FK → `channels.channel_id`, ON DELETE CASCADE | Uploading channel. |
| `title` | `VARCHAR(255)` | NOT NULL, non-blank CHECK | Video title. |
| `description` | `TEXT` | NULL allowed | 9,083 descriptions are empty. |
| `category` | `VARCHAR(50)` | NOT NULL, allowed-value CHECK | One of the ten exported categories. |
| `duration_sec` | `INTEGER` | NOT NULL, positive CHECK | Video duration in seconds. |
| `is_short` | `BOOLEAN` | NOT NULL, Shorts-duration CHECK | Identifies Shorts; true requires duration ≤ 60 seconds. |
| `is_made_for_kids` | `BOOLEAN` | NOT NULL, DEFAULT FALSE | Child-safety flag; default lets supplied W01 omit it. |
| `visibility` | `VARCHAR(20)` | NOT NULL, allowed-value CHECK | `PUBLIC`, `PRIVATE`, `UNLISTED`, or `SCHEDULED`. |
| `uploaded_at` | `TIMESTAMPTZ` | NOT NULL | Upload instant. |
| `published_at` | `TIMESTAMPTZ` | NULL allowed, state/order CHECKs | NULL only for private videos; never before upload. |
| `view_count` | `INTEGER` | NOT NULL, DEFAULT 0, non-negative CHECK | Stored counter used by the workload. |

### `subscriptions`

| Column | Type | Constraints | Reason |
|---|---|---|---|
| `user_id` | `INTEGER` | PK, FK → `users.user_id`, ON DELETE CASCADE | Subscriber. |
| `channel_id` | `INTEGER` | PK, FK → `channels.channel_id`, ON DELETE CASCADE | Subscribed channel. |
| `notifications` | `VARCHAR(20)` | NOT NULL, allowed-value CHECK | `ALL`, `NONE`, or `PERSONALIZED`. |
| `subscribed_at` | `TIMESTAMPTZ` | NOT NULL | Subscription instant. |

The composite primary key (`user_id`, `channel_id`) permits at most one subscription between the same user and channel.

### `watch_events`

| Column | Type | Constraints | Reason |
|---|---|---|---|
| `watch_id` | `INTEGER` | PK | Exported watch identifier. |
| `user_id` | `INTEGER` | NULL allowed, FK → `users.user_id`, ON DELETE SET NULL | NULL represents signed-out viewing and preserves the event if a user is removed. |
| `video_id` | `CHAR(11)` | NOT NULL, FK → `videos.video_id`, ON DELETE CASCADE | Watched video. |
| `started_at` | `TIMESTAMPTZ` | NOT NULL | Watch start instant. |
| `watch_seconds` | `INTEGER` | NOT NULL, non-negative CHECK | Watched duration. |
| `device` | `VARCHAR(20)` | NOT NULL, allowed-value CHECK | `ANDROID`, `IOS`, `TV`, or `WEB`. |
| `traffic_source` | `VARCHAR(30)` | NOT NULL, allowed-value CHECK | One of the six exported discovery sources. |

### `video_reactions`

| Column | Type | Constraints | Reason |
|---|---|---|---|
| `user_id` | `INTEGER` | PK, FK → `users.user_id`, ON DELETE CASCADE | Reacting user. |
| `video_id` | `CHAR(11)` | PK, FK → `videos.video_id`, ON DELETE CASCADE | Reacted-to video. |
| `reaction` | `VARCHAR(10)` | NOT NULL, allowed-value CHECK | `LIKE` or `DISLIKE`. |
| `reacted_at` | `TIMESTAMPTZ` | NOT NULL | Reaction instant. |

The composite primary key (`user_id`, `video_id`) permits one current reaction per user and video.

### `comments`

| Column | Type | Constraints | Reason |
|---|---|---|---|
| `comment_id` | `INTEGER` | PK | Exported comment identifier. |
| `video_id` | `CHAR(11)` | NOT NULL, FK → `videos.video_id`, ON DELETE CASCADE | Commented video. |
| `user_id` | `INTEGER` | NOT NULL, FK → `users.user_id`, ON DELETE CASCADE | Comment author. |
| `parent_comment_id` | `INTEGER` | NULL allowed, self-FK, ON DELETE CASCADE | NULL for top-level comments; otherwise identifies the parent. |
| `body` | `TEXT` | NOT NULL, non-blank CHECK | Comment text. |
| `like_count` | `INTEGER` | NOT NULL, DEFAULT 0, non-negative CHECK | Stored comment-like count. |
| `is_pinned` | `BOOLEAN` | NOT NULL, reply-not-pinned CHECK | Pinned state; replies cannot be pinned in the export. |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | Comment instant. |

### `playlists`

| Column | Type | Constraints | Reason |
|---|---|---|---|
| `playlist_id` | `INTEGER` | PK | Exported playlist identifier. |
| `owner_user_id` | `INTEGER` | NOT NULL, FK → `users.user_id`, ON DELETE CASCADE | Playlist owner. |
| `title` | `VARCHAR(150)` | NOT NULL, non-blank CHECK | Playlist title. |
| `visibility` | `VARCHAR(20)` | NOT NULL, allowed-value CHECK | `PUBLIC`, `PRIVATE`, or `UNLISTED`. |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | Playlist creation instant. |

### `playlist_items`

| Column | Type | Constraints | Reason |
|---|---|---|---|
| `playlist_id` | `INTEGER` | PK, FK → `playlists.playlist_id`, ON DELETE CASCADE | Parent playlist. |
| `position` | `INTEGER` | PK, positive CHECK | Display position within that playlist. |
| `video_id` | `CHAR(11)` | NOT NULL, FK → `videos.video_id`, ON DELETE CASCADE | Included video. |
| `added_at` | `TIMESTAMPTZ` | NOT NULL | Addition instant. |

The composite primary key (`playlist_id`, `position`) prevents duplicate positions inside a playlist.

### `ad_impressions`

| Column | Type | Constraints | Reason |
|---|---|---|---|
| `impression_id` | `INTEGER` | PK | Exported impression identifier. |
| `watch_id` | `INTEGER` | NOT NULL, FK → `watch_events.watch_id`, ON DELETE CASCADE | Watch during which the ad appeared. |
| `ad_format` | `VARCHAR(20)` | NOT NULL, allowed-value CHECK | `PREROLL` or `MIDROLL`. |
| `revenue_inr` | `NUMERIC(10,4)` | NOT NULL, non-negative CHECK | Exact INR revenue with four decimal places. |
| `shown_at` | `TIMESTAMPTZ` | NOT NULL | Ad display instant. |

## Relationships

- `users` 1:0..1 `channels` in the supplied data (`owner_user_id` is unique).
- `users` and `channels` are M:N through `subscriptions`.
- `channels` 1:N `videos`.
- `users` 0..1:N `watch_events`; the user side is optional for signed-out views.
- `videos` 1:N `watch_events`.
- `users` and `videos` are M:N through `video_reactions`.
- `users` 1:N `comments`; `videos` 1:N `comments`; `comments` 1:N reply comments.
- `users` 1:N `playlists`; `playlists` and `videos` are M:N through `playlist_items`.
- `watch_events` 1:N `ad_impressions`.

Editable Mermaid source and the rendered diagram are in `diagrams/er_diagram.mmd` and `diagrams/er_diagram.svg`.

## Functional dependencies and normal forms

| Table | Candidate key(s) and functional dependencies | Normal-form conclusion |
|---|---|---|
| `users` | `user_id →` all other columns; `email →` all other columns. | BCNF: every determinant shown is a candidate key. |
| `channels` | `channel_id →` all other columns; `owner_user_id →` all other columns; `handle →` all other columns. | BCNF for the supplied 1:1 ownership rule. |
| `videos` | `video_id →` all other columns. | 3NF, with deliberate derived/stored fields noted below. |
| `subscriptions` | (`user_id`, `channel_id`) `→ notifications, subscribed_at`. | BCNF: non-key attributes depend on the whole composite key. |
| `watch_events` | `watch_id → user_id, video_id, started_at, watch_seconds, device, traffic_source`. | BCNF. |
| `video_reactions` | (`user_id`, `video_id`) `→ reaction, reacted_at`. | BCNF. |
| `comments` | `comment_id → video_id, user_id, parent_comment_id, body, like_count, is_pinned, created_at`. | 3NF, with a stored counter noted below. |
| `playlists` | `playlist_id → owner_user_id, title, visibility, created_at`. | BCNF. |
| `playlist_items` | (`playlist_id`, `position`) `→ video_id, added_at`. | BCNF. |
| `ad_impressions` | `impression_id → watch_id, ad_format, revenue_inr, shown_at`. | BCNF. |

### Stored or derivable values

- `channels.subscriber_count` can be derived from `subscriptions`.
- `videos.view_count` can be derived from `watch_events`.
- `comments.like_count` is a stored counter because no comment-reaction export exists.
- `videos.is_short` can be inferred from duration under the supplied ≤60-second rule.

These fields are retained because they occur in the export and the fixed workload reads or updates them. Their redundancy must be kept consistent by the application or scheduled jobs.

## Load and integrity results

The seed files load in parent-before-child order.

| Table | Expected rows | Loaded rows |
|---|---:|---:|
| `users` | 30,000 | 30,000 |
| `channels` | 3,000 | 3,000 |
| `videos` | 30,000 | 30,000 |
| `subscriptions` | 129,253 | 129,253 |
| `watch_events` | 200,000 | 200,000 |
| `video_reactions` | 67,417 | 67,417 |
| `comments` | 60,000 | 60,000 |
| `playlists` | 8,000 | 8,000 |
| `playlist_items` | 56,005 | 56,005 |
| `ad_impressions` | 57,014 | 57,014 |
| **Total** | **640,689** | **640,689** |

| Integrity check | Violations |
|---|---:|
| Watches before their video's upload time | 0 |
| Watch duration greater than video duration | 0 |
| Reply attached to a different video than its parent | 0 |
| Duplicate video within one playlist | 0 |

## Data observations

- `users.birth_year` is empty in 4,433 rows and `premium_until` in 27,602 rows.
- `videos.description` is empty in 9,083 rows. `published_at` is empty in 1,526 rows, all private videos.
- `watch_events.user_id` is empty in 49,964 rows, representing signed-out views.
- `comments.parent_comment_id` is empty in 52,610 top-level comments.
- All primary keys, candidate keys, and foreign-key references in the supplied files are valid.

## Automatically created indexes

PostgreSQL creates indexes for primary-key and UNIQUE constraints. Therefore Phase 2 has indexes for each table's primary key plus `users.email`, `channels.owner_user_id`, and `channels.handle`. No performance-tuning index is added before the baseline phase.
