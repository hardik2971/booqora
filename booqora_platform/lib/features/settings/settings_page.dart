import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/page.dart';
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

class _NavEntry {
  final String key;
  final String label;
  final IconData icon;
  const _NavEntry(this.key, this.label, this.icon);
}

const _entries = [
  _NavEntry('general', 'General', Icons.business_outlined),
  _NavEntry('pricing', 'Pricing', Icons.sell_outlined),
  _NavEntry('taxes', 'Taxes', Icons.percent),
  _NavEntry('rental-period', 'Rental period', Icons.schedule_outlined),
  _NavEntry('payments', 'Payment providers', Icons.credit_card_outlined),
  _NavEntry('custom-fields', 'Custom fields', Icons.dynamic_form_outlined),
  _NavEntry('locations', 'Locations', Icons.place_outlined),
  _NavEntry('emails', 'Emails', Icons.mail_outline),
  _NavEntry('documents', 'Documents', Icons.description_outlined),
  _NavEntry('translations', 'Translations', Icons.translate),
  _NavEntry('security', 'Security', Icons.shield_outlined),
  _NavEntry('team', 'Team', Icons.group_outlined),
  _NavEntry('billing', 'Account and billing', Icons.workspace_premium_outlined),
];

class SettingsPage extends StatelessWidget {
  final String section;
  const SettingsPage({super.key, this.section = 'general'});

  Widget _content(String key) => switch (key) {
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
        _ => const GeneralSettings(),
      };

  @override
  Widget build(BuildContext context) {
    final key = _entries.any((e) => e.key == section) ? section : 'general';
    final w = MediaQuery.sizeOf(context).width;
    final wide = w >= 1100;
    final content = KeyedSubtree(key: ValueKey(key), child: _content(key));
    if (wide) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const PageHeader(title: 'Settings', subtitle: 'Configure how your rental business works'),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(left: 28, bottom: 24),
              child: SizedBox(width: 236, child: _SideNav(current: key)),
            ),
            const SizedBox(width: 28),
            Expanded(child: content),
          ]),
        ),
      ]);
    }
    final narrow = w < 700;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader(title: 'Settings'),
      Padding(
        padding: EdgeInsets.fromLTRB(narrow ? 16 : 28, 0, narrow ? 16 : 28, 16),
        child: _NarrowNav(current: key),
      ),
      Expanded(child: Padding(padding: EdgeInsets.only(left: narrow ? 0 : 24), child: content)),
    ]);
  }
}

class _SideNav extends StatelessWidget {
  final String current;
  const _SideNav({required this.current});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ListView(padding: const EdgeInsets.all(10), children: [
        const _GroupLabel('Back office'),
        for (var i = 0; i < _entries.length; i++)
          _NavTile(
            label: _entries[i].label,
            icon: _entries[i].icon,
            selected: _entries[i].key == current,
            onTap: () => context.go('/settings/${_entries[i].key}'),
          ).enterX(i, -0.04),
        const SizedBox(height: 12),
        const _GroupLabel('Online bookings'),
        _NavTile(
          label: 'Online store settings',
          icon: Icons.storefront_outlined,
          selected: false,
          trailing: const Icon(Icons.arrow_outward, size: 14, color: AppColors.muted),
          onTap: () => context.go('/online-store'),
        ).enterX(_entries.length, -0.04),
      ]),
    ).enterX(0, -0.04);
  }
}

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
        child: Text(text.toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.7, color: AppColors.muted)),
      );
}

class _NavTile extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;
  const _NavTile({required this.label, required this.icon, required this.selected, required this.onTap, this.trailing});

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: sel ? AppColors.primarySoft : (_hover ? const Color(0xFFF8F6FD) : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 3,
              height: 16,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(color: sel ? AppColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(2)),
            ),
            Icon(widget.icon, size: 18, color: sel ? AppColors.primary : AppColors.inkSoft),
            const SizedBox(width: 10),
            Expanded(
              child: Text(widget.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    color: sel ? AppColors.primaryDeep : AppColors.ink,
                  )),
            ),
            ?widget.trailing,
          ]),
        ),
      ),
    );
  }
}

class _NarrowNav extends StatelessWidget {
  final String current;
  const _NarrowNav({required this.current});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: current,
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          items: [
            for (final e in _entries)
              DropdownMenuItem(
                value: e.key,
                child: Row(children: [
                  Icon(e.icon, size: 18, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Text(e.label),
                ]),
              ),
            const DropdownMenuItem(
              value: '__store',
              child: Row(children: [
                Icon(Icons.storefront_outlined, size: 18, color: AppColors.primary),
                SizedBox(width: 10),
                Text('Online store settings'),
                SizedBox(width: 6),
                Icon(Icons.arrow_outward, size: 14, color: AppColors.muted),
              ]),
            ),
          ],
          onChanged: (k) {
            if (k == null || k == current) return;
            context.go(k == '__store' ? '/online-store' : '/settings/$k');
          },
        ),
      ),
    ).enter();
  }
}
