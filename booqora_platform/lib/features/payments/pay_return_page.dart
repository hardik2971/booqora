import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/payments.dart';
import '../../data/session.dart';
import '../../widgets/common.dart';

/// Landing page after Stripe / PayPal hosted checkout. Verifies the payment
/// server-side, then shows the outcome. Public (works for store customers).
class PayReturnPage extends StatefulWidget {
  final Map<String, String> params;
  const PayReturnPage({super.key, required this.params});

  @override
  State<PayReturnPage> createState() => _PayReturnPageState();
}

class _PayReturnPageState extends State<PayReturnPage> {
  bool _busy = true;
  bool _ok = false;
  bool _cancelled = false;
  String _message = '';
  num _amount = 0;
  String _currency = '';
  String? _slug;
  String? _orderId;
  String _store = '';

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final p = widget.params;
    final provider = p['provider'] ?? '';
    if (p['cancelled'] == '1') {
      setState(() {
        _busy = false;
        _cancelled = true;
        _message = 'You cancelled the payment. No money was taken.';
      });
      return;
    }
    try {
      final v = await Payments.verify({
        'workspaceId': p['w'],
        'sessionId': p['s'],
        if (provider == 'stripe') 'stripeSessionId': p['cs'],
        if (provider == 'paypal') 'paypalToken': p['token'],
      });
      setState(() {
        _busy = false;
        _ok = v['ok'] == true;
        _amount = (v['amount'] as num?) ?? 0;
        _currency = (v['currency'] ?? '').toString();
        _slug = v['slug']?.toString();
        _orderId = v['orderId']?.toString();
        _store = (v['storeName'] ?? '').toString();
        _message = _ok ? 'Thank you! Your payment has been received and a receipt is on its way by email.' : (v['message'] ?? 'The payment was not completed.').toString();
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _ok = false;
        _message = friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final staff = Session.instance.hasWorkspace;
    final (icon, color) = _busy
        ? (Icons.hourglass_top_rounded, AppColors.primary)
        : _ok
            ? (Icons.check_rounded, AppColors.success)
            : _cancelled
                ? (Icons.close_rounded, AppColors.warning)
                : (Icons.error_outline_rounded, AppColors.danger);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFF7F5FC), Color(0xFFEFE9FD)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: AppCard(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                    child: _busy
                        ? const Padding(padding: EdgeInsets.all(26), child: CircularProgressIndicator(strokeWidth: 3))
                        : Icon(icon, size: 44, color: color).animate().scaleXY(begin: 0.4, end: 1, curve: Curves.easeOutBack, duration: 500.ms),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _busy ? 'Confirming your payment…' : (_ok ? 'Payment successful' : (_cancelled ? 'Payment cancelled' : 'Payment not completed')),
                    style: t.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  if (_ok && _amount > 0) ...[
                    const SizedBox(height: 8),
                    Text(Fmt.money(_amount, sym: '$_currency '), style: t.titleLarge?.copyWith(color: AppColors.success)),
                  ],
                  if (_store.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(_store, style: const TextStyle(color: AppColors.muted)),
                  ],
                  const SizedBox(height: 14),
                  if (!_busy) Text(_message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.inkSoft, height: 1.5)),
                  const SizedBox(height: 24),
                  if (!_busy)
                    Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
                      if (staff && _orderId != null)
                        FilledButton.icon(onPressed: () => context.go('/orders/$_orderId'), icon: const Icon(Icons.receipt_long, size: 18), label: const Text('Open order')),
                      if (_slug != null && _slug!.isNotEmpty)
                        OutlinedButton.icon(onPressed: () => context.go('/s/$_slug'), icon: const Icon(Icons.storefront, size: 18), label: const Text('Back to store')),
                      if (!_ok && !_cancelled) TextButton(onPressed: () {
                        setState(() => _busy = true);
                        _run();
                      }, child: const Text('Check again')),
                    ]),
                  const SizedBox(height: 18),
                  const Text('Secured by Booqora', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                ]),
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
          ),
        ),
      ),
    );
  }
}
