import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../data/session.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/mobile.dart';
import 'settings_kit.dart';

class _Plan {
  final String key;
  final String name;
  final String tagline;
  final num monthly;
  final int seats;
  final List<String> features;
  final bool popular;
  const _Plan(this.key, this.name, this.tagline, this.monthly, this.seats, this.features, {this.popular = false});
}

const _plans = [
  _Plan('starter', 'Starter', 'For new rental shops getting organised', 1499, 3, [
    'Up to 3 team members',
    'Orders, inventory and customers',
    'Invoices, quotes and contracts',
    'Online store with your branding',
    'Email support',
  ]),
  _Plan('pro', 'Pro', 'For growing businesses taking bookings online', 3999, 10, [
    'Up to 10 team members',
    'Everything in Starter',
    'Pricing structures and custom fields',
    'Multiple locations',
    'Reports and app integrations',
    'Priority support',
  ], popular: true),
  _Plan('business', 'Business', 'For multi-location operations at scale', 8999, 25, [
    'Up to 25 team members',
    'Everything in Pro',
    'Security controls (2FA, IP allow-lists, SSO)',
    'Advanced permissions',
    'Dedicated onboarding manager',
  ]),
];

class BillingSettings extends StatefulWidget {
  const BillingSettings({super.key});

  @override
  State<BillingSettings> createState() => _BillingSettingsState();
}

class _BillingSettingsState extends SettingsState<BillingSettings> {
  @override
  String get section => 'billing';

  bool _yearly = false;
  late Future<List<int>> _usage = _loadUsage();

  Future<List<int>> _loadUsage() async {
    final r = await Future.wait([Db.list(C.orders), Db.list(C.products), Db.list(C.customers)]);
    return r.map((e) => e.length).toList();
  }

  String get _plan => Session.instance.workspace?.s('plan', 'trial') ?? 'trial';

  num _price(_Plan p) => _yearly ? (p.monthly * 12 * 0.8).round() : p.monthly;

  Future<void> _choose(_Plan p) async {
    final ok = await confirmDialog(context,
        title: 'Switch to ${p.name}?',
        message: 'Your workspace will move to the ${p.name} plan (${Fmt.money(_price(p))} / ${_yearly ? 'year' : 'month'}). '
            'Billing is handled by the Booqora team — we will contact you to arrange payment. No card details are collected here.',
        confirmLabel: 'Choose ${p.name}');
    if (!ok) return;
    try {
      await Db.workspaceRef.update({'plan': p.key});
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      toast(context, 'Plan updated to ${p.name}');
      setState(() {});
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Session.instance,
      builder: (context, _) => view(
        title: 'Account and billing',
        subtitle: 'Your subscription, plan options and billing details.',
        children: [
          _currentPlan(),
          _planHeader(),
          for (final p in _plans) Padding(padding: const EdgeInsets.only(bottom: 12), child: _planCard(p)),
          SGroup(
            title: 'Billing information',
            description: 'Used on the invoices Booqora sends you for your subscription.',
            children: [
              Field(label: 'Billing email', controller: text('email', Session.instance.user?.email ?? ''), keyboardType: TextInputType.emailAddress),
              Field(label: 'Company name', controller: text('company', Session.instance.workspace?.s('name') ?? '')),
              Field(label: 'Address', controller: text('address'), maxLines: 3),
              Field(label: 'GST / VAT number', controller: text('taxId'), hint: 'e.g. 22AAAAA0000A1Z5'),
              Field(label: 'Purchase order reference', controller: text('poReference'), hint: 'Optional'),
            ],
          ),
          SGroup(
            title: 'Usage',
            description: 'Records stored in this workspace.',
            trailing: IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: () => setState(() => _usage = _loadUsage()),
            ),
            children: [_usageCard()],
          ),
        ],
      ),
    );
  }

  Widget _currentPlan() {
    final ws = Session.instance.workspace;
    final plan = _plan;
    final trialEnds = ws?.d('trialEndsAt');
    final daysLeft = trialEnds == null ? 0 : trialEnds.difference(DateTime.now()).inHours / 24;
    final days = daysLeft <= 0 ? 0 : daysLeft.ceil();
    final isTrial = plan == 'trial';
    final p = _plans.where((e) => e.key == plan).firstOrNull;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: AppColors.primaryDeep.withValues(alpha: 0.3), blurRadius: 22, offset: const Offset(0, 10))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.workspace_premium, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('CURRENT PLAN', style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
              Text(isTrial ? 'Free trial' : (p?.name ?? Fmt.label(plan)),
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Text(
          isTrial
              ? (days > 0 ? '$days day${days == 1 ? '' : 's'} left · ends ${Fmt.date(trialEnds)}' : 'Your trial has ended — choose a plan to continue')
              : '${p?.seats ?? 0} seats · billed by the Booqora team',
          style: const TextStyle(color: Colors.white70),
        ),
        if (isTrial && trialEnds != null) ...[
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ((14 - days) / 14).clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: v, minHeight: 8, color: AppColors.lavender, backgroundColor: Colors.white.withValues(alpha: 0.15)),
            ),
          ),
          const SizedBox(height: 6),
          Text('${(14 - days).clamp(0, 14)} of 14 trial days used', style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      ]),
    );
  }

  Widget _planHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionLabel('Plans'),
        Row(children: [
          Expanded(
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('Monthly')),
                ButtonSegment(value: true, label: Text('Yearly')),
              ],
              selected: {_yearly},
              onSelectionChanged: (s) {
                HapticFeedback.selectionClick();
                setState(() => _yearly = s.first);
              },
            ),
          ),
          const SizedBox(width: 10),
          const Badge2('Save 20%', color: AppColors.success),
        ]),
        const SizedBox(height: 8),
        const Text('Billing is handled by the Booqora team. No card is captured in the app.', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
      ]),
    );
  }

  Widget _planCard(_Plan p) {
    final current = _plan == p.key;
    final canChoose = Session.instance.isAdmin;
    final highlight = p.popular || current;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: highlight ? AppColors.primary : AppColors.border, width: highlight ? 1.6 : 1),
        boxShadow: [BoxShadow(color: (highlight ? AppColors.primary : const Color(0xFF1C0938)).withValues(alpha: highlight ? 0.12 : 0.04), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(p.name, style: Theme.of(context).textTheme.titleLarge)),
          if (current) const Badge2('Current', color: AppColors.success) else if (p.popular) const Badge2('Most popular'),
        ]),
        const SizedBox(height: 4),
        Text(p.tagline, style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4)),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, 0.2), end: Offset.zero).animate(a), child: c)),
          child: Column(
            key: ValueKey(_yearly),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(Fmt.money(_price(p)).replaceAll('.00', ''), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.ink)),
                Padding(padding: const EdgeInsets.only(bottom: 5, left: 4), child: Text(_yearly ? '/ year' : '/ month', style: const TextStyle(color: AppColors.muted))),
              ]),
              if (_yearly)
                Text('${Fmt.money((_price(p) / 12).round()).replaceAll('.00', '')} per month, billed yearly',
                    style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final f in p.features)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.check_circle, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(f, style: const TextStyle(fontSize: 13.5, height: 1.35))),
            ]),
          ),
        const SizedBox(height: 10),
        if (current)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(onPressed: null, icon: const Icon(Icons.check, size: 18), label: const Text('Current plan')),
          )
        else if (p.popular)
          GradientButton(label: 'Choose ${p.name}', height: 48, onPressed: canChoose ? () => _choose(p) : null)
        else
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(onPressed: canChoose ? () => _choose(p) : null, child: Text('Choose ${p.name}')),
          ),
      ]),
    );
  }

  Widget _usageCard() {
    return FutureBuilder<List<int>>(
      future: _usage,
      builder: (context, s) {
        if (s.hasError) return Text(friendlyError(s.error!), style: const TextStyle(color: AppColors.danger));
        final d = s.data;
        final items = [
          ('Orders', Icons.receipt_long_outlined, AppColors.primary, d?[0]),
          ('Products', Icons.inventory_2_outlined, AppColors.info, d?[1]),
          ('Customers', Icons.people_alt_outlined, AppColors.success, d?[2]),
        ];
        return Row(children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: items[i].$3.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(items[i].$2, color: items[i].$3, size: 20),
                  const SizedBox(height: 8),
                  if (items[i].$4 == null)
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    CountUp(value: items[i].$4!, format: (v) => Fmt.integer(v), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
                  Text(items[i].$1, style: const TextStyle(color: AppColors.inkSoft, fontSize: 12)),
                ]),
              ).pop(i),
            ),
          ],
        ]);
      },
    );
  }
}
