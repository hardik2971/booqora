import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/browser.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../data/session.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import 'store_common.dart';

// ============================ Overview ============================

class OverviewSection extends StatelessWidget {
  const OverviewSection({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Session.instance;
    final store = s.settings('store');
    final enabled = store['enabled'] != false;
    final theme = (store['theme'] ?? '').toString();
    final t = Theme.of(context).textTheme;

    final channels = [
      _ChannelCard(
        icon: Icons.storefront_outlined,
        title: 'Booking page',
        status: enabled ? 'live' : 'inactive',
        statusLabel: enabled ? 'Live' : 'Offline',
        description: 'A hosted booking page your customers can use right away.',
        body: CopyField(StoreSync.url),
        actions: [
          FilledButton.icon(
            onPressed: () => Browser.openUrl(StoreSync.url),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('View online store'),
          ),
          TextButton(onPressed: () => context.go('/online-store/booking-page'), child: const Text('Customize')),
        ],
        index: 0,
      ),
      _ChannelCard(
        icon: Icons.web_outlined,
        title: 'Website builder',
        status: theme.isEmpty ? 'draft' : 'active',
        statusLabel: theme.isEmpty ? 'Default theme' : 'Theme: ${Fmt2.cap(theme)}',
        description: 'Pick a theme and manage pages, menus, blog posts and redirects.',
        actions: [
          OutlinedButton.icon(
            onPressed: () => context.go('/online-store/website'),
            icon: const Icon(Icons.brush_outlined, size: 16),
            label: const Text('Customize website'),
          ),
        ],
        index: 1,
      ),
      _ChannelCard(
        icon: Icons.integration_instructions_outlined,
        title: 'Website integration',
        status: 'draft',
        statusLabel: 'Embed',
        description: 'Add booking to WordPress, Shopify, Squarespace or any custom site.',
        actions: [
          OutlinedButton.icon(
            onPressed: () => context.go('/online-store/integration'),
            icon: const Icon(Icons.code, size: 16),
            label: const Text('Set up your integration'),
          ),
        ],
        index: 2,
      ),
    ];

    return SectionFrame(children: [
      LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth > 980 ? 3 : (c.maxWidth > 620 ? 2 : 1);
        final w = (c.maxWidth - (cols - 1) * 16) / cols;
        return Wrap(spacing: 16, runSpacing: 16, children: [for (final ch in channels) SizedBox(width: w, child: ch)]);
      }),
      const SizedBox(height: 24),
      WithPreview(
        preview: StorePreview.fromSettings(),
        children: [
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Steps to get started', style: t.titleMedium),
              const SizedBox(height: 4),
              Text('Complete these to start taking online bookings.', style: t.bodySmall?.copyWith(color: AppColors.muted)),
              const SizedBox(height: 14),
              StreamBuilder<List<Doc>>(
                stream: Db.watchWhere(C.products, 'showInStore', true),
                builder: (context, snap) {
                  final ob = s.workspace?.m('onboarding') ?? {};
                  final steps = [
                    (
                      'Set up rental period',
                      'Choose how customers pick dates and times.',
                      ob['rentalPeriod'] == true || ob['rental_period'] == true,
                      '/settings/rental-period',
                    ),
                    (
                      'Add products to store',
                      '${(snap.data ?? []).length} products visible in your store.',
                      (snap.data ?? []).isNotEmpty,
                      '/inventory',
                    ),
                    (
                      'Customize checkout',
                      'Form fields, payments and terms.',
                      s.settings('checkout')['fields'] != null || ob['checkout'] == true,
                      '/online-store/checkout',
                    ),
                    (
                      'Brand colour',
                      'Match the store to your brand.',
                      store['brandCustomized'] == true || (store['brandColor'] != null && store['brandColor'] != '#6431DD'),
                      '/online-store/preferences',
                    ),
                  ];
                  final done = steps.where((e) => e.$3).length;
                  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: done / steps.length),
                            duration: const Duration(milliseconds: 700),
                            curve: Curves.easeOutCubic,
                            builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 8, backgroundColor: AppColors.primarySoft),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('$done of ${steps.length}', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
                    ]),
                    const SizedBox(height: 10),
                    for (var i = 0; i < steps.length; i++)
                      _StepTile(title: steps[i].$1, subtitle: steps[i].$2, done: steps[i].$3, onTap: () => context.go(steps[i].$4)).enter(i + 1),
                  ]);
                },
              ),
            ]),
          ).enter(3),
        ],
      ),
    ]);
  }
}

class Fmt2 {
  static String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _ChannelCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String status;
  final String statusLabel;
  final String description;
  final Widget? body;
  final List<Widget> actions;
  final int index;
  const _ChannelCard({
    required this.icon,
    required this.title,
    required this.status,
    required this.statusLabel,
    required this.description,
    this.body,
    this.actions = const [],
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return HoverLift(
      child: AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const Spacer(),
            StatusPill(status, label: statusLabel),
          ]),
          const SizedBox(height: 14),
          Text(title, style: t.titleMedium),
          const SizedBox(height: 4),
          Text(description, style: t.bodySmall?.copyWith(color: AppColors.muted, height: 1.45)),
          if (body != null) ...[const SizedBox(height: 12), body!],
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: actions),
        ]),
      ),
    ).enter(index);
  }
}

class _StepTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool done;
  final VoidCallback onTap;
  const _StepTile({required this.title, required this.subtitle, required this.done, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: done ? AppColors.success : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: done ? AppColors.success : AppColors.border, width: 1.6),
            ),
            child: done ? const Icon(Icons.check, size: 15, color: Colors.white) : null,
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
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ]),
      ),
    );
  }
}

// ============================ Booking page ============================

class BookingPageSection extends StatefulWidget {
  const BookingPageSection({super.key});

  @override
  State<BookingPageSection> createState() => _BookingPageSectionState();
}

class _BookingPageSectionState extends State<BookingPageSection> with StoreSectionState {
  late final Map<String, dynamic> _store = Session.instance.settings('store');
  late bool _enabled = _store['enabled'] != false;
  late final _heroTitle = ctl(_store, 'heroTitle');
  late final _heroSubtitle = ctl(_store, 'heroSubtitle');
  late final _announcement = ctl(_store, 'announcement');
  late final _description = ctl(_store, 'description');

  @override
  void dispose() {
    for (final c in [_heroTitle, _heroSubtitle, _announcement, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  void _changed(String _) => setState(() => dirty = true);

  Future<void> _save() => runSave({
        'store': {
          'enabled': _enabled,
          'heroTitle': _heroTitle.text.trim(),
          'heroSubtitle': _heroSubtitle.text.trim(),
          'announcement': _announcement.text.trim(),
          'description': _description.text.trim(),
        },
      });

  @override
  Widget build(BuildContext context) {
    final url = StoreSync.url;
    final preview = StorePreview.fromSettings(store: {
      'heroTitle': _heroTitle.text,
      'heroSubtitle': _heroSubtitle.text,
      'announcement': _announcement.text,
    });
    return SectionFrame(
      onSave: _save,
      saving: saving,
      dirty: dirty,
      children: [
        WithPreview(preview: preview, children: [
          TitledCard(
            icon: Icons.power_settings_new,
            title: 'Store status',
            subtitle: 'When disabled, visitors see an offline message and cannot book.',
            trailing: StatusPill(_enabled ? 'live' : 'inactive', label: _enabled ? 'Live' : 'Offline'),
            children: [
              SwitchTile(
                value: _enabled,
                title: 'Enable online store',
                subtitle: 'Accept booking requests from your booking page.',
                onChanged: (v) => touch(() => _enabled = v),
              ),
              CopyField(url),
            ],
          ).enter(0),
          _ShareCard(url: url).enter(1),
          TitledCard(
            icon: Icons.brush_outlined,
            title: 'Customize',
            subtitle: 'Headline content shown at the top of your booking page.',
            children: [
              Field(label: 'Hero title', controller: _heroTitle, hint: 'Rent the best gear in town', onChanged: _changed),
              Field(label: 'Hero subtitle', controller: _heroSubtitle, hint: 'Pick your dates and book online in minutes.', onChanged: _changed),
              Field(label: 'Announcement bar text', controller: _announcement, hint: 'Free delivery on orders over ₹5,000', onChanged: _changed),
              Field(label: 'Store description', controller: _description, maxLines: 4, onChanged: _changed),
            ],
          ).enter(2),
        ]),
      ],
    );
  }
}

class _ShareCard extends StatelessWidget {
  final String url;
  const _ShareCard({required this.url});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.ios_share, color: AppColors.lavender, size: 20),
            const SizedBox(width: 8),
            const Text('Share your booking page', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            const Spacer(),
            const Icon(Icons.auto_awesome, color: AppColors.lavender, size: 18)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 0.85, end: 1.1, duration: 1400.ms),
          ]),
          const SizedBox(height: 14),
          SelectableText(
            url.replaceFirst(RegExp(r'^https?://'), ''),
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3),
          ),
          const SizedBox(height: 6),
          Text('Add it to your Instagram bio, WhatsApp status, Google Business profile or email signature.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13, height: 1.4)),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primaryDeep),
              onPressed: () => copyText(context, url, 'Link copied'),
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy link'),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38)),
              onPressed: () => Browser.openUrl(url),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Open'),
            ),
          ]),
        ]),
      ),
    );
  }
}
