import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../data/remote/cloud_backend.dart';
import 'pro_billing_service.dart' show ProPurchaseResult;

/// Which billing mode the Razorpay checkout should run.
enum RazorpayBillingMode {
  /// One-time Pro unlock (order-based).
  oneTime,

  /// Monthly subscription (subscription-based, renews automatically).
  monthly,
}

/// Real payment for ArtVault Pro via Razorpay (UPI / cards / netbanking),
/// for builds distributed outside the Play Store where Google Play Billing
/// is unavailable (sideloaded APKs).
///
/// Security model: the client never touches the Razorpay key secret. Order
/// / subscription creation and payment-signature verification happen
/// server-side in a Cloud Function (`createProOrder`, `verifyProPayment`,
/// `createProSubscription`, `verifyProSubscription` in `functions/`); only
/// after a verified payment does the server grant the plan, writing
/// `users/{uid}.plan = 'pro'` with the Admin SDK (which bypasses the
/// "self plan change is admin-only" Firestore rule). The signed-in device
/// picks the grant up through the live profile watcher — no client-side
/// entitlement write.
class RazorpayPaymentService {
  RazorpayPaymentService._();

  static final RazorpayPaymentService instance = RazorpayPaymentService._();

  /// Razorpay key ID (public, safe to embed). Pass with
  /// `--dart-define=RAZORPAY_KEY_ID=rzp_test_...`. The matching key secret
  /// lives only in the Cloud Function's environment.
  static const String keyId = String.fromEnvironment('RAZORPAY_KEY_ID');

  /// Pro price in INR paise — must match the backend's `PRO_PRICE_PAISE`.
  static const int proPricePaise = 19900; // ₹199

  /// Monthly Pro price in INR paise — must match the backend's
  /// `PRO_MONTHLY_PAISE`.
  static const int proMonthlyPricePaise = 9900; // ₹99

  bool get isConfigured => keyId.isNotEmpty;

  /// Runs the full checkout: create order/subscription → Razorpay UI →
  /// server-side verification → plan grant. Returns null when the user
  /// cancelled, [ProPurchaseResult.purchased] on verified success, or an
  /// error state.
  Future<ProPurchaseResult?> checkout({
    required String uid,
    required String email,
    required String name,
    RazorpayBillingMode mode = RazorpayBillingMode.oneTime,
  }) async {
    if (!CloudBackend.instance.isReady || !isConfigured) {
      return ProPurchaseResult.unavailable;
    }
    final functions = FirebaseFunctions.instance;

    final isSubscription = mode == RazorpayBillingMode.monthly;

    // 1. Create the order / subscription server-side (amount is set by the
    //    backend, never by the client — a tampered client cannot create a
    //    ₹0 order).
    final Map<String, dynamic> created;
    try {
      final res = await functions
          .httpsCallable(
            isSubscription ? 'createProSubscription' : 'createProOrder',
          )
          .call();
      created = Map<String, dynamic>.from(res.data as Map);
    } catch (_) {
      return ProPurchaseResult.error;
    }
    final entityId = created[
        isSubscription ? 'subscriptionId' : 'orderId'] as String?;
    if (entityId == null || entityId.isEmpty) {
      return ProPurchaseResult.error;
    }

    // 2. Open the Razorpay checkout and wait for the outcome.
    final razorpay = Razorpay();
    final completer = Completer<ProPurchaseResult?>();
    var settled = false;

    void settle(ProPurchaseResult? result) {
      if (settled) return;
      settled = true;
      razorpay.clear();
      if (!completer.isCompleted) completer.complete(result);
    }

    razorpay.on(
      Razorpay.EVENT_PAYMENT_SUCCESS,
      (PaymentSuccessResponse res) async {
        // 3. Verify server-side and let the backend grant the plan.
        //    For subscriptions the payment references the subscription id
        //    (Razorpay returns `razorpay_subscription_id` in the payload).
        final paymentId = res.paymentId;
        final signature = res.signature;
        final paidSubscriptionId = (res.data?['razorpay_subscription_id']
                as String?) ??
            entityId;
        final idKey = isSubscription ? 'subscriptionId' : 'orderId';
        if (paymentId == null || signature == null) {
          settle(ProPurchaseResult.error);
          return;
        }
        try {
          await functions.httpsCallable(
            isSubscription ? 'verifyProSubscription' : 'verifyProPayment',
          ).call({
            idKey: paidSubscriptionId,
            'paymentId': paymentId,
            'signature': signature,
          });
          settle(ProPurchaseResult.purchased);
        } catch (_) {
          settle(ProPurchaseResult.error);
        }
      },
    );
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse res) {
      settle(
        res.code == Razorpay.PAYMENT_CANCELLED ? null : ProPurchaseResult.error,
      );
    });
    // External wallets (e.g. Paytm) just hand over to the wallet app; keep
    // listening for the eventual success/error event.
    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (_) {});

    try {
      razorpay.open({
        'key': keyId,
        if (isSubscription) 'subscription_id': entityId else 'order_id': entityId,
        'name': 'ArtVault',
        'description': isSubscription
            ? 'ArtVault Pro — ₹99/month, cancel anytime'
            : 'ArtVault Pro — unlimited capacity & premium features',
        'prefill': {'email': email, 'name': name},
        'theme': {'color': '#7C4DFF'},
      });
    } catch (_) {
      settle(ProPurchaseResult.error);
    }

    // Timeout guard: never hang the UI on a dead checkout.
    return completer.future.timeout(
      const Duration(minutes: 3),
      onTimeout: () {
        settle(ProPurchaseResult.error);
        return ProPurchaseResult.error;
      },
    );
  }
}
