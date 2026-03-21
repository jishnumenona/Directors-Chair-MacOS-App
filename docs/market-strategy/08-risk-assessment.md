# Risk Assessment — DirectorsChair

**Date**: March 2026

---

## Risk Framework

Each risk is assessed on:
- **Probability**: Low (< 20%), Medium (20-50%), High (> 50%)
- **Impact**: Low (minor inconvenience), Medium (slows growth), High (existential threat)
- **Mitigation**: Specific actions to reduce probability or impact

---

## Technical Risks

### T1. Single-Developer Bus Factor
| | |
|---|---|
| **Probability** | High (current reality) |
| **Impact** | High (project dies if developer is unavailable) |
| **Description** | All architectural knowledge, codebase familiarity, and operational knowledge resides with one person. No documentation of system internals, no second developer onboarding guide. |
| **Mitigation** | |
| Short-term | Document architecture decisions, create CONTRIBUTING.md, maintain inline code comments |
| Medium-term | Recruit 1-2 part-time contributors (open-source selective components or hire) |
| Long-term | Build team of 3-5 engineers with overlapping knowledge areas |

### T2. Server Infrastructure Scalability
| | |
|---|---|
| **Probability** | Medium (will occur if user growth succeeds) |
| **Impact** | High (downtime = churn, especially for cloud sync/AI features) |
| **Description** | Current architecture: single DigitalOcean droplet ($24/mo) running Docker containers. No load balancing, no auto-scaling, no redundancy. Database (PostgreSQL) and file storage (Gitea) on same server. |
| **Mitigation** | |
| Short-term | Implement monitoring/alerting (UptimeRobot, Grafana); automated backups |
| Medium-term | Separate database to managed PostgreSQL; add CDN for static assets |
| Long-term | Kubernetes or Docker Swarm for horizontal scaling; multi-region deployment |
| **Trigger point** | Scale infrastructure when DAU exceeds 500 or monthly AI requests exceed 50K |

### T3. AI API Dependency and Costs
| | |
|---|---|
| **Probability** | High (AI costs are real and growing with users) |
| **Impact** | Medium-High (margin compression, potential feature degradation) |
| **Description** | All AI features depend on third-party APIs (Google, OpenAI, Stability, ElevenLabs). Costs per generation: text $0.005-0.02, image $0.04-0.08, video $0.50-1.00, speech $0.01-0.05. A heavy user could cost $50-100/month in API calls. Provider pricing can change without notice. |
| **Mitigation** | |
| Short-term | Implement strict per-tier usage limits; monitor cost per user in real-time |
| Medium-term | Negotiate volume pricing with primary providers (Google); cache common requests |
| Long-term | Explore on-device AI (Apple Neural Engine) for text/lightweight tasks; consider self-hosted open models (Llama, SDXL) for cost reduction |
| **Target** | Maintain AI cost at <35% of subscription revenue per user |

### T4. Data Loss or Corruption
| | |
|---|---|
| **Probability** | Low-Medium (complex sync increases risk) |
| **Impact** | High (losing a user's screenplay or production data is catastrophic) |
| **Description** | Local JSON files + Gitea cloud sync. Sync conflicts could corrupt project data. No automated backup verification. Git LFS for media files adds complexity. |
| **Mitigation** | |
| Short-term | Local auto-backup (versioned snapshots every save); conflict detection before merge |
| Medium-term | Server-side automated backups with point-in-time recovery |
| Long-term | Redundant storage (S3-compatible object storage for media); disaster recovery plan |
| **SLA Target** | <1 hour RPO (Recovery Point Objective), <4 hour RTO (Recovery Time Objective) |

### T5. Security Breach
| | |
|---|---|
| **Probability** | Medium (storing sensitive creative IP invites targeting) |
| **Impact** | High (leaked unreleased scripts/content = trust destruction) |
| **Description** | Cloud stores intellectual property: unreleased screenplays, character designs, production plans. Gitea instance exposed to internet. OAuth tokens in transit. Single server = single point of compromise. |
| **Mitigation** | |
| Short-term | Regular security updates; restrict Gitea API surface; implement rate limiting |
| Medium-term | Security audit; penetration testing; encrypted-at-rest storage |
| Long-term | SOC 2 Type II compliance; bug bounty program; end-to-end encryption option |

### T6. NLE Format Compatibility Risk
| | |
|---|---|
| **Probability** | Medium (Apple, Avid, and Adobe control their formats) |
| **Impact** | Medium-High (broken export = broken headline feature) |
| **Description** | The Automated Footage Assembly Pipeline depends on exporting to NLE timeline formats: FCPXML (Final Cut Pro), AAF (Avid Media Composer), and EDL (universal). These formats are controlled by Apple, Avid, and Adobe respectively. Format spec changes, undocumented quirks, or version incompatibilities could break the assembly pipeline — DirectorsChair's most important differentiator. FCPXML in particular has had breaking changes between Final Cut Pro versions. AAF is notoriously complex with limited public documentation. |
| **Mitigation** | |
| Short-term | Start with FCPXML (best documented) and EDL (simplest, universal); defer AAF; build comprehensive test suite against multiple NLE versions |
| Medium-term | Maintain compatibility matrix; automated testing against Final Cut Pro, DaVinci Resolve, Premiere Pro; community-reported issue tracking |
| Long-term | Join FCPXML developer community; consider partnership with Blackmagic (DaVinci Resolve has open ecosystem); build fallback XML-based format for manual import |
| **Critical note** | This risk is manageable because EDL is a universal fallback that all NLEs support. Even if FCPXML or AAF break, EDL ensures the core value proposition (automated assembly) always works. |

### T7. macOS Platform Lock-in
| | |
|---|---|
| **Probability** | High (SwiftUI/AppKit is deeply embedded) |
| **Impact** | Medium (limits addressable market to ~25%) |
| **Description** | The entire desktop app is built with SwiftUI, AppKit (NSTextView), and macOS-specific frameworks (AVFoundation for capture, Core Image for LUTs). Porting to Windows/web requires significant architectural changes. |
| **Mitigation** | |
| Short-term | Accept macOS-only; focus on Apple ecosystem strength |
| Medium-term | Build web read-only viewer for cross-platform access |
| Long-term | Evaluate Swift on Windows (experimental), Electron/Tauri wrapper, or native rewrite of core features |
| **Decision point** | If user growth stalls due to platform limitation (measure through signup abandonment data) |

---

## Market Risks

### M1. Competitor AI Feature Parity
| | |
|---|---|
| **Probability** | High (every competitor is adding AI in 2026) |
| **Impact** | Medium (erodes key differentiator) |
| **Description** | StudioBinder, Celtx, and Arc Studio are all adding AI features. StudioBinder has $10M+ in funding to invest. If they ship AI shot generation, character design, or script analysis, DirectorsChair's AI advantage narrows. |
| **Mitigation** | |
| Short-term | Ship AI features faster; deepen existing AI (trait calibration, multi-angle portraits are hard to replicate) |
| Medium-term | Build AI features that require deep workflow integration (AI scheduling from script breakdown, AI continuity checking across scenes) — these are harder for competitors to bolt on |
| Long-term | AI is a feature, not the moat. **The moat is the Automated Footage Assembly Pipeline** — it requires the entire data chain (script → shots → connections → takes → timeline) that took 2+ years to build. Even if competitors achieve AI parity, they cannot replicate automated assembly without first building the complete production management layer. |

### M2. Big Tech Platform Entry
| | |
|---|---|
| **Probability** | Low-Medium (possible but not imminent) |
| **Impact** | High (existential if Apple or Adobe enters directly) |
| **Description** | Apple (Final Cut ecosystem), Adobe (Premiere + Frame.io), or Google (Veo + Workspace) could build or acquire a production management platform. Their distribution, brand, and resources would be overwhelming. |
| **Mitigation** | |
| Short-term | Move fast — establish market position before big tech moves |
| Medium-term | Build deep domain expertise that generalist platforms won't match (prop continuity, take management, script-to-shot connections) |
| Long-term | Become an acquisition target (best outcome) or build enough switching costs through data/workflow lock-in |
| **Signal to watch** | Apple acquiring a production management startup; Adobe adding pre-production features to Premiere |

### M3. Market Fragmentation Persists
| | |
|---|---|
| **Probability** | Medium (filmmaking tools have always been fragmented) |
| **Impact** | Medium (limits total addressable market for all-in-one tools) |
| **Description** | Filmmakers may prefer best-in-class individual tools: Final Draft for writing, StudioBinder for production, Runway for AI video. The "all-in-one" value proposition may not resonate if each module isn't best-in-class. |
| **Mitigation** | |
| Short-term | Ensure FDX/Fountain export is flawless — let users adopt DirectorsChair gradually |
| Medium-term | Build integrations with popular tools (Frame.io, DaVinci Resolve) so DirectorsChair is a hub, not a silo |
| Long-term | Make each module independently competitive; users should choose DirectorsChair for ANY single feature, then discover the rest |

### M4. Film Industry Economic Downturn
| | |
|---|---|
| **Probability** | Medium (streaming cost cuts already happening) |
| **Impact** | Medium (fewer productions = fewer potential customers) |
| **Description** | Streaming platforms cutting content budgets. Potential recession reducing entertainment spend. Film financing becoming harder for indie projects. |
| **Mitigation** | |
| Short-term | Target budget-conscious filmmakers (they're more likely to adopt during downturns) |
| Medium-term | Diversify beyond film: theater, advertising, corporate video, YouTube creators |
| Long-term | Recession-resistant positioning: "save money by consolidating tools" |

### M5. AI Regulation Restricting Use
| | |
|---|---|
| **Probability** | Medium (EU AI Act effective 2025; US state laws emerging) |
| **Impact** | Medium (could limit AI features, especially AI-generated content in professional productions) |
| **Description** | Regulations may require: AI content labeling, consent for training data, restrictions on AI-generated faces/voices, union rules against AI in certain production roles. |
| **Mitigation** | |
| Short-term | Implement AI content metadata/watermarking proactively |
| Medium-term | Position AI as "assistant" not "replacement" — AI helps filmmakers, doesn't replace them |
| Long-term | Engage with industry groups and regulators; comply early to build trust |

---

## Operational Risks

### O1. Pricing Model Failure
| | |
|---|---|
| **Probability** | Medium (first attempt rarely optimal) |
| **Impact** | Medium (too expensive = no users; too cheap = no margin) |
| **Description** | The proposed pricing ($14.99 Pro, $39.99 Studio, $4.99 Education) is based on competitive analysis but untested. AI costs may be higher than projected. Users may not convert from free. |
| **Mitigation** | |
| Short-term | Launch with flexible pricing; gather data on conversion and churn |
| Medium-term | A/B test pricing; monitor AI cost per user; adjust tiers based on actual usage patterns |
| Long-term | Dynamic pricing based on value delivered; consider usage-based components |

### O2. Support Burden Overwhelming Solo Developer
| | |
|---|---|
| **Probability** | High (will happen with any meaningful user base) |
| **Impact** | Medium (support time = less development time = slower feature delivery) |
| **Description** | Users will need help with: onboarding, sync issues, AI failures, billing, feature requests. A solo developer handling support AND development is unsustainable past ~500 active users. |
| **Mitigation** | |
| Short-term | Comprehensive docs, FAQ, video tutorials; community Discord for peer support |
| Medium-term | Hire part-time support person or use AI-assisted support (chatbot for common issues) |
| Long-term | Build self-service tools (diagnostic reports, sync status dashboard, usage analytics) |

### O3. App Store Rejection or Policy Changes
| | |
|---|---|
| **Probability** | Low-Medium (Apple's review process is unpredictable) |
| **Impact** | Medium (delays distribution; 30% revenue cut if using in-app purchase) |
| **Description** | Apple may reject the app for policy violations, require in-app purchase (30% cut on subscriptions), or change guidelines affecting AI-generated content. |
| **Mitigation** | |
| Short-term | Distribute via notarized DMG initially (bypass App Store) |
| Medium-term | Submit to App Store as additional distribution channel; use web-based payment to avoid 30% cut |
| Long-term | Comply with App Store guidelines while maintaining direct distribution as primary channel |

### O4. Founder Burnout
| | |
|---|---|
| **Probability** | Medium-High (solo founder + ambitious product = high risk) |
| **Impact** | High (directly correlates with T1 — single developer dependency) |
| **Description** | Building, marketing, supporting, and maintaining a complex multi-platform product as a solo developer is unsustainable long-term. |
| **Mitigation** | |
| Short-term | Set realistic milestones; prioritize ruthlessly; automate everything possible |
| Medium-term | Revenue enables hiring — first hire should reduce highest-burden tasks |
| Long-term | Build team; delegate; transition from "builder" to "product leader" |

---

## Risk Priority Matrix

```
                           IMPACT
                   Low      Medium      High
              ┌─────────┬──────────┬──────────┐
         High │         │ M1, O2   │ T1, T3   │
              │         │ O4       │          │
  PROBABILITY ├─────────┼──────────┼──────────┤
       Medium │         │ M3, M4   │ T2, T4   │
              │         │ M5, O1   │ T5, T6   │
              ├─────────┼──────────┼──────────┤
          Low │         │ O3       │ M2       │
              │         │          │          │
              └─────────┴──────────┴──────────┘
```

### Top 5 Risks by Combined Priority

| Rank | Risk | Prob × Impact | Immediate Action |
|------|------|--------------|-----------------|
| 1 | **T1: Single-developer dependency** | High × High | Document architecture; begin contributor recruitment |
| 2 | **T3: AI API cost exposure** | High × Medium-High | Implement usage limits and cost monitoring |
| 3 | **T6: NLE format compatibility** | Medium × Medium-High | Build FCPXML/EDL test suite; test against multiple NLE versions |
| 4 | **T2: Server scalability** | Medium × High | Set up monitoring; plan scaling architecture |
| 5 | **O2: Support burden** | High × Medium | Build comprehensive docs and self-service tools |

---

## Risk Mitigation Budget

| Risk Area | Monthly Budget | Actions |
|-----------|---------------|---------|
| Infrastructure reliability | $50-200 | Monitoring, backups, redundancy |
| Security | $0-100 | Regular updates, basic audit tools |
| AI cost management | $0 (process) | Usage limits, cost tracking |
| Documentation | $0 (time) | Architecture docs, user guides |
| Community/support | $0-50 | Discord, FAQ, tutorials |
| **Total** | **$50-350/mo** | |

---

## Risk Review Schedule

| Frequency | Review |
|-----------|--------|
| Weekly | AI cost per user, server uptime, crash reports |
| Monthly | User growth vs projections, churn rate, support ticket volume |
| Quarterly | Competitive landscape scan, pricing model assessment, technology risk review |
| Annually | Full strategic risk assessment, insurance review, security audit |

---

## Contingency Plans

### If user growth stalls (<1,000 users after 6 months):
1. Pivot marketing approach — double down on film school partnerships
2. Consider open-sourcing non-AI core features to build community
3. Re-evaluate pricing (potentially go fully free with AI-only monetization)

### If a major competitor ships equivalent AI features:
1. **Lead with the Automated Footage Assembly Pipeline** — this is the moat they cannot replicate
2. Shift differentiation to workflow integration depth (not AI alone)
3. Accelerate assembly pipeline features (multi-camera, AI-assisted take selection, smart assembly ordering)
4. Consider strategic partnership or merger

### If AI API costs exceed 40% of revenue:
1. Implement stricter usage tiers
2. Move to on-device AI for text generation (Apple Neural Engine)
3. Self-host open models (Llama, SDXL) for cost-sensitive operations
4. Adjust pricing upward for heavy AI tiers

### If security breach occurs:
1. Immediate: Disable external access, rotate all credentials, notify affected users
2. Short-term: Engage security consultant, conduct forensic analysis
3. Medium-term: Implement remediation, communicate transparently, offer affected users extended free tier
4. Long-term: SOC 2 certification, ongoing penetration testing

### If Apple restricts App Store distribution:
1. Maintain direct distribution (notarized DMG) as primary channel
2. Ensure web-based payment works for subscription management
3. If forced to use in-app purchase, adjust pricing to account for 30% cut

### If NLE format compatibility breaks (FCPXML/AAF version changes):
1. Immediately fall back to EDL export (universal, simple, all NLEs support it)
2. Hotfix compatibility within 1-2 weeks of NLE version release
3. Maintain active testing against beta versions of Final Cut Pro, DaVinci Resolve, Premiere Pro
4. Build community-reported compatibility database
5. Long-term: partner with NLE vendors for advance format documentation access
