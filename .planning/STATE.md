# ArtVault — Project State

## Current Milestone: Cinematic Launch Experience
Goal: the app's opening moments (splash → onboarding → login) feel deliberate and coherent.

### Done
- **Splash intro** (`lib/features/splash/splash_screen.dart`): spotlight bloom, logo settle, letter-by-letter wordmark with shimmer, pulsing dots, camera-push exit
- **Staggered login fields** (`lib/features/auth/login_screen.dart` + `lib/core/widgets/motion.dart` `staggerReveal` helper)
- **Onboarding first-slide reveal** (`lib/features/onboarding/onboarding_screen.dart`): glow + expanding ring + badge settle + staggered text, matching the splash hand-off
- **Pacing**: all stages stretched ~1.5× so the choreography can be felt (splash intro 3.4s, login cascade ~1.4s, onboarding reveal ~1.7s)
- **Phase 1.6 — launch experience v2**: full 3.4s intro on first launch; ~700ms quick logo+wordmark fade on repeat launches; static render + no camera-push under reduced motion. Flag write is best-effort so a storage hiccup never blocks the hand-off. Widget tests cover all three variants (full / quick / reduced-motion via `FakeAccessibilityFeatures`).
- Widget tests re-timed for the longer timeline (wordmark asserted as letters; mount-time delay timers drained)

### Commits
- `3c54379` feat: cinematic splash intro and staggered login fields
- `d95df19` feat(onboarding): cinematic first-slide reveal to match splash hand-off
- `82c455d` perf(ui): slow the cinematic intros so they can be felt
- `3193316` docs(gsd): add planning scaffold and launch-experience-v2 phase plan
- `23494f4` feat(splash): add persisted splash-intro-shown flag
- `d3f3fed` feat(splash): quick intro and static reduced-motion variants
- `85857a4` test(splash): cover full, quick, and reduced-motion boot

### Verification
- `flutter analyze`: clean
- `flutter test`: green (3 boot tests: full / quick / reduced-motion)
- Working tree: clean

## Next Steps (candidate)
- Open a PR so the CodeRabbit app reviews the Phase 1.6 commits; adopt a feature-branch → PR workflow for future phases so reviews happen automatically
- Consider gating the onboarding reveal on reduced motion too (currently only the splash respects it)
- Remaining auth/onboarding flow completeness
