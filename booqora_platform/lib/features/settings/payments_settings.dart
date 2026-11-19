import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/payments.dart';
import '../../data/session.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import 'settings_kit.dart';

class _Provider {
  final String key;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final String keyLabel;
  final String keyHint;
  final String fees;
  const _Provider(this.key, this.name, this.description, this.icon, this.color, this.keyLabel, this.keyHint, this.fees);
}

const _providers = [
  _Provider('stripe', 'Stripe', 'Accept cards, Apple Pay and Google Pay in your online store and on payment links.', Icons.credit_card,
      Color(0xFF635BFF), 'Publishable key', 'pk_live_…', 'Stripe processing fees apply'),
  _Provider('paypal', 'PayPal', 'Let customers pay with their PayPal balance, Pay Later or cards via PayPal checkout.',
      Icons.account_balance_wallet_outlined, Color(0xFF003087), 'Client ID', 'AY3x…', 'PayPal processing fees apply'),
  _Provider('razorpay', 'Razorpay', 'Accept UPI, cards, netbanking and wallets across India.', Icons.bolt, Color(0xFF0C2451), 'Key ID',
      'rzp_live_…', 'Razorpay processing fees apply'),
];

class PaymentsSettings extends StatefulWidget {
  const PaymentsSettings({super.key});

  @override
  State<PaymentsSettings> createState() => _PaymentsSettingsState();
}

class _PaymentsSettingsState extends SettingsState<PaymentsSettings> {
  @override
  String get section => 'payments';

  @override
  Future<void> persist() async {
    await super.persist();
    await Session.instance.markOnboarding('payments');
  }

  /// Live provider status from the server (keys live in Secret Manager).
  late final Future<PayConfig> _cfg = Payments.config(workspaceId: Db.wid);

  Map<String, dynamic> _p(String key) => v[key] is Map ? Map<String, dynamic>.from(v[key] as Map) : <String, dynamic>{};

  Future<void> _setEnabled(_Provider p, bool on) async {
    try {
      final data = {..._p(p.key), 'enabled': on};
      await Session.instance.saveSettings('payments', {p.key: data});
      if (on) await Session.instance.markOnboarding('payments');
      v[p.key] = data;
      if (mounted) {
        setState(() {});
        toast(context, on ? '${p.name} is now offered to customers' : '${p.name} turned off');
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  Widget _providerCard(_Provider p, int i, PayConfig? cfg, Object? error) {
    final s = cfg?.providers[p.key];
    final enabled = _p(p.key)['enabled'] != false;
    final (String pill, String label) = cfg == null
        ? (error != null ? ('failed', 'Status unavailable') : ('scheduled', 'Checking…'))
        : !(s?.configured ?? false)
            ? ('inactive', 'Not configured')
            : !enabled
                ? ('inactive', 'Turned off')
                : (s!.available ? ('active', s.mode == 'test' ? 'Connected · Test mode' : 'Connected · Live') : ('needs_attention', 'Needs attention'));
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [p.color, Color.lerp(p.color, Colors.white, 0.25)!]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(p.icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(p.name, style: Theme.of(context).textTheme.titleMedium)),
          if (cfg == null && error == null) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        ]),
        const SizedBox(height: 10),
        StatusPill(pill, label: label),
        const SizedBox(height: 12),
        Text(p.description, style: const TextStyle(color: AppColors.inkSoft, height: 1.45, fontSize: 13.5)),
        const SizedBox(height: 6),
        Text(p.fees, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        if (s != null && s.configured) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _kv('Mode', s.mode == 'test' ? 'Test (no real money)' : 'Live'),
              _kv('Currency', s.currency),
              _kv('Keys', 'Stored securely on server'),
            ]),
          ),
        ],
        if (s?.reason != null && (s?.configured ?? false) && enabled) ...[
          const SizedBox(height: 10),
          Text(s!.reason!, style: const TextStyle(color: AppColors.warning, fontSize: 12.5)),
        ],
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(friendlyError(error), style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
        ],
        const SizedBox(height: 10),
        Row(children: [
          const Expanded(child: Text('Offer to customers', style: TextStyle(fontWeight: FontWeight.w600))),
          Switch(value: enabled, onChanged: (s?.configured ?? false) ? (x) => _setEnabled(p, x) : null),
        ]),
      ]),
    ).enter(i);
  }

  Widget _kv(String k, String val) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Text(k, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
          const SizedBox(width: 8),
          Expanded(child: Text(val, textAlign: TextAlign.right, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
        ]),
      );

  Widget _manual(String key, String title, String subtitle, IconData icon, String instrLabel, String hint) {
    final on = val<bool>('${key}Enabled', false);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: on ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border),
        color: on ? AppColors.primarySoft.withValues(alpha: 0.35) : Colors.white,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
            ]),
          ),
          Switch(value: on, onChanged: (x) => put('${key}Enabled', x)),
        ]),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: on
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Field(label: instrLabel, controller: text('${key}Instructions'), maxLines: 3, hint: hint),
                )
              : const SizedBox(width: double.infinity),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return view(
      title: 'Payment providers',
      subtitle: 'Connect online payment providers and set up the manual payment methods you accept.',
      children: [
        const InfoBanner(
          'Online payments run through secure Booqora servers. Secret keys stay on the server and are never stored in the browser.',
          tone: Tone.brand,
          icon: Icons.verified_user_outlined,
        ).enter(0),
        const SizedBox(height: 20),
        FutureBuilder<PayConfig>(future: _cfg, builder: (context, snap) => LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth > 900 ? 3 : (c.maxWidth > 560 ? 2 : 1);
          final w = (c.maxWidth - (cols - 1) * 16) / cols;
          return Wrap(spacing: 16, runSpacing: 16, children: [
            for (var i = 0; i < _providers.length; i++) SizedBox(width: w, child: HoverLift(child: _providerCard(_providers[i], i + 1, snap.data, snap.error))),
          ]);
        })),
        const SizedBox(height: 28),
        FormSection(
          index: 4,
          title: 'Manual payments',
          description: 'Payment methods you record yourself. Instructions are printed on invoices and shown in order confirmations.',
          children: [
            _manual('cash', 'Cash', 'Paid in person at pickup or delivery.', Icons.payments_outlined, 'Instructions',
                'e.g. Please pay the full amount in cash at pickup.'),
            _manual('bank', 'Bank transfer', 'Customer transfers money to your bank account.', Icons.account_balance_outlined,
                'Bank details and instructions', 'Account name, account number, IFSC / IBAN, reference to use'),
            _manual('upi', 'UPI', 'Customer pays to your UPI ID or QR code.', Icons.qr_code_2, 'UPI ID and instructions',
                'e.g. Pay to yourshop@okhdfcbank and mention the order number'),
          ],
        ),
      ],
    );
  }
}
