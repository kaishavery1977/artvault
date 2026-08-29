# ArtVault

**Your Private Gallery** — a secure, offline-first Flutter app for managing art collections. Catalogue paintings, track artists, store provenance documents, monitor condition reports, and share your collection via public QR-coded gallery links.

---

## Features

### Core Collection Management
- **Paintings** — Add, edit, and organize artworks with cover images, dimensions, medium, style, price, availability, and up to 12 images per piece.
- **Artists** — Profile artists with bios, photos, and link them to their works.
- **Documents** — Attach certificates, invoices, insurance docs, appraisals, and restoration reports to paintings.
- **Condition Reports** — Track artwork condition over time with timestamped inspections and photos.

### Smart Features
- **AI Insights** — Dashboard analytics: most common medium, most collected artist, average dimensions, upload trends.
- **Face Recognition** — On-device ML Kit face detection for biometric app lock and optional face-based vault unlock with blink-liveness anti-spoofing.
- **QR Scanner & Gallery Links** — Generate QR codes for paintings; scan codes to jump to artwork details. Public shareable gallery links with configurable expiry.
- **Duplicate Detection** — Similarity threshold-based detection to flag likely duplicate uploads.
- **Search** — Full-text search across paintings with filters.

### Security
- **AES-256 Encryption** — All local Hive boxes encrypted with keys stored in the OS secure enclave.
- **App Lock** — 4-digit passcode with PBKDF2-HMAC-SHA256 hashing, exponential lockout (30s → 10min).
- **Biometric Auth** — Fingerprint and face unlock via platform secure enclave.
- **Firebase App Check** — Play Integrity (Android) / App Attest (iOS) to block unauthorized API calls.
- **RBAC** — Admin, Curator, and Viewer roles enforced both client-side and via Firestore rules.

### Cloud & Offline
- **Offline-First** — Full functionality without network. All data lives in encrypted local Hive boxes first.
- **Cloud Sync** — Firebase Firestore sync with exponential backoff retry queue (persists across restarts).
- **Restore from Cloud** — Automatic vault re-download after reinstall with live progress reporting.
- **Cloud Backup** — Full vault JSON snapshots in Firebase Storage.

### Export & Reporting
- **PDF Reports** — Generate collection reports and insurance schedules as PDFs.
- **Excel/CSV Export** — Export painting data for spreadsheets.
- **Collection Value** — Running total of artwork prices with multi-currency support.

### Premium (Pro)
- Unlimited paintings (free: 25), artists (free: 5), documents (free: 5), and storage (free: 100 MB).
- Longer gallery link expiry (up to 1 year vs 30 days).
- Pro upgrade via Razorpay or Google Play In-App Purchases with server-side plan verification.

---

## Architecture

```
lib/
├── main.dart                      # Boot sequence, providers, MaterialApp
├── core/
│   ├── config/                    # Environment configuration
│   ├── constants/                 # App-wide constants, colors, pro limits
│   ├── extensions/                # Dart/Flutter extensions
│   ├── providers/                 # Riverpod providers (split by domain)
│   │   ├── providers.dart         # Barrel re-export
│   │   ├── auth_providers.dart    # Auth state, controller, restore progress
│   │   ├── data_providers.dart    # Collection data, stats, sync health
│   │   ├── settings_providers.dart# Theme, locale, onboarding
│   │   └── storage_providers.dart # Storage usage, device disk space
│   ├── router/                    # GoRouter config with RBAC guards
│   ├── services/                  # Business logic services
│   ├── theme/                     # Material 3 design system, adaptive layout
│   └── widgets/                   # Shared widgets (glassmorphism, animations)
├── data/
│   ├── models/                    # Data models (Painting, Artist, etc.)
│   ├── repositories/              # Repository pattern (local + cloud)
│   ├── local/                     # Hive database
│   └── remote/                    # Firebase/Supabase backends
├── features/                      # Feature screens
│   ├── home/                      # Dashboard with stats, AI insights
│   ├── gallery/                   # Grid/list gallery with search
│   ├── painting/                  # Detail, form, lightbox, trash
│   ├── artists/                   # Artist profiles
│   ├── documents/                 # Attached documents
│   ├── reports/                   # Collection reports
│   ├── auth/                      # Login, register, face scan
│   ├── settings/                  # Profile, security, storage, about
│   ├── admin/                     # User management, backups
│   ├── pro/                       # Upgrade flow, celebration
│   ├── qr/                        # QR scanner
│   ├── notifications/             # In-app notifications
│   ├── onboarding/                # First-run experience
│   └── splash/                    # Cinematic intro, app lock
└── utils/                         # HTTP overrides, helpers
```

### Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3.44+ (Dart 3.12+) |
| State | Riverpod 2.x |
| Navigation | GoRouter 17.x |
| Local DB | Hive (AES-256 encrypted) |
| Cloud | Firebase (Auth, Firestore, Storage, Functions, Messaging, Crashlytics, Analytics, App Check) |
| Auth | Email/password, Google Sign-In, Apple Sign-In |
| ML | Google ML Kit (face detection, text recognition) |
| Payments | Razorpay, Google Play In-App Purchases |
| Design | Material 3, glassmorphism, custom design system |

---

## Getting Started

### Prerequisites

- Flutter SDK 3.44+ (`flutter --version`)
- Firebase project (create at [console.firebase.google.com](https://console.firebase.google.com))
- Google Services config files (`google-services.json` for Android, `GoogleService-Info.plist` for iOS)
- (Optional) Supabase project for RLS-protected public galleries

### Setup

1. **Clone the repo:**
   ```bash
   git clone https://github.com/your-org/artvault.git
   cd artvault
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase:**
   - Add your `google-services.json` to `android/app/`
   - Add your `GoogleService-Info.plist` to `ios/Runner/`
   - Deploy Firestore rules: `firebase deploy --only firestore:rules`
   - Deploy Cloud Functions: `cd functions && npm install && firebase deploy --only functions`

4. **Run:**
   ```bash
   flutter run
   ```

### Environment

| Variable | Description |
|---|---|
| Firebase config | `lib/firebase_options.dart` (auto-generated by FlutterFire CLI) |
| Supabase URL/Key | Set in `lib/core/config/` (if using Supabase features) |
| Razorpay Key | Configured in `lib/core/services/razorpay_payment_service.dart` |

---

## Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Open coverage report
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

Tests cover: auth flows, RBAC guards, sync queue, onboarding, painting CRUD, condition reports, QR labels, upgrade flows, and widget rendering.

---

## CI/CD

GitHub Actions workflow (`.github/workflows/ci.yml`) runs on every push/PR:

- **Secret scanning** (Gitleaks)
- **Flutter analyze** (`--fatal-infos --fatal-warnings`)
- **Format check** (`dart format`)
- **Tests with coverage** (gate: >40% line coverage)
- **Functions audit** (`npm audit --audit-level=high`)
- **Supabase RLS lint** (when CLI available)

---

## Supported Locales

English, German, French, Spanish, Italian, Portuguese, Arabic, Chinese, Japanese.

---

## Security

See [SECURITY.md](SECURITY.md) for a detailed breakdown of security controls including:

- AES-256 local encryption
- PBKDF2 passcode hashing
- Brute-force lockout
- Blink-liveness face detection
- Firebase App Check
- Firestore owner-scoped rules
- Cloud Functions rate limiting

---

## License

Proprietary — all rights reserved.
