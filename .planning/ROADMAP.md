# ArtVault — Roadmap

## Phase 1: Launch Polish ✅ COMPLETE
1.1 ✅ Cinematic splash intro
1.2 ✅ Staggered login fields
1.3 ✅ Onboarding first-slide reveal
1.4 ✅ Pacing stretch (~1.5×)
1.5 ✅ CodeRabbit review + fixes
1.6 ✅ Repeat-launch quick intro + reduced-motion splash
1.7 ✅ Onboarding reveal gated on reduced motion
1.8 ✅ Landing complete

## Phase 2: Auth & Onboarding ✅ COMPLETE
2.1 ✅ Auth flows polish (biometric manage, offline guards, About credit)
2.2 ✅ All PRs merged
2.3 ✅ Social provider integration (Google, Apple)

## Phase 3: Vault Core ✅ COMPLETE
3.1 ✅ Painting CRUD with images, metadata, AI tags
3.2 ✅ Artist profiles with photos, biography
3.3 ✅ Document attachments
3.4 ✅ Condition reports
3.5 ✅ Trash/restore with tombstone protection
3.6 ✅ Batch operations

## Phase 4: App-Wide Motion ✅ COMPLETE
4.1 ✅ Ticker-only motion primitives
4.2 ✅ Browse choreography
4.3 ✅ Auth choreography
4.4 ✅ Settings/admin/lists cascades
4.5 ✅ All merged

## Phase 5: Web Support ✅ COMPLETE
5.1 ✅ Desktop-first 3D shell with sidebar
5.2 ✅ Command palette, keyboard shortcuts
5.3 ✅ Drag-and-drop, context menus
5.4 ✅ Google Drive as primary file storage
5.5 ✅ Web performance optimizations
5.6 ✅ Cleanup (4.2 GB removed)
5.7 ✅ All merged to main

## Phase 6: Production Readiness (mostly complete)
6.1 🟡 Auth flows — account deletion added for GDPR compliance; remaining: social provider scopes, account recovery UX
6.2 ⬜ Deploy to device — feel-check animations and flow on real hardware
6.3 ✅ Performance monitoring — Lighthouse CI on push + PR (perf/a11y/best-practices/SEO thresholds; WCAG AA color contrast blocks CI)
6.4 ✅ Accessibility audit — skip navigation, semantic labels, focus management; zoomable viewport (meta-viewport fix)
6.5 ✅ Error handling — pending sync count + sync-status error visibility added
6.6 ✅ CI/CD — Firebase Hosting auto-deploy on push to main (analyzer + tests + release web build gates); Open Graph / Twitter card meta in web/index.html

## Phase 7: Polish & Launch (current)
7.1 ✅ Localization cleanup — trimmed 13 unused locales to English-only; language picker replaced with "English (more languages coming soon)"
7.2 ⬜ Dark mode polish — verify all web widgets respect theme (no dedicated fixes landed yet)
7.3 🟡 PWA improvements — install banner added for web; remaining: native beforeinstallprompt interop, richer offline experience
7.4 ⬜ App Store / Play Store listing
7.5 ⬜ Marketing site
