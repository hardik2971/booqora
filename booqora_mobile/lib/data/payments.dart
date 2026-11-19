import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// One payment provider's availability for a store (from `paymentConfig`).
class PayProvider {
  final String id;
  final bool available;
  final bool configured;
  final bool enabled;
  final String mode;
  final String currency;
  final String? reason;
  const PayProvider(this.id, {this.available = false, this.configured = false, this.enabled = true, this.mode = 'test', this.currency = '', this.reason});

  String get name => const {'razorpay': 'Razorpay', 'stripe': 'Stripe', 'paypal': 'PayPal'}[id] ?? id;
  String get blurb => const {'razorpay': 'UPI, cards, netbanking & wallets', 'stripe': 'Credit & debit cards', 'paypal': 'PayPal balance or cards'}[id] ?? '';

  factory PayProvider.fromMap(String id, Map m) => PayProvider(
        id,
        available: m['available'] == true,
        configured: m['configured'] == true,
        enabled: m['enabled'] != false,
        mode: (m['mode'] ?? 'test').toString(),
        currency: (m['currency'] ?? '').toString(),
        reason: m['reason']?.toString(),
      );
}

class PayConfig {
  final String workspaceId;
  final String currency;
  final String paymentMode;
  final num downPaymentPercent;
  final Map<String, PayProvider> providers;
  const PayConfig(this.workspaceId, this.currency, this.paymentMode, this.downPaymentPercent, this.providers);
  List<PayProvider> get available => providers.values.where((p) => p.available).toList();
}

class PayResult {
  final bool ok;
  final bool cancelled;
  final bool pendingExternal; // opened in browser; order updates live when paid
  final num amount;
  final String message;
  const PayResult({required this.ok, this.cancelled = false, this.pendingExternal = false, this.amount = 0, this.message = ''});
}

/// Client for the Booqora payment + email Cloud Functions (mobile).
class Payments {
  static final _fn = FirebaseFunctions.instanceFor(region: 'asia-south1');

  /// Hosted checkouts return to the web confirmation page, which verifies the
  /// payment server-side; the app sees the result through the live order stream.
  static const returnUrl = 'https://booqora-platform.web.app/pay/return';

  static Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> data) async {
    try {
      final r = await _fn.httpsCallable(name, options: HttpsCallableOptions(timeout: const Duration(seconds: 60))).call(data);
      return Map<String, dynamic>.from(r.data as Map);
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? e.code);
    }
  }

  static Future<PayConfig> config({String? workspaceId, String? slug}) async {
    final m = await _call('paymentConfig', {'workspaceId': ?workspaceId, 'slug': ?slug});
    final provs = Map<String, dynamic>.from(m['providers'] as Map? ?? {});
    final checkout = Map<String, dynamic>.from(m['checkout'] as Map? ?? {});
    return PayConfig(
      (m['workspaceId'] ?? '').toString(),
      (m['currency'] ?? '').toString(),
      (checkout['paymentMode'] ?? 'none').toString(),
      (checkout['downPaymentPercent'] as num?) ?? 25,
      {for (final e in provs.entries) e.key: PayProvider.fromMap(e.key, Map.from(e.value as Map))},
    );
  }

  static Future<Map<String, dynamic>> create({
    required String workspaceId,
    required String orderId,
    required String provider,
    String purpose = 'balance',
    num? amount,
  }) =>
      _call('createPayment', {
        'workspaceId': workspaceId,
        'orderId': orderId,
        'provider': provider,
        'purpose': purpose,
        'amount': ?amount,
        'returnUrl': returnUrl,
      });

  static Future<Map<String, dynamic>> verify(Map<String, dynamic> data) => _call('verifyPayment', data);

  /// Razorpay → native checkout sheet, verified here.
  /// Stripe/PayPal → secure in-app browser; the order updates live once paid.
  static Future<PayResult> pay({
    required String workspaceId,
    required String orderId,
    required String provider,
    String purpose = 'balance',
    num? amount,
  }) async {
    final s = await create(workspaceId: workspaceId, orderId: orderId, provider: provider, purpose: purpose, amount: amount);
    if (provider == 'razorpay' && !kIsWeb) return _razorpay(workspaceId, s);
    final url = s['url']?.toString();
    if (url == null || url.isEmpty) throw Exception('The payment page could not be opened.');
    await openPaymentPage(url);
    return const PayResult(ok: false, pendingExternal: true, message: 'Complete the payment in the browser. This order updates automatically.');
  }

  static Future<void> openPaymentPage(String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
    if (!ok) await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  static Future<PayResult> _razorpay(String workspaceId, Map<String, dynamic> s) {
    final done = Completer<PayResult>();
    final rz = Razorpay();
    void finish(PayResult r) {
      if (!done.isCompleted) done.complete(r);
      rz.clear();
    }

    rz.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) async {
      try {
        final v = await verify({
          'workspaceId': workspaceId,
          'sessionId': s['sessionId'],
          'razorpay': {'paymentId': r.paymentId, 'signature': r.signature},
        });
        finish(PayResult(ok: v['ok'] == true, amount: (v['amount'] as num?) ?? 0, message: (v['message'] ?? '').toString()));
      } catch (e) {
        finish(PayResult(ok: false, message: e.toString().replaceFirst('Exception: ', '')));
      }
    });
    rz.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
      final cancelled = r.code == Razorpay.PAYMENT_CANCELLED;
      finish(PayResult(ok: false, cancelled: cancelled, message: cancelled ? 'Payment cancelled' : (r.message ?? 'Payment failed')));
    });
    rz.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {
      finish(PayResult(ok: false, pendingExternal: true, message: 'Continue in ${r.walletName ?? 'your wallet app'}.'));
    });
    final prefill = Map<String, dynamic>.from(s['prefill'] as Map? ?? {});
    rz.open({
      'key': s['keyId'],
      'amount': s['amountMinor'],
      'currency': s['currency'] ?? 'INR',
      'name': s['name'] ?? 'Booqora',
      'description': s['description'] ?? '',
      'order_id': s['providerOrderId'],
      'prefill': {for (final e in prefill.entries) if ((e.value ?? '').toString().isNotEmpty) e.key: e.value.toString()},
      'theme': {'color': s['brandColor'] ?? '#6431DD'},
    });
    return done.future;
  }

  static Future<void> sendEmail({
    required String workspaceId,
    required String to,
    required String subject,
    required String body,
    String context = 'general',
    String? entityId,
  }) =>
      _call('sendEmail', {'workspaceId': workspaceId, 'to': to, 'subject': subject, 'body': body, 'context': context, 'entityId': ?entityId});
}
