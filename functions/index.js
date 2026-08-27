/**
 * ArtVault payment backend.
 *
 * HTTPS callables used by the app's Pro upgrade flow:
 *
 *   createProOrder(uid)        → creates a Razorpay order (one-time) → id.
 *   verifyProPayment(uid)      → verifies a Razorpay order signature,
 *                                then grants `users/{uid}.plan = 'pro'`.
 *   createProSubscription(uid) → creates a Razorpay monthly subscription.
 *   verifyProSubscription(uid) → verifies a Razorpay subscription payment,
 *                                then grants the Pro plan.
 *   verifyPlayPurchase(uid)    → validates a Google Play purchase token via
 *                                the Play Developer API, then grants Pro.
 *
 * The client never sees the Razorpay key secret, and the plan grant happens
 * only after the provider's signature/token check passes — so a tampered
 * client cannot grant itself Pro or create a ₹0 order.
 *
 * Configure + deploy:
 *   firebase functions:config:set getRazorpay().key_id="rzp_..." \
 *     getRazorpay().key_secret="..." \
 *     pro.price_paise="19900" pro.monthly_paise="9900" \
 *     play.package_name="com.artvault.artvault" play.product_id="artvault_pro_monthly"
 *   firebase deploy --only functions
 *
 * Google Play verification needs the Play Developer API enabled and the
 * project's default service account added to Play Console → Users &
 * permissions with "View financial data" (and the API enabled in the Google
 * Cloud console for this project).
 */
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const crypto = require("crypto");
const Razorpay = require("razorpay");
const { google } = require("googleapis");

admin.initializeApp();

const config = functions.config();
const KEY_ID = config.getRazorpay().key_id || "";
const KEY_SECRET = config.getRazorpay().key_secret || "";
const PRICE_PAISE = parseInt(config.pro.price_paise || "19900", 10); // ₹199
const MONTHLY_PAISE = parseInt(config.pro.monthly_paise || "9900", 10); // ₹99
const PACKAGE_NAME = config.play.package_name || "com.artvault.artvault";
const PRO_PRODUCT_ID = config.play.product_id || "artvault_pro_monthly";

const razorpay = new Razorpay({ key_id: KEY_ID, key_secret: KEY_SECRET });

const db = admin.firestore();

// ── Per-user rate limiter ────────────────────────────────────────────────
// Sliding-window counter backed by Firestore.  Each callable that calls
// checkRateLimit writes a timestamped doc under rate_limits/{uid}/{fn}; the
// checker counts docs younger than [windowMs] and rejects when the count
// reaches [maxCalls].  Docs older than the window are deleted opportunistically
// to keep the collection tidy.
const _RATE_LIMITS = {
  verifyProSubscription: { maxCalls: 3, windowMs: 60_000 },   // 3 per minute
  verifyPlayPurchase:    { maxCalls: 3, windowMs: 60_000 },   // 3 per minute
  createProOrder:       { maxCalls: 5, windowMs: 60_000 },   // 5 per minute
  createProSubscription:{ maxCalls: 5, windowMs: 60_000 },   // 5 per minute
  verifyProPayment:     { maxCalls: 3, windowMs: 60_000 },   // 3 per minute
};

function getRazorpay() {
  if (!KEY_ID || !KEY_SECRET) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Razorpay is not configured on the server yet.",
    );
  }
  return razorpay;
}

async function checkRateLimit(uid, fnName) {
  const cfg = _RATE_LIMITS[fnName];
  if (!cfg) return;
  const now = Date.now();
  const cutoff = new Date(now - cfg.windowMs);
  const col = db.collection(`rate_limits/${uid}/${fnName}`);

  const recentSnap = await col.where("ts", ">=", cutoff).get();
  if (recentSnap.size >= cfg.maxCalls) {
    throw new functions.https.HttpsError(
      "resource-exhausted",
      "Too many requests. Please wait a moment and try again.",
    );
  }
  await db.runTransaction(async (tx) => {
    const ref = col.doc();
    tx.set(ref, {
      ts: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: new Date(now + cfg.windowMs * 2),
    });
  });
  // Best-effort cleanup outside transaction (non-transactional read inside tx is illegal).
  try {
    const staleSnap = await col.where("ts", "<", cutoff).limit(20).get();
    await Promise.all(staleSnap.docs.map((d) => col.doc(d.id).delete()));
  } catch (_) {}
}

function requireAuth(context) {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Sign in to upgrade to Pro.",
    );
  }
}

async function grantPro(uid, extra = {}) {
  await db.doc(`users/${uid}`).set(
    { plan: "pro", planGrantedAt: admin.firestore.FieldValue.serverTimestamp(), ...extra },
    { merge: true },
  );
  functions.logger.info(`Pro granted to ${uid}`, extra);
}

function razorpaySignature(secret, id, paymentId) {
  return crypto
    .createHmac("sha256", secret)
    .update(`${id}|${paymentId}`)
    .digest("hex");
}

/** Reuses (or creates) the Razorpay monthly plan for ArtVault Pro. */
async function ensureProPlan() {
  // Try to find an existing plan matching our amount so we don't create a
  // new plan on every checkout. `plans.all` is paginated; a small cache
  // avoids a second API call per request.
  if (ensureProPlan._planId) return ensureProPlan._planId;
  const list = await getRazorpay().plans.all({ count: 100 });
  const match = list.items.find(
    (p) =>
      p.period === "monthly" &&
      p.item &&
      p.item.amount === MONTHLY_PAISE &&
      p.item.currency === "INR",
  );
  if (match) {
    ensureProPlan._planId = match.id;
    return match.id;
  }
  const plan = await getRazorpay().plans.create({
    period: "monthly",
    interval: 1,
    item: {
      name: "ArtVault Pro",
      amount: MONTHLY_PAISE,
      currency: "INR",
    },
    notes: { purpose: "ArtVault Pro monthly subscription" },
  });
  ensureProPlan._planId = plan.id;
  return plan.id;
}

/** Creates a Razorpay order for a one-time Pro unlock. */
exports.createProOrder = functions.https.onCall(async (data, context) => {
  requireAuth(context);
  await checkRateLimit(context.auth.uid, "createProOrder");
  if (!KEY_ID || !KEY_SECRET) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Razorpay is not configured on the server yet.",
    );
  }
  try {
    const order = await getRazorpay().orders.create({
      amount: PRICE_PAISE,
      currency: "INR",
      receipt: `pro_${context.auth.uid}`,
      notes: { uid: context.auth.uid },
    });
    return { orderId: order.id, amount: order.amount, currency: order.currency };
  } catch (e) {
    functions.logger.error("createProOrder failed", e);
    throw new functions.https.HttpsError("internal", "Could not create order.");
  }
});

/** Verifies a one-time Razorpay payment signature, then grants Pro. */
exports.verifyProPayment = functions.https.onCall(async (data, context) => {
  requireAuth(context);
  await checkRateLimit(context.auth.uid, "verifyProPayment");
  const { orderId, paymentId, signature } = data || {};
  if (!orderId || !paymentId || !signature) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Missing payment details.",
    );
  }
  if (!KEY_SECRET) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Razorpay is not configured on the server yet.",
    );
  }
  if (razorpaySignature(KEY_SECRET, orderId, paymentId) !== signature) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Payment signature verification failed.",
    );
  }
  // The order must belong to this user — never grant a plan for an order
  // created by someone else.
  const order = await getRazorpay().orders.fetch(orderId);
  if (!order || order.notes.uid !== context.auth.uid) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "This order does not belong to your account.",
    );
  }
  await grantPro(context.auth.uid, { proMode: "one-time", proOrderId: orderId });
  return { ok: true };
});

/** Creates a Razorpay monthly subscription for Pro. */
exports.createProSubscription = functions.https.onCall(async (data, context) => {
  requireAuth(context);
  await checkRateLimit(context.auth.uid, "createProSubscription");
  if (!KEY_ID || !KEY_SECRET) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Razorpay is not configured on the server yet.",
    );
  }
  try {
    const planId = await ensureProPlan();
    const sub = await getRazorpay().subscriptions.create({
      plan_id: planId,
      total_count: 12, // renew monthly for a year; Razorpay continues billing
      customer_notify: 1,
      notes: { uid: context.auth.uid },
    });
    return {
      subscriptionId: sub.id,
      amount: MONTHLY_PAISE,
      currency: "INR",
    };
  } catch (e) {
    functions.logger.error("createProSubscription failed", e);
    throw new functions.https.HttpsError(
      "internal",
      "Could not create subscription.",
    );
  }
});

/** Verifies a Razorpay subscription payment signature, then grants Pro. */
exports.verifyProSubscription = functions.https.onCall(
  async (data, context) => {
    requireAuth(context);
    await checkRateLimit(context.auth.uid, "verifyProSubscription");
    const { subscriptionId, paymentId, signature } = data || {};
    if (!subscriptionId || !paymentId || !signature) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing subscription payment details.",
      );
    }
    if (!KEY_SECRET) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Razorpay is not configured on the server yet.",
      );
    }
    // Razorpay signs `${subscriptionId}|${paymentId}` for subscription
    // payments (the first payment of a subscription).
    if (razorpaySignature(KEY_SECRET, subscriptionId, paymentId) !== signature) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Payment signature verification failed.",
      );
    }
    const sub = await getRazorpay().subscriptions.fetch(subscriptionId);
    if (!sub || !sub.notes || sub.notes.uid !== context.auth.uid) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "This subscription does not belong to your account.",
      );
    }
    // Only grant while the subscription is actually active — a cancelled,
    // completed or halted subscription must not re-grant Pro.
    if (sub.status !== "active" && sub.status !== "authenticated") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Subscription is not active.",
      );
    }
    // Anchor the grant to the current billing period so the daily
    // maintenance job revokes the plan if the subscription lapses.
    const periodEnd = Number(sub.current_period_end || 0) * 1000;
    const anchor =
      periodEnd > 0 ? periodEnd : Date.now() + 30 * 864e5;
    await grantPro(context.auth.uid, {
      proMode: "monthly",
      proSubscriptionId: subscriptionId,
      proExpiresAt: new Date(anchor),
    });
    return { ok: true, expiresAt: new Date(anchor).toISOString() };
  },
);

/**
 * Validates a Google Play purchase token against the Play Developer API,
 * then grants Pro. Used for store purchases so the admin-only Firestore
 * rule ("users may not change their own plan") doesn't block legitimate
 * buyers: the grant comes from the server, not the client.
 *
 * Subscription products (artvault_pro_monthly) are validated against the
 * Play Subscriptions API and the grant carries an expiry derived from
 * `expiryTimeMillis`, so a lapsed or cancelled subscription is revoked by
 * the daily maintenance job instead of keeping Pro forever.
 */
exports.verifyPlayPurchase = functions.https.onCall(async (data, context) => {
  requireAuth(context);
  await checkRateLimit(context.auth.uid, "verifyPlayPurchase");
  const { productId, purchaseToken } = data || {};
  if (!productId || !purchaseToken) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Missing purchase details.",
    );
  }
  if (productId !== PRO_PRODUCT_ID) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Unknown product.",
    );
  }
  try {
    const auth = await google.auth.getClient({
      scopes: ["https://www.googleapis.com/auth/androidpublisher"],
    });
    const androidpublisher = google.androidpublisher({ version: "v3", auth });

    // The Pro product is a monthly subscription, so validate it against the
    // Subscriptions API (purchases.products.get only serves one-time items).
    const res = await androidpublisher.purchases.subscriptions.get({
      packageName: PACKAGE_NAME,
      subscriptionId: productId,
      token: purchaseToken,
    });
    const purchase = res.data;

    // paymentState: 0 = payment pending, 1 = payment received, 2 = free trial,
    // 3 = pending deferred upgrade/downgrade.
    const paid =
      purchase.paymentState === 1 ||
      purchase.paymentState === 2 ||
      purchase.paymentState === 3;
    if (!paid) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Purchase is not in a paid state.",
      );
    }

    // expiryTimeMillis is the anchor for the grant: when it passes, the
    // maintenance job revokes Pro. Only grant if the subscription is
    // currently active (future expiry) — a lapsed token must not re-grant.
    const expiryMs = Number(purchase.expiryTimeMillis || 0);
    if (expiryMs <= Date.now()) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Subscription has expired.",
      );
    }

    await grantPro(context.auth.uid, {
      proMode: "play",
      proPurchaseToken: purchaseToken,
      proExpiresAt: new Date(expiryMs),
    });
    return { ok: true, expiresAt: new Date(expiryMs).toISOString() };
  } catch (e) {
    if (e instanceof functions.https.HttpsError) throw e;
    functions.logger.error("verifyPlayPurchase failed", e);
    throw new functions.https.HttpsError(
      "internal",
      "Could not verify the purchase. Make sure the Play Developer API is "
        + "enabled and the service account is added in Play Console.",
    );
  }
});

/**
 * Daily maintenance: revokes Pro from subscriptions that have lapsed.
 *
 * - Play subscriptions: re-validates the stored purchase token against the
 *   Play Subscriptions API and refreshes `proExpiresAt` while the
 *   subscription is still active, or revokes when `expiryTimeMillis` has
 *   passed.
 * - Razorpay subscriptions: re-fetches the subscription from Razorpay and
 *   revokes when it is no longer active.
 *
 * One-time unlocks (proMode: "one-time") are never revoked — that is the
 * point of a one-time purchase.
 */
exports.maintainProPlans = functions.pubsub
  .schedule("every 24 hours")
  .onRun(async () => {
    // Single-field query on `plan` (no composite index to deploy); filter
    // the recurring modes in code. One-time unlocks are left untouched.
    const snap = await db
      .collection("users")
      .where("plan", "==", "pro")
      .get();

    let revoked = 0;
    let refreshed = 0;

    for (const doc of snap.docs) {
      const u = doc.data();
      const uid = doc.id;
      // Skip one-time unlocks and any grant without a recurring mode —
      // those are permanent by design.
      if (u.proMode !== "play" && u.proMode !== "monthly") continue;
      try {
        if (u.proMode === "play") {
          if (!u.proPurchaseToken) {
            // No token to re-validate — treat as lapsed.
            await db.doc(`users/${uid}`).update({ plan: "free" });
            revoked++;
            continue;
          }
          const auth = await google.auth.getClient({
            scopes: ["https://www.googleapis.com/auth/androidpublisher"],
          });
          const androidpublisher = google.androidpublisher({ version: "v3", auth });
          const res = await androidpublisher.purchases.subscriptions.get({
            packageName: PACKAGE_NAME,
            subscriptionId: PRO_PRODUCT_ID,
            token: u.proPurchaseToken,
          });
          const expiryMs = Number(res.data.expiryTimeMillis || 0);
          if (expiryMs > Date.now()) {
            await db
              .doc(`users/${uid}`)
              .update({ proExpiresAt: new Date(expiryMs) });
            refreshed++;
          } else {
            await db.doc(`users/${uid}`).update({ plan: "free" });
            revoked++;
          }
        } else if (u.proMode === "monthly") {
          if (!u.proSubscriptionId) {
            await db.doc(`users/${uid}`).update({ plan: "free" });
            revoked++;
            continue;
          }
          const sub = await getRazorpay().subscriptions.fetch(u.proSubscriptionId);
          // Active/authenticated = paid and recurring; anything else
          // (cancelled, completed, expired, halted, pending) = revoke.
          if (sub.status === "active" || sub.status === "authenticated") {
            // Refresh the expiry anchor from the subscription's current
            // period end, or keep a rolling +30d if the API omits it.
            const periodEnd = Number(sub.current_period_end || 0) * 1000;
            const anchor = periodEnd > 0 ? periodEnd : Date.now() + 30 * 864e5;
            await db.doc(`users/${uid}`).update({ proExpiresAt: new Date(anchor) });
            refreshed++;
          } else {
            await db.doc(`users/${uid}`).update({ plan: "free" });
            revoked++;
          }
        }
      } catch (e) {
        functions.logger.warn(
          `maintainProPlans: could not process ${uid} (${u.proMode})`,
          e,
        );
      }
    }

    functions.logger.info(
      `maintainProPlans: refreshed ${refreshed}, revoked ${revoked}`,
    );
    return null;
  });
