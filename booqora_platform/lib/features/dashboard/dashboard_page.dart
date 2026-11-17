import 'package:flutter/material.dart' hide Thumb;
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
import '../../widgets/page.dart';
import '../../widgets/side_panel.dart';
import '../reports/report_kit.dart';
import 'setup_page.dart' show ProgressRing;
import 'setup_steps.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final Map<String, Stream<List<Doc>>> _streams = {
    'orders': Db.watch(C.orders),
    'products': Db.watch(C.products, limit: 5),
    'notes': Db.watch(C.notes, limit: 6),
  };

  String get _firstName {
    final n = Session.instance.displayName.trim();
    return n.isEmpty ? 'there' : n.split(RegExp(r'\s+')).first;
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _viewStore() {
    final slug = Session.instance.workspace?.s('slug') ?? '';
    if (slug.isEmpty) {
      toast(context, 'Your store address isn’t set up yet', error: true);
      return;
    }
    Browser.openUrl('${Browser.origin}/s/$slug');
  }

  @override
  Widget build(BuildContext context) {
    context.watch<Session>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: '$_greeting, $_firstName',
          subtitle: DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
          actions: [
            FilledButton.icon(onPressed: () => context.go('/orders/new'), icon: const Icon(Icons.add, size: 18), label: const Text('New order')),
            OutlinedButton.icon(
              onPressed: () => context.go('/inventory/products/new'),
              icon: const Icon(Icons.inventory_2_outlined, size: 18),
              label: const Text('Add product'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.go('/customers/new'),
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
              label: const Text('Add customer'),
            ),
            OutlinedButton.icon(onPressed: _viewStore, icon: const Icon(Icons.open_in_new_rounded, size: 18), label: const Text('View store')),
          ],
        ),
        Expanded(
          child: MultiStream(
            streams: _streams,
            builder: (context, d) {
              final orders = d['orders']!;
              final products = d['products']!;
              if (orders.isEmpty && products.isEmpty) return _Onboarding(name: _firstName);
              return _Overview(orders: orders, notes: d['notes']!);
            },
          ),
        ),
      ],
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
    final outstanding = orders.where((o) => o.s('status') != 'canceled').fold<num>(0, (a, o) => a + o.n('due'));

    final today = dayOf(now);
    final last30 = DateTimeRange(start: today.subtract(const Duration(days: 29)), end: today.add(const Duration(days: 1)));
    final (labels, values) = bucketize(valid, last30, (o) => o.created, (o) => o.n('total'));
    final spark = values.sublist(values.length - 14);

    return PageBody(
      children: [
        _Hero(revenue: revenue, lastRevenue: lastRevenue, orders: thisMonth.length, spark: spark).enter(0),
        const SizedBox(height: 20),
        MetricRow(
          children: [
            MetricCard(label: 'Revenue this month', value: revenue, format: Fmt.money, icon: Icons.payments_outlined, index: 1),
            MetricCard(
              label: 'Orders this month',
              value: thisMonth.length,
              icon: Icons.receipt_long_outlined,
              color: AppColors.primaryDeep,
              index: 2,
            ),
            MetricCard(
              label: 'Active rentals',
              value: active,
              icon: Icons.local_shipping_outlined,
              color: AppColors.info,
              hint: 'Orders currently out with customers',
              index: 3,
            ),
            MetricCard(
              label: 'Outstanding balance',
              value: outstanding,
              format: Fmt.money,
              icon: Icons.account_balance_wallet_outlined,
              color: AppColors.danger,
              hint: 'Amount due across all non-canceled orders',
              index: 4,
            ),
          ],
        ),
        const SizedBox(height: 20),
        _TwoCol(
          a: _DayOrdersCard(
            title: 'Going out',
            icon: Icons.north_east_rounded,
            orders: orders,
            status: 'reserved',
            dateField: 'startsAt',
            emptyText: 'No pickups scheduled for this day.',
          ).enter(5),
          b: _DayOrdersCard(
            title: 'Coming back',
            icon: Icons.south_west_rounded,
            orders: orders,
            status: 'started',
            dateField: 'stopsAt',
            emptyText: 'No returns expected on this day.',
          ).enter(6),
        ),
        const SizedBox(height: 20),
        _TwoCol(
          flexA: 3,
          flexB: 2,
          a: ChartCard(
            title: 'Revenue',
            subtitle: 'Last 30 days · by order date',
            trailing: TextButton(onPressed: () => context.go('/reports/performance'), child: const Text('Full report')),
            child: BucketBarChart(labels: labels, values: values, format: Fmt.money, height: 260),
          ).enter(7),
          b: _TopProducts(orders: valid).enter(8),
        ),
        const SizedBox(height: 20),
        _TwoCol(
          a: _LatestNotes(notes: notes).enter(9),
          b: const ActivityCard(limit: 6).enter(10),
        ),
      ],
    );
  }
}

class _TwoCol extends StatelessWidget {
  final Widget a;
  final Widget b;
  final int flexA;
  final int flexB;
  const _TwoCol({required this.a, required this.b, this.flexA = 1, this.flexB = 1});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 900) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [a, const SizedBox(height: 20), b]);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: flexA, child: a),
            const SizedBox(width: 20),
            Expanded(flex: flexB, child: b),
          ],
        );
      },
    );
  }
}

class _Hero extends StatelessWidget {
  final num revenue;
  final num lastRevenue;
  final int orders;
  final List<num> spark;
  const _Hero({required this.revenue, required this.lastRevenue, required this.orders, required this.spark});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final change = lastRevenue > 0 ? (revenue - lastRevenue) / lastRevenue * 100 : null;
    final up = (change ?? 0) >= 0;
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_graph_rounded, color: AppColors.lavender, size: 18),
            const SizedBox(width: 8),
            Text(
              'Revenue in ${DateFormat('MMMM').format(DateTime.now())}',
              style: const TextStyle(color: Color(0xFFD9CCF8), fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: CountUp(
            value: revenue,
            format: Fmt.money,
            style: t.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: -1, fontSize: 38),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _HeroChip(icon: Icons.receipt_long_outlined, text: '$orders order${orders == 1 ? '' : 's'}'),
            if (change != null)
              _HeroChip(
                icon: up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                text: '${up ? '+' : ''}${change.toStringAsFixed(0)}% vs last month',
                color: up ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
              ),
          ],
        ),
      ],
    );
    final chart = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text('Last 14 days', style: TextStyle(color: Color(0xFFB9A6EC), fontSize: 12)),
        const SizedBox(height: 6),
        Sparkline(values: spark, height: 90),
      ],
    );
    return AppCard(
      gradient: AppColors.heroGradient,
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth < 640) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [info, const SizedBox(height: 18), chart]);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 5, child: info),
              const SizedBox(width: 24),
              Expanded(flex: 4, child: chart),
            ],
          );
        },
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
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

// ============================================================== going out / coming back
class _DayOrdersCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<Doc> orders;
  final String status;
  final String dateField;
  final String emptyText;
  const _DayOrdersCard({
    required this.title,
    required this.icon,
    required this.orders,
    required this.status,
    required this.dateField,
    required this.emptyText,
  });

  @override
  State<_DayOrdersCard> createState() => _DayOrdersCardState();
}

class _DayOrdersCardState extends State<_DayOrdersCard> {
  int _offset = 0;

  String _dayName(int i, DateTime d) => switch (i) {
    0 => 'Today',
    1 => 'Tomorrow',
    _ => Fmt.dayLabel(d),
  };

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = dayOf(now);
    final day = today.add(Duration(days: _offset));
    final next = day.add(const Duration(days: 1));
    final matching = widget.orders.where((o) => o.s('status') == widget.status).toList();
    final rows = matching.where((o) {
      final d = o.d(widget.dateField);
      return d != null && !d.isBefore(day) && d.isBefore(next);
    }).toList()..sort((a, b) => a.d(widget.dateField)!.compareTo(b.d(widget.dateField)!));
    final late = matching.where((o) => o.d(widget.dateField)?.isBefore(now) ?? false).length;
    final t = Theme.of(context).textTheme;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
                child: Icon(widget.icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(widget.title, style: t.titleMedium)),
              if (late > 0)
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: AppColors.warning),
                  onPressed: () => context.go('/orders'),
                  icon: const Icon(Icons.schedule_rounded, size: 16),
                  label: Text('View late ($late)'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 7,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, i) => ChoiceChip(
                label: Text(_dayName(i, today.add(Duration(days: i))), style: const TextStyle(fontSize: 12)),
                selected: _offset == i,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => setState(() => _offset = i),
              ),
            ),
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: rows.isEmpty
                ? Padding(
                    key: ValueKey('empty$_offset'),
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Column(
                      children: [
                        Icon(Icons.event_available_outlined, color: AppColors.lavender.withValues(alpha: 0.9), size: 30),
                        const SizedBox(height: 8),
                        Text(
                          widget.emptyText,
                          style: const TextStyle(color: AppColors.muted, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : Column(
                    key: ValueKey('rows$_offset'),
                    children: [
                      for (var i = 0; i < rows.length && i < 6; i++) _DayRow(o: rows[i], dateField: widget.dateField).enter(i),
                      if (rows.length > 6) TextButton(onPressed: () => context.go('/orders'), child: Text('View all ${rows.length} orders')),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  final Doc o;
  final String dateField;
  const _DayRow({required this.o, required this.dateField});

  @override
  Widget build(BuildContext context) {
    final name = o.s('customerName', 'Walk-in customer');
    final items = o.data['itemCount'] is num ? o.n('itemCount') : o.maps('lines').fold<num>(0, (a, l) => a + ((l['qty'] as num?) ?? 0));
    final late = o.d(dateField)?.isBefore(DateTime.now()) ?? false;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => context.go('/orders/${o.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Avatar(name, size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '#${o.i('number')} · ${Fmt.integer(items)} item${items == 1 ? '' : 's'}',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              Fmt.time(o.d(dateField)),
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.inkSoft),
            ),
            const SizedBox(width: 10),
            late ? const StatusPill('late') : StatusPill(o.s('status')),
          ],
        ),
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
    final max = shown.isEmpty ? 1 : shown.first.value;
    return ChartCard(
      title: 'Top products',
      subtitle: 'By units booked',
      trailing: TextButton(onPressed: () => context.go('/reports/products'), child: const Text('Report')),
      child: shown.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'Products appear here once they’re booked.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < shown.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      children: [
                        Thumb(url: images[shown[i].key], size: 38),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      names[shown[i].key]!,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text('${Fmt.integer(shown[i].value)} units', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: shown[i].value / max),
                                  duration: Duration(milliseconds: 700 + i * 120),
                                  curve: Curves.easeOutCubic,
                                  builder: (_, v, _) => LinearProgressIndicator(
                                    value: v,
                                    minHeight: 6,
                                    backgroundColor: AppColors.primarySoft,
                                    color: i == 0 ? AppColors.primary : (i == 1 ? AppColors.primaryDeep : AppColors.lavender),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
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
    return PanelCard(
      title: 'Latest notes',
      icon: Icons.sticky_note_2_outlined,
      child: notes.isEmpty
          ? const Text('Notes added to orders, customers and products appear here.', style: TextStyle(color: AppColors.muted, fontSize: 13))
          : Column(
              children: [
                for (final n in notes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _route(n) == null ? null : () => context.go(_route(n)!),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(10)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n.s('text'), maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(height: 1.4)),
                            const SizedBox(height: 6),
                            Text(
                              '${n.s('authorName')} · ${Fmt.label(n.s('entity')).replaceAll(RegExp(r's$'), '')} · ${Fmt.relative(n.d('createdAt'))}',
                              style: const TextStyle(fontSize: 11, color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

// ============================================================== onboarding
class _Onboarding extends StatelessWidget {
  final String name;
  const _Onboarding({required this.name});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final done = setupDoneCount;
    final welcome = AppCard(
      gradient: AppColors.heroGradient,
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome to Booqora, $name 👋',
            style: t.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          const Text(
            'Everything you need to run your rental business — inventory, bookings, documents and an online store — in one place. '
            'Start by adding a product, or let Bora, your AI assistant, guide you.',
            style: TextStyle(color: Color(0xFFD9CCF8), height: 1.55, fontSize: 15),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome, color: AppColors.lavender, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '“Set up my first product: a DSLR camera at ₹1,200 per day, 3 in stock.”',
                    style: TextStyle(color: Colors.white, fontStyle: FontStyle.italic, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primaryDeep),
                onPressed: () => context.go('/assistant'),
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Ask Bora'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38),
                ),
                onPressed: () => context.go('/inventory/products/new'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add your first product'),
              ),
            ],
          ),
        ],
      ),
    );
    final checklist = AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ProgressRing(done: done, total: setupSteps.length, size: 64, light: false),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Setup guide', style: t.titleMedium),
                    Text('$done of ${setupSteps.length} steps complete', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final s in setupSteps)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => context.go(s.done ? '/setup' : s.route),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
                child: Row(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        s.done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        key: ValueKey(s.done),
                        size: 20,
                        color: s.done ? AppColors.success : AppColors.border,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.title,
                        style: TextStyle(
                          color: s.done ? AppColors.muted : AppColors.ink,
                          decoration: s.done ? TextDecoration.lineThrough : null,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (!s.done) const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.muted),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => context.go('/setup'), child: const Text('Continue setup')),
        ],
      ),
    );
    return PageBody(
      children: [
        _TwoCol(flexA: 3, flexB: 2, a: welcome.enter(0), b: checklist.enter(1)),
        const SizedBox(height: 20),
        MetricRow(
          children: [
            for (final (i, q) in const [
              (Icons.inventory_2_outlined, 'Add products', 'Photos, prices and stock', '/inventory/products/new'),
              (Icons.people_alt_outlined, 'Add customers', 'Or import a CSV', '/customers'),
              (Icons.storefront_outlined, 'Open your store', 'Take bookings 24/7', '/online-store'),
              (Icons.menu_book_outlined, 'Read the guides', 'Step-by-step help', '/help'),
            ].indexed)
              AppCard(
                onTap: () => context.go(q.$4),
                child: Row(
                  children: [
                    Icon(q.$1, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(q.$2, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(q.$3, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ).enter(i + 2),
          ],
        ),
      ],
    );
  }
}
