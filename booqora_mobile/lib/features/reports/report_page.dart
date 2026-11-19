import 'dart:math' as math;

import 'package:flutter/material.dart' hide Thumb;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/pricing.dart';
import '../../data/schema.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/mobile.dart';
import '../../widgets/side_panel.dart';
import '../customers/customer_kit.dart';
import 'report_kit.dart';
import 'reports_page.dart';

typedef _R = Map<String, dynamic>;

const _types = {'performance', 'products', 'availability', 'fulfillment', 'customers', 'coupons', 'activity'};

/// Computed, phone-friendly report output.
class _Out {
  final List<MiniMetric> metrics;
  final List<Widget> extras;
  final List<Widget> filters;
  final String listTitle;
  final int count;
  final Widget Function(int i) item;
  final Widget empty;
  final List<String> csvHeaders;
  final List<List<Object?>> csvRows;
  const _Out({
    required this.metrics,
    this.extras = const [],
    this.filters = const [],
    required this.listTitle,
    required this.count,
    required this.item,
    required this.empty,
    required this.csvHeaders,
    required this.csvRows,
  });
}

class ReportPage extends StatefulWidget {
  final String type;
  const ReportPage({super.key, required this.type});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  String _preset = 'month';
  DateTimeRange? _custom;
  String _q = '';
  int _tab = 0;
  String _entity = 'all';
  late Map<String, Stream<List<Doc>>> _streams = _streamsFor(widget.type);

  Map<String, Stream<List<Doc>>> _streamsFor(String type) {
    switch (type) {
      case 'performance':
      case 'fulfillment':
        return {'orders': Db.watch(C.orders)};
      case 'products':
        return {'orders': Db.watch(C.orders), 'products': Db.watch(C.products)};
      case 'availability':
        return {'orders': Db.watch(C.orders), 'products': Db.watch(C.products), 'downtimes': Db.watch(C.downtimes)};
      case 'customers':
        return {'orders': Db.watch(C.orders), 'customers': Db.watch(C.customers)};
      case 'coupons':
        return {'orders': Db.watch(C.orders), 'coupons': Db.watch(C.coupons)};
      case 'activity':
        return {'activity': Db.watch(C.activity, limit: 1000)};
    }
    return {};
  }

  // ---------------------------------------------------------------- period
  DateTimeRange? get _period {
    final now = DateTime.now();
    switch (_preset) {
      case 'week':
        final s = dayOf(now).subtract(Duration(days: now.weekday - 1));
        return DateTimeRange(start: s, end: s.add(const Duration(days: 7)));
      case 'month':
        return DateTimeRange(start: DateTime(now.year, now.month), end: DateTime(now.year, now.month + 1));
      case 'last':
        return DateTimeRange(start: DateTime(now.year, now.month - 1), end: DateTime(now.year, now.month));
      case 'year':
        return DateTimeRange(start: DateTime(now.year), end: DateTime(now.year + 1));
      case 'custom':
        return _custom;
      default:
        return null;
    }
  }

  String get _periodLabel {
    final p = _period;
    if (p == null) return 'All time';
    return '${Fmt.date(p.start)} – ${Fmt.date(p.end.subtract(const Duration(days: 1)))}';
  }

  Future<void> _pickPeriod(String v) async {
    if (v != 'custom') {
      setState(() => _preset = v);
      return;
    }
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _custom == null ? null : DateTimeRange(start: _custom!.start, end: _custom!.end.subtract(const Duration(days: 1))),
      helpText: 'Report period',
    );
    if (r == null || !mounted) return;
    setState(() {
      _custom = DateTimeRange(start: dayOf(r.start), end: dayOf(r.end).add(const Duration(days: 1)));
      _preset = 'custom';
    });
  }

  bool get _searchable => const {'products', 'customers', 'activity', 'coupons', 'fulfillment', 'availability'}.contains(widget.type);

  bool _match(List<String> fields) {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return true;
    return fields.any((f) => f.toLowerCase().contains(q));
  }

  Future<void> _export(_Out out) async {
    HapticFeedback.lightImpact();
    if (out.csvRows.isEmpty) {
      toast(context, 'Nothing to export for this period', error: true);
      return;
    }
    try {
      await exportCsv('${widget.type}-report', out.csvHeaders, out.csvRows);
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  // ---------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    final title = reportTitle(widget.type);
    if (!_types.contains(widget.type)) {
      return MPage(title: 'Report not found', slivers: [
        SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.query_stats_rounded,
            title: 'This report doesn’t exist',
            message: 'Pick one from the reports overview.',
            actionLabel: 'Back to reports',
            onAction: () => context.pop(),
          ),
        ),
      ]);
    }
    final periodChips = ChoiceChipsBar<String>(
      value: _preset,
      options: [
        ('week', 'This week'),
        ('month', 'This month'),
        ('last', 'Last month'),
        ('year', 'This year'),
        ('all', 'All time'),
        ('custom', _preset == 'custom' && _custom != null ? '${Fmt.shortDate(_custom!.start)} – ${Fmt.shortDate(_custom!.end.subtract(const Duration(days: 1)))}' : 'Custom…'),
      ],
      onChanged: _pickPeriod,
    );
    return MultiStream(
      streams: _streams,
      loading: MPage(title: title, header: periodChips, headerHeight: 56, slivers: const [SliverToBoxAdapter(child: LoadingView())]),
      builder: (context, data) {
        final out = _compute(data);
        return MPage(
          title: title,
          subtitle: _periodLabel,
          header: periodChips,
          headerHeight: 56,
          onRefresh: () async {
            HapticFeedback.mediumImpact();
            await Future<void>.delayed(const Duration(milliseconds: 600));
            if (mounted) setState(() => _streams = _streamsFor(widget.type));
          },
          actions: [IconButton(tooltip: 'Export CSV', icon: const Icon(Icons.ios_share_rounded), onPressed: () => _export(out))],
          slivers: [
            SPad(_MetricGrid(items: out.metrics), padding: const EdgeInsets.fromLTRB(16, 6, 16, 6)),
            for (var i = 0; i < out.extras.length; i++) SPad(out.extras[i].enter(i + 1), padding: const EdgeInsets.fromLTRB(16, 10, 16, 0)),
            for (final f in out.filters) SPad(f, padding: const EdgeInsets.fromLTRB(16, 14, 16, 0)),
            if (_searchable)
              SPad(MSearch(hint: 'Search ${out.listTitle.toLowerCase()}', onChanged: (v) => setState(() => _q = v)),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0)),
            SPad(
              SectionLabel(out.listTitle, trailing: Text('${out.count}', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700))),
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            ),
            if (out.count == 0) SPad(out.empty) else SList(count: out.count, builder: (_, i) => out.item(i)),
          ],
        );
      },
    );
  }

  _Out _compute(Map<String, List<Doc>> d) {
    switch (widget.type) {
      case 'performance':
        return _performance(d['orders']!);
      case 'products':
        return _products(d['orders']!, d['products']!);
      case 'availability':
        return _availability(d['orders']!, d['products']!, d['downtimes']!);
      case 'fulfillment':
        return _fulfillment(d['orders']!);
      case 'customers':
        return _customers(d['orders']!, d['customers']!);
      case 'coupons':
        return _coupons(d['orders']!, d['coupons']!);
      default:
        return _activity(d['activity']!);
    }
  }

  Widget _empty(String title, String message) => Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
        child: EmptyState(icon: Icons.query_stats_rounded, title: title, message: message, compact: true),
      );

  DateTimeRange _spanOf(List<DateTime> dates) {
    final now = DateTime.now();
    final end = dayOf(now).add(const Duration(days: 1));
    if (dates.isEmpty) return DateTimeRange(start: end.subtract(const Duration(days: 30)), end: end);
    final first = dates.reduce((a, b) => a.isBefore(b) ? a : b);
    var start = dayOf(first);
    if (end.difference(start).inDays < 7) start = end.subtract(const Duration(days: 7));
    return DateTimeRange(start: start, end: end);
  }

  void _go(String route) {
    HapticFeedback.selectionClick();
    context.push(route);
  }

  // ---------------------------------------------------------------- performance
  _Out _performance(List<Doc> all) {
    final period = _period;
    final inPeriod = all.where((o) => inRange(o.created, period)).toList();
    final valid = inPeriod.where(isRevenueOrder).toList();
    final revenue = valid.fold<num>(0, (a, o) => a + o.n('total'));
    final items = valid.fold<num>(0, (a, o) => a + orderItems(o));
    final deposit = inPeriod.where((o) => Pricing.holding.contains(o.s('status'))).fold<num>(0, (a, o) => a + o.n('deposit'));
    final aov = valid.isEmpty ? 0 : revenue / valid.length;

    final range = period ?? _spanOf(all.map((o) => o.created).toList());
    final (labels, revVals) = bucketize(valid, range, (o) => o.created, (o) => o.n('total'));
    final (_, cntVals) = bucketize(valid, range, (o) => o.created, (_) => 1);

    final statusCounts = <String, int>{};
    for (final o in inPeriod) {
      statusCounts[o.s('status', 'draft')] = (statusCounts[o.s('status', 'draft')] ?? 0) + 1;
    }
    final rows = <_R>[
      for (var i = labels.length - 1; i >= 0; i--)
        if (cntVals[i] > 0) {'label': labels[i], 'orders': cntVals[i], 'revenue': revVals[i]},
    ];
    final maxRev = rows.isEmpty ? 1 : rows.map((r) => r['revenue'] as num).reduce(math.max);

    return _Out(
      metrics: [
        MiniMetric(label: 'Revenue', value: revenue, format: Fmt.compactMoney, icon: Icons.payments_outlined),
        MiniMetric(label: 'Orders', value: valid.length, format: Fmt.integer, icon: Icons.receipt_long_outlined, color: AppColors.primaryDeep),
        MiniMetric(label: 'Avg. order', value: aov, format: Fmt.compactMoney, icon: Icons.analytics_outlined, color: AppColors.info),
        MiniMetric(label: 'Items rented', value: items, format: Fmt.integer, icon: Icons.inventory_2_outlined, color: AppColors.success),
        MiniMetric(label: 'Deposit held', value: deposit, format: Fmt.compactMoney, icon: Icons.account_balance_wallet_outlined, color: AppColors.warning),
      ],
      extras: [
        ChartCard(
          title: 'Revenue',
          subtitle: 'Excludes draft and canceled orders',
          icon: Icons.bar_chart_rounded,
          child: BucketBarChart(labels: labels, values: revVals, format: Fmt.money),
        ),
        ChartCard(
          title: 'Orders',
          subtitle: 'Number of orders created',
          icon: Icons.show_chart_rounded,
          child: TrendLineChart(labels: labels, values: cntVals, format: (v) => '${Fmt.integer(v)} orders'),
        ),
        ChartCard(title: 'Orders by status', icon: Icons.donut_large_rounded, child: statusDonut(statusCounts)),
      ],
      listTitle: 'Breakdown',
      count: rows.length,
      item: (i) {
        final r = rows[i];
        final rev = r['revenue'] as num;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(r['label'] as String, style: const TextStyle(fontWeight: FontWeight.w700))),
              Text(Fmt.money(rev), style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 4),
            Text('${Fmt.integer(r['orders'] as num)} order${r['orders'] == 1 ? '' : 's'}', style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
            const SizedBox(height: 8),
            _Bar(value: maxRev <= 0 ? 0 : rev / maxRev),
          ]),
        );
      },
      empty: _empty('No orders in this period', 'Orders you create will appear here broken down by day.'),
      csvHeaders: ['Period', 'Orders', 'Revenue'],
      csvRows: [for (final r in rows.reversed) [r['label'], r['orders'], r['revenue']]],
    );
  }

  // ---------------------------------------------------------------- products
  _Out _products(List<Doc> orders, List<Doc> products) {
    const kinds = ['rental', 'sale', 'service'];
    final kind = kinds[_tab];
    final valid = orders.where((o) => isRevenueOrder(o) && inRange(o.d('startsAt') ?? o.created, _period)).toList();
    final stats = <String, _R>{};
    for (final o in valid) {
      final s = o.d('startsAt'), e = o.d('stopsAt');
      final hours = (s != null && e != null && e.isAfter(s)) ? e.difference(s).inMinutes / 60 : 0;
      final seen = <String>{};
      for (final l in o.maps('lines')) {
        final pid = l['productId'] as String?;
        if (pid == null) continue;
        final st = stats.putIfAbsent(pid, () => {'times': 0, 'units': 0, 'hours': 0, 'revenue': 0});
        final qty = (l['qty'] as num?) ?? 0;
        if (seen.add(pid)) st['times'] = (st['times'] as num) + 1;
        st['units'] = (st['units'] as num) + qty;
        st['hours'] = (st['hours'] as num) + hours * qty;
        st['revenue'] = (st['revenue'] as num) + ((l['total'] as num?) ?? ((l['unitPrice'] as num?) ?? 0) * qty);
      }
    }
    final counts = {for (final k in kinds) k: products.where((p) => p.s('type', 'rental') == k).length};
    final rows = <_R>[];
    for (final p in products) {
      if (p.s('type', 'rental') != kind) continue;
      if (!_match([p.s('name'), p.s('sku')])) continue;
      final st = stats[p.id] ?? const {'times': 0, 'units': 0, 'hours': 0, 'revenue': 0};
      final units = st['units'] as num;
      final cost = p.n('purchaseCost') * (kind == 'rental' ? math.max(p.i('quantity'), 1) : units);
      final revenue = st['revenue'] as num;
      rows.add({
        'id': p.id,
        'name': p.s('name'),
        'image': p.l<String>('imageUrls').firstOrNull,
        'added': p.created,
        'qty': p.i('quantity'),
        'times': st['times'],
        'units': units,
        'hours': st['hours'],
        'revenue': revenue,
        'cost': cost,
        'roi': cost > 0 ? (revenue - cost) / cost * 100 : null,
      });
    }
    rows.sort((a, b) => (b['revenue'] as num).compareTo(a['revenue'] as num));
    num sum(String k) => rows.fold<num>(0, (a, r) => a + (r[k] as num));
    final label = kind == 'rental' ? 'Times rented' : 'Times sold';
    final top = rows.where((r) => (r['revenue'] as num) > 0).take(5).toList();
    return _Out(
      metrics: [
        MiniMetric(label: 'Products', value: rows.length, format: Fmt.integer, icon: Icons.inventory_2_outlined),
        MiniMetric(label: label, value: sum('times'), format: Fmt.integer, icon: Icons.repeat_rounded, color: AppColors.primaryDeep),
        MiniMetric(label: kind == 'rental' ? 'Units rented' : 'Units', value: sum('units'), format: Fmt.integer, icon: Icons.layers_outlined, color: AppColors.info),
        MiniMetric(label: 'Revenue', value: sum('revenue'), format: Fmt.compactMoney, icon: Icons.payments_outlined, color: AppColors.success),
      ],
      filters: [
        ChoiceChipsBar<int>(
          value: _tab,
          counts: {for (var i = 0; i < kinds.length; i++) i: counts[kinds[i]]!},
          options: const [(0, 'Rental products'), (1, 'Sales items'), (2, 'Services')],
          onChanged: (i) => setState(() => _tab = i),
        ),
      ],
      extras: [
        ChartCard(
          title: 'Top earners',
          subtitle: 'By revenue in this period',
          icon: Icons.emoji_events_outlined,
          child: top.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('No bookings in this period yet.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                )
              : RankBars(
                  key: ValueKey('top-$_tab'),
                  format: Fmt.compactMoney,
                  items: [for (final r in top) (r['name'] as String, r['revenue'] as num, Thumb(url: r['image'] as String?, size: 36))],
                ),
        ),
      ],
      listTitle: 'Products',
      count: rows.length,
      item: (i) {
        final r = rows[i];
        final roi = r['roi'] as num?;
        return MTile(
          onTap: () => _go('/inventory/products/${r['id']}'),
          leading: Thumb(url: r['image'] as String?, size: 46),
          title: r['name'] as String,
          subtitle: '${Fmt.integer(r['times'] as num)}× · ${Fmt.integer(r['units'] as num)} units'
              '${kind == 'rental' ? ' · ${Fmt.integer(r['hours'] as num)} h' : ''} · stock ${Fmt.integer(r['qty'] as num)}',
          trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            Text(Fmt.compactMoney(r['revenue'] as num), style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(
              roi == null ? 'ROI —' : 'ROI ${roi.toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: roi == null ? AppColors.muted : (roi >= 0 ? AppColors.success : AppColors.danger)),
            ),
          ]),
        );
      },
      empty: _empty('No products here yet', 'Add products in Inventory to see how they perform.'),
      csvHeaders: ['Product', 'Added', 'Quantity', label, 'Units rented', 'Rent duration (hours)', 'Revenue', 'Purchase cost', 'ROI %'],
      csvRows: [
        for (final r in rows)
          [
            r['name'],
            Fmt.date(r['added'] as DateTime),
            r['qty'],
            r['times'],
            r['units'],
            (r['hours'] as num).toStringAsFixed(1),
            (r['revenue'] as num).toStringAsFixed(2),
            (r['cost'] as num).toStringAsFixed(2),
            r['roi'] == null ? '' : (r['roi'] as num).toStringAsFixed(1),
          ],
      ],
    );
  }

  // ---------------------------------------------------------------- availability
  _Out _availability(List<Doc> orders, List<Doc> products, List<Doc> downtimes) {
    final now = DateTime.now();
    final range = _period ?? DateTimeRange(start: dayOf(now), end: dayOf(now).add(const Duration(days: 30)));
    final rows = <_R>[];
    for (final p in products) {
      if (p.s('type', 'rental') != 'rental' || p.s('status') == 'archived') continue;
      if (!_match([p.s('name'), p.s('sku')])) continue;
      var reserved = 0;
      for (final o in orders) {
        if (!Pricing.holding.contains(o.s('status'))) continue;
        final s = o.d('startsAt'), e = o.d('stopsAt');
        if (s == null || e == null || !Pricing.overlaps(range.start, range.end, s, e)) continue;
        for (final l in o.maps('lines')) {
          if (l['productId'] == p.id) reserved += ((l['qty'] as num?) ?? 0).toInt();
        }
      }
      var down = 0;
      for (final dt in downtimes) {
        if (dt.s('productId') != p.id || !const {'scheduled', 'started'}.contains(dt.s('status'))) continue;
        final s = dt.d('startsAt'), e = dt.d('endsAt') ?? DateTime(2100);
        if (s != null && Pricing.overlaps(range.start, range.end, s, e)) down += dt.i('quantity', 1);
      }
      final available = Pricing.available(p, range.start, range.end, orders, downtimes);
      final status = available < 0 ? 'shortage' : (available == 0 ? 'full' : 'available');
      rows.add({
        'id': p.id,
        'name': p.s('name'),
        'image': p.l<String>('imageUrls').firstOrNull,
        'qty': p.i('quantity'),
        'reserved': reserved,
        'down': down,
        'available': available,
        'status': status,
      });
    }
    rows.sort((a, b) => (a['available'] as int).compareTo(b['available'] as int));
    final shortages = rows.where((r) => r['status'] == 'shortage').length;
    final full = rows.where((r) => r['status'] == 'full').length;
    num sum(String k) => rows.fold<num>(0, (a, r) => a + (r[k] as num));
    return _Out(
      metrics: [
        MiniMetric(label: 'Rental products', value: rows.length, format: Fmt.integer, icon: Icons.inventory_2_outlined),
        MiniMetric(label: 'Units in stock', value: sum('qty'), format: Fmt.integer, icon: Icons.warehouse_outlined, color: AppColors.primaryDeep),
        MiniMetric(label: 'Units reserved', value: sum('reserved'), format: Fmt.integer, icon: Icons.event_busy_outlined, color: AppColors.info),
        MiniMetric(
          label: 'Shortages',
          value: shortages,
          format: Fmt.integer,
          icon: Icons.warning_amber_rounded,
          color: shortages > 0 ? AppColors.danger : AppColors.success,
        ),
      ],
      extras: [
        if (shortages > 0)
          InfoBanner(
            '$shortages product${shortages == 1 ? ' is' : 's are'} overbooked in this period. Add stock or adjust the affected orders.',
            tone: Tone.warning,
            icon: Icons.warning_amber_rounded,
          ),
        ChartCard(
          title: 'Stock status',
          subtitle: _period == null ? 'Next 30 days' : 'Selected period',
          icon: Icons.donut_large_rounded,
          child: DonutChart(
            centerCaption: 'products',
            emptyText: 'No rental products yet',
            entries: [
              ('Available', rows.length - shortages - full, AppColors.success),
              ('Fully booked', full, AppColors.warning),
              ('Shortage', shortages, AppColors.danger),
            ],
          ),
        ),
      ],
      listTitle: 'Products',
      count: rows.length,
      item: (i) {
        final r = rows[i];
        final qty = r['qty'] as int, reserved = r['reserved'] as int, a = r['available'] as int;
        final s = r['status'] as String;
        final used = qty <= 0 ? (reserved > 0 ? 1.0 : 0.0) : ((reserved + (r['down'] as int)) / qty).clamp(0.0, 1.0);
        return MTile(
          onTap: () => _go('/inventory/products/${r['id']}'),
          leading: Thumb(url: r['image'] as String?, size: 46),
          title: r['name'] as String,
          subtitle: '$reserved reserved · ${r['down']} in downtime · $qty in stock',
          trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            Text(Fmt.integer(a), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: a < 0 ? AppColors.danger : AppColors.ink)),
            const Text('available', style: TextStyle(fontSize: 11, color: AppColors.muted)),
          ]),
          footer: Row(children: [
            Expanded(child: _Bar(value: used.toDouble(), color: s == 'shortage' ? AppColors.danger : (s == 'full' ? AppColors.warning : AppColors.primary))),
            const SizedBox(width: 10),
            StatusPill(s == 'full' ? 'late' : s, label: s == 'full' ? 'Fully booked' : (s == 'shortage' ? 'Shortage' : 'Available')),
          ]),
        );
      },
      empty: _empty('No rental products', 'Add rental products in Inventory to track their availability.'),
      csvHeaders: ['Product', 'Quantity', 'Reserved', 'Downtime', 'Available', 'Shortage'],
      csvRows: [
        for (final r in rows) [r['name'], r['qty'], r['reserved'], r['down'], r['available'], r['status'] == 'shortage' ? 'Yes' : 'No'],
      ],
    );
  }

  // ---------------------------------------------------------------- fulfillment
  _Out _fulfillment(List<Doc> orders) {
    final period = _period;
    final out = orders.where((o) => isRevenueOrder(o) && inRange(o.d('startsAt'), period)).toList();
    final rows = <_R>[];
    for (final o in out) {
      final lines = o.maps('lines');
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i];
        final r = {
          'orderId': o.id,
          'date': o.d('startsAt'),
          'number': o.i('number'),
          'customer': o.s('customerName').isEmpty ? 'Walk-in customer' : o.s('customerName'),
          'product': (l['name'] ?? '').toString(),
          'image': l['imageUrl'] as String?,
          'qty': (l['qty'] as num?) ?? 0,
          'status': o.s('status'),
          'fulfillment': o.s('fulfillment', 'pickup'),
        };
        if (_match([r['customer'] as String, r['product'] as String, '#${r['number']}'])) rows.add(r);
      }
    }
    rows.sort((a, b) => (a['date'] as DateTime? ?? DateTime(2000)).compareTo(b['date'] as DateTime? ?? DateTime(2000)));
    final pending = out.where((o) => o.s('status') == 'reserved').length;
    final range = period ?? _spanOf(out.map((o) => o.d('startsAt')).whereType<DateTime>().toList());
    final (labels, units) = bucketize(out, range, (o) => o.d('startsAt'), orderItems);
    return _Out(
      metrics: [
        MiniMetric(label: 'Orders going out', value: out.length, format: Fmt.integer, icon: Icons.local_shipping_outlined),
        MiniMetric(label: 'Lines', value: rows.length, format: Fmt.integer, icon: Icons.list_alt_rounded, color: AppColors.primaryDeep),
        MiniMetric(label: 'Units', value: rows.fold<num>(0, (a, r) => a + (r['qty'] as num)), format: Fmt.integer, icon: Icons.layers_outlined, color: AppColors.info),
        MiniMetric(label: 'Awaiting pickup', value: pending, format: Fmt.integer, icon: Icons.schedule_rounded, color: AppColors.warning),
      ],
      extras: [
        ChartCard(
          title: 'Units going out',
          subtitle: 'By pickup date',
          icon: Icons.bar_chart_rounded,
          child: BucketBarChart(labels: labels, values: units, format: (v) => '${Fmt.integer(v)} units', axisFormat: Fmt.integer, height: 190),
        ),
      ],
      listTitle: 'Pick list',
      count: rows.length,
      item: (i) {
        final r = rows[i];
        final d = r['date'] as DateTime?;
        final newDay = i == 0 || dayOf(rows[i - 1]['date'] as DateTime? ?? DateTime(2000)) != dayOf(d ?? DateTime(2000));
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (newDay)
            Padding(
              padding: EdgeInsets.only(bottom: 8, top: i == 0 ? 0 : 8, left: 4),
              child: Text(d == null ? 'No date' : Fmt.date(d),
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 13)),
            ),
          MTile(
            onTap: () => _go('/orders/${r['orderId']}'),
            leading: Stack(clipBehavior: Clip.none, children: [
              Thumb(url: r['image'] as String?, size: 46),
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(10)),
                  child: Text('×${Fmt.integer(r['qty'] as num)}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ),
            ]),
            title: (r['product'] as String).isEmpty ? 'Item' : r['product'] as String,
            subtitle: '#${r['number']} · ${r['customer']} · ${Fmt.time(d)} · ${Fmt.label(r['fulfillment'] as String)}',
            trailing: StatusPill(r['status'] as String),
          ),
        ]);
      },
      empty: _empty('Nothing going out', 'No reserved or started orders have a pickup date in this period.'),
      csvHeaders: ['Pickup date', 'Order #', 'Customer', 'Product', 'Qty', 'Method', 'Status'],
      csvRows: [
        for (final r in rows) [Fmt.dateTime(r['date'] as DateTime?), r['number'], r['customer'], r['product'], r['qty'], r['fulfillment'], r['status']],
      ],
    );
  }

  // ---------------------------------------------------------------- customers
  _Out _customers(List<Doc> orders, List<Doc> rawCustomers) {
    // Balances are computed live from orders, like the customers page.
    final customers = customersWithStats(rawCustomers, orders);
    final valid = orders.where((o) => isRevenueOrder(o) && inRange(o.created, _period)).toList();
    final revenue = valid.fold<num>(0, (a, o) => a + o.n('total'));
    final by = <String, (int, num)>{};
    for (final o in valid) {
      final id = o.s('customerId');
      if (id.isEmpty) continue;
      final cur = by[id] ?? (0, 0);
      by[id] = (cur.$1 + 1, cur.$2 + o.n('total'));
    }
    final newCount = customers.where((c) => inRange(c.created, _period)).length;
    final balance = customers.fold<num>(0, (a, c) => a + c.n('balanceDue'));
    final rows = <_R>[];
    for (final c in customers) {
      final st = by[c.id] ?? (0, 0);
      if (_period != null && st.$1 == 0 && !inRange(c.created, _period)) continue;
      if (!_match([c.s('name'), c.s('email'), c.s('phone')])) continue;
      rows.add({
        'id': c.id,
        'number': c.i('number'),
        'name': c.s('name'),
        'email': c.s('email'),
        'discount': c.n('discountPercent'),
        'balance': c.n('balanceDue'),
        'orders': st.$1,
        'revenue': st.$2,
        'share': revenue > 0 ? st.$2 / revenue * 100 : 0,
        'aov': st.$1 > 0 ? st.$2 / st.$1 : 0,
      });
    }
    rows.sort((a, b) => (b['revenue'] as num).compareTo(a['revenue'] as num));
    final top = rows.where((r) => (r['revenue'] as num) > 0).take(5).toList();
    final topSum = top.fold<num>(0, (a, r) => a + (r['revenue'] as num));
    return _Out(
      metrics: [
        MiniMetric(label: 'New customers', value: newCount, format: Fmt.integer, icon: Icons.person_add_alt_1_outlined),
        MiniMetric(label: 'Revenue', value: revenue, format: Fmt.compactMoney, icon: Icons.payments_outlined, color: AppColors.success),
        MiniMetric(
            label: 'Avg. order', value: valid.isEmpty ? 0 : revenue / valid.length, format: Fmt.compactMoney, icon: Icons.analytics_outlined, color: AppColors.info),
        MiniMetric(label: 'Balance due', value: balance, format: Fmt.compactMoney, icon: Icons.account_balance_wallet_outlined, color: AppColors.danger),
      ],
      extras: [
        ChartCard(
          title: 'Revenue share',
          subtitle: 'Top customers in this period',
          icon: Icons.pie_chart_outline_rounded,
          child: DonutChart(
            centerCaption: 'revenue',
            format: Fmt.compactMoney,
            emptyText: 'No customer revenue in this period',
            entries: [
              for (var i = 0; i < top.length; i++) ((top[i]['name'] as String).split(' ').first, top[i]['revenue'] as num, chartPalette[i]),
              if (revenue - topSum > 0) ('Others', revenue - topSum, AppColors.border),
            ],
          ),
        ),
      ],
      listTitle: 'Customers',
      count: rows.length,
      item: (i) {
        final r = rows[i];
        final b = r['balance'] as num;
        return MTile(
          onTap: () => _go('/customers/${r['id']}'),
          leading: Avatar(r['name'] as String, size: 44),
          title: r['name'] as String,
          subtitle: '${Fmt.integer(r['orders'] as num)} orders · avg ${Fmt.compactMoney(r['aov'] as num)}'
              '${(r['discount'] as num) > 0 ? ' · ${Fmt.integer(r['discount'] as num)}% discount' : ''}',
          trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            Text(Fmt.compactMoney(r['revenue'] as num), style: const TextStyle(fontWeight: FontWeight.w800)),
            Text('${(r['share'] as num).toStringAsFixed(1)}% share', style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
          ]),
          footer: b > 0
              ? Row(children: [
                  const Spacer(),
                  StatusPill('payment_due', label: '${Fmt.money(b)} due'),
                ])
              : null,
        );
      },
      empty: _empty('No customer activity', 'Customers who order or sign up in this period will appear here.'),
      csvHeaders: ['#', 'Name', 'Email', 'Discount %', 'Balance due', 'Orders', 'Revenue', 'Revenue %', 'Avg. order value'],
      csvRows: [
        for (final r in rows)
          [
            r['number'],
            r['name'],
            r['email'],
            r['discount'],
            (r['balance'] as num).toStringAsFixed(2),
            r['orders'],
            (r['revenue'] as num).toStringAsFixed(2),
            (r['share'] as num).toStringAsFixed(1),
            (r['aov'] as num).toStringAsFixed(2),
          ],
      ],
    );
  }

  // ---------------------------------------------------------------- coupons
  _Out _coupons(List<Doc> orders, List<Doc> coupons) {
    final valid = orders.where((o) => isRevenueOrder(o) && inRange(o.created, _period) && o.s('couponCode').isNotEmpty).toList();
    final rows = <_R>[];
    for (final c in coupons) {
      final code = c.s('code').toUpperCase();
      if (!_match([code])) continue;
      final used = valid.where((o) => o.s('couponCode').toUpperCase() == code).toList();
      rows.add({
        'id': c.id,
        'code': code,
        'active': c.b('active'),
        'discountLabel': c.s('discountType') == 'fixed' ? Fmt.money(c.n('value')) : '${Fmt.integer(c.n('value'))}%',
        'uses': c.i('uses'),
        'orders': used.length,
        'discount': used.fold<num>(0, (a, o) => a + o.n('couponDiscount')),
        'revenue': used.fold<num>(0, (a, o) => a + o.n('total')),
      });
    }
    rows.sort((a, b) => (b['revenue'] as num).compareTo(a['revenue'] as num));
    num sum(String k) => rows.fold<num>(0, (a, r) => a + (r[k] as num));
    final top = rows.where((r) => (r['revenue'] as num) > 0).take(5).toList();
    return _Out(
      metrics: [
        MiniMetric(label: 'Active coupons', value: coupons.where((c) => c.b('active')).length, format: Fmt.integer, icon: Icons.confirmation_number_outlined),
        MiniMetric(label: 'Redemptions', value: sum('orders'), format: Fmt.integer, icon: Icons.redeem_rounded, color: AppColors.primaryDeep),
        MiniMetric(label: 'Discount given', value: sum('discount'), format: Fmt.compactMoney, icon: Icons.percent_rounded, color: AppColors.warning),
        MiniMetric(label: 'Revenue', value: sum('revenue'), format: Fmt.compactMoney, icon: Icons.payments_outlined, color: AppColors.success),
      ],
      extras: [
        ChartCard(
          title: 'Revenue by coupon',
          subtitle: 'Orders that used a code in this period',
          icon: Icons.leaderboard_outlined,
          child: top.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('No coupon redemptions in this period.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                )
              : RankBars(format: Fmt.compactMoney, items: [for (final r in top) (r['code'] as String, r['revenue'] as num, null)]),
        ),
      ],
      listTitle: 'Coupons',
      count: rows.length,
      item: (i) {
        final r = rows[i];
        return PressScale(
          onTap: () => _go('/coupons/${r['id']}'),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.lavender.withValues(alpha: 0.7)),
                  ),
                  child: Text(r['code'] as String,
                      style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, color: AppColors.primaryDeep, letterSpacing: 1)),
                ),
                const SizedBox(width: 8),
                Text(r['discountLabel'] as String, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.inkSoft)),
                const Spacer(),
                StatusPill(r['active'] == true ? 'active' : 'inactive'),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                _Kpi('Orders', Fmt.integer(r['orders'] as num)),
                _Kpi('Discount', Fmt.compactMoney(r['discount'] as num)),
                _Kpi('Revenue', Fmt.compactMoney(r['revenue'] as num)),
                _Kpi('All-time uses', Fmt.integer(r['uses'] as num)),
              ]),
            ]),
          ),
        );
      },
      empty: _empty('No coupons yet', 'Create coupons to track redemptions and their impact on revenue.'),
      csvHeaders: ['Code', 'Discount', 'Total uses', 'Orders in period', 'Discount given', 'Revenue', 'Status'],
      csvRows: [
        for (final r in rows)
          [
            r['code'],
            r['discountLabel'],
            r['uses'],
            r['orders'],
            (r['discount'] as num).toStringAsFixed(2),
            (r['revenue'] as num).toStringAsFixed(2),
            r['active'] == true ? 'Active' : 'Inactive',
          ],
      ],
    );
  }

  // ---------------------------------------------------------------- activity
  _Out _activity(List<Doc> all) {
    final period = _period;
    final inPeriod = all.where((a) => inRange(a.d('createdAt'), period)).toList();
    final counts = <String, int>{};
    for (final a in inPeriod) {
      counts[a.s('entity')] = (counts[a.s('entity')] ?? 0) + 1;
    }
    final entities = counts.keys.toList()..sort();
    String entityLabel(String e) => Fmt.label(e.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]!.toLowerCase()}'));
    final rows = inPeriod
        .where((a) => _entity == 'all' || a.s('entity') == _entity)
        .where((a) => _match([a.s('label'), a.s('actorName'), a.s('entity'), a.s('action')]))
        .toList();
    final actors = rows.map((a) => a.s('actorName')).toSet().length;
    final range = period ?? _spanOf(inPeriod.map((a) => a.created).toList());
    final (labels, perDay) = bucketize(rows, range, (a) => a.d('createdAt'), (_) => 1);
    return _Out(
      metrics: [
        MiniMetric(label: 'Events', value: rows.length, format: Fmt.integer, icon: Icons.history_rounded),
        MiniMetric(label: 'Team members', value: actors, format: Fmt.integer, icon: Icons.groups_outlined, color: AppColors.primaryDeep),
        MiniMetric(label: 'Created', value: rows.where((a) => a.s('action') == 'created').length, format: Fmt.integer, icon: Icons.add_circle_outline, color: AppColors.success),
        MiniMetric(label: 'Deleted', value: rows.where((a) => a.s('action') == 'deleted').length, format: Fmt.integer, icon: Icons.delete_outline, color: AppColors.danger),
      ],
      extras: [
        ChartCard(
          title: 'Activity over time',
          icon: Icons.show_chart_rounded,
          child: TrendLineChart(labels: labels, values: perDay, format: (v) => '${Fmt.integer(v)} events', color: const Color(0xFF0E7490), height: 160),
        ),
      ],
      filters: [
        if (entities.isNotEmpty)
          ChoiceChipsBar<String>(
            value: entities.contains(_entity) ? _entity : 'all',
            counts: {'all': inPeriod.length, ...counts},
            options: [('all', 'All records'), for (final e in entities) (e, entityLabel(e))],
            onChanged: (v) => setState(() => _entity = v),
          ),
      ],
      listTitle: 'Events',
      count: rows.length,
      item: (i) {
        final a = rows[i];
        final action = a.s('action');
        final color = switch (action) {
          'created' => AppColors.success,
          'deleted' => AppColors.danger,
          _ => AppColors.primary,
        };
        final icon = switch (action) {
          'created' => Icons.add_rounded,
          'deleted' => Icons.delete_outline_rounded,
          _ => Icons.edit_outlined,
        };
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Stack(clipBehavior: Clip.none, children: [
              Avatar(a.s('actorName', 'System'), size: 38),
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                  child: Icon(icon, size: 11, color: Colors.white),
                ),
              ),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: a.s('actorName', 'System'), style: const TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(text: ' $action ${entityLabel(a.s('entity')).toLowerCase().replaceAll(RegExp(r's$'), '')} '),
                    TextSpan(text: a.s('label'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                  style: const TextStyle(fontSize: 13.5, height: 1.35),
                ),
                const SizedBox(height: 3),
                Text(Fmt.dateTime(a.d('createdAt')), style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
              ]),
            ),
          ]),
        );
      },
      empty: _empty('No activity found', 'Changes made by your team will be recorded here.'),
      csvHeaders: ['When', 'User', 'Action', 'Record type', 'Record'],
      csvRows: [
        for (final a in rows) [Fmt.dateTime(a.d('createdAt')), a.s('actorName'), a.s('action'), a.s('entity'), a.s('label')],
      ],
    );
  }
}

/// Two-column grid of compact metrics; an odd last item spans the full width.
class _MetricGrid extends StatelessWidget {
  final List<MiniMetric> items;
  const _MetricGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth - 12) / 2;
      return Wrap(spacing: 12, runSpacing: 12, children: [
        for (var i = 0; i < items.length; i++)
          SizedBox(
            width: (i == items.length - 1 && items.length.isOdd) ? c.maxWidth : w,
            height: 96,
            child: items[i].pop(i),
          ),
      ]);
    });
  }
}

class _Bar extends StatelessWidget {
  final double value;
  final Color color;
  const _Bar({required this.value, this.color = AppColors.primary});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.clamp(0, 1)),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 6, backgroundColor: AppColors.primarySoft, color: color),
        ),
      );
}

class _Kpi extends StatelessWidget {
  final String label;
  final String value;
  const _Kpi(this.label, this.value);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          const SizedBox(height: 2),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        ]),
      );
}
