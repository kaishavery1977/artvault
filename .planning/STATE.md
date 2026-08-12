# ArtVault — Project State

## Current Milestone: Cinematic Launch Experience
Goal: the app's opening moments (splash → onboarding → login) feel deliberate and coherent.

### Done
- **Splash intro** (`lib/features/splash/splash_screen.dart`): spotlight bloom, logo settle, letter-by-letter wordmark with shimmer, pulsing dots, camera-push exit
- **Staggered login fields** (`lib/features/auth/login_screen.dart` + `lib/core/widgets/motion.dart` `staggerReveal` helper)
- **Onboarding first-slide reveal** (`lib/features/onboarding/onboarding_screen.dart`): glow + expanding ring + badge settle + staggered text, matching the splash hand-off
- **Pacing**: all stages stretched ~1.5× so the choreography can be felt (splash intro 3.4s, login cascade ~1.4s, onboarding reveal ~1.7s)
- Widget test re-timed for the longer timeline (wordmark asserted as letters; mount-time delay timers drained)

### Commits
- `3c54379` feat: cinematic splash intro and staggered login fields
- `d95df19` feat(onboarding): cinematic first-slide reveal to match splash hand-off
- `82c455d` perf(ui): slow the cinematic intros so they can be felt

### Verification
- `flutter analyze`: clean
- `flutter test`: green
- Working tree: clean

## Next Steps (candidate)
- Review the three commits with CodeRabbit; fix Critical/Warning findings
- Consider skip-on-second-launch and `prefers-reduced-motion` handling now that the splash is 3.4s
- Remaining auth/onboarding flow completeness
