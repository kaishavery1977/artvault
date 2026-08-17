import 'package:cloud_functions/cloud_functions.dart';

import '../../data/remote/cloud_backend.dart';
import 'pro_billing_service.dart' show ProPurchaseResult;

/// Verifies Google Play purchases server-side through the
/// `verifyPlayPurchase` Cloud Function.
///
/// Why this exists: the Firestore rules only let an *admin* change a user's
/// plan (`users/{uid}` self-updates must keep the plan field unchanged
/// unless the caller is admin). A legitimate Play buyer is usually not an
/// admin, so a client-side `updatePlan` write would be rejected by the
/// rules — the payment would succeed at the store but the plan would never
/// flip. The Cloud Function validates the purchase token against the Play
/// Developer API with the Admin SDK and writes the plan itself, bypassing
/// the client rules safely.
class PlayPurchaseVerifier {
  PlayPurchaseVerifier._();

  static final PlayPurchaseVerifier instance = PlayPurchaseVerifier._();

  /// Sends the purchase token to the backend for validation. Returns
  /// [ProPurchaseResult.purchased] when the Play API confirms the purchase
  /// and the backend has granted the plan; otherwise an error (or null
  /// when the cloud isn't reachable and the purchase can't be verified).
  Future<ProPurchaseResult?> verify({
    required String productId,
    required String purchaseToken,
  }) async {
    if (!CloudBackend.instance.isReady || purchaseToken.isEmpty) {
      return ProPurchaseResult.unavailable;
    }
    try {
      await FirebaseFunctions.instance
          .httpsCallable('verifyPlayPurchase')
          .call({
        'productId': productId,
        'purchaseToken': purchaseToken,
      });
      return ProPurchaseResult.purchased;
    } catch (_) {
      return ProPurchaseResult.error;
    }
  }
}
