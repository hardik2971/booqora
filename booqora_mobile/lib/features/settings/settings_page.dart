import 'package:flutter/material.dart' hide Thumb;
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/session.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/mobile.dart';
import 'billing_settings.dart';
import 'custom_fields_settings.dart';
import 'documents_settings.dart';
import 'emails_settings.dart';
import 'general_settings.dart';
import 'locations_settings.dart';
import 'payments_settings.dart';
import 'pricing_settings.dart';
import 'rental_settings.dart';
import 'security_settings.dart';
import 'taxes_settings.dart';
import 'team_settings.dart';
import 'translations_settings.dart';

class _Entry {
  final String key;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  const _Entry(this.key, this.label, this.subtitle, this.icon, this.color);
}

const _groups = <(String, List<_Entry>)>[
  ('Business', [
    _Entry('general', 'General', 'Company info, address, region', Icons.business_rounded, Color(0xFF6431DD)),
    _Entry('pricing', 'Pricing', 'Currency, templates, deposits', Icons.sell_rounded, Color(0xFF16A34A)),
    _Entry('taxes', 'Taxes', 'Tax mode and tax profiles', Icons.percent_rounded, Color(0xFFD97706)),
    _Entry('rental-period', 'Rental period', 'Durations, hours, away mode', Icons.schedule_rounded, Color(0xFF2563EB)),
    _Entry('payments', 'Payments', 'Razorpay, Stripe, PayPal, cash', Icons.credit_card_rounded, Color(0xFF635BFF)),
  ]),
  ('Customization', [
    _Entry('custom-fields', 'Custom fields', 'Extra info on records', Icons.dynamic_form_rounded, Color(0xFF0E7490)),
    _Entry('locations', 'Locations', 'Pickup and delivery points', Icons.place_rounded, Color(0xFFDC2626)),
    _Entry('emails', 'Emails', 'Templates, sender, email log', Icons.mail_rounded, Color(0xFFDB2777)),
    _Entry('documents', 'Documents', 'Invoice look and numbering', Icons.description_rounded, Color(0xFF351DB1)),
    _Entry('translations', 'Translations', 'Customer-facing wording', Icons.translate_rounded, Color(0xFF7C3AED)),
  ]),
  ('Account', [
    _Entry('security', 'Security', '2FA, IP allow-list, SSO', Icons.shield_rounded, Color(0xFF475569)),
    _Entry('team', 'Team', 'Members, roles and invites', Icons.group_rounded, Color(0xFF0891B2)),
    _Entry('billing', 'Account and billing', 'Plan, billing info, usage', Icons.workspace_premium_rounded, Color(0xFFB45309)),
  ]),
];

class SettingsPage extends StatelessWidget {
  final String? section;
  const SettingsPage({super.key, this.section});

  @override
  Widget build(BuildContext context) {
    return switch (section) {
      null || '' => const _SettingsMenu(),
      'general' => const GeneralSettings(),
      'pricing' => const PricingSettings(),
      'taxes' => const TaxesSettings(),
      'rental-period' => const RentalPeriodSettings(),
      'payments' => const PaymentsSettings(),
      'custom-fields' => const CustomFieldsSettings(),
      'locations' => const LocationsSettings(),
      'emails' => const EmailsSettings(),
      'documents' => const DocumentsSettings(),
      'translations' => const TranslationsSettings(),
      'security' => const SecuritySettings(),
      'team' => const TeamSettings(),
      'billing' => const BillingSettings(),
      _ => const _SettingsMenu(),
    };
  }
}

class _SettingsMenu extends StatelessWidget {
  const _SettingsMenu();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Session.instance,
      builder: (context, _) {
        final s = Session.instance;
        final ws = s.workspace;
        final logo = s.setting('general', 'logoUrl', '')?.toString() ?? '';
        var i = 0;
        return MPage(
          title: 'Settings',
          subtitle: 'Configure how your rental business works',
          showBack: true,
          slivers: [
            SPad(
              PressScale(
                onTap: () => context.push('/settings/general'),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppColors.heroGradient,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [BoxShadow(color: AppColors.primaryDeep.withValues(alpha: 0.28), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: Row(children: [
                    Container(
                      width: 52,
                      height: 52,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                      child: Thumb(url: logo, size: 48, icon: Icons.storefront_rounded),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(ws?.s('name', 'Workspace') ?? 'Workspace',
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                        const SizedBox(height: 2),
                        Text('${Fmt.label(ws?.s('plan', 'trial') ?? 'trial')} plan · ${Fmt.label(s.role)}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                      ]),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.white70),
                  ]),
                ),
              ).enter(0),
            ),
            if (!s.isAdmin) SPad(const InfoBanner('Some settings can only be changed by workspace owners and admins.', tone: Tone.warning, icon: Icons.lock_outline).enter(1)),
            for (final g in _groups) ...[
              SPad(SectionLabel(g.$1).enter(++i)),
              SPad(
                Group(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  children: [
                    for (final e in g.$2)
                      NavRow(
                        icon: e.icon,
                        color: e.color,
                        title: e.label,
                        subtitle: e.subtitle,
                        onTap: () => context.push('/settings/${e.key}'),
                      ),
                  ],
                ).enter(++i),
              ),
            ],
            SPad(SectionLabel('Online bookings').enter(++i)),
            SPad(
              Group(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                children: [
                  NavRow(
                    icon: Icons.storefront_rounded,
                    color: const Color(0xFF6431DD),
                    title: 'Online store settings',
                    subtitle: 'Branding, checkout, SEO',
                    trailing: const Icon(Icons.arrow_outward_rounded, size: 18, color: AppColors.muted),
                    onTap: () => context.push('/online-store'),
                  ),
                ],
              ).enter(++i),
            ),
          ],
        );
      },
    );
  }
}
