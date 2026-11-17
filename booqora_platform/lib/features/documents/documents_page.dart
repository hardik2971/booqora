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
import '../orders/order_shared.dart';

class DocumentsPage extends StatefulWidget {
  final String tab;
  const DocumentsPage({super.key, this.tab = 'invoice'});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  final _stream = Db.watch(C.documents);
  String _q = '';
  bool _showMetrics = true;
  String _finalized = 'all';
  String _sent = 'all';
  Set<String> _payment = {};
  DateTimeRange? _range;

  String get _type => DocType.all.contains(widget.tab) ? widget.tab : 'invoice';

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

  Widget _triState(String value, ValueChanged<String> onChanged) => Wrap(spacing: 6, children: [
        for (final o in const [('all', 'All'), ('yes', 'Yes'), ('no', 'No')])
          ChoiceChip(
            label: Text(o.$2, style: const TextStyle(fontSize: 12)),
            selected: value == o.$1,
            visualDensity: VisualDensity.compact,
            onSelected: (_) => onChanged(o.$1),
          ),
      ]);

  Future<void> _bulkDelete(List<Doc> rows) async {
    final ok = await confirmDialog(context,
        title: 'Delete ${rows.length} document${rows.length == 1 ? '' : 's'}?',
        message: 'The selected documents will be permanently removed. Orders are not affected.',
        confirmLabel: 'Delete',
        danger: true);
    if (!ok) return;
    try {
      for (final d in rows) {
        await Db.remove(C.documents, d.id, label: DocType.number(d));
      }
      if (mounted) toast(context, 'Documents deleted');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  Future<void> _bulkSent(List<Doc> rows) async {
    try {
      for (final d in rows) {
        await Db.update(C.documents, d.id, {'sent': true}, label: DocType.number(d));
      }
      if (mounted) toast(context, 'Marked as sent');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 700;
    final type = _type;
    final header = PageHeader(
      title: 'Documents',
      subtitle: 'Invoices, quotes, contracts and packing slips generated from your orders.',
      actions: [SearchField(hint: 'Search number or customer', width: narrow ? 220 : 260, onChanged: (v) => setState(() => _q = v.trim()))],
    );
    return StreamBuilder<List<Doc>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) return Column(children: [header, Expanded(child: ErrorView(snap.error!))]);
        if (!snap.hasData) return Column(children: [header, const Expanded(child: LoadingView())]);
        final all = snap.data!;
        final counts = [for (final t in DocType.all) all.where((d) => d.s('type') == t).length];
        final ofType = all.where((d) => d.s('type') == type).toList();
        final rows = ofType.where((d) => _match(d)).toList();
        final payCounts = {for (final p in PaymentStatus.all) p: 0};
        for (final d in ofType.where((d) => _match(d, ignorePayment: true))) {
          final p = d.s('paymentStatus');
          if (payCounts.containsKey(p)) payCounts[p] = payCounts[p]! + 1;
        }
        final paid = rows.fold<num>(0, (a, d) => a + d.n('paid'));
        final revenue = rows.fold<num>(0, (a, d) => a + d.n('total'));
        final due = rows.fold<num>(0, (a, d) => a + d.n('due'));
        final packing = type == 'packing';

        final filters = [
          FilterSection(title: 'Finalized', child: _triState(_finalized, (v) => setState(() => _finalized = v))),
          FilterSection(title: 'Sent', child: _triState(_sent, (v) => setState(() => _sent = v))),
          if (!packing)
            FilterSection(
              title: 'Payment status',
              child: CheckFacet(options: PaymentStatus.all, counts: payCounts, selected: _payment, onChanged: (s) => setState(() => _payment = s)),
            ),
          FilterSection(title: 'Date', child: DateRangeFacet(value: _range, onChanged: (r) => setState(() => _range = r))),
        ];

        final empty = ofType.isEmpty
            ? EmptyState(
                icon: Icons.description_outlined,
                title: 'No ${DocType.plural[type]!.toLowerCase()} yet',
                message:
                    'Quotes, contracts and packing slips are generated from an order. Invoices are created from the Documents card on an order.',
                actionLabel: 'Go to orders',
                onAction: () => context.go('/orders'),
              )
            : const EmptyState(
                icon: Icons.filter_alt_off_outlined,
                title: 'No matching documents',
                message: 'Try a different search term or filter.',
                compact: true,
              );

        final body = ListView(padding: EdgeInsets.fromLTRB(narrow ? 16 : 24, 0, narrow ? 16 : 28, 32), children: [
          Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
            PillTabs(
              tabs: [for (final t in DocType.all) DocType.plural[t]!],
              index: DocType.all.indexOf(type),
              badges: counts,
              onChanged: (i) => context.go('/documents?tab=${DocType.all[i]}'),
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
                      MetricCard(label: 'Nr. of documents', value: rows.length, icon: Icons.description_outlined, index: 0),
                      MetricCard(label: 'Paid amount', value: paid, format: Fmt.money, icon: Icons.payments_outlined, color: AppColors.success, index: 1),
                      MetricCard(label: 'Revenue', value: revenue, format: Fmt.money, icon: Icons.trending_up, color: AppColors.info, index: 2),
                      MetricCard(label: 'Due', value: due, format: Fmt.money, icon: Icons.account_balance_wallet_outlined, color: AppColors.warning, index: 3),
                    ]),
                  )
                : const SizedBox(width: double.infinity),
          ),
          DataTableX<Doc>(
            key: ValueKey(type),
            rows: rows,
            idOf: (d) => d.id,
            noun: 'documents',
            minWidth: 960,
            empty: empty,
            onTap: (d) => context.go('/documents/${d.id}'),
            columns: [
              ColumnX('Number', (d) => CellText(DocType.number(d), subtitle: d.b('finalized') ? 'Finalized' : 'Draft'),
                  width: 120, sort: (d) => d.i('number')),
              ColumnX(
                  'Order #',
                  (d) => InkWell(
                        onTap: d.s('orderId').isEmpty ? null : () => context.go('/orders/${d.s('orderId')}'),
                        child: Text(d.i('orderNumber') > 0 ? '#${d.i('orderNumber')}' : '—',
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ),
                  width: 90,
                  sort: (d) => d.i('orderNumber')),
              ColumnX('Customer', (d) {
                final n = d.s('customerName');
                return CellText(n.isEmpty ? 'No customer' : n, leading: Avatar(n.isEmpty ? '?' : n, size: 28));
              }, flex: 3, sort: (d) => d.s('customerName').toLowerCase()),
              ColumnX('Date', (d) => Text(Fmt.date(d.d('date') ?? d.created)), flex: 2, sort: (d) => d.d('date') ?? d.created),
              ColumnX('Due date', (d) {
                final dd = d.d('dueDate');
                final overdue = dd != null && dd.isBefore(DateTime.now()) && d.n('due') > 0;
                return Text(type == 'invoice' ? Fmt.date(dd) : '—',
                    style: TextStyle(color: overdue ? AppColors.danger : null, fontWeight: overdue ? FontWeight.w600 : null));
              }, flex: 2, sort: (d) => d.d('dueDate') ?? DateTime(1970)),
              ColumnX('Total', (d) => Text(packing ? '—' : Fmt.money(d.n('total')), style: const TextStyle(fontWeight: FontWeight.w600)),
                  flex: 2, numeric: true, sort: (d) => d.n('total')),
              ColumnX('Payment', (d) => packing ? const Text('—') : StatusPill(d.s('paymentStatus', 'payment_due')),
                  flex: 2, sort: (d) => d.s('paymentStatus')),
              ColumnX('Sent', (d) => d.b('sent') ? const StatusPill('sent') : const StatusPill('not_sent', label: 'Not sent'),
                  flex: 2, sort: (d) => d.b('sent') ? 1 : 0),
            ],
            bulkActions: [
              BulkAction('Mark as sent', Icons.mark_email_read_outlined, _bulkSent),
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
            onPressed: rows.isEmpty
                ? null
                : () => exportCsv(DocType.plural[type]!.toLowerCase().replaceAll(' ', '_'), [
                      'Number', 'Order', 'Customer', 'Date', 'Due date', 'Subtotal', 'Tax', 'Total', 'Paid', 'Due', 'Payment status', 'Finalized', 'Sent'
                    ], [
                      for (final d in rows)
                        [
                          DocType.number(d), d.i('orderNumber'), d.s('customerName'), Fmt.date(d.d('date') ?? d.created),
                          type == 'invoice' ? Fmt.date(d.d('dueDate')) : '', d.n('subtotal'), d.n('taxTotal'), d.n('total'),
                          d.n('paid'), d.n('due'), d.s('paymentStatus'), d.b('finalized') ? 'yes' : 'no', d.b('sent') ? 'yes' : 'no'
                        ]
                    ]),
          ),
          body: body,
        );
      },
    );
  }
}
