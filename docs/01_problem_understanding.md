# Phase 1 — Problem Understanding

**Team:** T0106 · **Lead:** Priyanka Tiwari · **Members:** Abhimanyu, Kushagra Kaushik, Mani Amar Sehgal · **Date:** November 2026

## System and objective

The system stores YouTube users, creator channels, videos and Shorts, subscriptions, views, reactions, comments, playlists, and advertising revenue. Only raw CSV exports remain, so the team must rebuild a constrained PostgreSQL schema, measure the 30 supplied queries, optimize them without changing their results, and assess whether the design can handle 20× growth.

## Reported problems

| Problem | Business need and affected stakeholder | Queries | Classification |
|---|---|---|---|
| P1 | Channel, watch, and playlist pages must open quickly for viewers. | R01, R02, R15, R21 | Customer-facing / real-time |
| P2 | Signed-in viewers need responsive subscription feeds and watch history. | R03, R05 | Customer-facing / real-time |
| P3 | Viewers and the Search team need fast title search. | R04 | Customer-facing / real-time |
| P4 | Creators and YouTube Studio need timely views, retention, reaction, traffic-source, and subscriber reports. | R07, R08, R09, R14, R24 | Reporting / analytics |
| P5 | Creators need a correct list of subscribers who have never watched their channel. | R13 | Reporting / analytics |
| P6 | Recommendations must refresh the Shorts shelf and Trending tab from recent activity. | R10, R11 | Reporting / analytics |
| P7 | The publishing service must upload videos, record views, update counters, and publish scheduled videos promptly. | R06, W01, W02, W03, W05 | Customer-facing / real-time |
| P8 | Finance and the Partner Program need reliable revenue, eligibility, and Premium-ad audits. | R16, R17, R19, R25, W04 | Reporting / analytics |
| P9 | Trust, Safety, Moderation, Copyright, and Growth teams need scalable policy and usage reports. | R12, R18, R20, R22, R23 | Reporting / analytics |

## Assumptions derived from the supplied data

1. Each channel has one owner, and `owner_user_id` is unique in the supplied channel export.
2. A watch event may have no `user_id` because signed-out viewing is allowed.
3. Private videos have no `published_at`; public, unlisted, and scheduled videos do.
4. Shorts have a maximum duration of 60 seconds.
5. `subscriber_count`, `view_count`, and `like_count` are stored counters; the detailed event tables remain the source records.
6. Playlist position determines display order, and timestamps retain their time-zone offsets.
