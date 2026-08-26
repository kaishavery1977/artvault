# ArtVault Security Measures

This document describes the security controls implemented across the ArtVault codebase.

---

## 1. Data Protection at Rest

### 1.1 Local Database Encryption (Hive AES-256)

All local Hive boxes (paintings, artists, documents, condition reports, notifications, sync queue, profile) are encrypted with AES-256-CBC via HiveAesCipher.

- Key generation: A random 256-bit key is generated on first launch and stored in Flutter Secure Storage (OS-level keychain).
- Key retrieval: Subsequent launches read the same key from Secure Storage. The key never touches plaintext on disk.
- Migration: If an unencrypted box is detected, the box is cleared and reopened with encryption.

### 1.2 Android Backup Disabled

`android:allowBackup="false"` and `android:fullBackupContent="false"` prevent vault data from leaking via ADB backups.

### 1.3 Passcode Storage

- PBKDF2-HMAC-SHA256 (150,000 iterations) with random salt in Secure Storage.
- Legacy SHA-256 digests auto-upgrade to PBKDF2 on first successful verify.
- Constant-time comparison prevents timing side-channel attacks.

---

## 2. Authentication and Access Control

### 2.1 App Lock (Passcode)

- 4-digit PIN with brute-force throttle.
- 5 attempts before throttling, exponential backoff: 30s to 10 min cap.
- Lockout persists across app restarts.

### 2.2 Biometric Authentication

- Fingerprint unlock via platform secure enclave.
- Face unlock with blink-liveness detection (prevents photo spoofing).

### 2.3 Firebase App Check

- Android debug: AndroidDebugProvider.
- Android release: PlayIntegrityProvider.
- iOS: AppAttestWithDeviceCheckFallbackProvider.

---

## 3. Cloud Security

### 3.1 Firestore Rules

- Owner-scoped access for all vault documents.
- 1 MiB write size cap on all rules.
- Non-admin users can only read their own profile.
- Public gallery analytics only accepted on live links.

### 3.2 Storage Rules

- 20 MB upload cap per file.
- Image-only content type for paintings, artists, condition reports.
- App Check required for all writes.

### 3.3 Cloud Functions Rate Limiting

All payment functions are rate-limited per user (3-5 per minute) via Firestore-backed sliding-window counters.

### 3.4 Subscription Lifecycle

- Razorpay and Play subscriptions validated server-side.
- Daily maintenance job revokes lapsed subscriptions.
- One-time purchases never revoked.

---

## 4. Web and Network Security

### 4.1 Security Headers

- Content-Security-Policy, X-Content-Type-Options, X-Frame-Options, Referrer-Policy, Permissions-Policy, HSTS.

### 4.2 Analytics PII

- Email addresses never included in event parameters.

---

## 5. Build Security

### 5.1 Debug Build Signing

- Debug builds always use the debug key (never release keystore).

### 5.2 CI Secret Scanning

- Gitleaks scans on every push and PR.

### 5.3 Gitignore

- `backups/` and `strix_runs/` directories ignored.

---

## 6. Threat Model Summary

| Threat | Mitigation |
|---|---|
| Physical device theft | App lock, AES encryption, backup disabled |
| Brute-force passcode | Exponential lockout, persisted across restarts |
| Photo spoofing | Blink-liveness detection |
| Database bloat | 1 MiB write size cap |
| Unauthorized uploads | 20 MB cap, image-only, App Check |
| Subscription fraud | Server-side validation, daily maintenance |
| Rate abuse | Per-user rate limiter |
| PII leakage | Email stripped from analytics |
| Debug build abuse | Debug key only |
| Secret leakage | Gitleaks CI scanning |
| Web attacks | CSP headers, X-Frame-Options |
| Database enumeration | Own-profile-only reads for non-admins |
