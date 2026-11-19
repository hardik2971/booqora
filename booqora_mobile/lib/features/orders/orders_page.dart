import 'dart:async';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/mobile.dart';
import '../../widgets/page.dart';
import '../../widgets/side_panel.dart';
import 'order_editor_page.dart';
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
  Set<String> _status = {};
  Set<String> _payment = {};
  Set<String> _source = {};
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    _subs.add(Db.watch(C.orders).listen((v) {
      if (mounted) setState(() => _orders = v);
    }, onError: (e) {
      if (mounted) setState(() => _error = e);
    }));
    _subs.add(Db.watch(C.products).listen((v) {
      if (mounted) setState(() => _products = {for (final p in v) p.id: p});
    }, onError: (_) {}));
    _subs.add(Db.watch(C.downtimes).listen((v) {
      if (mounted) setState(() => _downtimes = v);
    }, onError: (_) {}));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final v = await Db.list(C.orders);
      if (mounted) setState(() => _orders = v);
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  int get _filterCount => _status.length + _payment.length + _source.length + (_range == null ? 0 : 1);

  bool _matches(Doc o, {bool ignoreStatus = false, bool ignorePayment = false, bool ignoreSource = false}) {
    if (_q.isNotEmpty) {
      final q = _q.toLowerCase();
      final hay = '${o.i('number')} #${o.i('number')} ${o.s('customerName')} ${o.s('customerEmail')} ${o.l<String>('tags').join(' ')}'.toLowerCase();
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

  Map<String, Map<String, int>> _shortageMap(List<Doc> orders) {
    final out = <String, Map<String, int>>{};
    for (final o in orders) {
      final s = OrderX.shortages(o, _products, orders, _downtimes);
      if (s.isNotEmpty) out[o.id] = s;
    }
    return out;
  }

  bool _inTab(Doc o, int t, Map<String, Map<String, int>> shortages, DateTime now) => switch (t) {
        1 => OrderX.isUpcoming(o, now),
        2 => OrderX.isLate(o, now),
        3 => shortages.containsKey(o.id),
        _ => true,
      };

  Future<bool> _setStatus(Doc o, String status) async {
    final cancel = status == 'canceled';
    final ok = await confirmDialog(
      context,
      title: cancel ? 'Cancel order ${OrderX.label(o)}?' : 'Archive order ${OrderX.label(o)}?',
      message: cancel ? 'The reserved items will be released for other orders.' : 'Archived orders stay in reports and can be restored at any time.',
      confirmLabel: cancel ? 'Cancel order' : 'Archive',
      danger: cancel,
    );
    if (!ok) return false;
    try {
      await Db.update(C.orders, o.id, {'status': status}, label: 'Order ${OrderX.label(o)}');
      await OrderX.syncCustomer(o.s('customerId'));
      HapticFeedback.mediumImpact();
      if (mounted) toast(context, 'Order ${OrderX.label(o)} ${cancel ? 'canceled' : 'archived'}');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
    return false; // the live stream updates the card in place
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

  // ---------------------------------------------------------------------------
  // Filter sheet
  // ---------------------------------------------------------------------------

  Future<void> _openFilters() async {
    HapticFeedback.selectionClick();
    await showAppSheet<void>(
      context,
      title: 'Filter orders',
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
        void upd(VoidCallback f) {
          setState(f);
          setD(() {});
        }

        final all = _orders ?? [];
        final now = DateTime.now();
        final shortages = _shortageMap(all);
        Map<String, int> facet(String field, List<String> opts, bool Function(Doc) pre, [String def = '']) {
          final m = {for (final o in opts) o: 0};
          for (final o in all.where(pre)) {
            final v = o.s(field, def);
            if (m.containsKey(v)) m[v] = m[v]! + 1;
          }
          return m;
        }

        final statusCounts = facet('status', OrderStatus.all, (o) => _matches(o, ignoreStatus: true) && _inTab(o, _tab, shortages, now));
        final payCounts = facet('paymentStatus', PaymentStatus.all, (o) => _matches(o, ignorePayment: true) && _inTab(o, _tab, shortages, now));
        final srcCounts =
            facet('source', const ['manual', 'online'], (o) => _matches(o, ignoreSource: true) && _inTab(o, _tab, shortages, now), 'manual');
        final rows = all.where((o) => _matches(o) && _inTab(o, _tab, shortages, now)).toList();

        Widget chips(List<String> opts, Map<String, int> counts, Set<String> sel, ValueChanged<Set<String>> on, [String Function(String)? lab]) =>
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final o in opts)
                FilterChip(
                  label: Text('${lab?.call(o) ?? Fmt.label(o)}  ${counts[o] ?? 0}'),
                  selected: sel.contains(o),
                  showCheckmark: false,
                  selectedColor: AppColors.primarySoft,
                  side: BorderSide(color: sel.contains(o) ? AppColors.primary : AppColors.border),
                  labelStyle: TextStyle(fontWeight: FontWeight.w600, color: sel.contains(o) ? AppColors.primaryDeep : AppColors.inkSoft),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (v) {
                    HapticFeedback.selectionClick();
                    final s = {...sel};
                    v ? s.add(o) : s.remove(o);
                    on(s);
                  },
                ),
            ]);

        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionLabel('Status'),
          chips(OrderStatus.all, statusCounts, _status, (s) => upd(() => _status = s)),
          const SectionLabel('Payment status'),
          chips(PaymentStatus.all, payCounts, _payment, (s) => upd(() => _payment = s)),
          const SectionLabel('Pickup date'),
          DateRangeFacet(value: _range, onChanged: (r) => upd(() => _range = r)),
          const SectionLabel('Source'),
          chips(const ['manual', 'online'], srcCounts, _source, (s) => upd(() => _source = s), (s) => s == 'online' ? 'Online store' : 'Manual'),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                onPressed: _filterCount == 0
                    ? null
                    : () => upd(() {
                          _status = {};
                          _payment = {};
                          _source = {};
                          _range = null;
                        }),
                child: const Text('Reset'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: GradientButton(label: 'Show ${rows.length} order${rows.length == 1 ? '' : 's'}', onPressed: () => Navigator.pop(ctx)),
            ),
          ]),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: rows.isEmpty ? null : () => _export(rows),
            icon: const Icon(Icons.ios_share_rounded, size: 18),
            label: const Text('Export these orders as CSV'),
          ),
        ]);
      }),
    );
  }

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final actions = [
      _BadgeIcon(icon: Icons.tune_rounded, badge: _filterCount, onTap: _openFilters),
      IconButton(
        tooltip: 'Add order',
        icon: const Icon(Icons.add_circle_rounded, color: AppColors.primary, size: 28),
        onPressed: () {
          HapticFeedback.lightImpact();
          context.push('/orders/new');
        },
      ),
    ];
    final header = MSearch(hint: 'Search number, customer or tag', onChanged: (v) => setState(() => _q = v.trim()));

    if (_error != null) {
      return MPage(title: 'Orders', actions: actions, slivers: [SliverFillRemaining(hasScrollBody: false, child: ErrorView(_error!))]);
    }
    final all = _orders;
    if (all == null) {
      return MPage(
        title: 'Orders',
        actions: actions,
        header: header,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(children: [
                for (var i = 0; i < 5; i++) const Padding(padding: EdgeInsets.only(bottom: 10), child: Skeleton(height: 112, radius: 18)),
              ]),
            ),
          ),
        ],
      );
    }

    final now = DateTime.now();
    final shortages = _shortageMap(all);
    final base = all.where((o) => _matches(o)).toList();
    final counts = {for (var t = 0; t < 4; t++) t: base.where((o) => _inTab(o, t, shortages, now)).length};
    final rows = base.where((o) => _inTab(o, _tab, shortages, now)).toList();

    final billable = rows.where((o) => o.s('status') != 'canceled' && o.s('status') != 'draft');
    final revenue = billable.fold<num>(0, (a, o) => a + o.n('total'));
    final due = billable.fold<num>(0, (a, o) => a + o.n('due'));
    final items = rows.fold<num>(0, (a, o) => a + o.n('itemCount'));

    return MPage(
      title: 'Orders',
      actions: actions,
      header: header,
      onRefresh: _refresh,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 0, 12),
            child: ChoiceChipsBar<int>(
              options: const [(0, 'All'), (1, 'Upcoming'), (2, 'Late'), (3, 'With shortage')],
              value: _tab,
              counts: counts,
              onChanged: (v) => setState(() => _tab = v),
            ),
          ),
        ),
        if (all.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: MetricScroller(items: [
                MiniMetric(label: 'Orders', value: rows.length, format: (v) => Fmt.integer(v), icon: Icons.receipt_long_rounded),
                MiniMetric(label: 'Items', value: items, format: (v) => Fmt.integer(v), icon: Icons.inventory_2_outlined, color: AppColors.info),
                MiniMetric(label: 'Revenue', value: revenue, format: Fmt.compactMoney, icon: Icons.trending_up_rounded, color: AppColors.success),
                MiniMetric(label: 'Due', value: due, format: Fmt.compactMoney, icon: Icons.account_balance_wallet_outlined, color: AppColors.warning),
              ]),
            ),
          ),
        if (_filterCount > 0)
          SPad(
            Row(children: [
              const Icon(Icons.filter_alt_outlined, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                  child: Text('$_filterCount filter${_filterCount == 1 ? '' : 's'} applied',
                      style: const TextStyle(color: AppColors.primaryDeep, fontWeight: FontWeight.w600, fontSize: 13))),
              TextButton(
                onPressed: () => setState(() {
                  _status = {};
                  _payment = {};
                  _source = {};
                  _range = null;
                }),
                child: const Text('Clear'),
              ),
            ]),
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
          ),
        if (rows.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: all.isEmpty
                ? EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Create your first order',
                    message: 'Live availability and automatic pricing. Reserve, pick up and return in a few taps.',
                    actionLabel: 'Add order',
                    onAction: () => context.push('/orders/new'),
                  )
                : const EmptyState(
                    icon: Icons.filter_alt_off_outlined,
                    title: 'No matching orders',
                    message: 'Try a different tab, search term or filter.',
                    compact: true,
                  ),
          )
        else
          SList(
            count: rows.length,
            builder: (c, i) {
              final o = rows[i];
              return _SwipeOrder(
                key: ValueKey(o.id),
                order: o,
                onArchive: () => _setStatus(o, 'archived'),
                onCancel: () => _setStatus(o, 'canceled'),
                child: _OrderCard(order: o, late: OrderX.isLate(o, now), shortage: shortages.containsKey(o.id)),
              );
            },
          ),
      ],
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  final IconData icon;
  final int badge;
  final VoidCallback onTap;
  const _BadgeIcon({required this.icon, required this.badge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Filters',
      onPressed: onTap,
      icon: Badge(
        isLabelVisible: badge > 0,
        label: Text('$badge'),
        backgroundColor: AppColors.primary,
        child: Icon(icon, color: AppColors.ink),
      ),
    );
  }
}

/// Swipe right to archive, left to cancel (both confirmed).
class _SwipeOrder extends StatelessWidget {
  final Doc order;
  final Widget child;
  final Future<bool> Function() onArchive;
  final Future<bool> Function() onCancel;
  const _SwipeOrder({super.key, required this.order, required this.child, required this.onArchive, required this.onCancel});

  Widget _bg(Color color, IconData icon, String label, Alignment align) => Container(
        alignment: align,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final st = order.s('status', 'draft');
    final canArchive = st != 'archived';
    final canCancel = st == 'draft' || st == 'reserved';
    if (!canArchive && !canCancel) return child;
    return Dismissible(
      key: ValueKey('swipe-${order.id}'),
      direction: canArchive && canCancel
          ? DismissDirection.horizontal
          : (canArchive ? DismissDirection.startToEnd : DismissDirection.endToStart),
      background: _bg(AppColors.primary, Icons.archive_outlined, 'Archive', Alignment.centerLeft),
      secondaryBackground: _bg(AppColors.danger, Icons.block_rounded, 'Cancel', Alignment.centerRight),
      confirmDismiss: (dir) {
        HapticFeedback.mediumImpact();
        return dir == DismissDirection.startToEnd ? onArchive() : onCancel();
      },
      child: child,
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Doc order;
  final bool late;
  final bool shortage;
  const _OrderCard({required this.order, required this.late, required this.shortage});

  @override
  Widget build(BuildContext context) {
    final o = order;
    final name = o.s('customerName');
    final online = o.s('source') == 'online';
    return OpenContainer(
      useRootNavigator: true,
      closedElevation: 0,
      openElevation: 0,
      closedColor: Colors.transparent,
      openColor: AppColors.bg,
      middleColor: AppColors.bg,
      closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      transitionDuration: const Duration(milliseconds: 420),
      openBuilder: (_, _) => OrderEditorPage(id: o.id),
      closedBuilder: (ctx, open) => MTile(
        onTap: () {
          HapticFeedback.selectionClick();
          open();
        },
        leading: Avatar(name.isEmpty ? '?' : name, size: 44),
        title: name.isEmpty ? 'No customer' : name,
        subtitle: '${OrderX.label(o)}${online ? ' · Online store' : ''} · ${o.i('itemCount')} item${o.i('itemCount') == 1 ? '' : 's'}',
        trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
          Text(Fmt.money(o.n('total')), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: -0.2)),
          const SizedBox(height: 4),
          StatusPill(o.s('paymentStatus', 'payment_due')),
        ]),
        footer: Container(
          padding: const EdgeInsets.only(top: 10),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF1EEF7)))),
          child: Row(children: [
            const Icon(Icons.event_outlined, size: 15, color: AppColors.muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${Fmt.shortDate(o.d('startsAt'))} ${Fmt.time(o.d('startsAt'))}  →  ${Fmt.shortDate(o.d('stopsAt'))} ${Fmt.time(o.d('stopsAt'))}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 6),
            if (shortage) ...[
              const Tooltip(message: 'Shortage', child: Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning)),
              const SizedBox(width: 4),
            ],
            if (late) ...[
              const StatusPill('late', dot: false),
              const SizedBox(width: 4),
            ],
            StatusPill(o.s('status', 'draft')),
          ]),
        ),
      ),
    );
  }
}
