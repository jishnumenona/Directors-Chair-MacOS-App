# User Management System

## Overview

Authentication, authorization, and cloud sync for DirectorsChair via Gitea OAuth2 (PKCE).

## Architecture

- **Identity Provider**: Self-hosted Gitea with OAuth2
- **Desktop Auth**: OAuth2 PKCE flow via `ASWebAuthenticationSession` + Keychain storage
- **Server Auth**: Bearer token validation against Gitea API with Redis caching
- **Cloud Sync**: Push/pull projects as Gitea repos via REST Contents API
- **Usage Tracking**: Per-user AI usage logging in PostgreSQL with quota enforcement

## Components

### Client (Desktop)
- `AuthManager` — OAuth2 PKCE login/logout/refresh, Keychain persistence
- `KeychainService` — Secure token storage via Security.framework
- `LoginView` — Full-screen login gate
- `AccountMenuView` — Toolbar user menu (account, usage, sync, logout)
- `CloudSyncManager` — Push/pull projects to/from Gitea repos
- `SyncStatusView` — Cloud sync status indicator

### Server
- `auth/` package — Shared token validation, rate limiting, models
- AI Proxy auth middleware — Gates all `/generate/*` endpoints
- Usage tracking — PostgreSQL `ai_usage_log` + `user_quotas` tables
- API server endpoints — Usage stats, project listing, admin tools

## User Flow

1. Launch app → LoginView if not authenticated
2. "Login with Gitea" → ASWebAuthenticationSession opens browser
3. User authorizes → callback with auth code
4. Exchange code for tokens (PKCE) → store in Keychain
5. All AI requests include `Authorization: Bearer <token>`
6. Token refresh happens automatically before expiry
7. Cloud sync: serialize project → push to Gitea repo via REST API
