# ArtVault — Project Context

## Vision
A Flutter art vault app: a place to store, browse, and appreciate artworks, with a cinematic, deliberate onboarding and auth experience.

## Stack
- Flutter 3.44.8 (stable) — app framework; targets android / ios / web / windows
- Firebase — Firestore (`firestore.rules`, `firestore.indexes.json`), Cloud Storage (`storage.rules`), hosting config (`firebase.json`), project pinned in `.firebaserc`
- flutter_animate — motion primitives for the splash/onboarding choreography

## Working Conventions
- Per-commit identity: `ArtVault Dev <dev@artvault.local>` (no global git identity configured; pass per-invocation)
- Verify with `flutter analyze` and `flutter test` before committing
- Motion language is shared: splash and onboarding speak the same bloom/ring/cascade vocabulary via `lib/core/widgets/motion.dart`

## Operating Mode
Work is planned, executed, and verified through GSD (this `.planning/`), reviewed with CodeRabbit (`coderabbit review --agent`), and driven autonomously via the Ralph loop when a wide outcome prompt is given.
