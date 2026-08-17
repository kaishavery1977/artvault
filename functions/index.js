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
 *   firebase functions:config:set razorpay.key_id="rzp_..." \
 *     razorpay.key_secret="..." \
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
const KEY_ID = config.razorpay.key_id || "";
const KEY_SECRET = config.razorpay.key_secret || "";
const PRICE_PAISE = parseInt(config.pro.price_paise || "19900", 10); // ₹199
const MONTHLY_PAISE = parseInt(config.pro.monthly_paise || "9900", 10); // ₹99
const PACKAGE_NAME = config.play.package_name || "com.artvault.artvault";
const PRO_PRODUCT_ID = config.play.product_id || "artvault_pro_monthly";

const razorpay = new Razorpay({ key_id: KEY_ID, key_secret: KEY_SECRET });

const db = admin.firestore();

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
  const list = await razorpay.plans.all({ count: 100 });
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
  const plan = await razorpay.plans.create({
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
  if (!KEY_ID || !KEY_SECRET) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Razorpay is not configured on the server yet.",
    );
  }
  try {
    const order = await razorpay.orders.create({
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
  const order = await razorpay.orders.fetch(orderId);
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
  if (!KEY_ID || !KEY_SECRET) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Razorpay is not configured on the server yet.",
    );
  }
  try {
    const planId = await ensureProPlan();
    const sub = await razorpay.subscriptions.create({
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
    const sub = await razorpay.subscriptions.fetch(subscriptionId);
    if (!sub || !sub.notes || sub.notes.uid !== context.auth.uid) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "This subscription does not belong to your account.",
      );
    }
    await grantPro(context.auth.uid, {
      proMode: "monthly",
      proSubscriptionId: subscriptionId,
    });
    return { ok: true };
  },
);

/**
 * Validates a Google Play purchase token against the Play Developer API,
 * then grants Pro. Used for store purchases so the admin-only Firestore
 * rule ("users may not change their own plan") doesn't block legitimate
 * buyers: the grant comes from the server, not the client.
 */
exports.verifyPlayPurchase = functions.https.onCall(async (data, context) => {
  requireAuth(context);
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
    const res = await androidpublisher.purchases.products.get({
      packageName: PACKAGE_NAME,
      productId,
      token: purchaseToken,
    });
    const purchase = res.data;
    // purchaseState: 0 = purchased, 1 = cancelled, 2 = pending.
    if (purchase.purchaseState !== 0) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Purchase is not in a purchased state.",
      );
    }
    // consumed: true would mean the item was consumed (irrelevant for a
    // non-consumable) — accept otherwise as-is.
    await grantPro(context.auth.uid, {
      proMode: "play",
      proPurchaseToken: purchaseToken,
    });
    return { ok: true };
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
