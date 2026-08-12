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

### Verification
- `flutter analyze`: clean
- `flutter test`: green (3 boot tests: full / quick / reduced-motion + 3 onboarding tests)
- PR #1 open (`feat/onboarding-polish` → main) awaiting CodeRabbit review
- Working tree: clean (on `main`)

## Next Steps (candidate)
- Land PR #1 after CodeRabbit review; squash merge per branch-per-phase workflow
- RalphLoop goals A (offline-first hardening) and B (premium vault browsing) queued
- Remaining auth/onboarding flow completeness
