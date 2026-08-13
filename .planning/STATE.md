# ArtVault — Project State

## Current Milestone: Cinematic Launch Experience
Goal: the app's opening moments (splash → onboarding → login) feel deliberate and coherent.

### Done
- **Splash intro** (`lib/features/splash/splash_screen.dart`): spotlight bloom, logo settle, letter-by-letter wordmark with shimmer, pulsing dots, camera-push exit
- **Staggered login fields** (`lib/features/auth/login_screen.dart` + `lib/core/widgets/motion.dart` `staggerReveal` helper)
- **Onboarding first-slide reveal** (`lib/features/onboarding/onboarding_screen.dart`): glow + expanding ring + badge settle + staggered text, matching the splash hand-off
- **Pacing**: all stages stretched ~1.5× so the choreography can be felt (splash intro 3.4s, login cascade ~1.4s, onboarding reveal ~1.7s)
- **Phase 1.6 — launch experience v2**: full 3.4s intro on first launch; ~700ms quick logo+wordmark fade on repeat launches; static render + no camera-push under reduced motion. Flag write is best-effort so a storage hiccup never blocks the hand-off. Widget tests cover all three variants (full / quick / reduced-motion via `FakeAccessibilityFeatures`).
- **RalphLoop goal C — onboarding complete & delightful**: best-effort persistence on finish (fire-and-forget; worst case onboarding replays), slide reveal gates on `MediaQuery.disableAnimationsOf` (roadmap 1.7 ✅). Verification surfaced and fixed two real device bugs: AuthLayout `Border` per-side colors + `borderRadius` paint assert, and login footer/remember-me rows overflowing on narrow widths. New Hive test harness (fake `PathProviderPlatform` over a temp dir) + shared test helpers (providers pinned, google_fonts runtime fetch off); 3 new onboarding tests (Skip → login, Next walkthrough, reduced-motion static).
- Widget tests re-timed for the longer timeline (wordmark asserted as letters; mount-time delay timers drained)
- **RalphLoop goals A (offline-first) & B (premium browsing)**: PR #2 (sync edge fixes: trash/purge resurrection, tombstone queue; 10 no-network tests) and PR #3 (debounced instant search, lightbox Hero hand-off, cascade gallery stagger; 5 tests). Both open for CodeRabbit review.
- **RalphLoop goal — auth flows complete**: biometric manage sheets (re-scan face, test/remove fingerprint), offline guards for Google/Apple sign-in, guarded secure-storage reads so Security can't freeze, GlassCard paint-crash fix; 'Built by Kais Havery' About credit; 12 new auth tests.
- **Restore & profile fixes** (PR #5 `feat/vault-restore-fixes`): auto-pull vault on login so the home section populates without pressing Sync; `_pullRemote` URL adoption + `_syncPainting` URL alignment (photos no longer missing after cloud restore); local-first profile restore so name/avatar edits survive re-login; avatar upload to storage with `photoUrl`; storage.rules avatar entry; 13 tests.
- **App-wide animation overhaul** (PR #6 `feat/app-animations`): ticker-only `RevealEntrance`/`KenBurns`/`GradientShimmerText`/`ShakeOnError` primitives (no pending timers, reduced-motion gated); shell tab fade+drift; home greeting shimmer + welcome spotlight; gallery/search/trash/artist/documents/notifications/reports/users item cascades; detail Ken Burns hero; register/forgot cascade; lock-screen PIN shake; settings/profile/security/storage/backup card cascades; shimmering About credit.

### Commits
- `3c54379` feat: cinematic splash intro and staggered login fields
- `d95df19` feat(onboarding): cinematic first-slide reveal to match splash hand-off
- `82c455d` perf(ui): slow the cinematic intros so they can be felt
- `3193316` docs(gsd): add planning scaffold and launch-experience-v2 phase plan
- `23494f4` feat(splash): add persisted splash-intro-shown flag
- `d3f3fed` feat(splash): quick intro and static reduced-motion variants
- `6aa254e` docs(gsd): mark launch-experience-v2 phase complete
- `85e0393` docs(gsd): adopt branch-per-phase workflow with CodeRabbit PR review
- `1dfb0d0` feat(onboarding): best-effort persistence on finish, reduced-motion gating (branch `feat/onboarding-polish`)
- `993e11e` fix(auth): prevent paint crash and narrow-screen overflows
- `9415114` test(onboarding): cover skip, walkthrough, and reduced-motion render
- `64aca61` fix(auth): replace illegal per-side borders and overflow-prone rows (branch `feat/auth-flows-polish`)
- `b15a1e4` feat(security): manage face lock and fingerprint after enrollment
- `02ebf84` feat(about): credit the builder on the About screen
- `6d38076` test(auth): cover validation, offline social guard, biometric manage

### Verification
- `flutter analyze`: clean
- `flutter test`: 33/33 green (3 boot + 12 auth + 5 browse + 13 restore/profile)
- PRs #1–#5 merged into `main`; PR #6 (`feat/app-animations` → main) open for CodeRabbit review
- Working tree: clean (on `feat/app-animations`)

## Next Steps (candidate)
- Land PR #6 (`feat/app-animations`) after CodeRabbit review; squash merge per branch-per-phase workflow
- Build merged `main` onto the phone via wireless debugging so the animation overhaul can be felt live
- Auth flows: remaining sign-in path completeness (social provider scopes, account recovery UX)
