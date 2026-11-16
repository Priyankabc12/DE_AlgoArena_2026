CREATE SCHEMA IF NOT EXISTS youtube;
SET search_path TO youtube;

CREATE TABLE users (
    user_id INTEGER PRIMARY KEY,
    email VARCHAR(150) UNIQUE NOT NULL,
    display_name VARCHAR(100) NOT NULL,
    country_code CHAR(2) NOT NULL,
    birth_year SMALLINT,
    premium_until DATE,
    created_at TIMESTAMPTZ NOT NULL,

    CONSTRAINT users_email_format CHECK (email LIKE '_%@_%._%'),
    CONSTRAINT users_display_name_not_blank CHECK (btrim(display_name) <> ''),
    CONSTRAINT users_country_code_format CHECK (country_code ~ '^[A-Z]{2}$')
);

CREATE TABLE channels (
    channel_id INTEGER PRIMARY KEY,
    owner_user_id INTEGER UNIQUE NOT NULL,
    handle VARCHAR(50) UNIQUE NOT NULL,
    channel_name VARCHAR(150) NOT NULL,
    country_code CHAR(2) NOT NULL,
    is_verified BOOLEAN NOT NULL,
    monetization_status VARCHAR(20) NOT NULL,
    subscriber_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL,

    CONSTRAINT channels_owner_fk FOREIGN KEY (owner_user_id)
        REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT channels_handle_format CHECK (handle ~ '^@[A-Za-z0-9_]+$'),
    CONSTRAINT channels_name_not_blank CHECK (btrim(channel_name) <> ''),
    CONSTRAINT channels_country_code_format CHECK (country_code ~ '^[A-Z]{2}$'),
    CONSTRAINT channels_monetization_status_allowed
        CHECK (monetization_status IN ('ELIGIBLE', 'NOT_ELIGIBLE', 'SUSPENDED')),
    CONSTRAINT channels_subscriber_count_nonnegative CHECK (subscriber_count >= 0)
);

CREATE TABLE videos (
    video_id CHAR(11) PRIMARY KEY,
    channel_id INTEGER NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(50) NOT NULL,
    duration_sec INTEGER NOT NULL,
    is_short BOOLEAN NOT NULL,
    is_made_for_kids BOOLEAN NOT NULL DEFAULT FALSE,
    visibility VARCHAR(20) NOT NULL,
    uploaded_at TIMESTAMPTZ NOT NULL,
    published_at TIMESTAMPTZ,
    view_count INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT videos_channel_fk FOREIGN KEY (channel_id)
        REFERENCES channels(channel_id) ON DELETE CASCADE,
    CONSTRAINT videos_id_format CHECK (video_id ~ '^[A-Za-z0-9_-]{11}$'),
    CONSTRAINT videos_title_not_blank CHECK (btrim(title) <> ''),
    CONSTRAINT videos_category_allowed CHECK (
        category IN ('Comedy', 'Cooking', 'Education', 'Film', 'Gaming',
                     'Music', 'News', 'Sports', 'Tech', 'Vlogs')
    ),
    CONSTRAINT videos_duration_positive CHECK (duration_sec > 0),
    CONSTRAINT videos_short_duration CHECK (NOT is_short OR duration_sec <= 60),
    CONSTRAINT videos_visibility_allowed
        CHECK (visibility IN ('PUBLIC', 'PRIVATE', 'UNLISTED', 'SCHEDULED')),
    CONSTRAINT videos_publication_state CHECK (
        (visibility = 'PRIVATE' AND published_at IS NULL)
        OR (visibility <> 'PRIVATE' AND published_at IS NOT NULL)
    ),
    CONSTRAINT videos_publication_order
        CHECK (published_at IS NULL OR published_at >= uploaded_at),
    CONSTRAINT videos_view_count_nonnegative CHECK (view_count >= 0)
);

CREATE TABLE subscriptions (
    user_id INTEGER NOT NULL,
    channel_id INTEGER NOT NULL,
    notifications VARCHAR(20) NOT NULL,
    subscribed_at TIMESTAMPTZ NOT NULL,

    PRIMARY KEY (user_id, channel_id),
    CONSTRAINT subscriptions_user_fk FOREIGN KEY (user_id)
        REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT subscriptions_channel_fk FOREIGN KEY (channel_id)
        REFERENCES channels(channel_id) ON DELETE CASCADE,
    CONSTRAINT subscriptions_notifications_allowed
        CHECK (notifications IN ('ALL', 'NONE', 'PERSONALIZED'))
);

CREATE TABLE watch_events (
    watch_id INTEGER PRIMARY KEY,
    user_id INTEGER,
    video_id CHAR(11) NOT NULL,
    started_at TIMESTAMPTZ NOT NULL,
    watch_seconds INTEGER NOT NULL,
    device VARCHAR(20) NOT NULL,
    traffic_source VARCHAR(30) NOT NULL,

    CONSTRAINT watch_events_user_fk FOREIGN KEY (user_id)
        REFERENCES users(user_id) ON DELETE SET NULL,
    CONSTRAINT watch_events_video_fk FOREIGN KEY (video_id)
        REFERENCES videos(video_id) ON DELETE CASCADE,
    CONSTRAINT watch_events_seconds_nonnegative CHECK (watch_seconds >= 0),
    CONSTRAINT watch_events_device_allowed
        CHECK (device IN ('ANDROID', 'IOS', 'TV', 'WEB')),
    CONSTRAINT watch_events_traffic_source_allowed CHECK (
        traffic_source IN ('EXTERNAL', 'HOME', 'SEARCH', 'SHORTS_FEED',
                           'SUBSCRIPTION', 'SUGGESTED')
    )
);

CREATE TABLE video_reactions (
    user_id INTEGER NOT NULL,
    video_id CHAR(11) NOT NULL,
    reaction VARCHAR(10) NOT NULL,
    reacted_at TIMESTAMPTZ NOT NULL,

    PRIMARY KEY (user_id, video_id),
    CONSTRAINT video_reactions_user_fk FOREIGN KEY (user_id)
        REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT video_reactions_video_fk FOREIGN KEY (video_id)
        REFERENCES videos(video_id) ON DELETE CASCADE,
    CONSTRAINT video_reactions_reaction_allowed
        CHECK (reaction IN ('LIKE', 'DISLIKE'))
);

CREATE TABLE comments (
    comment_id INTEGER PRIMARY KEY,
    video_id CHAR(11) NOT NULL,
    user_id INTEGER NOT NULL,
    parent_comment_id INTEGER,
    body TEXT NOT NULL,
    like_count INTEGER NOT NULL DEFAULT 0,
    is_pinned BOOLEAN NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,

    CONSTRAINT comments_video_fk FOREIGN KEY (video_id)
        REFERENCES videos(video_id) ON DELETE CASCADE,
    CONSTRAINT comments_user_fk FOREIGN KEY (user_id)
        REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT comments_parent_fk FOREIGN KEY (parent_comment_id)
        REFERENCES comments(comment_id) ON DELETE CASCADE,
    CONSTRAINT comments_body_not_blank CHECK (btrim(body) <> ''),
    CONSTRAINT comments_like_count_nonnegative CHECK (like_count >= 0),
    CONSTRAINT comments_reply_not_pinned
        CHECK (parent_comment_id IS NULL OR NOT is_pinned)
);

CREATE TABLE playlists (
    playlist_id INTEGER PRIMARY KEY,
    owner_user_id INTEGER NOT NULL,
    title VARCHAR(150) NOT NULL,
    visibility VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,

    CONSTRAINT playlists_owner_fk FOREIGN KEY (owner_user_id)
        REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT playlists_title_not_blank CHECK (btrim(title) <> ''),
    CONSTRAINT playlists_visibility_allowed
        CHECK (visibility IN ('PUBLIC', 'PRIVATE', 'UNLISTED'))
);

CREATE TABLE playlist_items (
    playlist_id INTEGER NOT NULL,
    position INTEGER NOT NULL,
    video_id CHAR(11) NOT NULL,
    added_at TIMESTAMPTZ NOT NULL,

    PRIMARY KEY (playlist_id, position),
    CONSTRAINT playlist_items_playlist_fk FOREIGN KEY (playlist_id)
        REFERENCES playlists(playlist_id) ON DELETE CASCADE,
    CONSTRAINT playlist_items_video_fk FOREIGN KEY (video_id)
        REFERENCES videos(video_id) ON DELETE CASCADE,
    CONSTRAINT playlist_items_position_positive CHECK (position > 0)
);

CREATE TABLE ad_impressions (
    impression_id INTEGER PRIMARY KEY,
    watch_id INTEGER NOT NULL,
    ad_format VARCHAR(20) NOT NULL,
    revenue_inr NUMERIC(10,4) NOT NULL,
    shown_at TIMESTAMPTZ NOT NULL,

    CONSTRAINT ad_impressions_watch_fk FOREIGN KEY (watch_id)
        REFERENCES watch_events(watch_id) ON DELETE CASCADE,
    CONSTRAINT ad_impressions_format_allowed
        CHECK (ad_format IN ('PREROLL', 'MIDROLL')),
    CONSTRAINT ad_impressions_revenue_nonnegative CHECK (revenue_inr >= 0)
);
