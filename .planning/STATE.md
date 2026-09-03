# ArtVault — Project State

## Current State: Production-Ready MVP

The app is a fully functional art collection manager with:
- **Cross-platform**: Android, iOS, Web, Windows
- **Offline-first**: Hive local storage, syncs when online
- **Multi-user**: Admin/Curator/Viewer roles via Supabase RLS
- **Cloud storage**: Google Drive (primary) → Supabase → Firebase Storage
- **Real-time sync**: Supabase Postgres streaming
- **Public galleries**: Shareable HTML pages with analytics

### Tech Stack
- Flutter 3.44.8 (stable)
- Firebase (Auth, Analytics, Crashlytics, Messaging, Storage fallback)
- Supabase (PostgreSQL DB, Storage, Realtime)
- Google Drive (user's own 15 GB for file storage)
- Hive (local offline-first storage)

### Test Coverage
- **182 tests passing, 0 analyzer issues** (re-verified Sep 3)
- Covers: auth, gallery, painting CRUD, sync, offline, RBAC, onboarding, animations

## Recent Work (this session)

### PR #17 — Web Support & UI Polish (merged to main)
1. **Google Drive storage** — primary file storage with 3-tier fallback (Drive → Supabase → Firebase)
2. **Web performance** — preconnect hints, stale-while-revalidate SW, skip mobile init, 5 MB tflite removal
3. **Cleanup** — 4.2 GB of build artifacts, temp files, dev scripts removed
4. **Lint fixes** — all 11 analyzer warnings resolved

### Sep 2 evening — Production-Readiness & Phase 7 sprint (8 commits, on main)
1. **GDPR compliance** — account deletion added to settings/profile (`280cbed`)
2. **Sync visibility** — pending sync count indicator + sync-status error visibility via `pendingSyncCountProvider` (`2d7c573`, `e6d90c2`)
3. **Lighthouse CI** — GitHub Action on push + PR to main with perf/a11y/best-practices/SEO assertions and WCAG AA color-contrast enforcement (`ce187a3`, `dd95330`)
4. **Accessibility** — skip-navigation link, semantic labels, focus management (`2de1dc7`); zoomable viewport fix (was flagged by the Lighthouse meta-viewport rule) (`dd95330`)
5. **Phase 7 partial** — trimmed 13 unused locales to English-only (removed dead code + language-picker sheet), added PWA install banner for web (`e97ab88`)
6. **Deploy** — Firebase Hosting auto-deploy GitHub Action on push to main (analyzer + tests + release web build gates); Open Graph + Twitter card meta tags in web/index.html (`42a31a2`)

### Commits (this session)
- `280cbed` feat(auth): add account deletion for GDPR compliance
- `2d7c573` feat: add pending sync count and improve error visibility
- `e6d90c2` feat: add pendingSyncCountProvider for sync visibility
- `ce187a3` ci: add Lighthouse CI for web performance monitoring
- `2de1dc7` feat(a11y): add skip navigation, semantic labels, and focus management
- `dd95330` feat(a11y): fix viewport meta-viewport and add Lighthouse color contrast CI
- `e97ab88` feat(phase7): localization cleanup, PWA install banner, dark mode polish
- `42a31a2` feat(deploy): add Firebase Hosting auto-deploy and Open Graph meta tags

## What's Done (comprehensive)

### Launch Experience
- ✅ Cinematic splash intro (3.4s full, 700ms quick, reduced-motion static)
- ✅ Staggered login fields
- ✅ Onboarding first-slide reveal with glow + ring + badge settle
- ✅ Pacing stretched ~1.5× for choreography feel

### Auth & Security
- ✅ Email/password, Google, Apple sign-in
- ✅ Biometric manage (face lock, fingerprint)
- ✅ Passcode lock with PBKDF2 hashing
- ✅ Offline guards for social sign-in
- ✅ Admin code gate for role management
- ✅ Account deletion for GDPR compliance

### Vault Core
- ✅ Painting CRUD with images, metadata, AI tags
- ✅ Artist profiles with photos, biography, social links
- ✅ Document attachments (certificates, invoices, provenance)
- ✅ Condition reports with chips, notes, photos
- ✅ Trash/restore with tombstone protection
- ✅ Batch operations (select, delete, export)

### Cloud & Sync
- ✅ Offline-first with Hive, background sync to Supabase
- ✅ Google Drive as primary file storage
- ✅ Real-time sync via Supabase Postgres streaming
- ✅ Pending sync count + sync-status error visibility in the UI
- ✅ Public gallery links with view analytics
- ✅ PDF exports (insurance schedule, QR labels, print reports)

### Web
- ✅ Desktop-first 3D shell with sidebar navigation
- ✅ Command palette (Ctrl+K)
- ✅ Keyboard shortcuts
- ✅ Drag-and-drop upload
- ✅ Context menus
- ✅ Stale-while-revalidate service worker
- ✅ Preconnect hints for faster first paint
- ✅ PWA install banner (subtle, dismissible, web-only)
- ✅ Firebase Hosting auto-deploy on push to main
- ✅ Open Graph / Twitter card meta tags

### Accessibility
- ✅ Skip-navigation link, semantic labels, focus management
- ✅ Zoomable viewport (user-scalable, max 5× — resolves meta-viewport audit)
- ✅ Lighthouse CI gates — WCAG AA color contrast fails CI

### UI & Motion
- ✅ App-wide animation overhaul (ticker-only, reduced-motion gated)
- ✅ Ken Burns hero transitions
- ✅ Gradient shimmer text
- ✅ Shake on error
- ✅ Ambient background with floating orbs

## Next Steps (candidate)

### High Priority
- **Verify CI on first run** — confirm Lighthouse CI and the Firebase Hosting deploy Action go green in GitHub Actions (Lighthouse: the lhci `startServerCommand` runs `flutter run` on port 3000, which may conflict with the static server the workflow starts on the same port)
- **Deploy to device** — feel-check animations and flow on real hardware
- **Update ROADMAP.md** — reflect current state, plan next milestones (synced Sep 3)

### Medium Priority
- **Dark mode polish** — verify all web widgets respect theme (no dedicated fixes landed yet)
- **PWA improvements** — native beforeinstallprompt interop, richer offline experience
- **Error handling** — comprehensive failure states across remaining flows

### Low Priority
- **Auth flows completion** — social provider scopes, account recovery UX
- **Localization** — real translations for non-English locales (currently English-only by design, "more languages coming soon")
- **App Store / Play Store listing**
- **Marketing site**
