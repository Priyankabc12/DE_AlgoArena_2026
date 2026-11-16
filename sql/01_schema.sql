CREATE SCHEMA IF NOT EXISTS youtube;
SET search_path TO youtube;

-- USERS
CREATE TABLE users (
    user_id INTEGER PRIMARY KEY,
    email VARCHAR(150) UNIQUE NOT NULL,
    display_name VARCHAR(100) NOT NULL,
    country_code CHAR(2) NOT NULL,
    birth_year SMALLINT,
    premium_until DATE,
    created_at TIMESTAMPTZ NOT NULL,
    CHECK (country_code ~ '^[A-Z]{2}$')
);

-- CHANNELS
CREATE TABLE channels (
    channel_id INTEGER PRIMARY KEY,
    owner_user_id INTEGER NOT NULL UNIQUE,
    handle VARCHAR(50) UNIQUE NOT NULL,
    channel_name VARCHAR(150) NOT NULL,
    country_code CHAR(2) NOT NULL,
    is_verified BOOLEAN NOT NULL,
    monetization_status VARCHAR(20) NOT NULL,
    subscriber_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL,
    FOREIGN KEY (owner_user_id)
        REFERENCES users(user_id)
        ON DELETE CASCADE
);

-- VIDEOS
CREATE TABLE videos (
    video_id CHAR(11) PRIMARY KEY,
    channel_id INTEGER NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(50) NOT NULL,
    duration_sec INTEGER NOT NULL,
    is_short BOOLEAN NOT NULL,
    is_made_for_kids BOOLEAN NOT NULL,
    visibility VARCHAR(20) NOT NULL,
    uploaded_at TIMESTAMPTZ NOT NULL,
    published_at TIMESTAMPTZ,
    view_count INTEGER NOT NULL DEFAULT 0,

    FOREIGN KEY (channel_id)
        REFERENCES channels(channel_id)
        ON DELETE CASCADE,

    CHECK (duration_sec > 0),
    CHECK (char_length(video_id)=11),
    CHECK (visibility IN ('PUBLIC','PRIVATE','UNLISTED','SCHEDULED')),
    CHECK (is_short = FALSE OR duration_sec <= 60)
);

-- SUBSCRIPTIONS
CREATE TABLE subscriptions (
    user_id INTEGER,
    channel_id INTEGER,
    notifications VARCHAR(20) NOT NULL,
    subscribed_at TIMESTAMPTZ NOT NULL,

    PRIMARY KEY(user_id, channel_id),

    FOREIGN KEY(user_id)
        REFERENCES users(user_id)
        ON DELETE CASCADE,

    FOREIGN KEY(channel_id)
        REFERENCES channels(channel_id)
        ON DELETE CASCADE
);

-- WATCH EVENTS
CREATE TABLE watch_events (
    watch_id INTEGER PRIMARY KEY,
    user_id INTEGER,
    video_id CHAR(11) NOT NULL,
    started_at TIMESTAMPTZ NOT NULL,
    watch_seconds INTEGER NOT NULL,
    device VARCHAR(20) NOT NULL,
    traffic_source VARCHAR(30) NOT NULL,

    FOREIGN KEY(user_id)
        REFERENCES users(user_id)
        ON DELETE SET NULL,

    FOREIGN KEY(video_id)
        REFERENCES videos(video_id)
        ON DELETE CASCADE,

    CHECK (watch_seconds >= 0)
);

-- VIDEO REACTIONS
CREATE TABLE video_reactions (
    user_id INTEGER,
    video_id CHAR(11),
    reaction VARCHAR(10) NOT NULL,
    reacted_at TIMESTAMPTZ NOT NULL,

    PRIMARY KEY(user_id, video_id),

    FOREIGN KEY(user_id)
        REFERENCES users(user_id)
        ON DELETE CASCADE,

    FOREIGN KEY(video_id)
        REFERENCES videos(video_id)
        ON DELETE CASCADE,

    CHECK (reaction IN ('LIKE','DISLIKE'))
);

-- COMMENTS
CREATE TABLE comments (
    comment_id INTEGER PRIMARY KEY,
    video_id CHAR(11) NOT NULL,
    user_id INTEGER NOT NULL,
    parent_comment_id INTEGER,
    body TEXT NOT NULL,
    like_count INTEGER DEFAULT 0,
    is_pinned BOOLEAN NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,

    FOREIGN KEY(video_id)
        REFERENCES videos(video_id)
        ON DELETE CASCADE,

    FOREIGN KEY(user_id)
        REFERENCES users(user_id)
        ON DELETE CASCADE,

    FOREIGN KEY(parent_comment_id)
        REFERENCES comments(comment_id)
        ON DELETE CASCADE
);

-- PLAYLISTS
CREATE TABLE playlists (
    playlist_id INTEGER PRIMARY KEY,
    owner_user_id INTEGER NOT NULL,
    title VARCHAR(150) NOT NULL,
    visibility VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,

    FOREIGN KEY(owner_user_id)
        REFERENCES users(user_id)
        ON DELETE CASCADE
);

-- PLAYLIST ITEMS
CREATE TABLE playlist_items (
    playlist_id INTEGER,
    position INTEGER,
    video_id CHAR(11) NOT NULL,
    added_at TIMESTAMPTZ NOT NULL,

    PRIMARY KEY(playlist_id, position),

    FOREIGN KEY(playlist_id)
        REFERENCES playlists(playlist_id)
        ON DELETE CASCADE,

    FOREIGN KEY(video_id)
        REFERENCES videos(video_id)
        ON DELETE CASCADE
);

-- AD IMPRESSIONS
CREATE TABLE ad_impressions (
    impression_id INTEGER PRIMARY KEY,
    watch_id INTEGER NOT NULL,
    ad_format VARCHAR(20) NOT NULL,
    revenue_inr NUMERIC(10,4) NOT NULL,
    shown_at TIMESTAMPTZ NOT NULL,

    FOREIGN KEY(watch_id)
        REFERENCES watch_events(watch_id)
        ON DELETE CASCADE,

    CHECK (revenue_inr >= 0)
);