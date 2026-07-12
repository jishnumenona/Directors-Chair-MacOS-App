# Secrets & Auth Design — DirectorsChair Server (replacement)

Status: design / not-yet-built. Scope: the new first-party server that replaces
the retired Gitea droplet, plus the secrets hygiene that applies to **every**
repo in the suite.

This document is deliberately grounded in the concrete failures the July 2026
suite audit found, so the same mistakes can't be reintroduced. Each principle
below names the anti-pattern it retires.

---

## 0. What went wrong last time (the failures this design retires)

| # | Audit finding | Root cause | This design's answer |
|---|---|---|---|
| 1 | GitHub PAT, Google API key, Gitea token, admin password committed to public repos | secrets in source & docs | §1 — secrets never in source; env-only; scanning gate |
| 2 | Plaintext admin creds in `docs/CREDENTIALS.md`; live root password `DirectorsChair2026` on an internet-facing droplet | passwords stored/shared in cleartext | §2.6 — argon2id hashing, no shared passwords, key-only SSH |
| 3 | Web app had an **admin-token authz fallback bypass** (`webapp/blueprints/projects.py`) | a backdoor path around normal authz | §2.5 — single authorization path, no admin-token shortcut |
| 4 | Server sent `Authorization: token {user.username}` instead of the bearer token (`api/routers/projects.py`) | auth identity conflated with a bearer credential | §2.2 — opaque bearer tokens, never the username/identifier |
| 5 | Client stored tokens in UserDefaults (pre-WS3.1) | no secure client storage | §2.4 — macOS Keychain only (already implemented) |
| 6 | Concurrent 401s double-spent a rotating refresh token → session loss | no refresh coalescing | §2.3 — single-flight refresh (already implemented) |

The desktop client already got items 4–6 right during WS3 (`AuthManager`:
Keychain via Security.framework, `inFlightRefresh` coalescing, OAuth `state`
CSRF check, offline-tolerant `restoreSession`). **The server must be designed to
match that client, not undo it.**

---

## 1. Secrets management

**Principle: no secret ever lives in source, docs, or a committed config file.
Configuration comes from the environment; the environment comes from a secret
store.**

### 1.1 The three environments
- **Local dev** — a `.env` file, **git-ignored**, loaded at process start. A
  committed `.env.example` documents every key with placeholder values (never
  real ones). New devs copy `.env.example` → `.env` and fill it.
- **CI** — GitHub Actions encrypted secrets (`${{ secrets.X }}`), injected as
  env vars for the step that needs them. Never `echo`'d; never written to logs.
- **Production** — secrets delivered to the service as environment variables by
  the platform, **not** a file in the repo or the image:
  - Minimum viable (single box): a `systemd` unit with
    `EnvironmentFile=/etc/directorschair/server.env`, that file `chmod 600`,
    owned by the service user, outside any git tree.
  - Better: a managed secret store (Doppler / 1Password Secrets Automation /
    AWS Secrets Manager / GCP Secret Manager / HashiCorp Vault) that injects at
    boot or fetches at runtime. Pick one and standardize.

### 1.2 `.env.example` contract (illustrative)
```dotenv
# --- Server ---
PORT=8002
PUBLIC_BASE_URL=https://api.directorschair.app

# --- Database ---
DATABASE_URL=postgres://user:password@localhost:5432/directorschair

# --- Auth ---
JWT_SIGNING_KEY=            # 32+ random bytes; rotate on schedule (see §3)
ACCESS_TOKEN_TTL_SECONDS=900
REFRESH_TOKEN_TTL_DAYS=30

# --- Third-party AI providers (server holds these, NOT the desktop app) ---
ANTHROPIC_API_KEY=
OPENAI_API_KEY=
GOOGLE_API_KEY=
DEEPSEEK_API_KEY=
```
The real values exist only in each environment's secret store. `.env` is in
`.gitignore`; `.env.example` is committed.

### 1.3 Provider keys live on the server, never in the client
The Google API key leaked *because it was embedded in the desktop app*. Fix the
class of bug: the desktop app calls **your** server; your server calls the AI
providers using keys from its own environment. The client never ships a provider
key. (This also gives you per-user rate limiting, cost control, and provider
switching without shipping an app update.)

---

## 2. Auth architecture

### 2.1 Transport
- HTTPS only. HSTS enabled. HTTP → HTTPS redirect. Modern TLS (1.2+).
- The desktop app pins the API base URL via config (`PUBLIC_BASE_URL`), never a
  hard-coded IP (that's what made `165.22.172.244` a liability).

### 2.2 Authentication — token model
First-party email/password (or an OAuth IdP if preferred; the client already
implements Authorization-Code + `state`). On successful login the server issues:
- **Access token** — a signed JWT, short-lived (~15 min), carrying `sub` (user
  id), `exp`, `iat`, and minimal scope claims. Sent as `Authorization: Bearer
  <token>`. **It is an opaque credential to the client — never the username**
  (retires audit #4).
- **Refresh token** — an opaque, high-entropy random string, stored **server-side
  hashed** so it can be revoked. Long-lived (~30 days), single-use (rotates on
  every refresh — see §2.3).

Access tokens are stateless (fast to verify, no DB hit); refresh tokens are
stateful (revocable). This is the standard split.

### 2.3 Refresh rotation + reuse detection
- Every `/auth/refresh` issues a **new** refresh token and invalidates the
  presented one (rotation).
- The client already coalesces concurrent refreshes (`inFlightRefresh`) so a
  burst of 401s spends the refresh token **once** (retires audit #6). The server
  must tolerate this: rotation is atomic, and a brief grace window (a few
  seconds) on the just-rotated token avoids racing a legitimately in-flight
  request.
- **Reuse detection:** if an *already-rotated* refresh token is presented, treat
  it as theft — revoke the entire token family for that session and force
  re-login. Refresh tokens belong to a `family_id`; reuse nukes the family.

### 2.4 Client-side token storage
- macOS **Keychain** via Security.framework (`kSecClassGenericPassword`,
  `AfterFirstUnlockThisDeviceOnly`) — already implemented in release builds.
  **Never** UserDefaults in release (retires audit #5). DEBUG may use UserDefaults
  to avoid unsigned-`swift test` Keychain prompts, but there is **no release
  fallback** (a fallback would reintroduce the vuln).

### 2.5 Authorization — one path, no backdoors
- Every protected endpoint authorizes the **same way**: verify the bearer token,
  resolve `sub`, enforce per-user (and per-resource) ownership.
- **No admin-token fallback, no "if this header matches, skip authz" shortcut**
  (retires audit #3). Admin actions are a *role claim* checked by the same
  middleware, not a separate credential that bypasses it.
- Resource scoping is server-enforced: a user can only read/write their own
  projects. The client's per-user directory scoping (`ProjectDirectoryManager`)
  is a UX convenience, **not** a security boundary — the server is the boundary.

### 2.6 Passwords & server access
- User passwords: hashed with **argon2id** (or bcrypt cost ≥ 12). Never stored
  or logged in cleartext (retires audit #2). No password ever appears in a repo,
  doc, or log line.
- Server host access: **SSH keys only**, password auth disabled
  (`PasswordAuthentication no`), root login disabled (`PermitRootLogin no`), a
  non-root deploy user with `sudo`. This is exactly the exposure that let a
  public root password sit reachable on the old droplet.
- Rate-limit and lock out auth endpoints (login, refresh) to blunt brute force.

### 2.7 CSRF / callback integrity
- If any browser/OAuth callback flow is used, verify the `state` parameter
  (already implemented client-side in `AuthManager.handleCallback`).
- For any cookie-based web session: `SameSite=Lax/Strict`, `Secure`, `HttpOnly`,
  plus a CSRF token on state-changing requests.

---

## 3. Secret scanning & rotation (wired now)

### 3.1 Scanning gate (in this repo as of this change)
- **CI:** a `secret-scan` job runs `gitleaks` over the working tree **and full
  git history** on every push/PR (`.gitleaks.toml`). Promote it to a *required*
  status check after a couple of green runs (branch-protection, owner action).
- **Local:** `scripts/verify.sh` runs the same scan before every commit when
  gitleaks is installed (`brew install gitleaks`).
- Apply the identical job to the new server repo from commit #1.

### 3.2 Rotation runbook (per credential type)
1. **Issue** the new secret in the provider.
2. **Deploy** it to the environment's secret store (dev/CI/prod).
3. **Verify** the new one works (health check).
4. **Revoke** the old one at the provider.
5. **Confirm revocation** with a read-only call — a live response means it's not
   actually rotated. (This is exactly how the July-2026 leaked credentials were
   confirmed dead: GitHub PAT → `401`, Google key → `400 API key not valid`,
   Gitea token → `401`.)
6. If the secret was ever committed: rotation makes it harmless, but scrub it
   from history (`git filter-repo`) or delete the dead repo.

### 3.3 Cadence
- Signing/JWT keys and provider keys: rotate on a schedule (e.g. quarterly) and
  immediately on any suspected exposure.
- Keep a single owner-maintained inventory of *what* secrets exist and *where*
  each lives — never the values, just the map.

---

## 4. New-server bring-up checklist
- [ ] Repo created with `.gitignore` covering `.env`, and a committed `.env.example`.
- [ ] `secret-scan` (gitleaks) CI job present from the first commit.
- [ ] Secrets in a store (env-file 600 / managed vault) — none in source.
- [ ] HTTPS + HSTS; base URL configurable, no hard-coded host/IP.
- [ ] Access-JWT + rotating opaque refresh tokens; reuse detection with families.
- [ ] One authorization middleware; no admin-token bypass; server-enforced ownership.
- [ ] argon2id password hashing; auth-endpoint rate limiting.
- [ ] SSH key-only, root login + password auth disabled, non-root deploy user.
- [ ] AI provider keys server-side only; desktop app calls the server, never providers directly.
- [ ] Client unchanged where it's already correct: Keychain storage, refresh coalescing, `state` check.

---

*Companion change:* this repo now ships the gitleaks CI job + `.gitleaks.toml` +
a `verify.sh` scan, and the stale `165.22.172.244` default was removed from
`FEATURE_LIST.md`. The desktop client's existing `AuthManager` is the reference
the server should conform to.
