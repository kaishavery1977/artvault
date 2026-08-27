import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:in_app_purchase/in_app_purchase.dart';

/// Real in-app purchase for ArtVault Pro using the official
/// `in_app_purchase` plugin (Google Play Billing on Android, StoreKit on
/// iOS). Wraps the whole flow so callers only see a simple result enum.
///
/// Product ID: `artvault_pro_monthly` (a non-consumable subscription-style
/// unlock). The store must be configured in Play Console / App Store
/// Connect before purchases can actually complete; until then every call
/// degrades to [ProPurchaseResult.unavailable] and the app keeps working
/// with the preview unlock behind the same `isPro` flag.
class ProBillingService {
  ProBillingService._();

  static final ProBillingService instance = ProBillingService._();

  /// Play Console / App Store Connect product identifier for the Pro unlock.
  static const String proProductId = 'artvault_pro_monthly';

  final InAppPurchase _iap = InAppPurchase.instance;

  /// Test hook: forces [isAvailable] to report the store as unavailable so
  /// widget tests can exercise the no-store paths deterministically (the
  /// host platform in tests reports "available" by default).
  @visibleForTesting
  static bool debugForceStoreUnavailable = false;

  /// True when the store is reachable on this device (Play Billing /
  /// StoreKit available and the app is installed via the store).
  Future<bool> get isAvailable async {
    if (debugForceStoreUnavailable) return false;
    try {
      return await _iap.isAvailable();
    } catch (_) {
      return false;
    }
  }

  /// Looks up the Pro product's store listing. Returns null when the store
  /// is unavailable or the product isn't configured yet (common on debug
  /// builds and sideloaded APKs).
  Future<ProductDetails?> getProProduct() async {
    try {
      final response = await _iap.queryProductDetails({proProductId});
      for (final product in response.productDetails) {
        if (product.id == proProductId) return product;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Starts a purchase for the given product and waits for the outcome.
  /// Returns null when the user cancelled; an outcome carrying
  /// [ProPurchaseResult.error] on any failure; [ProPurchaseResult.purchased]
  /// on success. The outcome also carries the store's purchase token so the
  /// caller can verify the purchase server-side before granting the plan.
  Future<ProPurchaseOutcome?> buy(ProductDetails product) async {
    final completer = Completer<ProPurchaseOutcome?>();
    late final StreamSubscription<List<PurchaseDetails>> sub;
    var settled = false;

    void settle(ProPurchaseOutcome? outcome) {
      if (settled) return;
      settled = true;
      sub.cancel();
      if (!completer.isCompleted) completer.complete(outcome);
    }

    sub = _iap.purchaseStream.listen(
      (details) {
        for (final purchase in details) {
          if (purchase.productID != proProductId) continue;
          switch (purchase.status) {
            case PurchaseStatus.purchased:
            case PurchaseStatus.restored:
              _iap.completePurchase(purchase);
              settle(
                ProPurchaseOutcome(
                  ProPurchaseResult.purchased,
                  // The token the Play Developer API validates (purchase token
                  // on Android; the app receipt on iOS).
                  purchaseToken:
                      purchase.verificationData.serverVerificationData,
                ),
              );
            case PurchaseStatus.pending:
              // A pending payment must NOT cancel the attempt — the store may
              // still confirm it later; keep listening.
              break;
            case PurchaseStatus.error:
              settle(const ProPurchaseOutcome(ProPurchaseResult.error));
            case PurchaseStatus.canceled:
              settle(null);
          }
        }
      },
      onError: (_) => settle(const ProPurchaseOutcome(ProPurchaseResult.error)),
    );

    try {
      final param = PurchaseParam(
        productDetails: product,
        applicationUserName: null,
      );
      await _iap.buyNonConsumable(purchaseParam: param);
    } catch (_) {
      settle(const ProPurchaseOutcome(ProPurchaseResult.error));
    }

    // Timeout guard: if the store dialog never emits an event, don't hang
    // the UI forever — and always settle (cancel the subscription) on the
    // way out so the attempt can never leak a listener.
    final outcome = await completer.future.timeout(
      const Duration(minutes: 3),
      onTimeout: () {
        settle(const ProPurchaseOutcome(ProPurchaseResult.error));
        return const ProPurchaseOutcome(ProPurchaseResult.error);
      },
    );
    return outcome;
  }

  /// Restores previous purchases (new device / reinstall). Returns true
  /// only when the store actually reports a restored purchase for the Pro
  /// product — not merely because the restore call completed.
  Future<bool> restore() async {
    final completer = Completer<bool>();
    late final StreamSubscription<List<PurchaseDetails>> sub;

    void finish(bool ok) {
      if (completer.isCompleted) return;
      sub.cancel();
      completer.complete(ok);
    }

    sub = _iap.purchaseStream.listen((details) {
      for (final purchase in details) {
        if (purchase.productID != proProductId) continue;
        if (purchase.status == PurchaseStatus.restored ||
            purchase.status == PurchaseStatus.purchased) {
          _iap.completePurchase(purchase);
          finish(true);
          return;
        }
        if (purchase.status == PurchaseStatus.error) {
          finish(false);
          return;
        }
      }
    }, onError: (_) => finish(false));

    try {
      await _iap.restorePurchases();
    } catch (_) {
      finish(false);
      return false;
    }
    // The store may never emit anything (nothing to restore) — a short
    // grace window lets a genuine restored event arrive before we give up.
    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        sub.cancel();
        return false;
      },
    );
  }
}

/// Outcome of a purchase attempt, including the store's purchase token so
/// the plan grant can be verified server-side (the Firestore rules reject
/// a non-admin self-grant).
class ProPurchaseOutcome {
  final ProPurchaseResult result;

  /// The provider's verification token (Play purchase token on Android, the
  /// app receipt on iOS). Empty when the outcome is not a purchase.
  final String purchaseToken;

  const ProPurchaseOutcome(this.result, {this.purchaseToken = ''});
}

/// Outcome of a purchase attempt.
enum ProPurchaseResult {
  /// Payment completed — the caller should flip the Pro flag.
  purchased,

  /// The store is mid-flow (e.g. awaiting payment confirmation).
  pending,

  /// The store rejected the purchase or something failed.
  error,

  /// The store / product isn't set up on this build yet. Keep using the
  /// preview unlock.
  unavailable,
}
