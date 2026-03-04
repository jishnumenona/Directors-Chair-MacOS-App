# User Management — Implementation Progress

## Phase 1: Token Infrastructure (Server)
- [x] S-1.1: Add NATIVE_OAUTH2_CLIENT_ID to .env.example
- [x] S-1.2: Create auth/ Python package (models, validator, rate limiter, dependencies)
- [x] S-1.3: Add Redis + asyncpg to AI Proxy requirements, update docker-compose

## Phase 2: AI Proxy Auth Middleware (Server)
- [x] S-2.1: Add auth middleware to all /generate/* endpoints
- [x] S-2.2: Create usage tables (ai_usage_log, user_quotas)
- [x] S-2.3: Add usage logging after each AI call
- [x] S-2.4: Add quota enforcement

## Phase 3: Desktop Auth Manager + Keychain (Client)
- [x] C-3.1: Create KeychainService.swift
- [x] C-3.2: Create AuthManager.swift (OAuth2 PKCE)
- [x] C-3.3: Register URL scheme in Info.plist
- [x] C-3.4: Handle URL callback via onOpenURL
- [x] C-3.5: Wire AuthManager into app lifecycle
- [x] C-3.6: Add auth header to AIServiceClient (+ 401/429 error handling)

## Phase 4: Desktop Login UI + Account Menu (Client)
- [x] C-4.1: Create LoginView.swift
- [x] C-4.2: Create AccountMenuView.swift
- [x] C-4.3: Auth-gate ContentView
- [x] C-4.4: Create UsageStatsView.swift

## Phase 5: Cloud Sync via Gitea REST API (Client)
- [x] C-5.1: Extend GiteaClient with Contents API (getFileContents, createFile, updateFile, deleteFile, getTree, getRawFile, listContents)
- [x] C-5.2: Create CloudSyncManager.swift (push/pull via REST API)
- [x] C-5.3: Create SyncStatusView.swift (toolbar popover with sync status)
- [x] C-5.4: Wire sync into app lifecycle + toolbar

## Phase 6: API Server Endpoints (Server)
- [x] S-6.1: Rewrite api/main.py (asyncpg pool, Redis, auth)
- [x] S-6.2: Create usage endpoints (GET /api/usage/me, /me/history, /quota/me)
- [x] S-6.3: Create project endpoints (GET /api/projects, /{owner}/{repo}/overview)
- [x] S-6.4: Create admin endpoints (GET /api/admin/users, /usage/summary, POST /users/{username}/quota)

## Phase 7: Webapp Enhancements (Server)
- [x] S-7.1: Add project browser blueprint + templates
- [x] S-7.2: Enhance admin dashboard with AI usage stats
- [x] S-7.3: Add projects link to sidebar

## Phase 8: Security Hardening
- [x] S-8.1: CORS hardening (restricted to localhost + directorschair.app)
- [x] C-8.5: iOS compatibility (Security.framework + ASWebAuthenticationSession — cross-platform)
- [x] C-8.6: Backward compatibility (Continue Offline mode, auth-gated AI only)

## Remaining (Manual Steps)
- [ ] S-0: Register native OAuth2 app in Gitea admin panel (get CLIENT_ID)
- [ ] S-0: Set NATIVE_OAUTH2_CLIENT_ID in .env on server
- [ ] Update AuthConfiguration.default.clientID with actual client ID
