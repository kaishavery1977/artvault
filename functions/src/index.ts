/**
 * ArtVault backend — password-reset email delivery.
 *
 * Firebase's own default sender (no-reply@<project>.firebaseapp.com) is
 * aggressively filtered into spam, and Firebase is currently blocking SMTP
 * config changes at their end. This function works around both:
 *
 *   1. The Firebase Admin SDK generates the official, secure reset link
 *      (same link Firebase would email, incl. the oobCode).
 *   2. nodemailer delivers it through the project's OWN SMTP sender
 *      (e.g. Gmail), so it lands in the inbox instead of spam.
 *
 * The Flutter app calls this endpoint instead of `sendPasswordResetEmail`.
 *
 * Configure (see functions/.env.example):
 *   SMTP_HOST, SMTP_PORT, SMTP_SECURITY (SSL | START_TLS | NONE),
 *   SMTP_USERNAME, SMTP_SENDER, SMTP_SENDER_NAME, RESET_CONTINUE_URL
 * Secret (functions:secrets:set GMAIL_APP_PASSWORD): the app password.
 */
import * as admin from "firebase-admin";
import * as nodemailer from "nodemailer";
import { onRequest } from "firebase-functions/v2/https";
import { defineString, defineSecret } from "firebase-functions/params";

admin.initializeApp();

// ------------------------------------------------------------------ config --
// Params (non-secret). Deploy with `firebase functions:secrets:set` for the
// password and set the rest via `.env.<project-id>` / config env.
const SMTP_HOST = defineString("SMTP_HOST", { default: "smtp.gmail.com" });
const SMTP_PORT = defineString("SMTP_PORT", { default: "465" });
const SMTP_SECURITY = defineString("SMTP_SECURITY", { default: "SSL" });
const SMTP_USERNAME = defineString("SMTP_USERNAME");
const SMTP_SENDER = defineString("SMTP_SENDER");
const SMTP_SENDER_NAME = defineString("SMTP_SENDER_NAME", {
  default: "ArtVault",
});
const RESET_CONTINUE_URL = defineString("RESET_CONTINUE_URL", {
  default: "https://artvault-d69d0.firebaseapp.com",
});

// Secret: the Gmail app password (16-char, NOT the account password).
const GMAIL_APP_PASSWORD = defineSecret("GMAIL_APP_PASSWORD");

// Lazy singleton — created on first use so secret values are read inside
// the request context (never at module-load time).
let transporter: nodemailer.Transporter | null = null;

function getTransporter(): nodemailer.Transporter {
  if (!transporter) {
    transporter = nodemailer.createTransport({
      host: SMTP_HOST.value(),
      port: parseInt(SMTP_PORT.value(), 10) || 465,
      secure: SMTP_SECURITY.value() === "SSL",
      auth: {
        user: SMTP_USERNAME.value(),
        pass: GMAIL_APP_PASSWORD.value(),
      },
    });
  }
  return transporter;
}

// -------------------------------------------------------------- rate limit --
// In-memory throttle: max N reset requests per email, and per IP, per hour.
// Good enough for a personal vault; a cold start resets the counters.
const MAX_PER_EMAIL = 3;
const MAX_PER_IP = 10;
const WINDOW_MS = 60 * 60 * 1000;
const hits = new Map<string, number[]>();

function allow(key: string, max: number): boolean {
  const now = Date.now();
  const recent = (hits.get(key) ?? []).filter((t) => now - t < WINDOW_MS);
  if (recent.length >= max) return false;
  recent.push(now);
  hits.set(key, recent);
  return true;
}

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// ----------------------------------------------------------------- function --
export const sendPasswordReset = onRequest(
  { cors: true, secrets: [GMAIL_APP_PASSWORD] },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ ok: false, error: "Method not allowed." });
      return;
    }

    const email = String(req.body?.email ?? "").trim().toLowerCase();
    if (!EMAIL_RE.test(email)) {
      res.status(400).json({ ok: false, error: "Enter a valid email address." });
      return;
    }

    // Throttle abuse (both per address and per caller IP).
    const ip = (req.headers["x-forwarded-for"] as string | undefined)
      ?.split(",")[0]
      .trim() ?? "unknown";
    if (!allow(`email:${email}`, MAX_PER_EMAIL) ||
        !allow(`ip:${ip}`, MAX_PER_IP)) {
      res.status(429).json({
        ok: false,
        error: "Too many reset requests. Try again in about an hour.",
      });
      return;
    }

    // Existence check the client can't do (enumeration protection hides it):
    // with the Admin SDK we can be honest about whether the account exists.
    try {
      await admin.auth().getUserByEmail(email);
    } catch (e: unknown) {
      const code = (e as { code?: string } | null)?.code ?? "";
      if (code === "auth/user-not-found") {
        res.status(404).json({
          ok: false,
          error: "No account is registered with this email address.",
        });
        return;
      }
      console.error("getUserByEmail failed", e);
      res.status(500).json({
        ok: false,
        error: "Could not verify the account. Please try again later.",
      });
      return;
    }

    // Generate the official Firebase reset link.
    let link: string;
    try {
      link = await admin.auth().generatePasswordResetLink(email, {
        url: RESET_CONTINUE_URL.value(),
      });
    } catch (e) {
      console.error("generatePasswordResetLink failed", e);
      res.status(500).json({
        ok: false,
        error: "Could not create a reset link. Please try again later.",
      });
      return;
    }

    // Deliver via our own SMTP.
    try {
      await getTransporter().sendMail({
        from: `"${SMTP_SENDER_NAME.value()}" <${SMTP_SENDER.value()}>`,
        to: email,
        subject: "Reset your ArtVault password",
        text:
          `Hello,\n\n` +
          `You asked to reset your ArtVault password. Click the link below to choose a new one:\n\n` +
          `${link}\n\n` +
          `If you did not request this, you can safely ignore this email.\n\n` +
          `— ArtVault`,
        html:
          `<p>Hello,</p>` +
          `<p>You asked to reset your ArtVault password. Click the button below to choose a new one:</p>` +
          `<p style="margin:24px 0"><a href="${link}" style="background:#1e2761;color:#ffffff;padding:12px 22px;border-radius:8px;text-decoration:none;font-weight:600">Reset password</a></p>` +
          `<p>If the button does not work, copy this link into your browser:</p>` +
          `<p><code>${link}</code></p>` +
          `<p>If you did not request this, you can safely ignore this email.</p>` +
          `<p>— ArtVault</p>`,
      });
    } catch (e) {
      console.error("SMTP send failed", e);
      res.status(502).json({
        ok: false,
        error:
          "The reset email could not be sent right now (SMTP). Please try again in a few minutes.",
      });
      return;
    }

    res.json({ ok: true });
  },
);
