# Growth Roadmap — DirectorsChair

**Date**: March 2026

---

## Current State Assessment

### What's Built (Production-Ready)
- Full screenplay editor with FDX/Fountain/PDF/HTML export
- Character design with 70+ fields, 25 personality traits, 12-angle AI portraits
- Location world-building with 3D cinema scenes
- Cinematography: shot planning, scene connections, timeline, AI video generation
- Production management: budget (6 tabs), schedule (3 views), cast/crew, equipment
- Cloud sync via Gitea with per-user isolation
- OAuth2 authentication, AI usage tracking
- iPad digital clapboard (DirectorsChairSlate) with timecode sync
- Take management with timestamps, ratings (Circle/Alt/NG), camera source tracking
- 7 AI providers, 12+ AI features
- Guided tour and onboarding

### What's In Development (Partially Built — CRITICAL DIFFERENTIATOR)
- **Automated Footage Assembly Pipeline**: The building blocks exist (take metadata, shot-script connections, timeline positioning, clapboard sync). What remains is: footage ingestion/matching engine, assembly logic, and NLE timeline export (FCPXML, AAF, EDL). This is the single most important feature to complete — it creates a new product category.

### What's Missing (Critical Gaps)
- **Complete Automated Assembly Pipeline** (highest priority — category-creating feature)
- Real-time collaboration
- Windows/web access
- iOS companion app
- App Store distribution
- User community / social proof
- Automated testing suite
- Enterprise features (SSO, audit logs)

---

## 6-Month Roadmap (March 2026 — September 2026)

### Month 1-2: Beta Launch Foundation

#### Feature Priorities
| Priority | Feature | Effort | Impact |
|----------|---------|--------|--------|
| P0 | **Automated Footage Assembly Pipeline v1** (footage ingestion, script matching, EDL export) | 4 weeks | **Category-creating differentiator** — no competitor has this |
| P0 | **Public beta signup and distribution** | 2 weeks | Enables user acquisition |
| P0 | **Crash reporting and analytics** | 1 week | Enables data-driven decisions |
| P0 | **Onboarding improvements** (example project, tooltips) | 2 weeks | Reduces churn |
| P1 | **Freemium tier enforcement** (AI limits, project caps) | 1 week | Enables monetization |
| P1 | **Stripe payment integration** | 2 weeks | Enables revenue |
| P1 | **App notarization and distribution** (DMG/PKG or TestFlight) | 1 week | Enables secure distribution |

#### Go-to-Market
- Launch private beta with 100-200 indie filmmakers
- Post on r/Filmmakers, r/Screenwriting, r/IndieFilm — **lead with character psychology analysis** (screenwriters will try this immediately; it's the lowest-friction entry point)
- Create demo video showing: 1) character analysis from script, 2) full screenplay → production workflow
- Set up landing page with waitlist at directorschair.app — hero section should feature the pentagon personality chart and assembly pipeline side by side

### Month 3-4: Public Beta + Revenue

#### Feature Priorities
| Priority | Feature | Effort | Impact |
|----------|---------|--------|--------|
| P0 | **Assembly Pipeline v2** (FCPXML export for Final Cut Pro, multi-camera sync) | 3 weeks | Headline launch feature |
| P0 | **Subscription billing** (Stripe, annual/monthly) | 1 week | Revenue |
| P0 | **AI credit system** (per-tier limits, top-up packs) | 2 weeks | Margin control |
| P1 | **AAF export** (Avid Media Composer support) | 2 weeks | Studio market reach |
| P1 | **Project sharing** (read-only link sharing) | 2 weeks | Collaboration v0 |
| P1 | **Mac App Store submission** | 2 weeks | Distribution channel |
| P1 | **Auto-update mechanism** (Sparkle or App Store) | 1 week | User retention |
| P2 | **Script collaboration** (shared editing, comments) | 3 weeks | Team adoption |

#### Go-to-Market
- Product Hunt launch — **lead with the Automated Assembly Pipeline as the headline**
- "Founding Member" pricing ($9.99/mo locked for 12 months)
- First case study: shoot a short film with DirectorsChair and demo the full pipeline (script → shoot → auto-assembled timeline in Final Cut Pro)
- Begin film school outreach (5-10 programs)
- YouTube tutorial series: "From Script to Editor Timeline in One App"
- **Demo video**: Side-by-side of manual assembly (hours) vs DirectorsChair automated assembly (minutes)

### Month 5-6: Stabilization + Education

#### Feature Priorities
| Priority | Feature | Effort | Impact |
|----------|---------|--------|--------|
| P0 | **Server scaling** (multi-container, load balancing) | 2 weeks | Reliability |
| P0 | **Automated backup system** | 1 week | Data safety |
| P1 | **Education tier** (institutional dashboard, roles) | 3 weeks | Revenue stream |
| P1 | **Improved AI screenplay import** (handle edge cases) | 2 weeks | Onboarding quality |
| P2 | **Script diff/merge** for collaboration | 2 weeks | Team feature |
| P2 | **iOS companion app kickoff** | Begin 17-week timeline | Platform expansion |

#### Go-to-Market
- First education pilot: 2-3 film schools
- Industry conference presence (ideally demo booth at a regional film festival)
- Press outreach to filmmaking media (No Film School, IndieWire, Filmmaker Magazine)
- Community forum launch

---

## 12-Month Roadmap (March 2026 — March 2027)

### Month 7-9: Platform Expansion

#### Feature Priorities
| Priority | Feature | Effort | Impact |
|----------|---------|--------|--------|
| P0 | **Web companion app** (read-only project viewer) | 6 weeks | Cross-platform access |
| P0 | **Real-time collaboration v1** (conflict resolution, live cursors) | 8 weeks | Team adoption |
| P1 | **iOS companion app launch** | Continued | On-set mobile |
| P1 | **Template library** (built-in screenplay structures, budget templates) | 3 weeks | Onboarding |
| P2 | **API for third-party integrations** | 4 weeks | Ecosystem |

### Month 10-12: Deepening + Marketplace

#### Feature Priorities
| Priority | Feature | Effort | Impact |
|----------|---------|--------|--------|
| P0 | **AI storyboard generation** (full scene → storyboard panels) | 4 weeks | Key differentiator |
| P1 | **Template/asset marketplace** (user-generated content) | 6 weeks | Revenue + retention |
| P1 | **Advanced AI features** (AI scheduling suggestions, budget estimation) | 4 weeks | Production value |
| P2 | **Integration: Frame.io** (review and approval workflow) | 3 weeks | Pipeline |
| P2 | **Integration: Final Cut Pro** (XML export/import) | 2 weeks | Post-production bridge |
| P2 | **Localization** (Spanish, French, Portuguese, Hindi) | 4 weeks | Regional markets |

#### 12-Month Targets
| Metric | Target |
|--------|--------|
| Total registered users | 20,000 |
| Paid subscribers | 2,500 |
| ARR | $500K |
| Film school partnerships | 15-20 |
| NPS | >40 |
| Monthly churn | <5% |

---

## 24-Month Roadmap (March 2026 — March 2028)

### Year 2: Scale + Enterprise

#### Q1 (Month 13-15): Enterprise Foundation
- **SSO/SAML authentication** for studio accounts
- **Role-based access control** (director, writer, producer, PA roles)
- **Audit logging** for compliance
- **Multi-project dashboards** for production companies
- **Windows app** (via Catalyst/SwiftUI cross-compilation or Electron wrapper)

#### Q2 (Month 16-18): AI Leadership
- **AI-powered scheduling** (auto-generate optimal shoot schedule from script breakdown)
- **AI casting suggestions** (match character descriptions to available cast)
- **AI budget estimation** (estimate costs from script analysis)
- **AI continuity checker** (flag continuity errors across scenes)
- **On-device AI** (Apple Neural Engine for offline AI features)

#### Q3 (Month 19-21): Ecosystem
- **Full marketplace launch** with creator payouts
- **Plugin/extension system** for third-party developers
- **Integration hub**: DaVinci Resolve, Premiere Pro, Avid, ShotGrid
- **Apple Vision Pro app** for spatial pre-visualization

#### Q4 (Month 22-24): Market Leadership
- **Enterprise tier launch** (custom pricing, dedicated support, SLA)
- **Distribution partnerships** (camera manufacturers, film equipment rental houses)
- **Industry certification** (recognized by guilds/unions as production tool)
- **International expansion** (localized marketing in top 5 film markets)

#### 24-Month Targets
| Metric | Target |
|--------|--------|
| Total registered users | 100,000 |
| Paid subscribers | 10,000 |
| ARR | $2M+ |
| Film school partnerships | 50+ |
| Enterprise accounts | 20-30 |
| Available platforms | macOS, iOS, iPadOS, Web, Windows |

---

## Missing Capabilities — Priority Assessment

### Critical (Must Have for Market Viability)

| Capability | Why Critical | Timeline |
|-----------|-------------|----------|
| **Automated Footage Assembly Pipeline** | **Category-creating feature, strongest competitive moat, headline differentiator** | Month 1-4 |
| Payment/billing | Can't monetize without it | Month 1-2 |
| App distribution (notarized DMG or App Store) | Users can't install without it | Month 1-2 |
| Analytics/crash reporting | Can't improve without data | Month 1 |
| NLE timeline export (FCPXML, AAF, EDL) | Delivers assembly pipeline value to editors | Month 2-4 |
| Auto-updates | Users won't manually update | Month 3-4 |
| Basic collaboration (sharing, comments) | Teams won't adopt without it | Month 3-6 |

### Important (Needed for Growth)

| Capability | Why Important | Timeline |
|-----------|--------------|----------|
| Real-time co-editing | Team adoption blocker | Month 7-9 |
| iOS companion | On-set workflows | Month 5-12 |
| Web viewer | Cross-platform access | Month 7-9 |
| Automated tests | Prevent regressions as features grow | Month 3-6 |
| Server scaling | Reliability at >1000 users | Month 5-6 |

### Nice to Have (Competitive Advantages)

| Capability | Why Valuable | Timeline |
|-----------|-------------|----------|
| AI storyboard generation | Unique differentiator | Month 10-12 |
| Apple Vision Pro | Media attention, early adopter draw | Month 19-21 |
| Plugin system | Ecosystem lock-in | Month 19-21 |
| Windows app | Market reach expansion | Month 13-15 |

---

## Partnership Opportunities

### Tier 1: Strategic (Pursue Immediately)

| Partner Type | Examples | Value |
|-------------|---------|-------|
| Film schools | USC, NYU, AFI, NFTS, VFS, local programs | Distribution, credibility, recurring revenue |
| Film festivals | Sundance, SXSW, Tribeca labs/programs | Visibility, filmmaker access |
| Filmmaking educators | YouTube channels (D4Darious, Film Riot, DSLRguide) | Audience reach |

### Tier 2: Growth (Pursue in 6-12 Months)

| Partner Type | Examples | Value |
|-------------|---------|-------|
| Camera manufacturers | Blackmagic, RED, Sony | Hardware integration, co-marketing |
| Post-production tools | Frame.io, DaVinci Resolve | Pipeline integration |
| AI providers | Google, Stability, ElevenLabs | Preferred pricing, co-development |
| Equipment rental | Lensrentals, BorrowLenses, ShareGrid | User channel, cross-promotion |

### Tier 3: Scale (Pursue in 12-24 Months)

| Partner Type | Examples | Value |
|-------------|---------|-------|
| Streaming platforms | Short film programs (Netflix Short Film Fund) | Distribution integration |
| Talent agencies | WME, CAA digital divisions | Enterprise access |
| Insurance providers | Production insurance companies | Bundle deals |
| Unions/guilds | SAG-AFTRA, WGA (educational programs) | Industry legitimacy |

---

## Go-to-Market Strategy

### Channel Strategy

| Channel | Investment | Expected CAC | Priority |
|---------|-----------|-------------|----------|
| **Organic/SEO** (blog, tutorials) | $0 (time) | $0 | High |
| **Filmmaking communities** (Reddit, forums) | $0 (time) | $0 | High |
| **YouTube content** (tutorials, case studies) | $0-500/mo | $5-10 | High |
| **Product Hunt** launch | $0 | $2-5 | Medium |
| **Film school outreach** (direct) | $0 (time) | $0 per student | High |
| **Filmmaker YouTube sponsors** | $500-2000/video | $15-30 | Medium |
| **Film festival presence** | $1000-5000/event | $20-50 | Medium |
| **Google/Apple Search Ads** | $500-2000/mo | $30-50 | Low (later) |

### Content Strategy
1. **"Analyze Your Characters" viral hook**: Upload a screenplay → AI generates 25-trait psychological profiles of every character with pentagon charts and evidence. Shareable, visual, instantly compelling. This is the top-of-funnel acquisition tool — writers will share their character analyses on social media.
2. **"Script to Timeline" demo**: The killer video — write a script, plan shots, shoot with clapboard, and watch the footage auto-assemble into a Final Cut Pro timeline. No competitor can show this.
3. **"Making Of" series**: Document creating a short film entirely in DirectorsChair, highlighting character analysis + assembly pipeline saving days of work
4. **Template releases**: Free screenplay templates, budget templates, shot list templates
5. **Comparison content**: "DirectorsChair vs StudioBinder", "DirectorsChair vs Celtx" — lead with "none of them analyze your characters psychologically or auto-assemble your footage"
6. **Tutorial series**: "From Script to Editor Timeline" — step-by-step production workflow
7. **AI filmmaking content**: Showcase AI character generation, shot previsualization, video generation
8. **Character psychology content**: "What a Psychologist Would Say About Your Screenplay Characters" — use DirectorsChair to analyze characters from famous screenplays, share results

### Community Building
- **Discord server** for beta users, feature requests, filmmaking discussion
- **Monthly showcase**: Highlight projects made with DirectorsChair
- **Feature request voting**: Public roadmap with user voting (GitHub Discussions or Canny)
- **Beta tester recognition**: Credits in app, early access to features
