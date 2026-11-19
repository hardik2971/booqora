import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/browser.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../data/session.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/mobile.dart';
import 'section_booking.dart';
import 'section_checkout.dart';
import 'section_fulfillment.dart';
import 'section_misc.dart';
import 'section_preferences.dart';
import 'section_website.dart';
import 'store_common.dart';

/// (key, title, subtitle, icon, colour)
const storeSections = <(String, String, String, IconData, Color)>[
  ('booking-page', 'Booking page', 'Status, hero text and sharing', Icons.storefront_outlined, AppColors.primary),
  ('website', 'Website', 'Themes, pages, menus, blog, redirects', Icons.web_outlined, Color(0xFF2563EB)),
  ('integration', 'Website integration', 'Embed on WordPress, Shopify & more', Icons.integration_instructions_outlined, Color(0xFF0891B2)),
  ('cross-sell', 'Cross-sell', 'Recommend related products', Icons.auto_awesome_motion_outlined, Color(0xFFDB2777)),
  ('preferences', 'Preferences', 'Brand colour, availability, cart', Icons.tune_rounded, Color(0xFF7C3AED)),
  ('fulfillment', 'Fulfillment', 'Pickup and delivery', Icons.local_shipping_outlined, Color(0xFF059669)),
  ('checkout', 'Checkout', 'Form fields, payments and terms', Icons.shopping_cart_checkout_rounded, Color(0xFFD97706)),
  ('seo', 'SEO', 'Search engine listing', Icons.travel_explore_outlined, Color(0xFF4B3F66)),
];

class OnlineStorePage extends StatelessWidget {
  final String section;
  const OnlineStorePage({super.key, this.section = 'overview'});

  @override
  Widget build(BuildContext context) {
    if (Session.instance.workspace == null) {
      return ListenableBuilder(
        listenable: Session.instance,
        builder: (context, _) => Session.instance.workspace == null
            ? const Scaffold(backgroundColor: AppColors.bg, body: Center(child: CircularProgressIndicator()))
            : OnlineStorePage(section: section),
      );
    }
    switch (section) {
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
        return const _StoreHub();
    }
  }
}

// ============================ Hub ============================

class _StoreHub extends StatefulWidget {
  const _StoreHub();

  @override
  State<_StoreHub> createState() => _StoreHubState();
}

class _StoreHubState extends State<_StoreHub> {
  bool? _pendingEnabled;
  bool _toggling = false;

  Future<void> _toggle(bool v) async {
    HapticFeedback.mediumImpact();
    setState(() {
      _pendingEnabled = v;
      _toggling = true;
    });
    try {
      await StoreSync.save({
        'store': {'enabled': v},
      });
      if (mounted) toast(context, v ? 'Your online store is live' : 'Your online store is offline');
    } catch (e) {
      if (mounted) {
        setState(() => _pendingEnabled = null);
        toast(context, friendlyError(e), error: true);
      }
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Session.instance,
      builder: (context, _) {
        final store = Session.instance.settings('store');
        final saved = store['enabled'] != false;
        if (_pendingEnabled == saved && !_toggling) _pendingEnabled = null;
        final enabled = _pendingEnabled ?? saved;
        return MPage(
          title: 'Online store',
          subtitle: 'Take bookings online, anywhere',
          actions: [
            IconButton(
              tooltip: 'View online store',
              icon: const Icon(Icons.open_in_new_rounded),
              onPressed: () => Browser.openUrl(StoreSync.url),
            ),
          ],
          slivers: [
            SPad(_HeroCard(enabled: enabled, busy: _toggling, onToggle: _toggle).enter(0)),
            SPad(_SetupSteps(store: store).enter(1)),
            const SPad(SectionLabel('Customize your store')),
            SPad(
              Group(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                children: [
                  for (var i = 0; i < storeSections.length; i++)
                    NavRow(
                      icon: storeSections[i].$4,
                      color: storeSections[i].$5,
                      title: storeSections[i].$2,
                      subtitle: storeSections[i].$3,
                      onTap: () => context.push('/online-store/${storeSections[i].$1}'),
                    ).enterX(i + 2),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HeroCard extends StatelessWidget {
  final bool enabled;
  final bool busy;
  final ValueChanged<bool> onToggle;
  const _HeroCard({required this.enabled, required this.busy, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final url = StoreSync.url;
    final short = url.replaceFirst(RegExp(r'^https?://'), '');
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: AppColors.primaryDeep.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 14))],
      ),
      child: Stack(children: [
        Positioned(
          right: -60,
          top: -40,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.lavender.withValues(alpha: 0.14)),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 0.9, end: 1.12, duration: 3200.ms, curve: Curves.easeInOut),
        ),
        Positioned(
          left: -50,
          bottom: 120,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withValues(alpha: 0.25)),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).moveY(begin: 0, end: 18, duration: 2800.ms, curve: Curves.easeInOut),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (enabled ? AppColors.success : AppColors.danger).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: (enabled ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5)).withValues(alpha: 0.5)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(color: enabled ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5), shape: BoxShape.circle),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scaleXY(begin: 1, end: 1.5, duration: 900.ms),
                  const SizedBox(width: 6),
                  Text(enabled ? 'Live' : 'Offline', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                ]),
              ),
              const Spacer(),
              if (busy) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              const SizedBox(width: 6),
              Switch(
                value: enabled,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.success,
                onChanged: busy ? null : onToggle,
              ),
            ]),
            const SizedBox(height: 16),
            Center(child: const LiveStorePreview(width: 220).animate().fadeIn(duration: 500.ms).moveY(begin: 18, end: 0, duration: 600.ms, curve: Curves.easeOutCubic)),
            const SizedBox(height: 22),
            Text('Your booking page', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(short, maxLines: 2, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _HeroButton(icon: Icons.copy_rounded, label: 'Copy', onTap: () => copyText(context, url, 'Link copied'))),
              const SizedBox(width: 8),
              Expanded(
                child: _HeroButton(
                  icon: Icons.ios_share_rounded,
                  label: 'Share',
                  onTap: () => Browser.shareText('Book with ${Session.instance.workspace?.s('name') ?? 'us'} online: $url', subject: 'Book online'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _HeroButton(icon: Icons.open_in_new_rounded, label: 'Open', primary: true, onTap: () => Browser.openUrl(url))),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _HeroButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;
  const _HeroButton({required this.icon, required this.label, required this.onTap, this.primary = false});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: primary ? Colors.white : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: primary ? 0 : 0.22)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 17, color: primary ? AppColors.primaryDeep : Colors.white),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: primary ? AppColors.primaryDeep : Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5)),
        ]),
      ),
    );
  }
}

class _SetupSteps extends StatefulWidget {
  final Map<String, dynamic> store;
  const _SetupSteps({required this.store});

  @override
  State<_SetupSteps> createState() => _SetupStepsState();
}

class _SetupStepsState extends State<_SetupSteps> {
  late final Stream<List<Doc>> _products = Db.watchWhere(C.products, 'showInStore', true);

  @override
  Widget build(BuildContext context) {
    final s = Session.instance;
    final store = widget.store;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: StreamBuilder<List<Doc>>(
        stream: _products,
        builder: (context, snap) {
          final ob = s.workspace?.m('onboarding') ?? {};
          final count = (snap.data ?? const []).length;
          final steps = [
            ('Set up rental period', 'Choose how customers pick dates and times.', ob['rentalPeriod'] == true || ob['rental_period'] == true, '/settings/rental-period'),
            ('Add products to store', '$count product${count == 1 ? '' : 's'} visible in your store.', count > 0, '/inventory'),
            ('Customize checkout', 'Form fields, payments and terms.', s.settings('checkout')['fields'] != null || ob['checkout'] == true, '/online-store/checkout'),
            ('Brand colour', 'Match the store to your brand.', store['brandCustomized'] == true || (store['brandColor'] != null && store['brandColor'] != '#6431DD'), '/online-store/preferences'),
          ];
          final done = steps.where((e) => e.$3).length;
          if (done == steps.length) return const SizedBox.shrink();
          return Group(children: [
            Row(children: [
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Steps to get started', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  SizedBox(height: 2),
                  Text('Complete these to start taking online bookings.', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
                ]),
              ),
              SizedBox(
                width: 46,
                height: 46,
                child: Stack(alignment: Alignment.center, children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: done / steps.length),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => SizedBox.expand(
                      child: CircularProgressIndicator(value: v, strokeWidth: 5, backgroundColor: AppColors.primarySoft, strokeCap: StrokeCap.round),
                    ),
                  ),
                  Text('$done/${steps.length}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.primaryDeep)),
                ]),
              ),
            ]),
            Column(children: [
              for (var i = 0; i < steps.length; i++)
                _StepRow(
                  title: steps[i].$1,
                  subtitle: steps[i].$2,
                  done: steps[i].$3,
                  onTap: () {
                    final r = steps[i].$4;
                    r == '/inventory' ? context.go(r) : context.push(r);
                  },
                ).enter(i + 1),
            ]),
          ]);
        },
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool done;
  final VoidCallback onTap;
  const _StepRow({required this.title, required this.subtitle, required this.done, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              gradient: done ? const LinearGradient(colors: [Color(0xFF22C55E), AppColors.success]) : null,
              color: done ? null : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: done ? Colors.transparent : AppColors.border, width: 1.6),
            ),
            child: done ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: done ? AppColors.muted : AppColors.ink,
                    decoration: done ? TextDecoration.lineThrough : null,
                  )),
              Text(subtitle, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ]),
      ),
    );
  }
}
