import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/payments.dart';
import '../../data/session.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/mobile.dart';
import 'settings_kit.dart';

class _Provider {
  final String key;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final String fees;
  const _Provider(this.key, this.name, this.description, this.icon, this.color, this.fees);
}

const _providers = [
  _Provider('razorpay', 'Razorpay', 'Accept UPI, cards, netbanking and wallets across India.', Icons.bolt, Color(0xFF0C2451),
      'Razorpay processing fees apply'),
  _Provider('stripe', 'Stripe', 'Accept cards, Apple Pay and Google Pay in your online store and on payment links.', Icons.credit_card,
      Color(0xFF635BFF), 'Stripe processing fees apply'),
  _Provider('paypal', 'PayPal', 'Let customers pay with their PayPal balance, Pay Later or cards via PayPal checkout.',
      Icons.account_balance_wallet_outlined, Color(0xFF003087), 'PayPal processing fees apply'),
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
  late Future<PayConfig> _cfg = Payments.config(workspaceId: Db.wid);

  void _refresh() {
    HapticFeedback.selectionClick();
    setState(() => _cfg = Payments.config(workspaceId: Db.wid));
  }

  Map<String, dynamic> _p(String key) => v[key] is Map ? Map<String, dynamic>.from(v[key] as Map) : <String, dynamic>{};

  Future<void> _setEnabled(_Provider p, bool on) async {
    HapticFeedback.lightImpact();
    final prev = v[p.key];
    final data = {..._p(p.key), 'enabled': on};
    setState(() => v[p.key] = data);
    try {
      await Session.instance.saveSettings('payments', {p.key: data});
      if (on) await Session.instance.markOnboarding('payments');
      if (mounted) toast(context, on ? '${p.name} is now offered to customers' : '${p.name} turned off');
    } catch (e) {
      if (mounted) {
        setState(() => v[p.key] = prev);
        toast(context, friendlyError(e), error: true);
      }
    }
  }

  Widget _providerCard(_Provider p, PayConfig? cfg, Object? error) {
    final s = cfg?.providers[p.key];
    final enabled = _p(p.key)['enabled'] != false;
    final (String pill, String label) = cfg == null
        ? (error != null ? ('failed', 'Status unavailable') : ('scheduled', 'Checking…'))
        : !(s?.configured ?? false)
            ? ('inactive', 'Not configured')
            : !enabled
                ? ('inactive', 'Turned off')
                : (s!.available ? ('active', s.mode == 'test' ? 'Connected · Test mode' : 'Connected · Live') : ('needs_attention', 'Needs attention'));
    final configured = s?.configured ?? false;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: configured && enabled ? p.color.withValues(alpha: 0.35) : AppColors.border),
        boxShadow: const [BoxShadow(color: Color(0x0A1C0938), blurRadius: 14, offset: Offset(0, 6))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [p.color.withValues(alpha: 0.10), p.color.withValues(alpha: 0.02)]),
          ),
          child: Row(children: [
            IconBubble(p.icon, color: p.color, size: 46, solid: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                const SizedBox(height: 4),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: StatusPill(pill, key: ValueKey(label), label: label),
                ),
              ]),
            ),
            if (cfg == null && error == null) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(p.description, style: const TextStyle(color: AppColors.inkSoft, height: 1.45, fontSize: 13.5)),
            const SizedBox(height: 4),
            Text(p.fees, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            if (s != null && configured) ...[
              const SizedBox(height: 12),
              SoftBox(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _kv('Mode', s.mode == 'test' ? 'Test (no real money)' : 'Live'),
                  _kv('Currency', s.currency.isEmpty ? '—' : s.currency),
                  _kv('Keys', 'Stored securely on server'),
                ]),
              ),
            ],
            if (s?.reason != null && configured && enabled) ...[
              const SizedBox(height: 10),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
                const SizedBox(width: 6),
                Expanded(child: Text(s!.reason!, style: const TextStyle(color: AppColors.warning, fontSize: 12.5))),
              ]),
            ],
            if (!configured && cfg != null) ...[
              const SizedBox(height: 10),
              const Text('Ask the Booqora team to add this provider’s keys on the server to start accepting payments.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.4)),
            ],
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(friendlyError(error), style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
            ],
            const Divider(height: 22),
            Row(children: [
              const Expanded(child: Text('Offer to customers', style: TextStyle(fontWeight: FontWeight.w600))),
              Switch(value: enabled, onChanged: configured ? (x) => _setEnabled(p, x) : null),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _kv(String k, String val) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Text(k, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(val,
                textAlign: TextAlign.right, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        ]),
      );

  Widget _manual(String key, String title, String subtitle, IconData icon, String instrLabel, String hint) {
    final on = val<bool>('${key}Enabled', false);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: on ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border),
        color: on ? AppColors.primarySoft.withValues(alpha: 0.4) : Colors.white,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          IconBubble(icon, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
            ]),
          ),
          Switch(
            value: on,
            onChanged: (x) {
              HapticFeedback.selectionClick();
              put('${key}Enabled', x);
            },
          ),
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
      title: 'Payments',
      subtitle: 'Online payment providers and the manual payment methods you accept.',
      actions: [IconButton(tooltip: 'Refresh status', onPressed: _refresh, icon: const Icon(Icons.refresh_rounded))],
      children: [
        const InfoBanner(
          'Online payments run through secure Booqora servers. Secret keys stay on the server and never touch this device.',
          tone: Tone.brand,
          icon: Icons.verified_user_outlined,
        ),
        const SizedBox(height: 4),
        FutureBuilder<PayConfig>(
          future: _cfg,
          builder: (context, snap) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SectionLabel('Online providers'),
            for (var i = 0; i < _providers.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _providerCard(_providers[i], snap.data, snap.error).enter(i + 1),
              ),
          ]),
        ),
        SGroup(
          title: 'Manual payments',
          description: 'Methods you record yourself. Instructions are printed on invoices and shown in order confirmations.',
          children: [
            _manual('cash', 'Cash', 'Paid in person at pickup or delivery.', Icons.payments_outlined, 'Instructions',
                'e.g. Please pay the full amount in cash at pickup.'),
            _manual('bank', 'Bank transfer', 'Customer transfers to your bank account.', Icons.account_balance_outlined,
                'Bank details and instructions', 'Account name, number, IFSC / IBAN, reference to use'),
            _manual('upi', 'UPI', 'Customer pays to your UPI ID or QR code.', Icons.qr_code_2, 'UPI ID and instructions',
                'e.g. Pay to yourshop@okhdfcbank and mention the order number'),
          ],
        ),
      ],
    );
  }
}
