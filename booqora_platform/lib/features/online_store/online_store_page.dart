import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/browser.dart';
import '../../core/theme.dart';
import '../../data/session.dart';
import '../../widgets/anim.dart';
import '../../widgets/page.dart';
import 'section_checkout.dart';
import 'section_fulfillment.dart';
import 'section_misc.dart';
import 'section_overview.dart';
import 'section_preferences.dart';
import 'section_website.dart';
import 'store_common.dart';

const storeSections = <(String, String, IconData)>[
  ('overview', 'Overview', Icons.dashboard_outlined),
  ('booking-page', 'Booking page', Icons.storefront_outlined),
  ('website', 'Website', Icons.web_outlined),
  ('integration', 'Website integration', Icons.integration_instructions_outlined),
  ('cross-sell', 'Cross-sell', Icons.auto_awesome_motion_outlined),
  ('preferences', 'Preferences', Icons.tune),
  ('fulfillment', 'Fulfillment', Icons.local_shipping_outlined),
  ('checkout', 'Checkout', Icons.shopping_cart_checkout),
  ('seo', 'SEO', Icons.travel_explore_outlined),
];

class OnlineStorePage extends StatelessWidget {
  final String section;
  const OnlineStorePage({super.key, this.section = 'overview'});

  @override
  Widget build(BuildContext context) {
    final key = storeSections.any((s) => s.$1 == section) ? section : 'overview';
    final meta = storeSections.firstWhere((s) => s.$1 == key);
    return ListenableBuilder(
      listenable: Session.instance,
      builder: (context, _) {
        final ws = Session.instance.workspace;
        if (ws == null) return const Center(child: CircularProgressIndicator());
        final wide = MediaQuery.sizeOf(context).width >= 1000;
        final body = KeyedSubtree(key: ValueKey(key), child: _section(key));
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PageHeader(
            title: key == 'overview' ? 'Online store' : meta.$2,
            subtitle: key == 'overview' ? 'Take bookings online through your booking page, website or an embed.' : null,
            breadcrumbs: key == 'overview' ? const [] : const [('Online store', '/online-store')],
            actions: [
              FilledButton.icon(
                onPressed: () => Browser.openUrl(StoreSync.url),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('View online store'),
              ),
            ],
          ),
          Expanded(
            child: wide
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(padding: const EdgeInsets.only(left: 28, right: 24, bottom: 24), child: _SideNav(current: key)),
                    Expanded(child: body),
                  ])
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: _NavDropdown(current: key)),
                    Expanded(child: body),
                  ]),
          ),
        ]);
      },
    );
  }

  Widget _section(String key) {
    switch (key) {
      case 'booking-page':
        return const BookingPageSection();
      case 'website':
        return const WebsiteSection();
      case 'integration':
        return const IntegrationSection();
      case 'cross-sell':
        return const CrossSellSection();
      case 'preferences':
        return const PreferencesSection();
      case 'fulfillment':
        return const FulfillmentSection();
      case 'checkout':
        return const CheckoutSection();
      case 'seo':
        return const SeoSection();
      default:
        return const OverviewSection();
    }
  }
}

class _SideNav extends StatelessWidget {
  final String current;
  const _SideNav({required this.current});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < storeSections.length; i++)
          _NavItem(
            label: storeSections[i].$2,
            icon: storeSections[i].$3,
            selected: storeSections[i].$1 == current,
            onTap: () => context.go('/online-store/${storeSections[i].$1}'),
          ).enterX(i, -0.04),
      ]),
    );
  }
}

class _NavItem extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
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
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: sel ? AppColors.primarySoft : (_hover ? AppColors.bg : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Icon(widget.icon, size: 18, color: sel ? AppColors.primary : AppColors.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(widget.label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    color: sel ? AppColors.primaryDeep : AppColors.inkSoft,
                  )),
            ),
            AnimatedOpacity(
              opacity: sel ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _NavDropdown extends StatelessWidget {
  final String current;
  const _NavDropdown({required this.current});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: current,
      isExpanded: true,
      borderRadius: BorderRadius.circular(12),
      decoration: const InputDecoration(prefixIcon: Icon(Icons.menu_open, size: 18)),
      items: [
        for (final s in storeSections)
          DropdownMenuItem(
            value: s.$1,
            child: Row(children: [Icon(s.$3, size: 18, color: AppColors.primary), const SizedBox(width: 10), Text(s.$2)]),
          ),
      ],
      onChanged: (v) {
        if (v != null && v != current) context.go('/online-store/$v');
      },
    );
  }
}
