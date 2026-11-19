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
import '../orders/order_sheets.dart' show IconBadge, OptionChip;
import '../orders/order_shared.dart';
import 'document_page.dart';

class DocumentsPage extends StatefulWidget {
  final String tab;
  const DocumentsPage({super.key, this.tab = 'invoice'});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

IconData docIcon(String type) => switch (type) {
      'quote' => Icons.request_quote_outlined,
      'contract' => Icons.handshake_outlined,
      'packing' => Icons.checklist_rtl_rounded,
      _ => Icons.receipt_long_outlined,
    };

class _DocumentsPageState extends State<DocumentsPage> {
  late Stream<List<Doc>> _stream = Db.watch(C.documents);
  late String _type = DocType.all.contains(widget.tab) ? widget.tab : 'invoice';
  String _q = '';
  String _finalized = 'all';
  String _sent = 'all';
  Set<String> _payment = {};
  DateTimeRange? _range;

  int get _filterCount => (_finalized == 'all' ? 0 : 1) + (_sent == 'all' ? 0 : 1) + _payment.length + (_range == null ? 0 : 1);

  bool _match(Doc d, {bool ignorePayment = false}) {
    if (_q.isNotEmpty) {
      final q = _q.toLowerCase();
      final hay = '${DocType.number(d)} ${d.i('number')} #${d.i('orderNumber')} ${d.s('customerName')}'.toLowerCase();
      if (!hay.contains(q)) return false;
    }
    if (_finalized != 'all' && d.b('finalized') != (_finalized == 'yes')) return false;
    if (_sent != 'all' && d.b('sent') != (_sent == 'yes')) return false;
    if (!ignorePayment && _payment.isNotEmpty && !_payment.contains(d.s('paymentStatus'))) return false;
    if (_range != null) {
      final dt = d.d('date') ?? d.created;
      if (dt.isBefore(_range!.start) || !dt.isBefore(_range!.end)) return false;
    }
    return true;
  }

  Future<bool> _delete(Doc d) async {
    final ok = await confirmDialog(context,
        title: 'Delete ${DocType.number(d)}?', message: 'This document will be permanently removed. The order is not affected.', confirmLabel: 'Delete', danger: true);
    if (!ok) return false;
    try {
      await Db.remove(C.documents, d.id, label: DocType.number(d));
      HapticFeedback.mediumImpact();
      if (mounted) toast(context, '${DocType.title[d.s('type')]} deleted');
      return true;
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
      return false;
    }
  }

  Future<bool> _toggleSent(Doc d) async {
    try {
      await Db.update(C.documents, d.id, {'sent': !d.b('sent')}, label: DocType.number(d));
      HapticFeedback.mediumImpact();
      if (mounted) toast(context, d.b('sent') ? 'Marked as not sent' : 'Marked as sent');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
    return false;
  }

  void _export(List<Doc> rows) {
    exportCsv(DocType.plural[_type]!.toLowerCase().replaceAll(' ', '_'), [
      'Number', 'Order', 'Customer', 'Date', 'Due date', 'Subtotal', 'Tax', 'Total', 'Paid', 'Due', 'Payment status', 'Finalized', 'Sent'
    ], [
      for (final d in rows)
        [
          DocType.number(d), d.i('orderNumber'), d.s('customerName'), Fmt.date(d.d('date') ?? d.created),
          _type == 'invoice' ? Fmt.date(d.d('dueDate')) : '', d.n('subtotal'), d.n('taxTotal'), d.n('total'),
          d.n('paid'), d.n('due'), d.s('paymentStatus'), d.b('finalized') ? 'yes' : 'no', d.b('sent') ? 'yes' : 'no'
        ]
    ]);
  }

  Future<void> _openFilters(List<Doc> all) async {
    HapticFeedback.selectionClick();
    await showAppSheet<void>(
      context,
      title: 'Filter ${DocType.plural[_type]!.toLowerCase()}',
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
        void upd(VoidCallback f) {
          setState(f);
          setD(() {});
        }

        final ofType = all.where((d) => d.s('type') == _type).toList();
        final rows = ofType.where((d) => _match(d)).toList();
        final payCounts = {for (final p in PaymentStatus.all) p: 0};
        for (final d in ofType.where((d) => _match(d, ignorePayment: true))) {
          final p = d.s('paymentStatus');
          if (payCounts.containsKey(p)) payCounts[p] = payCounts[p]! + 1;
        }

        Widget tri(String value, ValueChanged<String> on) => Row(children: [
              for (final o in const [('all', 'All'), ('yes', 'Yes'), ('no', 'No')]) ...[
                Expanded(child: OptionChip(label: o.$2, selected: value == o.$1, onTap: () => on(o.$1))),
                if (o.$1 != 'no') const SizedBox(width: 8),
              ],
            ]);

        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionLabel('Finalized'),
          tri(_finalized, (v) => upd(() => _finalized = v)),
          const SectionLabel('Sent'),
          tri(_sent, (v) => upd(() => _sent = v)),
          if (_type != 'packing') ...[
            const SectionLabel('Payment status'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final p in PaymentStatus.all)
                FilterChip(
                  label: Text('${Fmt.label(p)}  ${payCounts[p] ?? 0}'),
                  selected: _payment.contains(p),
                  showCheckmark: false,
                  selectedColor: AppColors.primarySoft,
                  side: BorderSide(color: _payment.contains(p) ? AppColors.primary : AppColors.border),
                  labelStyle: TextStyle(fontWeight: FontWeight.w600, color: _payment.contains(p) ? AppColors.primaryDeep : AppColors.inkSoft),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (v) {
                    HapticFeedback.selectionClick();
                    upd(() {
                      final s = {..._payment};
                      v ? s.add(p) : s.remove(p);
                      _payment = s;
                    });
                  },
                ),
            ]),
          ],
          const SectionLabel('Date'),
          DateRangeFacet(value: _range, onChanged: (r) => upd(() => _range = r)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                onPressed: _filterCount == 0
                    ? null
                    : () => upd(() {
                          _finalized = 'all';
                          _sent = 'all';
                          _payment = {};
                          _range = null;
                        }),
                child: const Text('Reset'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: GradientButton(label: 'Show ${rows.length} result${rows.length == 1 ? '' : 's'}', onPressed: () => Navigator.pop(ctx))),
          ]),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: rows.isEmpty ? null : () => _export(rows),
            icon: const Icon(Icons.ios_share_rounded, size: 18),
            label: const Text('Export as CSV'),
          ),
        ]);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Doc>>(
      stream: _stream,
      builder: (context, snap) {
        final all = snap.data;
        final actions = [
          IconButton(
            tooltip: 'Filters',
            onPressed: all == null ? null : () => _openFilters(all),
            icon: Badge(
              isLabelVisible: _filterCount > 0,
              label: Text('$_filterCount'),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.tune_rounded, color: AppColors.ink),
            ),
          ),
        ];
        final header = MSearch(hint: 'Search number, order or customer', onChanged: (v) => setState(() => _q = v.trim()));
        if (snap.hasError) {
          return MPage(title: 'Documents', actions: actions, slivers: [SliverFillRemaining(hasScrollBody: false, child: ErrorView(snap.error!))]);
        }
        if (all == null) {
          return MPage(title: 'Documents', actions: actions, header: header, slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(children: [
                  for (var i = 0; i < 5; i++) const Padding(padding: EdgeInsets.only(bottom: 10), child: Skeleton(height: 84, radius: 18)),
                ]),
              ),
            ),
          ]);
        }

        final counts = {for (final t in DocType.all) t: all.where((d) => d.s('type') == t).length};
        final ofType = all.where((d) => d.s('type') == _type).toList();
        final rows = ofType.where((d) => _match(d)).toList();
        final paid = rows.fold<num>(0, (a, d) => a + d.n('paid'));
        final revenue = rows.fold<num>(0, (a, d) => a + d.n('total'));
        final due = rows.fold<num>(0, (a, d) => a + d.n('due'));
        final packing = _type == 'packing';

        return MPage(
          title: 'Documents',
          actions: actions,
          header: header,
          onRefresh: () async {
            setState(() => _stream = Db.watch(C.documents));
            await _stream.first;
          },
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 0, 12),
                child: ChoiceChipsBar<String>(
                  options: [for (final t in DocType.all) (t, DocType.plural[t]!)],
                  value: _type,
                  counts: counts,
                  onChanged: (v) => setState(() {
                    _type = v;
                    _payment = {};
                  }),
                ),
              ),
            ),
            if (ofType.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: MetricScroller(
                    key: ValueKey(_type),
                    items: [
                      MiniMetric(label: DocType.plural[_type]!, value: rows.length, format: (v) => Fmt.integer(v), icon: docIcon(_type)),
                      if (!packing) ...[
                        MiniMetric(label: 'Revenue', value: revenue, format: Fmt.compactMoney, icon: Icons.trending_up_rounded, color: AppColors.info),
                        MiniMetric(label: 'Paid', value: paid, format: Fmt.compactMoney, icon: Icons.payments_outlined, color: AppColors.success),
                        MiniMetric(label: 'Due', value: due, format: Fmt.compactMoney, icon: Icons.account_balance_wallet_outlined, color: AppColors.warning),
                      ] else
                        MiniMetric(
                          label: 'Sent',
                          value: rows.where((d) => d.b('sent')).length,
                          format: (v) => Fmt.integer(v),
                          icon: Icons.mark_email_read_outlined,
                          color: AppColors.success,
                        ),
                    ],
                  ),
                ),
              ),
            if (rows.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: ofType.isEmpty
                    ? EmptyState(
                        icon: docIcon(_type),
                        title: 'No ${DocType.plural[_type]!.toLowerCase()} yet',
                        message: 'Documents are generated from an order. Open an order and create one from its Documents section.',
                        actionLabel: 'Go to orders',
                        onAction: () => context.go('/orders'),
                      )
                    : const EmptyState(
                        icon: Icons.filter_alt_off_outlined,
                        title: 'No matching documents',
                        message: 'Try a different search term or filter.',
                        compact: true,
                      ),
              )
            else
              SList(
                count: rows.length,
                builder: (c, i) {
                  final d = rows[i];
                  return Dismissible(
                    key: ValueKey('doc-${d.id}'),
                    background: _swipeBg(AppColors.primary, d.b('sent') ? Icons.unsubscribe_outlined : Icons.mark_email_read_outlined,
                        d.b('sent') ? 'Not sent' : 'Sent', Alignment.centerLeft),
                    secondaryBackground: _swipeBg(AppColors.danger, Icons.delete_outline_rounded, 'Delete', Alignment.centerRight),
                    confirmDismiss: (dir) {
                      HapticFeedback.mediumImpact();
                      return dir == DismissDirection.startToEnd ? _toggleSent(d) : _delete(d);
                    },
                    child: _DocCard(doc: d),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _swipeBg(Color color, IconData icon, String label, Alignment align) => Container(
        alignment: align,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
        ]),
      );
}

class _DocCard extends StatelessWidget {
  final Doc doc;
  const _DocCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final d = doc;
    final type = d.s('type', 'invoice');
    final packing = type == 'packing';
    final dd = d.d('dueDate');
    final overdue = type == 'invoice' && dd != null && dd.isBefore(DateTime.now()) && d.n('due') > 0;
    final name = d.s('customerName');
    return OpenContainer(
      useRootNavigator: true,
      closedElevation: 0,
      openElevation: 0,
      closedColor: Colors.transparent,
      openColor: AppColors.bg,
      middleColor: AppColors.bg,
      closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      transitionDuration: const Duration(milliseconds: 420),
      openBuilder: (_, _) => DocumentPage(id: d.id),
      closedBuilder: (ctx, open) => MTile(
        onTap: () {
          HapticFeedback.selectionClick();
          open();
        },
        leading: IconBadge(docIcon(type), size: 44),
        title: DocType.number(d),
        subtitle: '${name.isEmpty ? 'No customer' : name}${d.i('orderNumber') > 0 ? ' · Order #${d.i('orderNumber')}' : ''}',
        trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
          if (!packing) Text(Fmt.money(d.n('total')), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 4),
          if (!packing && type == 'invoice')
            StatusPill(d.s('paymentStatus', 'payment_due'))
          else
            StatusPill(d.b('finalized') ? 'finalized' : 'draft'),
        ]),
        footer: Container(
          padding: const EdgeInsets.only(top: 10),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF1EEF7)))),
          child: Row(children: [
            const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                type == 'invoice' && dd != null ? '${Fmt.date(d.d('date') ?? d.created)} · due ${Fmt.date(dd)}' : Fmt.date(d.d('date') ?? d.created),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: overdue ? AppColors.danger : AppColors.inkSoft, fontWeight: overdue ? FontWeight.w700 : FontWeight.w500),
              ),
            ),
            if (overdue) ...[const StatusPill('overdue', dot: false), const SizedBox(width: 4)],
            d.b('sent') ? const StatusPill('sent', dot: false) : const StatusPill('not_sent', label: 'Not sent', dot: false),
          ]),
        ),
      ),
    );
  }
}
