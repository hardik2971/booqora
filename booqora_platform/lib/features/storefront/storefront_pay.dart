import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme.dart';
import '../../data/payments.dart';
import '../../widgets/common.dart';
import 'storefront_data.dart';

/// "Pay now" step shown after a storefront booking request, driven by the
/// store's checkout payment mode and the providers configured on the server.
class PayNowCard extends StatefulWidget {
  final StoreData data;
  final Map<String, dynamic> order;
  const PayNowCard({super.key, required this.data, required this.order});

  @override
  State<PayNowCard> createState() => _PayNowCardState();
}

class _PayNowCardState extends State<PayNowCard> {
  PayConfig? _cfg;
  bool _loading = true;
  String? _busy;
  String? _error;
  PayResult? _result;

  @override
  void initState() {
    super.initState();
    Payments.config(workspaceId: widget.order['workspaceId'] as String?).then((c) {
      if (mounted) setState(() => (_cfg = c, _loading = false));
    }).catchError((Object _) {
      if (mounted) setState(() => _loading = false); // payments optional: hide card on error
    });
  }

  num get _amount {
    final c = _cfg!;
    final total = (widget.order['total'] as num?) ?? 0;
    switch (c.paymentMode) {
      case 'full':
        return total;
      case 'down':
        return (total * c.downPaymentPercent / 100 * 100).round() / 100;
      case 'deposit':
        return (widget.order['deposit'] as num?) ?? 0;
      default:
        return 0;
    }
  }

  String get _label => switch (_cfg!.paymentMode) {
        'down' => 'Pay a ${_cfg!.downPaymentPercent}% down payment to confirm',
        'deposit' => 'Pay the security deposit to confirm',
        _ => 'Pay now to confirm your booking',
      };

  Future<void> _pay(PayProvider p) async {
    setState(() {
      _busy = p.id;
      _error = null;
    });
    try {
      final r = await Payments.pay(
        workspaceId: widget.order['workspaceId'] as String,
        orderId: widget.order['orderId'] as String,
        provider: p.id,
        purpose: 'checkout',
      );
      if (!mounted) return;
      if (r == null) return; // redirecting to Stripe / PayPal
      setState(() {
        _busy = null;
        if (r.ok) {
          _result = r;
        } else if (!r.cancelled) {
          _error = r.message;
        }
      });
    } catch (e) {
      if (mounted) setState(() => (_busy = null, _error = friendlyError(e)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(height: 4, child: LinearProgressIndicator());
    final c = _cfg;
    if (c == null || !c.checkoutEnabled || _amount < 1) return const SizedBox.shrink();
    final brand = widget.data.brand;

    if (_result != null) {
      return AppCard(
        color: AppColors.successSoft,
        child: Row(children: [
          const Icon(Icons.verified_rounded, color: AppColors.success, size: 30).animate().scaleXY(begin: 0.4, end: 1, curve: Curves.easeOutBack),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Payment received · ${widget.data.money(_result!.amount)}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const Text('A receipt has been sent to your email.', style: TextStyle(color: AppColors.inkSoft, fontSize: 13)),
            ]),
          ),
        ]),
      );
    }

    final test = c.available.any((p) => p.mode == 'test');
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.lock_outline, size: 18, color: brand),
          const SizedBox(width: 8),
          Expanded(child: Text(_label, style: const TextStyle(fontWeight: FontWeight.w700))),
          Text(widget.data.money(_amount), style: TextStyle(fontWeight: FontWeight.w800, color: brand, fontSize: 16)),
        ]),
        if (test)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Test mode — no real money will be charged.', style: TextStyle(fontSize: 12, color: AppColors.warning)),
          ),
        const SizedBox(height: 14),
        for (final p in c.available)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), side: BorderSide(color: brand.withValues(alpha: 0.35))),
              onPressed: _busy != null ? null : () => _pay(p),
              child: Row(children: [
                Icon(_icon(p.id), color: brand),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Pay with ${p.name}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(p.blurb, style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w400)),
                  ]),
                ),
                if (_busy == p.id)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  const Icon(Icons.arrow_forward_rounded, size: 18),
              ]),
            ),
          ),
        if (_error != null) InfoBanner(_error!, tone: Tone.danger, icon: Icons.error_outline),
        const Text('You can also pay later — the store will confirm your booking by email.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
      ]),
    );
  }

  static IconData _icon(String id) => switch (id) {
        'razorpay' => Icons.bolt_rounded,
        'paypal' => Icons.account_balance_wallet_outlined,
        _ => Icons.credit_card_rounded,
      };
}
