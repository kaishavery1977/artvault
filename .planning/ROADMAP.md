# ArtVault — Roadmap

## Phase 1: Launch Polish (in progress)
1.1 ✅ Cinematic splash intro
1.2 ✅ Staggered login fields
1.3 ✅ Onboarding first-slide reveal
1.4 ✅ Pacing stretch (~1.5×)
1.5 ⬜ CodeRabbit review of 1.1–1.4 + Phase 1.6, fix findings
1.6 ✅ Repeat-launch quick intro + reduced-motion splash (committed `23494f4` `d3f3fed` `85857a4`)
1.7 ✅ Onboarding reveal gated on reduced motion (committed `1dfb0d0` on `feat/onboarding-polish`, PR #1)
1.8 ⬜ Land PR #1 after CodeRabbit review (squash merge)

## Phase 2: Auth & Onboarding Completion
1.1 ✅ Auth flows polish (biometric manage sheets, offline Google/Apple guards, About credit) — `feat/auth-flows-polish`, PR #4
1.2 ⬜ Land PRs #1–#4 after CodeRabbit review (squash merge)
1.3 ⬜ Social provider scopes / account recovery UX
- Onboarding completion → main vault entry

## Phase 3: Vault Core
- Artwork storage/browsing (Firestore + Storage rules enforcement)
- Main vault UI

## Phase 4: App-Wide Motion (in progress)
4.1 ✅ Ticker-only motion primitives (RevealEntrance, KenBurns, GradientShimmerText, ShakeOnError) — no pending timers, reduced-motion gated
4.2 ✅ Browse choreography: shell tab fade+drift, home greeting shimmer + welcome spotlight, gallery/search/trash/artist cascades, detail Ken Burns hero
4.3 ✅ Auth choreography: gradient wordmark, register/forgot cascade, lock-screen PIN shake
4.4 ✅ Settings/admin/lists cascades + shimmering About credit
4.5 ⬜ Land PR #6 after CodeRabbit review (squash merge); build onto phone for live feel-check

*Phases 2–3 are placeholders to be refined via GSD planning; do not treat as commitments.*
