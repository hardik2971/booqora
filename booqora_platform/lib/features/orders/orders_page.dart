import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/page.dart';
import '../../widgets/side_panel.dart';
import '../../widgets/table.dart';
import 'order_shared.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final _subs = <StreamSubscription>[];
  List<Doc>? _orders;
  Map<String, Doc> _products = {};
  List<Doc> _downtimes = [];
  Object? _error;

  int _tab = 0;
  String _q = '';
  bool _showMetrics = true;
  Set<String> _status = {};
  Set<String> _payment = {};
  Set<String> _source = {};
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    _subs.add(Db.watch(C.orders).listen((v) => setState(() => _orders = v), onError: (e) => setState(() => _error = e)));
    _subs.add(Db.watch(C.products).listen((v) => setState(() => _products = {for (final p in v) p.id: p}), onError: (_) {}));
    _subs.add(Db.watch(C.downtimes).listen((v) => setState(() => _downtimes = v), onError: (_) {}));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  Map<String, Map<String, int>> _shortageMap(List<Doc> orders) {
    final out = <String, Map<String, int>>{};
    for (final o in orders) {
      final s = OrderX.shortages(o, _products, orders, _downtimes);
      if (s.isNotEmpty) out[o.id] = s;
    }
    return out;
  }

  bool _matchesFilters(Doc o, {bool ignoreStatus = false, bool ignorePayment = false, bool ignoreSource = false}) {
    if (_q.isNotEmpty) {
      final q = _q.toLowerCase();
      final hay = '${o.i('number')} #${o.i('number')} ${o.s('customerName')} ${o.s('customerEmail')}'.toLowerCase();
      if (!hay.contains(q)) return false;
    }
    if (!ignoreStatus && _status.isNotEmpty && !_status.contains(o.s('status'))) return false;
    if (!ignorePayment && _payment.isNotEmpty && !_payment.contains(o.s('paymentStatus'))) return false;
    if (!ignoreSource && _source.isNotEmpty && !_source.contains(o.s('source', 'manual'))) return false;
    if (_range != null) {
      final s = o.d('startsAt');
      if (s == null || s.isBefore(_range!.start) || !s.isBefore(_range!.end)) return false;
    }
    return true;
  }

  Future<void> _bulkStatus(List<Doc> rows, String status) async {
    try {
      for (final o in rows) {
        await Db.update(C.orders, o.id, {'status': status}, label: 'Order ${OrderX.label(o)}');
        await OrderX.syncCustomer(o.s('customerId'));
      }
      if (mounted) toast(context, '${rows.length} order${rows.length == 1 ? '' : 's'} ${status == 'archived' ? 'archived' : 'canceled'}');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  Future<void> _bulkDelete(List<Doc> rows) async {
    final ok = await confirmDialog(context,
        title: 'Delete ${rows.length} order${rows.length == 1 ? '' : 's'}?',
        message: 'This permanently removes the selected orders. Payments and documents remain in their own lists.',
        confirmLabel: 'Delete',
        danger: true);
    if (!ok) return;
    try {
      for (final o in rows) {
        await Db.remove(C.orders, o.id, label: 'Order ${OrderX.label(o)}');
        await OrderX.syncCustomer(o.s('customerId'));
      }
      if (mounted) toast(context, 'Orders deleted');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  void _export(List<Doc> rows) {
    exportCsv('orders', [
      'Number', 'Customer', 'Email', 'Status', 'From', 'Until', 'Items', 'Subtotal', 'Discount', 'Tax', 'Total', 'Paid', 'Due', 'Payment status', 'Source', 'Tags'
    ], [
      for (final o in rows)
        [
          OrderX.label(o), o.s('customerName'), o.s('customerEmail'), o.s('status'), Fmt.dateTime(o.d('startsAt')), Fmt.dateTime(o.d('stopsAt')),
          o.i('itemCount'), o.n('subtotal'), o.n('discountTotal'), o.n('taxTotal'), o.n('total'), o.n('paid'), o.n('due'),
          o.s('paymentStatus'), o.s('source', 'manual'), o.l<String>('tags').join(' ')
        ]
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 700;
    final header = PageHeader(
      title: 'Orders',
      subtitle: 'Reserve, pick up and return rentals with live availability.',
      actions: [
        SearchField(hint: 'Search number or customer', width: narrow ? 220 : 260, onChanged: (v) => setState(() => _q = v.trim())),
        FilledButton.icon(onPressed: () => context.go('/orders/new'), icon: const Icon(Icons.add, size: 18), label: const Text('Add order')),
      ],
    );
    if (_error != null) return Column(children: [header, Expanded(child: ErrorView(_error!))]);
    final all = _orders;
    if (all == null) return Column(children: [header, const Expanded(child: LoadingView())]);

    final now = DateTime.now();
    final shortages = _shortageMap(all);
    bool inTab(Doc o, int t) => switch (t) {
          1 => OrderX.isUpcoming(o, now),
          2 => OrderX.isLate(o, now),
          3 => shortages.containsKey(o.id),
          _ => true,
        };
    final base = all.where((o) => _matchesFilters(o)).toList();
    final counts = [for (var t = 0; t < 4; t++) base.where((o) => inTab(o, t)).length];
    final rows = base.where((o) => inTab(o, _tab)).toList();

    Map<String, int> facet(String field, List<String> opts, bool Function(Doc) pre, [String def = '']) {
      final m = {for (final o in opts) o: 0};
      for (final o in all.where(pre)) {
        final v = o.s(field, def);
        if (m.containsKey(v)) m[v] = m[v]! + 1;
      }
      return m;
    }

    final statusCounts = facet('status', OrderStatus.all, (o) => _matchesFilters(o, ignoreStatus: true) && inTab(o, _tab));
    final payCounts = facet('paymentStatus', PaymentStatus.all, (o) => _matchesFilters(o, ignorePayment: true) && inTab(o, _tab));
    final srcCounts = facet('source', const ['manual', 'online'], (o) => _matchesFilters(o, ignoreSource: true) && inTab(o, _tab), 'manual');

    final billable = rows.where((o) => o.s('status') != 'canceled' && o.s('status') != 'draft');
    final revenue = billable.fold<num>(0, (a, o) => a + o.n('total'));
    final due = billable.fold<num>(0, (a, o) => a + o.n('due'));
    final items = rows.fold<num>(0, (a, o) => a + o.n('itemCount'));

    final filters = [
      FilterSection(
        title: 'Status',
        child: CheckFacet(options: OrderStatus.all, counts: statusCounts, selected: _status, onChanged: (s) => setState(() => _status = s)),
      ),
      FilterSection(
        title: 'Payment status',
        child: CheckFacet(options: PaymentStatus.all, counts: payCounts, selected: _payment, onChanged: (s) => setState(() => _payment = s)),
      ),
      FilterSection(title: 'Pickup date', child: DateRangeFacet(value: _range, onChanged: (r) => setState(() => _range = r))),
      FilterSection(
        title: 'Source',
        child: CheckFacet(
          options: const ['manual', 'online'],
          counts: srcCounts,
          selected: _source,
          labeler: (s) => s == 'online' ? 'Online store' : 'Manual',
          onChanged: (s) => setState(() => _source = s),
        ),
      ),
    ];

    final empty = all.isEmpty
        ? EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Create your first order',
            message: 'Live availability and automatic pricing. Reserve, pick up and return in a few clicks.',
            actionLabel: 'Add order',
            onAction: () => context.go('/orders/new'),
          )
        : const EmptyState(
            icon: Icons.filter_alt_off_outlined,
            title: 'No matching orders',
            message: 'Try a different tab, search term or filter.',
            compact: true,
          );

    final body = ListView(padding: EdgeInsets.fromLTRB(narrow ? 16 : 24, 0, narrow ? 16 : 28, 32), children: [
      Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        PillTabs(
          tabs: const ['All', 'Upcoming', 'Late', 'With shortage'],
          index: _tab,
          badges: counts,
          onChanged: (i) => setState(() => _tab = i),
        ),
        TextButton.icon(
          onPressed: () => setState(() => _showMetrics = !_showMetrics),
          icon: Icon(_showMetrics ? Icons.visibility_off_outlined : Icons.insights_outlined, size: 18),
          label: Text(_showMetrics ? 'Hide metrics' : 'Show metrics'),
        ),
      ]).enter(0),
      const SizedBox(height: 16),
      AnimatedSize(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        child: _showMetrics
            ? Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: MetricRow(children: [
                  MetricCard(label: 'Orders', value: rows.length, icon: Icons.receipt_long_outlined, index: 0),
                  MetricCard(label: 'Items ordered', value: items, icon: Icons.inventory_2_outlined, color: AppColors.info, index: 1),
                  MetricCard(
                      label: 'Revenue',
                      value: revenue,
                      format: Fmt.money,
                      icon: Icons.trending_up,
                      color: AppColors.success,
                      hint: 'Total of reserved, active, returned and archived orders',
                      index: 2),
                  MetricCard(label: 'Due', value: due, format: Fmt.money, icon: Icons.account_balance_wallet_outlined, color: AppColors.warning, index: 3),
                ]),
              )
            : const SizedBox(width: double.infinity),
      ),
      DataTableX<Doc>(
        rows: rows,
        idOf: (o) => o.id,
        noun: 'orders',
        minWidth: 1040,
        empty: empty,
        onTap: (o) => context.go('/orders/${o.id}'),
        columns: [
          ColumnX('#', (o) => CellText(OrderX.label(o), subtitle: o.s('source') == 'online' ? 'Online' : null),
              width: 96, sort: (o) => o.i('number')),
          ColumnX('Customer', (o) {
            final n = o.s('customerName');
            return CellText(n.isEmpty ? 'No customer' : n,
                subtitle: o.s('customerEmail'), leading: Avatar(n.isEmpty ? '?' : n, size: 30));
          }, flex: 3, sort: (o) => o.s('customerName').toLowerCase()),
          ColumnX('Status', (o) {
            final late = OrderX.isLate(o, now);
            final short = shortages.containsKey(o.id);
            return Wrap(spacing: 4, runSpacing: 4, children: [
              StatusPill(o.s('status', 'draft')),
              if (late) const StatusPill('late', dot: false),
              if (short) const StatusPill('shortage', dot: false),
            ]);
          }, flex: 2, sort: (o) => OrderStatus.all.indexOf(o.s('status'))),
          ColumnX(
              'From → Until',
              (o) => CellText(Fmt.dateTime(o.d('startsAt')), subtitle: '→ ${Fmt.dateTime(o.d('stopsAt'))}'),
              flex: 3,
              sort: (o) => o.d('startsAt') ?? DateTime(1970)),
          ColumnX('Total', (o) => Text(Fmt.money(o.n('total')), style: const TextStyle(fontWeight: FontWeight.w600)),
              flex: 2, numeric: true, sort: (o) => o.n('total')),
          ColumnX('Payment', (o) => Padding(padding: const EdgeInsets.only(left: 16), child: StatusPill(o.s('paymentStatus', 'payment_due'))),
              width: 160, sort: (o) => o.s('paymentStatus')),
          ColumnX('Tags', (o) {
            final tags = o.l<String>('tags');
            if (tags.isEmpty) return const Text('—', style: TextStyle(color: AppColors.muted));
            return Wrap(spacing: 4, runSpacing: 4, children: [
              for (final t in tags.take(3)) StatusPill('tag', label: t, dot: false),
            ]);
          }, width: 120),
        ],
        bulkActions: [
          BulkAction('Archive', Icons.archive_outlined, (r) => _bulkStatus(r, 'archived')),
          BulkAction('Cancel', Icons.block, (r) => _bulkStatus(r, 'canceled')),
          BulkAction('Delete', Icons.delete_outline, _bulkDelete, danger: true),
        ],
      ).enter(2),
    ]);

    return ListLayout(
      header: header,
      filters: filters,
      footerFilters: OutlinedButton.icon(
        icon: const Icon(Icons.download_outlined, size: 18),
        label: const Text('Export CSV'),
        onPressed: rows.isEmpty ? null : () => _export(rows),
      ),
      body: body,
    );
  }
}
