import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
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

  Map<String, dynamic> _p(String key) => v[key] is Map ? Map<String, dynamic>.from(v[key] as Map) : <String, dynamic>{};

  Future<void> _connect(_Provider p) async {
    final cur = _p(p.key);
    final keyCtl = TextEditingController(text: cur['publicKey']?.toString() ?? '');
    final emailCtl = TextEditingController(text: cur['accountEmail']?.toString() ?? '');
    var mode = cur['mode']?.toString() ?? 'live';
    final ok = await formDialog(
      context: context,
      title: 'Connect ${p.name}',
      saveLabel: 'Connect',
      width: 480,
      onSave: () async {
        final data = {
          'connected': true,
          'publicKey': keyCtl.text.trim(),
          'accountEmail': emailCtl.text.trim(),
          'mode': mode,
          'connectedAt': DateTime.now().toIso8601String(),
          'connectedBy': Session.instance.displayName,
        };
        await Session.instance.saveSettings('payments', {p.key: data});
        await Session.instance.markOnboarding('payments');
        v[p.key] = data;
      },
      body: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Field(label: p.keyLabel, controller: keyCtl, required: true, hint: p.keyHint, helper: 'Public identifier only — safe to store in the browser.'),
        const SizedBox(height: 14),
        Field(
          label: 'Account email',
          controller: emailCtl,
          keyboardType: TextInputType.emailAddress,
          validator: (x) => (x ?? '').trim().isNotEmpty && !(x ?? '').contains('@') ? 'Enter a valid email' : null,
        ),
        const SizedBox(height: 14),
        DropdownX<String>(
          label: 'Mode',
          value: mode,
          items: const {'live': 'Live', 'test': 'Test'},
          onChanged: (x) => setS(() => mode = x ?? 'live'),
        ),
        const SizedBox(height: 14),
        const InfoBanner(
          'Never paste secret keys here. Secret keys and webhook signing secrets must be configured server-side by the Booqora team '
          'before online payments can be captured.',
          tone: Tone.warning,
          icon: Icons.key_off_outlined,
        ),
      ]),
    );
    keyCtl.dispose();
    emailCtl.dispose();
    if (ok && mounted) {
      setState(() {});
      toast(context, '${p.name} details saved');
    }
  }

  Future<void> _disconnect(_Provider p) async {
    final ok = await confirmDialog(context,
        title: 'Disconnect ${p.name}?',
        message: 'Customers will no longer be offered ${p.name} at checkout. The stored details will be removed.',
        confirmLabel: 'Disconnect',
        danger: true);
    if (!ok) return;
    try {
      final data = {'connected': false, 'publicKey': '', 'accountEmail': '', 'mode': 'live'};
      await Session.instance.saveSettings('payments', {p.key: data});
      v[p.key] = data;
      if (mounted) {
        setState(() {});
        toast(context, '${p.name} disconnected');
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  Widget _providerCard(_Provider p, int i) {
    final d = _p(p.key);
    final connected = d['connected'] == true;
    final key = d['publicKey']?.toString() ?? '';
    final masked = key.length > 10 ? '${key.substring(0, 8)}…${key.substring(key.length - 4)}' : key;
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
          StatusPill(connected ? 'active' : 'inactive', label: connected ? 'Connected' : 'Not connected'),
        ]),
        const SizedBox(height: 12),
        Text(p.description, style: const TextStyle(color: AppColors.inkSoft, height: 1.45, fontSize: 13.5)),
        const SizedBox(height: 6),
        Text(p.fees, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        if (connected) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _kv(p.keyLabel, masked.isEmpty ? '—' : masked),
              if ((d['accountEmail'] ?? '').toString().isNotEmpty) _kv('Account', d['accountEmail'].toString()),
              _kv('Mode', Fmt.label(d['mode']?.toString() ?? 'live')),
            ]),
          ),
        ],
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (!connected)
            FilledButton.icon(onPressed: () => _connect(p), icon: const Icon(Icons.link, size: 18), label: const Text('Connect'))
          else ...[
            OutlinedButton(onPressed: () => _connect(p), child: const Text('Edit details')),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              onPressed: () => _disconnect(p),
              child: const Text('Disconnect'),
            ),
          ],
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
          'Provider connections store your public account identifiers only. Online card capture becomes active once the matching '
          'secret keys are configured server-side by the Booqora team.',
          tone: Tone.brand,
          icon: Icons.verified_user_outlined,
        ).enter(0),
        const SizedBox(height: 20),
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth > 900 ? 3 : (c.maxWidth > 560 ? 2 : 1);
          final w = (c.maxWidth - (cols - 1) * 16) / cols;
          return Wrap(spacing: 16, runSpacing: 16, children: [
            for (var i = 0; i < _providers.length; i++) SizedBox(width: w, child: HoverLift(child: _providerCard(_providers[i], i + 1))),
          ]);
        }),
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
