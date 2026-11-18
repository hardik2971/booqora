import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:web/web.dart' as web;

/// One payment provider's availability for a store (from the `paymentConfig` function).
class PayProvider {
  final String id;
  final bool available;
  final bool configured;
  final bool enabled;
  final String mode; // 'test' | 'live'
  final String currency;
  final String? reason;
  const PayProvider(this.id, {this.available = false, this.configured = false, this.enabled = true, this.mode = 'test', this.currency = '', this.reason});

  String get name => const {'razorpay': 'Razorpay', 'stripe': 'Stripe', 'paypal': 'PayPal'}[id] ?? id;
  String get blurb => const {
        'razorpay': 'UPI, cards, netbanking & wallets',
        'stripe': 'Credit & debit cards',
        'paypal': 'PayPal balance or cards',
      }[id] ??
      '';

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
  final String paymentMode; // full | down | deposit | none
  final num downPaymentPercent;
  final Map<String, PayProvider> providers;
  const PayConfig(this.workspaceId, this.currency, this.paymentMode, this.downPaymentPercent, this.providers);

  List<PayProvider> get available => providers.values.where((p) => p.available).toList();
  bool get checkoutEnabled => paymentMode != 'none' && available.isNotEmpty;
}

/// Result of an in-page payment (Razorpay) or a verified redirect.
class PayResult {
  final bool ok;
  final bool cancelled;
  final num amount;
  final String currency;
  final String message;
  final Map<String, dynamic> raw;
  const PayResult({required this.ok, this.cancelled = false, this.amount = 0, this.currency = '', this.message = '', this.raw = const {}});
}

/// Client for the Booqora payment + email Cloud Functions.
class Payments {
  static final _fn = FirebaseFunctions.instanceFor(region: 'asia-south1');

  static Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> data) async {
    try {
      final r = await _fn.httpsCallable(name, options: HttpsCallableOptions(timeout: const Duration(seconds: 60))).call(data);
      return Map<String, dynamic>.from(r.data as Map);
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? e.code);
    }
  }

  static String get returnUrl => '${web.window.location.origin}/pay/return';

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

  /// Starts a payment session. For Stripe/PayPal the result contains a hosted `url`.
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

  /// Full flow: Razorpay opens in the page and is verified here; Stripe/PayPal redirect away
  /// (the /pay/return page verifies them). Returns null when the browser is redirecting.
  static Future<PayResult?> pay({
    required String workspaceId,
    required String orderId,
    required String provider,
    String purpose = 'balance',
    num? amount,
  }) async {
    final s = await create(workspaceId: workspaceId, orderId: orderId, provider: provider, purpose: purpose, amount: amount);
    if (provider == 'razorpay') return _razorpay(workspaceId, s);
    final url = s['url']?.toString();
    if (url == null || url.isEmpty) throw Exception('The payment page could not be opened.');
    web.window.location.assign(url);
    return null;
  }

  // ---------------- Razorpay Checkout (in-page) ----------------
  static Future<void>? _rzLoading;

  static Future<void> _loadRazorpay() {
    if (globalContext.has('Razorpay')) return Future.value();
    return _rzLoading ??= () {
      final c = Completer<void>();
      final s = web.HTMLScriptElement()
        ..src = 'https://checkout.razorpay.com/v1/checkout.js'
        ..async = true;
      s.onload = ((web.Event _) => c.complete()).toJS;
      s.onerror = ((web.Event _) {
        _rzLoading = null;
        if (!c.isCompleted) c.completeError(Exception('Could not load Razorpay. Check your connection.'));
      }).toJS;
      web.document.head!.append(s);
      return c.future;
    }();
  }

  static Future<PayResult> _razorpay(String workspaceId, Map<String, dynamic> s) async {
    await _loadRazorpay();
    final done = Completer<PayResult>();
    final prefill = Map<String, dynamic>.from(s['prefill'] as Map? ?? {});

    final opts = JSObject();
    opts['key'] = (s['keyId'] ?? '').toString().toJS;
    opts['amount'] = (s['amountMinor'] as num).toJS;
    opts['currency'] = (s['currency'] ?? 'INR').toString().toJS;
    opts['name'] = (s['name'] ?? 'Booqora').toString().toJS;
    opts['description'] = (s['description'] ?? '').toString().toJS;
    opts['order_id'] = (s['providerOrderId'] ?? '').toString().toJS;
    final pf = JSObject();
    for (final e in prefill.entries) {
      if ((e.value ?? '').toString().isNotEmpty) pf[e.key] = e.value.toString().toJS;
    }
    opts['prefill'] = pf;
    final theme = JSObject();
    theme['color'] = (s['brandColor'] ?? '#6431DD').toString().toJS;
    opts['theme'] = theme;
    opts['handler'] = ((JSObject resp) {
      String f(String k) => (resp[k] as JSString?)?.toDart ?? '';
      verify({
        'workspaceId': workspaceId,
        'sessionId': s['sessionId'],
        'razorpay': {'paymentId': f('razorpay_payment_id'), 'signature': f('razorpay_signature')},
      }).then((v) {
        if (!done.isCompleted) {
          done.complete(PayResult(
            ok: v['ok'] == true,
            amount: (v['amount'] as num?) ?? 0,
            currency: (v['currency'] ?? '').toString(),
            message: (v['message'] ?? '').toString(),
            raw: v,
          ));
        }
      }).catchError((Object e) {
        if (!done.isCompleted) done.complete(PayResult(ok: false, message: e.toString().replaceFirst('Exception: ', '')));
      });
    }).toJS;
    final modal = JSObject();
    modal['ondismiss'] = (() {
      if (!done.isCompleted) done.complete(const PayResult(ok: false, cancelled: true, message: 'Payment cancelled'));
    }).toJS;
    opts['modal'] = modal;

    final ctor = globalContext['Razorpay'] as JSFunction;
    final rz = ctor.callAsConstructor<JSObject>(opts);
    rz.callMethod('on'.toJS, 'payment.failed'.toJS, ((JSObject r) {
      final err = r['error'] as JSObject?;
      final desc = (err?['description'] as JSString?)?.toDart ?? 'Payment failed';
      if (!done.isCompleted) done.complete(PayResult(ok: false, message: desc));
    }).toJS);
    rz.callMethod('open'.toJS);
    return done.future;
  }

  // ---------------- Email ----------------
  static Future<void> sendEmail({
    required String workspaceId,
    required String to,
    required String subject,
    required String body,
    String context = 'general',
    String? entityId,
  }) =>
      _call('sendEmail', {
        'workspaceId': workspaceId,
        'to': to,
        'subject': subject,
        'body': body,
        'context': context,
        'entityId': ?entityId,
      });
}
