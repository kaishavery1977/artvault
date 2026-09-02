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
- **182 tests passing**, 0 analyzer issues
- Covers: auth, gallery, painting CRUD, sync, offline, RBAC, onboarding, animations

## Recent Work (this session)

### PR #17 — Web Support & UI Polish (merged to main)
1. **Google Drive storage** — primary file storage with 3-tier fallback (Drive → Supabase → Firebase)
2. **Web performance** — preconnect hints, stale-while-revalidate SW, skip mobile init, 5 MB tflite removal
3. **Cleanup** — 4.2 GB of build artifacts, temp files, dev scripts removed
4. **Lint fixes** — all 11 analyzer warnings resolved

### Commits (this session)
- `6b939ec` fix: resolve all flutter analyze warnings (11 → 0)
- `94cd8c5` feat(storage): Google Drive as primary file storage with 3-tier fallback
- `303eb67` chore: clean up 4.2 GB of build artifacts, temp files, and dev scripts
- `c9952bb` perf(web): optimize load time and bundle size for web

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

### UI & Motion
- ✅ App-wide animation overhaul (ticker-only, reduced-motion gated)
- ✅ Ken Burns hero transitions
- ✅ Gradient shimmer text
- ✅ Shake on error
- ✅ Ambient background with floating orbs

## Next Steps (candidate)

### High Priority
- **Auth flows completion** — social provider scopes, account recovery UX
- **Deploy to device** — feel-check animations and flow on real hardware
- **Update ROADMAP.md** — reflect current state, plan next milestones

### Medium Priority
- **Performance monitoring** — add Lighthouse CI for web, track bundle size
- **Accessibility audit** — screen reader testing, keyboard navigation
- **Error handling** — comprehensive error states for all failure modes

### Low Priority
- **Localization** — translate remaining screens (currently English + 8 locales declared)
- **Dark mode polish** — verify all web widgets respect theme
- **PWA improvements** — better offline experience, install prompt
