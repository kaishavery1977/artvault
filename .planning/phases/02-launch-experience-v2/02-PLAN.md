# Phase 1.6 — Launch Experience v2 (repeat-launch + reduced motion)

**Goal:** The 3.4s cinematic splash plays in full on first launch, but returns users and motion-sensitive users get a quick, respectful hand-off — without weakening the splash's job as the session-restore wait point.

**Why the splash can't just be skipped:** `app_router.dart` redirects every non-`/splash` path back to `/splash` while `auth.status == unknown`, and the splash runs `authProvider.bootstrap()` concurrently with the intro. The hand-off already waits on `Future.wait([boot, delayed(intro)])`, so shortening the *presentation* keeps bootstrap safety intact.

**Architecture:**
- New persisted flag `kSplashIntroShown` (SettingsRepository, via LocalDatabase) — true once the user has seen the full intro.
- Splash selects a variant: full choreography (first run), quick intro (~700ms: logo + wordmark fade, no bloom/ring/stagger/pulse), or static (reduced motion: `MediaQuery.disableAnimationsOf(context)` — logo fade only, ~400ms).
- Hand-off always still waits for bootstrap; intro delay is the only thing that shortens.

## Tasks (waves)

### Wave 1 — plumbing
- [ ] **1.1 Add the flag.** `lib/core/constants/app_constants.dart`: add `kSplashIntroShown`. `lib/data/repositories/settings_repository.dart`: add `bool get splashIntroShown` and `Future<void> setSplashIntroShown()` mirroring the `onboarded` pair.
- Verify: `flutter analyze` clean.

### Wave 2 — splash variants
- [ ] **2.1 Introduce variant selection.** In `_SplashScreenState._start()`: read `SettingsRepository.instance.splashIntroShown` and `MediaQuery.disableAnimationsOf(context)`; choose `_introDuration` (3400 / ~700 / ~400 ms).
- [ ] **2.2 Static & quick renders.** `build()`: when reduced-motion, render logo + wordmark with no `.animate()` chains (keep `_exit` push). When quick mode, keep logo + wordmark with a single short fade, skip spotlight/ring/stagger/shimmer/dots.
- [ ] **2.3 Set the flag.** After the first full intro completes (in `_start()`, right before hand-off, only when the full variant ran): `await SettingsRepository.instance.setSplashIntroShown()`.
- Verify: `flutter analyze` clean; `flutter test` green.

### Wave 3 — tests
- [ ] **3.1 Update boot test.** Existing pumps assume the 3400ms intro; keep them (first-run path unchanged) and assert full wordmark still renders.
- [ ] **3.2 Repeat-launch test.** Pre-set `splashIntroShown = true` in the test's LocalDatabase; pump ~800ms; assert the hand-off to `/onboarding` (or `/home`) fires.
- [ ] **3.3 Reduced-motion test.** Wrap the app in `MediaQuery(data: ...disableAnimations: true)`; pump ~500ms; assert navigation happens with no pending animation timers.
- Verify: `flutter analyze` + `flutter test` green.

## Phase verification
- `flutter analyze`: clean
- `flutter test`: all pass
- Manual: cold launch shows full intro once; relaunch shows the quick variant; system reduced-motion shows static splash.

## Follow-up (after this phase lands)
- CodeRabbit review (`coderabbit review --agent --base-commit 82c455d`) of Phase 1.6 + the earlier splash/onboarding commits.
