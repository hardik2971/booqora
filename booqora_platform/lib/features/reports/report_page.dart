import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart' hide Thumb;
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/pricing.dart';
import '../../data/schema.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/page.dart';
import '../../widgets/side_panel.dart';
import '../../widgets/table.dart';
import 'report_kit.dart';
import 'reports_page.dart';

typedef _R = Map<String, dynamic>;

const _types = {'performance', 'products', 'availability', 'fulfillment', 'customers', 'coupons', 'activity'};

class ReportPage extends StatefulWidget {
  final String type;
  const ReportPage({super.key, required this.type});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

/// Computed report output.
class _Out {
  final String subtitle;
  final List<Widget> metrics;
  final List<Widget> extras;
  final Widget table;
  final List<String> csvHeaders;
  final List<List<Object?>> csvRows;
  final List<Widget> filters;
  const _Out({
    required this.subtitle,
    required this.metrics,
    this.extras = const [],
    required this.table,
    required this.csvHeaders,
    required this.csvRows,
    this.filters = const [],
  });
}

class _ReportPageState extends State<ReportPage> {
  DateTimeRange? _period = DateRangeFacet.preset('month');
  Set<String> _entities = {};
  String _q = '';
  int _tab = 0;
  late final Map<String, Stream<List<Doc>>> _streams = _streamsFor(widget.type);

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

  String get _periodLabel {
    final p = _period;
    if (p == null) return 'All time';
    return '${Fmt.date(p.start)} – ${Fmt.date(p.end.subtract(const Duration(days: 1)))}';
  }

  bool get _searchable => const {'products', 'customers', 'activity', 'coupons', 'fulfillment'}.contains(widget.type);

  bool _match(List<String> fields) {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return true;
    return fields.any((f) => f.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    if (!_types.contains(widget.type)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeader(title: 'Report not found', breadcrumbs: [('Reports', '/reports')]),
          Expanded(
            child: EmptyState(
              icon: Icons.query_stats_rounded,
              title: 'This report doesn’t exist',
              message: 'The report you’re looking for isn’t available. Pick one from the reports overview.',
              actionLabel: 'Back to reports',
              onAction: () => context.go('/reports'),
            ),
          ),
        ],
      );
    }
    return MultiStream(
      streams: _streams,
      loading: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(title: reportTitle(widget.type), breadcrumbs: const [('Reports', '/reports')]),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 28), child: LoadingView()),
        ],
      ),
      builder: (context, data) {
        final out = _compute(data);
        return ListLayout(
          header: PageHeader(
            title: reportTitle(widget.type),
            subtitle: out.subtitle,
            breadcrumbs: const [('Reports', '/reports')],
            actions: [
              if (_searchable) SearchField(hint: 'Search…', width: 220, onChanged: (v) => setState(() => _q = v)),
              OutlinedButton.icon(
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Export CSV'),
                onPressed: () async {
                  try {
                    await exportCsv('${widget.type}-report', out.csvHeaders, out.csvRows);
                    if (context.mounted) toast(context, 'Report exported');
                  } catch (e) {
                    if (context.mounted) toast(context, friendlyError(e), error: true);
                  }
                },
              ),
            ],
          ),
          filters: [
            FilterSection(
              title: 'Period',
              child: DateRangeFacet(value: _period, onChanged: (v) => setState(() => _period = v)),
            ),
            ...out.filters,
          ],
          body: PageBody(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.muted),
                    const SizedBox(width: 6),
                    Text(
                      _periodLabel,
                      style: const TextStyle(color: AppColors.muted, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              _MetricGrid(children: out.metrics),
              const SizedBox(height: 20),
              for (var i = 0; i < out.extras.length; i++) ...[out.extras[i].enter(i + 2), const SizedBox(height: 20)],
              out.table.enter(out.extras.length + 2),
            ],
          ),
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

  Widget _emptyTable(String title, String message) => AppCard(
    padding: EdgeInsets.zero,
    child: EmptyState(icon: Icons.query_stats_rounded, title: title, message: message, compact: true),
  );

  // ---------------------------------------------------------------- performance
  _Out _performance(List<Doc> all) {
    final inPeriod = all.where((o) => inRange(o.created, _period)).toList();
    final valid = inPeriod.where(isRevenueOrder).toList();
    final revenue = valid.fold<num>(0, (a, o) => a + o.n('total'));
    final items = valid.fold<num>(0, (a, o) => a + _items(o));
    final deposit = inPeriod.where((o) => Pricing.holding.contains(o.s('status'))).fold<num>(0, (a, o) => a + o.n('deposit'));
    final aov = valid.isEmpty ? 0 : revenue / valid.length;

    final range = _period ?? _spanOf(all.map((o) => o.created).toList());
    final (labels, revVals) = bucketize(valid, range, (o) => o.created, (o) => o.n('total'));
    final (_, cntVals) = bucketize(valid, range, (o) => o.created, (_) => 1);

    final statusCounts = <String, int>{};
    for (final o in inPeriod) {
      statusCounts[o.s('status', 'draft')] = (statusCounts[o.s('status', 'draft')] ?? 0) + 1;
    }

    final rows = <_R>[
      for (var i = 0; i < labels.length; i++)
        if (cntVals[i] > 0) {'id': '$i', 'i': i, 'label': labels[i], 'orders': cntVals[i], 'revenue': revVals[i]},
    ];

    final bar = ChartCard(
      title: 'Revenue',
      subtitle: 'Excludes draft and canceled orders',
      child: BucketBarChart(labels: labels, values: revVals, format: Fmt.money),
    );
    final donut = ChartCard(
      title: 'Orders by status',
      child: _StatusDonut(counts: statusCounts),
    );

    return _Out(
      subtitle: 'Revenue, orders and deposits for the selected period.',
      metrics: [
        MetricCard(label: 'Revenue', value: revenue, icon: Icons.payments_outlined, format: Fmt.money, index: 0),
        MetricCard(label: 'Orders', value: valid.length, icon: Icons.receipt_long_outlined, color: AppColors.primaryDeep, index: 1),
        MetricCard(label: 'Avg. order value', value: aov, icon: Icons.analytics_outlined, format: Fmt.money, color: AppColors.info, index: 2),
        MetricCard(label: 'Items rented', value: items, icon: Icons.inventory_2_outlined, color: AppColors.success, index: 3),
        MetricCard(
          label: 'Deposit held',
          value: deposit,
          icon: Icons.account_balance_wallet_outlined,
          format: Fmt.money,
          color: AppColors.warning,
          hint: 'Deposits on reserved and started orders',
          index: 4,
        ),
      ],
      extras: [
        LayoutBuilder(
          builder: (context, c) {
            if (c.maxWidth < 900) return Column(children: [bar, const SizedBox(height: 20), donut]);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: bar),
                const SizedBox(width: 20),
                Expanded(flex: 2, child: SizedBox(height: 330, child: donut)),
              ],
            );
          },
        ),
      ],
      table: DataTableX<_R>(
        rows: rows,
        idOf: (r) => r['id'] as String,
        noun: 'periods',
        minWidth: 480,
        empty: _emptyTable('No orders in this period', 'Orders you create will appear here broken down by day.'),
        columns: [
          ColumnX(
            'Period',
            (r) => Text(r['label'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
            sort: (r) => r['i'] as int,
            flex: 2,
          ),
          ColumnX('Orders', (r) => Text(Fmt.integer(r['orders'] as num)), sort: (r) => r['orders'] as num, numeric: true),
          ColumnX('Revenue', (r) => Text(Fmt.money(r['revenue'] as num)), sort: (r) => r['revenue'] as num, numeric: true),
        ],
      ),
      csvHeaders: ['Period', 'Orders', 'Revenue'],
      csvRows: [
        for (final r in rows) [r['label'], r['orders'], r['revenue']],
      ],
    );
  }

  num _items(Doc o) {
    final ic = o.data['itemCount'];
    if (ic is num) return ic;
    return o.maps('lines').fold<num>(0, (a, l) => a + ((l['qty'] as num?) ?? 0));
  }

  DateTimeRange _spanOf(List<DateTime> dates) {
    final now = DateTime.now();
    final end = dayOf(now).add(const Duration(days: 1));
    if (dates.isEmpty) return DateTimeRange(start: end.subtract(const Duration(days: 30)), end: end);
    final first = dates.reduce((a, b) => a.isBefore(b) ? a : b);
    var start = dayOf(first);
    if (end.difference(start).inDays < 7) start = end.subtract(const Duration(days: 7));
    return DateTimeRange(start: start, end: end);
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

    return _Out(
      subtitle: 'How each product, sales item and service performed (by rental start date).',
      metrics: [
        MetricCard(label: 'Products', value: rows.length, icon: Icons.inventory_2_outlined, index: 0),
        MetricCard(label: label, value: sum('times'), icon: Icons.repeat_rounded, color: AppColors.primaryDeep, index: 1),
        MetricCard(
          label: kind == 'rental' ? 'Units rented' : 'Units',
          value: sum('units'),
          icon: Icons.layers_outlined,
          color: AppColors.info,
          index: 2,
        ),
        MetricCard(label: 'Revenue', value: sum('revenue'), icon: Icons.payments_outlined, format: Fmt.money, color: AppColors.success, index: 3),
      ],
      extras: [
        Align(
          alignment: Alignment.centerLeft,
          child: PillTabs(
            tabs: const ['Rental products', 'Sales items', 'Services'],
            badges: [for (final k in kinds) counts[k]],
            index: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
        ),
      ],
      table: DataTableX<_R>(
        key: ValueKey('products-$_tab'),
        rows: rows,
        idOf: (r) => r['id'] as String,
        noun: 'products',
        minWidth: 1100,
        onTap: (r) => context.go('/inventory/products/${r['id']}'),
        empty: _emptyTable('No products here yet', 'Add products in Inventory to see how they perform.'),
        columns: [
          ColumnX(
            'Product',
            (r) => CellText(r['name'] as String, leading: Thumb(url: r['image'] as String?, size: 34)),
            sort: (r) => (r['name'] as String).toLowerCase(),
            flex: 3,
          ),
          ColumnX('Added', (r) => Text(Fmt.date(r['added'] as DateTime)), sort: (r) => r['added'] as DateTime),
          ColumnX('Quantity', (r) => Text(Fmt.integer(r['qty'] as num)), sort: (r) => r['qty'] as num, numeric: true),
          ColumnX(label, (r) => Text(Fmt.integer(r['times'] as num)), sort: (r) => r['times'] as num, numeric: true),
          ColumnX('Units rented', (r) => Text(Fmt.integer(r['units'] as num)), sort: (r) => r['units'] as num, numeric: true),
          ColumnX('Rent duration (h)', (r) => Text(Fmt.integer(r['hours'] as num)), sort: (r) => r['hours'] as num, numeric: true),
          ColumnX(
            'Revenue',
            (r) => Text(Fmt.money(r['revenue'] as num), style: const TextStyle(fontWeight: FontWeight.w600)),
            sort: (r) => r['revenue'] as num,
            numeric: true,
          ),
          ColumnX('Purchase cost', (r) => Text(Fmt.money(r['cost'] as num)), sort: (r) => r['cost'] as num, numeric: true),
          ColumnX(
            'ROI %',
            (r) {
              final roi = r['roi'] as num?;
              if (roi == null) return const Text('—', style: TextStyle(color: AppColors.muted));
              return Text(
                '${roi.toStringAsFixed(1)}%',
                style: TextStyle(fontWeight: FontWeight.w600, color: roi >= 0 ? AppColors.success : AppColors.danger),
              );
            },
            sort: (r) => (r['roi'] as num?) ?? -1e12,
            numeric: true,
          ),
        ],
      ),
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
    num sum(String k) => rows.fold<num>(0, (a, r) => a + (r[k] as num));

    return _Out(
      subtitle: _period == null ? 'Stock versus reservations over the next 30 days.' : 'Stock versus reservations in the selected period.',
      metrics: [
        MetricCard(label: 'Rental products', value: rows.length, icon: Icons.inventory_2_outlined, index: 0),
        MetricCard(label: 'Units in stock', value: sum('qty'), icon: Icons.warehouse_outlined, color: AppColors.primaryDeep, index: 1),
        MetricCard(label: 'Units reserved', value: sum('reserved'), icon: Icons.event_busy_outlined, color: AppColors.info, index: 2),
        MetricCard(
          label: 'Shortages',
          value: shortages,
          icon: Icons.warning_amber_rounded,
          color: shortages > 0 ? AppColors.danger : AppColors.success,
          index: 3,
        ),
      ],
      extras: [
        if (shortages > 0)
          InfoBanner(
            '$shortages product${shortages == 1 ? ' is' : 's are'} overbooked in this period. Add stock or adjust the affected orders.',
            tone: Tone.warning,
            icon: Icons.warning_amber_rounded,
          ),
      ],
      table: DataTableX<_R>(
        rows: rows,
        idOf: (r) => r['id'] as String,
        noun: 'products',
        minWidth: 760,
        onTap: (r) => context.go('/inventory/products/${r['id']}'),
        empty: _emptyTable('No rental products', 'Add rental products in Inventory to track their availability.'),
        columns: [
          ColumnX(
            'Product',
            (r) => CellText(r['name'] as String, leading: Thumb(url: r['image'] as String?, size: 34)),
            sort: (r) => (r['name'] as String).toLowerCase(),
            flex: 3,
          ),
          ColumnX('Quantity', (r) => Text(Fmt.integer(r['qty'] as num)), sort: (r) => r['qty'] as num, numeric: true),
          ColumnX('Reserved', (r) => Text(Fmt.integer(r['reserved'] as num)), sort: (r) => r['reserved'] as num, numeric: true),
          ColumnX('Downtime', (r) => Text(Fmt.integer(r['down'] as num)), sort: (r) => r['down'] as num, numeric: true),
          ColumnX(
            'Available',
            (r) {
              final a = r['available'] as int;
              return Text(
                Fmt.integer(a),
                style: TextStyle(fontWeight: FontWeight.w700, color: a < 0 ? AppColors.danger : AppColors.ink),
              );
            },
            sort: (r) => r['available'] as int,
            numeric: true,
          ),
          ColumnX(
            'Status',
            (r) {
              final s = r['status'] as String;
              return StatusPill(s == 'full' ? 'late' : s, label: s == 'full' ? 'Fully booked' : (s == 'shortage' ? 'Shortage' : 'Available'));
            },
            sort: (r) => r['status'] as String,
            width: 140,
          ),
        ],
      ),
      csvHeaders: ['Product', 'Quantity', 'Reserved', 'Downtime', 'Available', 'Shortage'],
      csvRows: [
        for (final r in rows) [r['name'], r['qty'], r['reserved'], r['down'], r['available'], r['status'] == 'shortage' ? 'Yes' : 'No'],
      ],
    );
  }

  // ---------------------------------------------------------------- fulfillment
  _Out _fulfillment(List<Doc> orders) {
    final out = orders.where((o) => isRevenueOrder(o) && inRange(o.d('startsAt'), _period)).toList();
    final rows = <_R>[];
    for (final o in out) {
      final lines = o.maps('lines');
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i];
        final r = {
          'id': '${o.id}_${l['id'] ?? i}',
          'orderId': o.id,
          'date': o.d('startsAt'),
          'number': o.i('number'),
          'customer': o.s('customerName', 'Walk-in customer'),
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
    return _Out(
      subtitle: 'Every line going out in the period, in pickup order.',
      metrics: [
        MetricCard(label: 'Orders going out', value: out.length, icon: Icons.local_shipping_outlined, index: 0),
        MetricCard(label: 'Lines', value: rows.length, icon: Icons.list_alt_rounded, color: AppColors.primaryDeep, index: 1),
        MetricCard(
          label: 'Units',
          value: rows.fold<num>(0, (a, r) => a + (r['qty'] as num)),
          icon: Icons.layers_outlined,
          color: AppColors.info,
          index: 2,
        ),
        MetricCard(label: 'Awaiting pickup', value: pending, icon: Icons.schedule_rounded, color: AppColors.warning, index: 3),
      ],
      table: DataTableX<_R>(
        rows: rows,
        idOf: (r) => r['id'] as String,
        noun: 'lines',
        minWidth: 900,
        onTap: (r) => context.go('/orders/${r['orderId']}'),
        empty: _emptyTable('Nothing going out', 'No reserved or started orders have a pickup date in this period.'),
        columns: [
          ColumnX('Pickup', (r) => Text(Fmt.dateTime(r['date'] as DateTime?)), sort: (r) => r['date'] as DateTime? ?? DateTime(2000), flex: 2),
          ColumnX(
            'Order',
            (r) => Text(
              '#${r['number']}',
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
            sort: (r) => r['number'] as int,
            width: 90,
          ),
          ColumnX('Customer', (r) => Text(r['customer'] as String, overflow: TextOverflow.ellipsis), sort: (r) => r['customer'] as String, flex: 2),
          ColumnX(
            'Product',
            (r) => CellText(r['product'] as String, leading: Thumb(url: r['image'] as String?, size: 30)),
            sort: (r) => r['product'] as String,
            flex: 3,
          ),
          ColumnX(
            'Qty',
            (r) => Text(Fmt.integer(r['qty'] as num), style: const TextStyle(fontWeight: FontWeight.w700)),
            sort: (r) => r['qty'] as num,
            numeric: true,
            width: 70,
          ),
          ColumnX('Method', (r) => Text(Fmt.label(r['fulfillment'] as String)), width: 100),
          ColumnX('Status', (r) => StatusPill(r['status'] as String), sort: (r) => r['status'] as String, width: 120),
        ],
      ),
      csvHeaders: ['Pickup date', 'Order #', 'Customer', 'Product', 'Qty', 'Method', 'Status'],
      csvRows: [
        for (final r in rows)
          [Fmt.dateTime(r['date'] as DateTime?), r['number'], r['customer'], r['product'], r['qty'], r['fulfillment'], r['status']],
      ],
    );
  }

  // ---------------------------------------------------------------- customers
  _Out _customers(List<Doc> orders, List<Doc> customers) {
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
    return _Out(
      subtitle: 'Customer value, revenue share and outstanding balances.',
      metrics: [
        MetricCard(label: 'New customers', value: newCount, icon: Icons.person_add_alt_1_outlined, index: 0),
        MetricCard(label: 'Total revenue', value: revenue, icon: Icons.payments_outlined, format: Fmt.money, color: AppColors.success, index: 1),
        MetricCard(
          label: 'Avg. order value',
          value: valid.isEmpty ? 0 : revenue / valid.length,
          icon: Icons.analytics_outlined,
          format: Fmt.money,
          color: AppColors.info,
          index: 2,
        ),
        MetricCard(
          label: 'Balance due',
          value: balance,
          icon: Icons.account_balance_wallet_outlined,
          format: Fmt.money,
          color: AppColors.danger,
          hint: 'Outstanding across all customers',
          index: 3,
        ),
      ],
      table: DataTableX<_R>(
        rows: rows,
        idOf: (r) => r['id'] as String,
        noun: 'customers',
        minWidth: 1000,
        onTap: (r) => context.go('/customers/${r['id']}'),
        empty: _emptyTable('No customer activity', 'Customers who order or sign up in this period will appear here.'),
        columns: [
          ColumnX(
            '#',
            (r) => Text('${r['number']}', style: const TextStyle(color: AppColors.muted)),
            sort: (r) => r['number'] as int,
            width: 60,
          ),
          ColumnX(
            'Name',
            (r) => CellText(r['name'] as String, leading: Avatar(r['name'] as String, size: 30)),
            sort: (r) => (r['name'] as String).toLowerCase(),
            flex: 3,
          ),
          ColumnX('Email', (r) => Text(r['email'] as String, overflow: TextOverflow.ellipsis), flex: 3),
          ColumnX('Discount %', (r) => Text('${Fmt.integer(r['discount'] as num)}%'), sort: (r) => r['discount'] as num, numeric: true),
          ColumnX(
            'Balance due',
            (r) {
              final b = r['balance'] as num;
              return Text(
                Fmt.money(b),
                style: TextStyle(color: b > 0 ? AppColors.danger : AppColors.ink, fontWeight: b > 0 ? FontWeight.w600 : null),
              );
            },
            sort: (r) => r['balance'] as num,
            numeric: true,
            flex: 2,
          ),
          ColumnX('Orders', (r) => Text(Fmt.integer(r['orders'] as num)), sort: (r) => r['orders'] as num, numeric: true),
          ColumnX(
            'Revenue',
            (r) => Text(Fmt.money(r['revenue'] as num), style: const TextStyle(fontWeight: FontWeight.w600)),
            sort: (r) => r['revenue'] as num,
            numeric: true,
            flex: 2,
          ),
          ColumnX('Revenue %', (r) => Text('${(r['share'] as num).toStringAsFixed(1)}%'), sort: (r) => r['share'] as num, numeric: true),
          ColumnX('Avg. order value', (r) => Text(Fmt.money(r['aov'] as num)), sort: (r) => r['aov'] as num, numeric: true, flex: 2),
        ],
      ),
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
    return _Out(
      subtitle: 'Redemptions, discounts given and revenue per coupon code.',
      metrics: [
        MetricCard(label: 'Active coupons', value: coupons.where((c) => c.b('active')).length, icon: Icons.confirmation_number_outlined, index: 0),
        MetricCard(
          label: 'Redemptions',
          value: sum('orders'),
          icon: Icons.redeem_rounded,
          color: AppColors.primaryDeep,
          hint: 'Orders in this period that used a coupon',
          index: 1,
        ),
        MetricCard(
          label: 'Discount given',
          value: sum('discount'),
          icon: Icons.percent_rounded,
          format: Fmt.money,
          color: AppColors.warning,
          index: 2,
        ),
        MetricCard(label: 'Revenue', value: sum('revenue'), icon: Icons.payments_outlined, format: Fmt.money, color: AppColors.success, index: 3),
      ],
      table: DataTableX<_R>(
        rows: rows,
        idOf: (r) => r['id'] as String,
        noun: 'coupons',
        minWidth: 820,
        onTap: (r) => context.go('/coupons/${r['id']}'),
        empty: _emptyTable('No coupons yet', 'Create coupons to track redemptions and their impact on revenue.'),
        columns: [
          ColumnX('Code', (r) => _CodeChip(r['code'] as String), sort: (r) => r['code'] as String, flex: 2),
          ColumnX('Discount', (r) => Text(r['discountLabel'] as String)),
          ColumnX('Total uses', (r) => Text(Fmt.integer(r['uses'] as num)), sort: (r) => r['uses'] as num, numeric: true),
          ColumnX('Orders in period', (r) => Text(Fmt.integer(r['orders'] as num)), sort: (r) => r['orders'] as num, numeric: true),
          ColumnX('Discount given', (r) => Text(Fmt.money(r['discount'] as num)), sort: (r) => r['discount'] as num, numeric: true),
          ColumnX(
            'Revenue',
            (r) => Text(Fmt.money(r['revenue'] as num), style: const TextStyle(fontWeight: FontWeight.w600)),
            sort: (r) => r['revenue'] as num,
            numeric: true,
          ),
          ColumnX('Status', (r) => StatusPill(r['active'] == true ? 'active' : 'inactive'), width: 110),
        ],
      ),
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
    final inPeriod = all.where((a) => inRange(a.d('createdAt'), _period)).toList();
    final counts = <String, int>{};
    for (final a in inPeriod) {
      counts[a.s('entity')] = (counts[a.s('entity')] ?? 0) + 1;
    }
    final entities = counts.keys.toList()..sort();
    final rows = inPeriod
        .where((a) => _entities.isEmpty || _entities.contains(a.s('entity')))
        .where((a) => _match([a.s('label'), a.s('actorName'), a.s('entity'), a.s('action')]))
        .toList();
    final actors = rows.map((a) => a.s('actorName')).toSet().length;
    String pillStatus(String action) => switch (action) {
      'created' => 'active',
      'deleted' => 'canceled',
      'updated' => 'reserved',
      _ => action,
    };
    String entityLabel(String e) => Fmt.label(e.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]!.toLowerCase()}'));

    return _Out(
      subtitle: 'A complete audit trail of changes in your workspace.',
      filters: [
        if (entities.isNotEmpty)
          FilterSection(
            title: 'Record type',
            child: CheckFacet(
              options: entities,
              counts: counts,
              selected: _entities,
              labeler: entityLabel,
              onChanged: (s) => setState(() => _entities = s),
            ),
          ),
      ],
      metrics: [
        MetricCard(label: 'Events', value: rows.length, icon: Icons.history_rounded, index: 0),
        MetricCard(label: 'Team members', value: actors, icon: Icons.groups_outlined, color: AppColors.primaryDeep, index: 1),
        MetricCard(
          label: 'Created',
          value: rows.where((a) => a.s('action') == 'created').length,
          icon: Icons.add_circle_outline,
          color: AppColors.success,
          index: 2,
        ),
        MetricCard(
          label: 'Deleted',
          value: rows.where((a) => a.s('action') == 'deleted').length,
          icon: Icons.delete_outline,
          color: AppColors.danger,
          index: 3,
        ),
      ],
      table: DataTableX<Doc>(
        rows: rows,
        idOf: (a) => a.id,
        noun: 'events',
        minWidth: 820,
        pageSize: 50,
        empty: _emptyTable('No activity found', 'Changes made by your team will be recorded here.'),
        columns: [
          ColumnX('When', (a) => Text(Fmt.dateTime(a.d('createdAt'))), sort: (a) => a.created, flex: 2),
          ColumnX(
            'User',
            (a) => CellText(a.s('actorName', 'System'), leading: Avatar(a.s('actorName', 'System'), size: 28)),
            sort: (a) => a.s('actorName'),
            flex: 2,
          ),
          ColumnX('Action', (a) => StatusPill(pillStatus(a.s('action')), label: Fmt.label(a.s('action'))), sort: (a) => a.s('action'), width: 120),
          ColumnX('Record type', (a) => Text(entityLabel(a.s('entity'))), sort: (a) => a.s('entity'), flex: 2),
          ColumnX(
            'Record',
            (a) => Text(
              a.s('label', '—'),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            sort: (a) => a.s('label').toLowerCase(),
            flex: 3,
          ),
        ],
      ),
      csvHeaders: ['When', 'User', 'Action', 'Record type', 'Record'],
      csvRows: [
        for (final a in rows) [Fmt.dateTime(a.d('createdAt')), a.s('actorName'), a.s('action'), a.s('entity'), a.s('label')],
      ],
    );
  }
}

/// Responsive grid allowing up to five metric cards on one row.
class _MetricGrid extends StatelessWidget {
  final List<Widget> children;
  const _MetricGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth > 1100 ? children.length : (c.maxWidth > 820 ? math.min(3, children.length) : (c.maxWidth > 520 ? 2 : 1));
        final w = (c.maxWidth - (cols - 1) * 16) / cols;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [for (final ch in children) SizedBox(width: w, child: ch)],
        );
      },
    );
  }
}

class _StatusDonut extends StatefulWidget {
  final Map<String, int> counts;
  const _StatusDonut({required this.counts});

  @override
  State<_StatusDonut> createState() => _StatusDonutState();
}

class _StatusDonutState extends State<_StatusDonut> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final entries = OrderStatus.all.where((s) => (widget.counts[s] ?? 0) > 0).map((s) => MapEntry(s, widget.counts[s]!)).toList();
    final total = entries.fold<int>(0, (a, e) => a + e.value);
    if (total == 0) {
      return const SizedBox(
        height: 240,
        child: Center(
          child: Text('No orders in this period', style: TextStyle(color: AppColors.muted)),
        ),
      );
    }
    Color colorOf(String s) {
      final (fg, _) = statusColors(s);
      return s == 'reserved' ? AppColors.primary : (s == 'archived' ? AppColors.lavender : fg);
    }

    return Column(
      children: [
        SizedBox(
          height: 190,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 58,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, resp) {
                      setState(
                        () => _touched = (event.isInterestedForInteractions && resp?.touchedSection != null)
                            ? resp!.touchedSection!.touchedSectionIndex
                            : -1,
                      );
                    },
                  ),
                  sections: [
                    for (var i = 0; i < entries.length; i++)
                      PieChartSectionData(
                        value: entries[i].value.toDouble(),
                        color: colorOf(entries[i].key),
                        radius: _touched == i ? 30 : 24,
                        showTitle: false,
                      ),
                  ],
                ),
                duration: const Duration(milliseconds: 400),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(Fmt.integer(total), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const Text('orders', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final e in entries)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: colorOf(e.key), borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(width: 6),
                  Text('${Fmt.label(e.key)} · ${e.value}', style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _CodeChip extends StatelessWidget {
  final String code;
  const _CodeChip(this.code);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.lavender.withValues(alpha: 0.6)),
      ),
      child: Text(
        code,
        style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, color: AppColors.primaryDeep, letterSpacing: 0.8, fontSize: 12),
      ),
    );
  }
}
