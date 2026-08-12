# ArtVault password-reset backend

One Cloud Function — `sendPasswordReset` — that fixes reset emails landing in
spam.

## Why this exists

Firebase's default sender (`no-reply@<project>.firebaseapp.com`) is aggressively
filtered into spam, and Firebase is currently blocking SMTP configuration
changes at their end (`EMAIL_TEMPLATE_UPDATE_NOT_ALLOWED`).

This function works around both:

1. The **Firebase Admin SDK** generates the official, secure reset link
   (the same `oobCode` link Firebase would email).
2. **nodemailer** delivers it through the project's **own SMTP sender**
   (Gmail, in the current config) so it lands in the inbox.

Extra wins over the client-side `sendPasswordResetEmail`:

- **Honest account check** — the Admin SDK can see whether the address is
  registered (the client can't; Firebase's email-enumeration protection masks
  it). Unknown addresses get a clear "no account" response instead of a fake
  success.
- **Rate limiting** — max 3 requests per address and 10 per IP per hour.

The Flutter app calls this endpoint automatically and falls back to Firebase's
built-in sender only when the function isn't deployed/reachable.

## Deploy

Prereqs: Node 22+, `firebase-tools` (`npm i -g firebase-tools` or use
`npx -y firebase-tools@latest`).

```bash
cd functions
npm install

# 1. Store the Gmail APP password as a secret (NOT your account password).
#    For Gmail: Google Account → Security → 2-Step Verification → App passwords
npx -y firebase-tools@latest functions:secrets:set GMAIL_APP_PASSWORD

# 2. (Optional) deploy non-secret params via .env.<project-id>:
#    copy .env.example → .env.artvault-d69d0 and fill in SMTP_* values.
#    Defaults already point at smtp.gmail.com:465 SSL.

# 3. Deploy
npx -y firebase-tools@latest deploy --only functions
```

After deploy, the endpoint is
`https://us-central1-artvault-d69d0.cloudfunctions.net/sendPasswordReset`
(already wired into the app via `AppConstants.resetBackendUrl`).

## Local emulation

```bash
cd functions
cp .env.example .env      # fill in values (incl. GMAIL_APP_PASSWORD)
npm run serve             # starts the functions emulator
```

## Config reference

| Param | Default | Purpose |
|---|---|---|
| `SMTP_HOST` | `smtp.gmail.com` | SMTP relay host |
| `SMTP_PORT` | `465` | SMTP port |
| `SMTP_SECURITY` | `SSL` | `SSL` \| `START_TLS` \| `NONE` |
| `SMTP_USERNAME` | — | SMTP auth user (Gmail address) |
| `SMTP_SENDER` | — | From address shown to recipients |
| `SMTP_SENDER_NAME` | `ArtVault` | Display name shown to recipients |
| `RESET_CONTINUE_URL` | `https://artvault-d69d0.firebaseapp.com` | Where the user lands after resetting |
| `GMAIL_APP_PASSWORD` | — (secret) | Gmail **App** password, stored via `functions:secrets:set` |

## Notes

- Secrets are read lazily inside the request handler (never at module load).
- Rate-limit counters are in-memory and reset on cold start — fine for a
  personal vault.
