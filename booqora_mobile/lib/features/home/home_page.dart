import 'package:flutter/material.dart' hide Thumb;
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/browser.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../data/session.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/mobile.dart';
import '../../widgets/side_panel.dart';
import '../reports/report_kit.dart';
import '../welcome/illustrations.dart';
import 'setup_steps.dart';

String _firstName() {
  final n = Session.instance.displayName.trim();
  return n.isEmpty ? 'there' : n.split(RegExp(r'\s+')).first;
}

void _viewStore(BuildContext context) {
  final slug = Session.instance.workspace?.s('slug') ?? '';
  if (slug.isEmpty) {
    toast(context, 'Your store address isn’t set up yet', error: true);
    return;
  }
  Browser.openUrl('${Browser.origin}/s/$slug');
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Map<String, Stream<List<Doc>>> _streams = _make();

  Map<String, Stream<List<Doc>>> _make() => {
        'orders': Db.watch(C.orders),
        'products': Db.watch(C.products, limit: 1),
        'notes': Db.watch(C.notes, limit: 4),
      };

  Future<void> _refresh() async {
    HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (mounted) setState(() => _streams = _make());
  }

  @override
  Widget build(BuildContext context) {
    context.watch<Session>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        const _TopGlow(),
        RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.primary,
          edgeOffset: MediaQuery.paddingOf(context).top,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              const SliverToBoxAdapter(child: SafeArea(bottom: false, child: _Header())),
              SliverToBoxAdapter(
                child: MultiStream(
                  streams: _streams,
                  loading: const _HomeSkeleton(),
                  builder: (context, d) {
                    final orders = d['orders']!;
                    if (orders.isEmpty && d['products']!.isEmpty) return const _Welcome();
                    return _Overview(orders: orders, notes: d['notes']!);
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ]),
    );
  }
}

// ============================================================== header
class _TopGlow extends StatelessWidget {
  const _TopGlow();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: -120,
      right: -80,
      child: IgnorePointer(
        child: Container(
          width: 320,
          height: 320,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [AppColors.lavender.withValues(alpha: 0.35), AppColors.lavender.withValues(alpha: 0)]),
          ),
        ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 0.92, end: 1.06, duration: 5.seconds, curve: Curves.easeInOut),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final s = Session.instance;
    final ws = s.workspace;
    final t = Theme.of(context).textTheme;
    final trial = ws?.s('plan') == 'trial';
    final ends = ws?.d('trialEndsAt');
    final daysLeft = ends == null ? null : (ends.difference(DateTime.now()).inHours / 24).ceil().clamp(0, 999);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(DateFormat('EEEE, d MMMM').format(DateTime.now()).toUpperCase(),
                  style: const TextStyle(fontSize: 11.5, letterSpacing: 1, fontWeight: FontWeight.w700, color: AppColors.muted)),
              const SizedBox(height: 4),
              Text('$_greeting,', style: t.titleMedium?.copyWith(color: AppColors.inkSoft, fontWeight: FontWeight.w500)),
              Text(_firstName(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800, fontSize: 28, letterSpacing: -0.6, height: 1.15)),
            ]).enterX(0),
          ),
          PressScale(
            onTap: () {
              HapticFeedback.selectionClick();
              context.push('/profile');
            },
            child: Container(
              padding: const EdgeInsets.all(2.5),
              decoration: const BoxDecoration(gradient: AppColors.brandGradient, shape: BoxShape.circle),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Avatar(s.displayName, url: s.profile?.s('avatarUrl'), size: 46),
              ),
            ),
          ).pop(1),
        ]),
        if (trial || (ws?.s('name') ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(children: [
            if ((ws?.s('name') ?? '').isNotEmpty)
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.storefront_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(ws!.s('name'),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
                    ),
                  ]),
                ),
              ),
            if (trial) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: (daysLeft ?? 1) <= 3
                      ? const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)])
                      : AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.bolt_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    daysLeft == null
                        ? 'Free trial'
                        : daysLeft == 0
                            ? 'Trial ended'
                            : 'Trial · $daysLeft day${daysLeft == 1 ? '' : 's'} left',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ]),
              ),
            ],
          ]).enter(2),
        ],
      ]),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Skeleton(height: 210, radius: 28),
        SizedBox(height: 18),
        Row(children: [
          Expanded(child: Skeleton(height: 92, radius: 20)),
          SizedBox(width: 12),
          Expanded(child: Skeleton(height: 92, radius: 20)),
          SizedBox(width: 12),
          Expanded(child: Skeleton(height: 92, radius: 20)),
        ]),
        SizedBox(height: 18),
        Skeleton(height: 104, radius: 18),
        SizedBox(height: 18),
        Skeleton(height: 240, radius: 22),
      ]),
    );
  }
}

// ============================================================== overview
class _Overview extends StatelessWidget {
  final List<Doc> orders;
  final List<Doc> notes;
  const _Overview({required this.orders, required this.notes});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final lastMonthStart = DateTime(now.year, now.month - 1);
    final valid = orders.where(isRevenueOrder).toList();
    final thisMonth = valid.where((o) => !o.created.isBefore(monthStart)).toList();
    final lastMonth = valid.where((o) => !o.created.isBefore(lastMonthStart) && o.created.isBefore(monthStart)).toList();
    final revenue = thisMonth.fold<num>(0, (a, o) => a + o.n('total'));
    final lastRevenue = lastMonth.fold<num>(0, (a, o) => a + o.n('total'));
    final active = orders.where((o) => o.s('status') == 'started').length;
    final outstanding = orders.where((o) => o.s('status') != 'canceled').fold<num>(0, (a, o) => a + (o.n('due') < 0 ? 0 : o.n('due')));

    final today = dayOf(now);
    final last30 = DateTimeRange(start: today.subtract(const Duration(days: 29)), end: today.add(const Duration(days: 1)));
    final (labels, values) = bucketize(valid, last30, (o) => o.created, (o) => o.n('total'));
    final spark = values.sublist(values.length - 14);
    final done = setupDoneCount;

    const pad = EdgeInsets.symmetric(horizontal: 16);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: _Hero(revenue: revenue, lastRevenue: lastRevenue, orders: thisMonth.length, spark: spark),
      ).enter(0, 0.08),
      const SizedBox(height: 22),
      const Padding(padding: pad, child: _QuickGrid()),
      if (done < setupSteps.length) ...[
        const SizedBox(height: 16),
        Padding(padding: pad, child: _SetupProgressCard(done: done)).enter(3),
      ],
      const Padding(padding: EdgeInsets.fromLTRB(20, 22, 20, 10), child: _Heading('At a glance')),
      MetricScroller(items: [
        MiniMetric(label: 'Revenue', value: revenue, format: Fmt.compactMoney, icon: Icons.payments_outlined),
        MiniMetric(label: 'Orders', value: thisMonth.length, format: Fmt.integer, icon: Icons.receipt_long_outlined, color: AppColors.primaryDeep),
        MiniMetric(label: 'Active rentals', value: active, format: Fmt.integer, icon: Icons.local_shipping_outlined, color: AppColors.info),
        MiniMetric(label: 'Outstanding', value: outstanding, format: Fmt.compactMoney, icon: Icons.account_balance_wallet_outlined, color: AppColors.danger),
      ]),
      const Padding(padding: EdgeInsets.fromLTRB(20, 24, 20, 10), child: _Heading('Today')),
      Padding(padding: pad, child: _TodayCard(orders: orders)).enter(4),
      const SizedBox(height: 16),
      Padding(
        padding: pad,
        child: ChartCard(
          title: 'Revenue',
          subtitle: 'Last 30 days · by order date',
          icon: Icons.bar_chart_rounded,
          trailing: TextButton(onPressed: () => context.push('/reports/performance'), child: const Text('Report')),
          child: BucketBarChart(labels: labels, values: values, format: Fmt.money, height: 200),
        ),
      ).enter(5),
      const SizedBox(height: 16),
      Padding(padding: pad, child: _TopProducts(orders: valid)).enter(6),
      const SizedBox(height: 16),
      Padding(padding: pad, child: _LatestNotes(notes: notes)).enter(7),
      const SizedBox(height: 16),
      const Padding(padding: pad, child: ActivityCard(limit: 6)),
    ]);
  }
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);

  @override
  Widget build(BuildContext context) => Text(text, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 19, fontWeight: FontWeight.w800));
}

class _Hero extends StatelessWidget {
  final num revenue;
  final num lastRevenue;
  final int orders;
  final List<num> spark;
  const _Hero({required this.revenue, required this.lastRevenue, required this.orders, required this.spark});

  @override
  Widget build(BuildContext context) {
    final change = lastRevenue > 0 ? (revenue - lastRevenue) / lastRevenue * 100 : null;
    final up = (change ?? 0) >= 0;
    return PressScale(
      scale: 0.98,
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/reports/performance');
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.heroGradient,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: AppColors.primaryDeep.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 14))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          Positioned(
            right: -50,
            top: -60,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [AppColors.primary.withValues(alpha: 0.55), Colors.transparent])),
            ),
          ),
          Positioned(
            left: -40,
            bottom: -70,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.07), width: 18)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
                  child: const Icon(Icons.auto_graph_rounded, color: AppColors.lavender, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Revenue in ${DateFormat('MMMM').format(DateTime.now())}',
                      style: const TextStyle(color: Color(0xFFD9CCF8), fontWeight: FontWeight.w600, fontSize: 13)),
                ),
                const Icon(Icons.arrow_outward_rounded, color: Colors.white54, size: 18),
              ]),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: CountUp(
                  value: revenue,
                  format: Fmt.money,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: -1.2, fontSize: 36),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _HeroChip(icon: Icons.receipt_long_outlined, text: '$orders order${orders == 1 ? '' : 's'}'),
                if (change != null)
                  _HeroChip(
                    icon: up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                    text: '${up ? '+' : ''}${change.toStringAsFixed(0)}% vs last month',
                    color: up ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                  )
                else
                  const _HeroChip(icon: Icons.auto_awesome, text: 'First month tracked'),
              ]),
              const SizedBox(height: 14),
              Sparkline(values: spark, height: 74),
              const SizedBox(height: 4),
              const Row(children: [
                Text('14 days ago', style: TextStyle(color: Color(0xFF9F8BD8), fontSize: 11)),
                Spacer(),
                Text('Today', style: TextStyle(color: Color(0xFF9F8BD8), fontSize: 11)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _HeroChip({required this.icon, required this.text, this.color = Colors.white});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      );
}

// ============================================================== quick actions
class _QuickGrid extends StatelessWidget {
  const _QuickGrid();

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, Color, VoidCallback)>[
      (Icons.add_rounded, 'New order', AppColors.primary, () => context.push('/orders/new')),
      (Icons.inventory_2_outlined, 'Add product', AppColors.primaryDeep, () => context.push('/inventory/products/new')),
      (Icons.qr_code_scanner_rounded, 'Scan', AppColors.info, () => context.push('/scan')),
      (Icons.calendar_month_outlined, 'Calendar', AppColors.success, () => context.push('/calendar')),
      (Icons.people_alt_outlined, 'Customers', AppColors.warning, () => context.push('/customers')),
      (Icons.storefront_outlined, 'View store', const Color(0xFF0E7490), () => _viewStore(context)),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.08,
      children: [
        for (var i = 0; i < items.length; i++) _QuickTile(icon: items[i].$1, label: items[i].$2, color: items[i].$3, onTap: items[i].$4, primary: i == 0).pop(i + 1),
      ],
    );
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool primary;
  const _QuickTile({required this.icon, required this.label, required this.color, required this.onTap, this.primary = false});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: primary ? AppColors.brandGradient : null,
          color: primary ? null : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: primary ? null : Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: primary ? AppColors.primary.withValues(alpha: 0.35) : const Color(0x0D1C0938),
              blurRadius: primary ? 18 : 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: primary ? Colors.white.withValues(alpha: 0.18) : null,
              gradient: primary ? null : LinearGradient(colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.06)]),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: primary ? Colors.white : color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: primary ? Colors.white : AppColors.ink)),
        ]),
      ),
    );
  }
}

class _SetupProgressCard extends StatelessWidget {
  final int done;
  const _SetupProgressCard({required this.done});

  @override
  Widget build(BuildContext context) {
    final next = setupSteps.where((s) => !s.done).firstOrNull;
    return PressScale(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/setup');
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.lavender.withValues(alpha: 0.6)),
          boxShadow: const [BoxShadow(color: Color(0x146431DD), blurRadius: 16, offset: Offset(0, 6))],
        ),
        child: Row(children: [
          ProgressRing(done: done, total: setupSteps.length, size: 54, light: false),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Finish setting up', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 2),
              Text(
                next == null ? '$done of ${setupSteps.length} steps complete' : 'Next: ${next.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ]),
          ),
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(gradient: AppColors.brandGradient, shape: BoxShape.circle),
            child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
          ),
        ]),
      ),
    );
  }
}

// ============================================================== today
class _TodayCard extends StatefulWidget {
  final List<Doc> orders;
  const _TodayCard({required this.orders});

  @override
  State<_TodayCard> createState() => _TodayCardState();
}

class _TodayCardState extends State<_TodayCard> {
  int _seg = 0; // 0 going out, 1 coming back
  int _offset = 0;

  String get _status => _seg == 0 ? 'reserved' : 'started';
  String get _field => _seg == 0 ? 'startsAt' : 'stopsAt';

  List<Doc> _on(DateTime day) {
    final next = day.add(const Duration(days: 1));
    return widget.orders.where((o) {
      if (o.s('status') != _status) return false;
      final d = o.d(_field);
      return d != null && !d.isBefore(day) && d.isBefore(next);
    }).toList()
      ..sort((a, b) => a.d(_field)!.compareTo(b.d(_field)!));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = dayOf(now);
    final day = today.add(Duration(days: _offset));
    final rows = _on(day);
    final late = widget.orders.where((o) => o.s('status') == _status && (o.d(_field)?.isBefore(now) ?? false)).length;
    final outToday = _countFor(0, today), backToday = _countFor(1, today);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: Color(0x0D1C0938), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Segmented(
          index: _seg,
          labels: ['Going out · $outToday', 'Coming back · $backToday'],
          icons: const [Icons.north_east_rounded, Icons.south_west_rounded],
          onChanged: (i) => setState(() => _seg = i),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: 7,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final d = today.add(Duration(days: i));
              final sel = _offset == i;
              final has = _on(d).isNotEmpty;
              return PressScale(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _offset = i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  width: 52,
                  decoration: BoxDecoration(
                    gradient: sel ? AppColors.brandGradient : null,
                    color: sel ? null : AppColors.bg,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: sel ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))] : null,
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(i == 0 ? 'Today' : DateFormat('EEE').format(d),
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: sel ? Colors.white70 : AppColors.muted)),
                    const SizedBox(height: 2),
                    Text('${d.day}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: sel ? Colors.white : AppColors.ink)),
                    const SizedBox(height: 2),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: has ? (sel ? Colors.white : AppColors.primary) : Colors.transparent),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
        if (late > 0) ...[
          const SizedBox(height: 10),
          PressScale(
            onTap: () => context.go('/orders'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(color: AppColors.warningSoft, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.schedule_rounded, size: 16, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('$late ${_seg == 0 ? 'pickup' : 'return'}${late == 1 ? '' : 's'} running late',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.ink)),
                ),
                const Text('View', style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w700, fontSize: 13)),
                const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.warning),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 6),
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: rows.isEmpty
                ? Padding(
                    key: ValueKey('e$_seg$_offset'),
                    padding: const EdgeInsets.symmetric(vertical: 22),
                    child: Column(children: [
                      Icon(Icons.event_available_outlined, color: AppColors.lavender.withValues(alpha: 0.9), size: 30),
                      const SizedBox(height: 8),
                      Text(
                        _seg == 0 ? 'No pickups scheduled for this day.' : 'No returns expected on this day.',
                        style: const TextStyle(color: AppColors.muted, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ]),
                  )
                : Column(key: ValueKey('r$_seg$_offset'), children: [
                    for (var i = 0; i < rows.length && i < 6; i++) _DayRow(o: rows[i], dateField: _field).enterX(i),
                    if (rows.length > 6)
                      TextButton(onPressed: () => context.go('/orders'), child: Text('View all ${rows.length} orders')),
                  ]),
          ),
        ),
      ]),
    );
  }

  int _countFor(int seg, DateTime day) {
    final status = seg == 0 ? 'reserved' : 'started';
    final field = seg == 0 ? 'startsAt' : 'stopsAt';
    final next = day.add(const Duration(days: 1));
    return widget.orders.where((o) {
      if (o.s('status') != status) return false;
      final d = o.d(field);
      return d != null && !d.isBefore(day) && d.isBefore(next);
    }).length;
  }
}

class _Segmented extends StatelessWidget {
  final int index;
  final List<String> labels;
  final List<IconData> icons;
  final ValueChanged<int> onChanged;
  const _Segmented({required this.index, required this.labels, required this.icons, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(14)),
      child: Stack(children: [
        AnimatedAlign(
          alignment: index == 0 ? Alignment.centerLeft : Alignment.centerRight,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          child: FractionallySizedBox(
            widthFactor: 1 / labels.length,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(11),
                boxShadow: const [BoxShadow(color: Color(0x1A1C0938), blurRadius: 8, offset: Offset(0, 2))],
              ),
            ),
          ),
        ),
        Row(children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (i == index) return;
                  HapticFeedback.selectionClick();
                  onChanged(i);
                },
                child: Center(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icons[i], size: 15, color: i == index ? AppColors.primary : AppColors.muted),
                    const SizedBox(width: 6),
                    Flexible(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: i == index ? AppColors.ink : AppColors.muted),
                        child: Text(labels[i], maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
        ]),
      ]),
    );
  }
}

class _DayRow extends StatelessWidget {
  final Doc o;
  final String dateField;
  const _DayRow({required this.o, required this.dateField});

  @override
  Widget build(BuildContext context) {
    final name = o.s('customerName').isEmpty ? 'Walk-in customer' : o.s('customerName');
    final items = orderItems(o);
    final late = o.d(dateField)?.isBefore(DateTime.now()) ?? false;
    return PressScale(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/orders/${o.id}');
      },
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(color: const Color(0xFFFBFAFE), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Avatar(name, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('#${o.i('number')} · ${Fmt.integer(items)} item${items == 1 ? '' : 's'}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(Fmt.time(o.d(dateField)), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.inkSoft)),
            const SizedBox(height: 4),
            late ? const StatusPill('late') : StatusPill(o.s('status')),
          ]),
        ]),
      ),
    );
  }
}

// ============================================================== top products / notes
class _TopProducts extends StatelessWidget {
  final List<Doc> orders;
  const _TopProducts({required this.orders});

  @override
  Widget build(BuildContext context) {
    final qty = <String, num>{};
    final names = <String, String>{};
    final images = <String, String?>{};
    for (final o in orders) {
      for (final l in o.maps('lines')) {
        final key = (l['productId'] ?? l['name'] ?? '').toString();
        if (key.isEmpty) continue;
        qty[key] = (qty[key] ?? 0) + ((l['qty'] as num?) ?? 0);
        names[key] = (l['name'] ?? 'Item').toString();
        images[key] ??= l['imageUrl'] as String?;
      }
    }
    final top = qty.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final shown = top.take(5).toList();
    return ChartCard(
      title: 'Top products',
      subtitle: 'By units booked',
      icon: Icons.emoji_events_outlined,
      trailing: TextButton(onPressed: () => context.push('/reports/products'), child: const Text('Report')),
      child: shown.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Text('Products appear here once they’re booked.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
            )
          : RankBars(
              format: (v) => '${Fmt.integer(v)} units',
              items: [for (final e in shown) (names[e.key]!, e.value, Thumb(url: images[e.key], size: 38))],
            ),
    );
  }
}

class _LatestNotes extends StatelessWidget {
  final List<Doc> notes;
  const _LatestNotes({required this.notes});

  String? _route(Doc n) => switch (n.s('entity')) {
        'customers' => '/customers/${n.s('entityId')}',
        'orders' => '/orders/${n.s('entityId')}',
        'products' => '/inventory/products/${n.s('entityId')}',
        'documents' => '/documents/${n.s('entityId')}',
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    return ChartCard(
      title: 'Latest notes',
      icon: Icons.sticky_note_2_outlined,
      child: notes.isEmpty
          ? const Text('Notes added to orders, customers and products appear here.', style: TextStyle(color: AppColors.muted, fontSize: 13))
          : Column(children: [
              for (final n in notes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PressScale(
                    onTap: _route(n) == null ? null : () => context.push(_route(n)!),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFDE9B8)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(n.s('text'), maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(height: 1.4)),
                        const SizedBox(height: 6),
                        Text(
                          '${n.s('authorName')} · ${Fmt.label(n.s('entity')).replaceAll(RegExp(r's$'), '')} · ${Fmt.relative(n.d('createdAt'))}',
                          style: const TextStyle(fontSize: 11, color: AppColors.muted),
                        ),
                      ]),
                    ),
                  ),
                ),
            ]),
    );
  }
}

// ============================================================== welcome (empty workspace)
class _Welcome extends StatelessWidget {
  const _Welcome();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final done = setupDoneCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: AppColors.primaryDeep.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 14))],
          ),
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Center(child: OrbitHero(size: 210)),
            Text('Welcome to Booqora, ${_firstName()}',
                textAlign: TextAlign.center, style: t.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 23)),
            const SizedBox(height: 8),
            const Text(
              'Inventory, bookings, documents and an online store — all in your pocket. Add a product to get started, or let Bora set things up for you.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFD9CCF8), height: 1.5, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
              child: const Row(children: [
                Icon(Icons.auto_awesome, color: AppColors.lavender, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text('“Set up my first product: a DSLR camera at ₹1,200 per day, 3 in stock.”',
                      style: TextStyle(color: Colors.white, fontStyle: FontStyle.italic, height: 1.4, fontSize: 13)),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            PressScale(
              onTap: () {
                HapticFeedback.lightImpact();
                context.push('/assistant');
              },
              child: Container(
                height: 52,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.auto_awesome, size: 19, color: AppColors.primaryDeep),
                  SizedBox(width: 8),
                  Text('Ask Bora', style: TextStyle(color: AppColors.primaryDeep, fontWeight: FontWeight.w800, fontSize: 15.5)),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            PressScale(
              onTap: () {
                HapticFeedback.lightImpact();
                context.push('/inventory/products/new');
              },
              child: Container(
                height: 52,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white38)),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.add_rounded, size: 20, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Add your first product', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                ]),
              ),
            ),
          ]),
        ).enter(0, 0.08),
        const SizedBox(height: 22),
        const _QuickGrid(),
        const SizedBox(height: 22),
        Group(children: [
          Row(children: [
            ProgressRing(done: done, total: setupSteps.length, size: 64, light: false),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Setup checklist', style: t.titleMedium),
                Text('$done of ${setupSteps.length} steps complete', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
              ]),
            ),
          ]),
          Column(children: [
            for (final s in setupSteps)
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.push(s.done ? '/setup' : s.route);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
                  child: Row(children: [
                    Icon(s.done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        size: 22, color: s.done ? AppColors.success : AppColors.border),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(s.title,
                          style: TextStyle(
                            color: s.done ? AppColors.muted : AppColors.ink,
                            decoration: s.done ? TextDecoration.lineThrough : null,
                            fontWeight: FontWeight.w600,
                          )),
                    ),
                    if (!s.done) const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.muted),
                  ]),
                ),
              ),
          ]),
          GradientButton(label: 'Continue setup', icon: Icons.rocket_launch_outlined, onPressed: () => context.push('/setup')),
        ]).enter(3),
        const SizedBox(height: 16),
        Group(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), children: [
          NavRow(icon: Icons.menu_book_outlined, title: 'Help center', subtitle: 'Step-by-step guides', onTap: () => context.push('/help')),
        ]).enter(4),
      ]),
    );
  }
}
