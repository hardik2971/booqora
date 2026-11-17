import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart' hide Thumb;
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/browser.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/pricing.dart';
import '../../data/schema.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/page.dart';
import '../../widgets/side_panel.dart';
import '../orders/order_dialogs.dart';
import '../orders/order_shared.dart';
import 'doc_html.dart';

class DocumentPage extends StatefulWidget {
  final String id;
  const DocumentPage({super.key, required this.id});

  @override
  State<DocumentPage> createState() => _DocumentPageState();
}

class _DocumentPageState extends State<DocumentPage> {
  StreamSubscription? _docSub, _orderSub;
  Doc? _doc;
  Doc? _order;
  bool _loaded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _docSub = Db.watchDoc(C.documents, widget.id).listen((d) {
      if (!mounted) return;
      setState(() {
        _doc = d;
        _loaded = true;
      });
      final oid = d?.s('orderId') ?? '';
      if (oid.isNotEmpty && _orderSub == null) {
        _orderSub = Db.watchDoc(C.orders, oid).listen((o) {
          if (mounted) setState(() => _order = o);
        }, onError: (_) {});
      }
    }, onError: (_) {
      if (mounted) setState(() => _loaded = true);
    });
  }

  @override
  void dispose() {
    _docSub?.cancel();
    _orderSub?.cancel();
    super.dispose();
  }

  String get _type => _doc?.s('type', 'invoice') ?? 'invoice';
  String get _title => DocType.title[_type] ?? 'Document';
  String get _number => _doc == null ? '' : DocType.number(_doc!);
  String get _email => _order?.s('customerEmail') ?? _doc?.s('customerEmail') ?? '';

  Future<void> _update(Map<String, dynamic> data, String success, {bool silent = false}) async {
    setState(() => _busy = true);
    try {
      await Db.update(C.documents, widget.id, data, label: _number, silent: silent);
      if (mounted) toast(context, success);
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finalize() async {
    final ok = await confirmDialog(context,
        title: 'Finalize $_title $_number?',
        message: _type == 'invoice'
            ? 'Lines and totals will be locked. Payments can still be recorded.'
            : 'The document content will be locked and can no longer be refreshed from the order.',
        confirmLabel: 'Finalize');
    if (ok) await _update({'finalized': true}, '$_title finalized');
  }

  Future<void> _refreshFromOrder() async {
    final o = _order;
    if (o == null) return;
    final total = o.n('total');
    final paid = _type == 'invoice' ? _doc!.n('paid') : o.n('paid');
    await _update({
      'lines': o.maps('lines'),
      'subtotal': o.n('subtotal'),
      'discountTotal': o.n('discountTotal'),
      'taxTotal': o.n('taxTotal'),
      'total': total,
      'deposit': o.n('deposit'),
      'paid': paid,
      'due': OrderX.dueOf(total, paid),
      'paymentStatus': Pricing.paymentStatus(total, paid),
      'customerName': o.s('customerName'),
      'customerId': o.s('customerId'),
    }, 'Updated from order #${o.i('number')}');
  }

  void _print({bool download = false}) {
    final html = buildDocumentHtml(_doc!, _order);
    if (download) {
      Browser.downloadText(html, '$_number.html', 'text/html');
    } else {
      Browser.printHtml(html);
    }
  }

  Future<void> _send() async {
    final d = _doc!;
    final sent = await showEmailDialog(
      context,
      emailContext: DocType.emailContext[_type] ?? 'orders',
      to: _email,
      entityId: widget.id,
      title: 'Send ${_title.toLowerCase()}',
      vars: {
        'document.number': _number,
        'order.number': '${d.i('orderNumber')}',
        'customer.name': d.s('customerName'),
        'company.name': companyName,
      },
      defaultSubject: '$_title {{document.number}} from {{company.name}}',
      defaultBody: 'Hi {{customer.name}},\n\nPlease find $_title {{document.number}} for order #{{order.number}}.'
          '${_type == 'invoice' ? '\nAmount due: ${Fmt.money(d.n('due'))} by ${Fmt.date(d.d('dueDate'))}.' : ''}\n\nKind regards,\n{{company.name}}',
    );
    if (sent) await _update({'sent': true}, 'Marked as sent', silent: true);
  }

  Future<void> _sign() async {
    final c = TextEditingController(text: _doc!.s('customerName'));
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign document'),
        content: SizedBox(
          width: 420,
          child: StatefulBuilder(
            builder: (ctx, setD) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Field(label: 'Full name', controller: c, autofocus: true, onChanged: (_) => setD(() {})),
              const SizedBox(height: 16),
              Container(
                height: 80,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: Text(c.text.isEmpty ? 'Your signature' : c.text,
                    style: GoogleFonts.dancingScript(fontSize: 34, color: c.text.isEmpty ? AppColors.muted : AppColors.primaryDeep)),
              ),
              const SizedBox(height: 10),
              const Text('By signing you agree to the terms of this document.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Sign')),
        ],
      ),
    );
    c.dispose();
    if (name == null || name.isEmpty) return;
    await _update({'signature': {'name': name, 'signedAt': Timestamp.now()}}, 'Document signed');
  }

  void _requestSignature() {
    final to = _email;
    final subject = 'Signature requested: $_title $_number from $companyName';
    final body = 'Hi ${_doc!.s('customerName')},\n\nPlease review $_title $_number for order #${_doc!.i('orderNumber')} '
        'and reply to confirm your signature.\n\nKind regards,\n$companyName';
    Browser.openUrl('mailto:$to?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}');
  }

  Future<void> _recordPayment() async {
    final d = _doc!;
    if (d.s('orderId').isEmpty) {
      toast(context, 'This invoice is not linked to an order', error: true);
      return;
    }
    final p = await showPaymentDialog(context, suggested: d.n('due'));
    if (p == null) return;
    setState(() => _busy = true);
    try {
      await OrderX.recordPayment(
        orderId: d.s('orderId'),
        orderNumber: d.i('orderNumber'),
        amount: p.amount,
        method: p.method,
        kind: p.kind,
        note: p.note.isEmpty ? 'Invoice $_number' : p.note,
        invoiceId: widget.id,
      );
      if (mounted) toast(context, 'Payment recorded');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context,
        title: 'Delete $_title $_number?', message: 'This document will be permanently removed.', confirmLabel: 'Delete', danger: true);
    if (!ok) return;
    final type = _type;
    try {
      await Db.remove(C.documents, widget.id, label: _number);
      if (!mounted) return;
      toast(context, '$_title deleted');
      context.go('/documents?tab=$type');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  Future<void> _togglePacked(String lineId) async {
    final packed = _doc!.l<String>('packed').toSet();
    packed.contains(lineId) ? packed.remove(lineId) : packed.add(lineId);
    try {
      await Db.update(C.documents, widget.id, {'packed': packed.toList()}, silent: true);
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const LoadingView();
    final d = _doc;
    if (d == null) {
      return EmptyState(
        icon: Icons.search_off,
        title: 'Document not found',
        message: 'It may have been deleted.',
        actionLabel: 'Back to documents',
        onAction: () => context.go('/documents'),
      );
    }
    final type = _type;
    return Column(children: [
      PageHeader(
        title: '$_title $_number',
        breadcrumbs: [('Documents', '/documents?tab=$type'), (DocType.plural[type]!, '/documents?tab=$type')],
        titleTrailing: Wrap(spacing: 6, children: [
          if (d.b('finalized')) const StatusPill('finalized') else const StatusPill('draft'),
          if (d.b('sent')) const StatusPill('sent'),
        ]),
        actions: _actions(d),
      ),
      Expanded(
        child: PageBody(maxWidth: 1240, children: [
          DetailLayout(main: _Paper(child: _paperContent(d)).enter(1), side: _side(d)),
        ]),
      ),
    ]);
  }

  List<Widget> _actions(Doc d) {
    final type = _type;
    return [
      if (!d.b('finalized'))
        OutlinedButton.icon(onPressed: _busy ? null : _finalize, icon: const Icon(Icons.lock_outline, size: 18), label: const Text('Finalize')),
      if (type == 'invoice')
        OutlinedButton.icon(onPressed: _busy ? null : _recordPayment, icon: const Icon(Icons.payments_outlined, size: 18), label: const Text('Record payment')),
      OutlinedButton.icon(onPressed: () => _print(), icon: const Icon(Icons.print_outlined, size: 18), label: const Text('Print')),
      FilledButton.icon(onPressed: _busy ? null : _send, icon: const Icon(Icons.send_rounded, size: 18), label: const Text('Send')),
      PopupMenuButton<String>(
        tooltip: 'More actions',
        icon: const Icon(Icons.more_horiz),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: (v) {
          switch (v) {
            case 'download':
              _print(download: true);
            case 'sent':
              _update({'sent': !d.b('sent')}, d.b('sent') ? 'Marked as not sent' : 'Marked as sent');
            case 'refresh':
              _refreshFromOrder();
            case 'delete':
              _delete();
          }
        },
        itemBuilder: (_) => [
          _menuItem('download', 'Download HTML', Icons.download_outlined),
          _menuItem('sent', d.b('sent') ? 'Mark as not sent' : 'Mark as sent', Icons.mark_email_read_outlined),
          if (!d.b('finalized') && _order != null) _menuItem('refresh', 'Update from order', Icons.sync),
          _menuItem('delete', 'Delete', Icons.delete_outline, danger: true),
        ],
      ),
    ];
  }

  PopupMenuItem<String> _menuItem(String v, String label, IconData icon, {bool danger = false}) => PopupMenuItem(
        value: v,
        child: Row(children: [
          Icon(icon, size: 18, color: danger ? AppColors.danger : AppColors.inkSoft),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: danger ? AppColors.danger : AppColors.ink)),
        ]),
      );

  List<Widget> _side(Doc d) {
    final o = _order;
    return [
      PanelCard(
        title: 'Order',
        icon: Icons.receipt_long_outlined,
        child: o == null
            ? const Text('The linked order is no longer available.', style: TextStyle(color: AppColors.muted, fontSize: 13))
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: Text(OrderX.label(o), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                  StatusPill(o.s('status', 'draft')),
                ]),
                const SizedBox(height: 6),
                Text(periodText(o.d('startsAt'), o.d('stopsAt')), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => context.go('/orders/${o.id}'),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Open order'),
                ),
              ]),
      ).enter(1),
      if (_type == 'invoice')
        PanelCard(
          title: 'Payment',
          icon: Icons.payments_outlined,
          trailing: StatusPill(d.s('paymentStatus', 'payment_due')),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KV('Total', Fmt.money(d.n('total'))),
            KV('Paid', Fmt.money(d.n('paid')), color: AppColors.success),
            KV('Due', Fmt.money(d.n('due')), bold: true, color: d.n('due') > 0 ? AppColors.danger : null),
            const SizedBox(height: 8),
            FilledButton.icon(onPressed: _busy ? null : _recordPayment, icon: const Icon(Icons.add, size: 18), label: const Text('Record payment')),
          ]),
        ).enter(2),
      TagsCard(collection: C.documents, id: widget.id, tags: d.l<String>('tags')).enter(3),
      NotesCard(entity: 'documents', entityId: widget.id).enter(4),
      ActivityCard(entityId: widget.id).enter(5),
    ];
  }

  // ---- Paper ----
  Widget _paperContent(Doc d) {
    final c = CompanyInfo.current();
    final type = _type;
    final o = _order;
    final t = Theme.of(context).textTheme;
    final brand = _hexColor(c.brandColor);
    final narrow = MediaQuery.sizeOf(context).width < 600;

    final company = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (c.logoUrl.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 52, maxWidth: 180),
            child: Image.network(c.logoUrl, fit: BoxFit.contain, errorBuilder: (_, _, _) => const SizedBox.shrink()),
          ),
        ),
      Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      if (c.address.isNotEmpty) Text(c.address, style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4)),
      if (c.email.isNotEmpty || c.phone.isNotEmpty)
        Text([c.email, c.phone].where((e) => e.isNotEmpty).join(' · '), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
    ]);
    final titleBlock = Column(crossAxisAlignment: narrow ? CrossAxisAlignment.start : CrossAxisAlignment.end, children: [
      Text(_title.toUpperCase(), style: t.headlineSmall?.copyWith(color: brand, letterSpacing: 1.2, fontWeight: FontWeight.w800)),
      Text(_number, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
    ]);

    final meta = Wrap(spacing: 32, runSpacing: 14, children: [
      _meta('Date', Fmt.date(d.d('date') ?? d.created)),
      if (type == 'invoice') _meta('Due date', Fmt.date(d.d('dueDate'))),
      _meta('Order', d.i('orderNumber') > 0 ? '#${d.i('orderNumber')}' : '—'),
      _metaWidget(
        'Reference',
        _InlineEdit(
          value: d.s('reference'),
          placeholder: 'Add reference',
          enabled: !d.b('finalized'),
          onSave: (v) => _update({'reference': v}, 'Reference saved', silent: true),
        ),
      ),
    ]);

    final billing = o == null ? '' : addressText(o.m('billingAddress'));
    final parties = Wrap(spacing: 48, runSpacing: 16, children: [
      _metaWidget(
        'Bill to',
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(d.s('customerName').isEmpty ? 'No customer' : d.s('customerName'), style: const TextStyle(fontWeight: FontWeight.w700)),
          if (billing.isNotEmpty) Text(billing, style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.inkSoft)),
          if (_email.isNotEmpty) Text(_email, style: const TextStyle(fontSize: 13, color: AppColors.inkSoft)),
        ]),
      ),
      if (o != null)
        _metaWidget(
          'Rental period',
          Text('${Fmt.dateTime(o.d('startsAt'))}\n→ ${Fmt.dateTime(o.d('stopsAt'))}', style: const TextStyle(fontSize: 13, height: 1.5)),
        ),
    ]);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      narrow
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [company, const SizedBox(height: 18), titleBlock])
          : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: company), titleBlock]),
      const SizedBox(height: 28),
      meta,
      const SizedBox(height: 24),
      parties,
      const SizedBox(height: 28),
      _linesTable(d, brand),
      if (type != 'packing') ...[
        const SizedBox(height: 16),
        Align(alignment: Alignment.centerRight, child: SizedBox(width: 320, child: _totals(d, brand))),
      ],
      const SizedBox(height: 28),
      const _Label('Notes'),
      _InlineEdit(
        value: d.s('text'),
        placeholder: 'Add terms, instructions or a personal message',
        multiline: true,
        onSave: (v) => _update({'text': v}, 'Text saved', silent: true),
      ),
      if (type == 'quote' || type == 'contract') ...[
        const SizedBox(height: 28),
        _signature(d, brand),
      ],
      const SizedBox(height: 28),
      const Divider(),
      const SizedBox(height: 8),
      _InlineEdit(
        value: d.s('footer'),
        placeholder: 'Add footer (bank details, registration number…)',
        multiline: true,
        center: true,
        onSave: (v) => _update({'footer': v}, 'Footer saved', silent: true),
      ),
    ]);
  }

  static Color _hexColor(String hex) {
    final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    return v == null ? AppColors.primary : Color(0xFF000000 | v);
  }

  Widget _meta(String label, String value) => _metaWidget(label, Text(value, style: const TextStyle(fontWeight: FontWeight.w600)));

  Widget _metaWidget(String label, Widget child) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        _Label(label),
        child,
      ]);

  Widget _linesTable(Doc d, Color brand) {
    final packing = _type == 'packing';
    final lines = d.maps('lines');
    final packed = d.l<String>('packed').toSet();
    const hs = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6);
    Widget row(List<Widget> cells, {Color? bg, bool header = false}) => Container(
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: null,
          child: DefaultTextStyle.merge(style: header ? hs.copyWith(color: brand) : const TextStyle(fontSize: 13), child: Row(children: cells)),
        );
    Widget cell(String s, {double w = 90}) => SizedBox(width: w, child: Text(s, textAlign: TextAlign.right));

    final table = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      row(
        packing
            ? [const SizedBox(width: 40), cell('QTY', w: 50), const SizedBox(width: 16), const Expanded(child: Text('ITEM'))]
            : [cell('QTY', w: 50), const SizedBox(width: 16), const Expanded(child: Text('ITEM')), cell('PRICE'), cell('TAX', w: 60), cell('TOTAL', w: 100)],
        bg: brand.withValues(alpha: 0.08),
        header: true,
      ),
      if (lines.isEmpty)
        const Padding(padding: EdgeInsets.all(16), child: Text('No lines', style: TextStyle(color: AppColors.muted))),
      for (final l in lines)
        Container(
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEEE9F7)))),
          child: row(packing
              ? [
                  SizedBox(
                    width: 40,
                    child: Checkbox(
                      value: packed.contains(l['id']),
                      visualDensity: VisualDensity.compact,
                      onChanged: l['id'] == null ? null : (_) => _togglePacked('${l['id']}'),
                    ),
                  ),
                  cell('${l['qty'] ?? 1}', w: 50),
                  const SizedBox(width: 16),
                  Expanded(child: Text('${l['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600))),
                ]
              : [
                  cell('${l['qty'] ?? 1}', w: 50),
                  const SizedBox(width: 16),
                  Expanded(child: Text('${l['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600))),
                  cell(Fmt.money(l['unitPrice'] as num?)),
                  cell(((l['taxRate'] as num?) ?? 0) > 0 ? '${l['taxRate']}%' : '—', w: 60),
                  cell(Fmt.money(l['total'] as num?), w: 100),
                ]),
        ),
    ]);
    return LayoutBuilder(builder: (context, c) {
      final min = packing ? 300.0 : 520.0;
      if (c.maxWidth >= min) return table;
      return SingleChildScrollView(scrollDirection: Axis.horizontal, child: SizedBox(width: min, child: table));
    });
  }

  Widget _totals(Doc d, Color brand) {
    final invoice = _type == 'invoice';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      KV('Subtotal', Fmt.money(d.n('subtotal'))),
      if (d.n('discountTotal') > 0) KV('Discount', '-${Fmt.money(d.n('discountTotal'))}'),
      KV('Tax', Fmt.money(d.n('taxTotal'))),
      Divider(color: brand, thickness: 1.5, height: 14),
      KV('Total incl. taxes', Fmt.money(d.n('total')), bold: true),
      if (d.n('deposit') > 0) KV('Security deposit', Fmt.money(d.n('deposit')), color: AppColors.inkSoft),
      if (invoice) ...[
        KV('Paid', Fmt.money(d.n('paid')), color: AppColors.success),
        KV('Due', Fmt.money(d.n('due')), bold: true, color: d.n('due') > 0 ? AppColors.danger : AppColors.ink),
      ],
    ]);
  }

  Widget _signature(Doc d, Color brand) {
    final sig = d.m('signature');
    final signed = (sig['name'] ?? '').toString().isNotEmpty;
    return Wrap(spacing: 24, runSpacing: 16, crossAxisAlignment: WrapCrossAlignment.end, children: [
      SizedBox(
        width: 280,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _Label('Signature'),
          Container(
            height: 64,
            alignment: Alignment.bottomLeft,
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.ink))),
            child: signed
                ? Text('${sig['name']}', style: GoogleFonts.dancingScript(fontSize: 34, color: brand)).pop()
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 6),
          Text(
            signed ? 'Signed by ${sig['name']} on ${Fmt.dateTime(Doc.toDate(sig['signedAt']))}' : 'Awaiting signature',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ]),
      ),
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton.icon(
          onPressed: _busy ? null : _sign,
          icon: const Icon(Icons.draw_outlined, size: 18),
          label: Text(signed ? 'Sign again' : 'Sign now'),
        ),
        if (!signed)
          OutlinedButton.icon(
            onPressed: _requestSignature,
            icon: const Icon(Icons.forward_to_inbox_outlined, size: 18),
            label: const Text('Request signature'),
          ),
      ]),
    ]);
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text.toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.muted)),
      );
}

/// A4-like white sheet.
class _Paper extends StatelessWidget {
  final Widget child;
  const _Paper({required this.child});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, minHeight: 600),
        child: Container(
          padding: EdgeInsets.all(narrow ? 18 : 44),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: const Border(top: BorderSide(color: AppColors.primary, width: 5)),
            boxShadow: const [
              BoxShadow(color: Color(0x141C0938), blurRadius: 30, offset: Offset(0, 12)),
              BoxShadow(color: Color(0x0A1C0938), blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Click-to-edit text with save / cancel.
class _InlineEdit extends StatefulWidget {
  final String value;
  final String placeholder;
  final bool multiline;
  final bool center;
  final bool enabled;
  final Future<void> Function(String) onSave;
  const _InlineEdit({
    required this.value,
    required this.placeholder,
    required this.onSave,
    this.multiline = false,
    this.center = false,
    this.enabled = true,
  });

  @override
  State<_InlineEdit> createState() => _InlineEditState();
}

class _InlineEditState extends State<_InlineEdit> {
  bool _editing = false;
  late final _c = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant _InlineEdit old) {
    super.didUpdateWidget(old);
    if (!_editing && old.value != widget.value) _c.text = widget.value;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _editing = false);
    if (_c.text.trim() != widget.value) await widget.onSave(_c.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: widget.multiline ? double.infinity : 260),
          child: TextField(
            controller: _c,
            autofocus: true,
            minLines: widget.multiline ? 3 : 1,
            maxLines: widget.multiline ? 8 : 1,
            onSubmitted: widget.multiline ? null : (_) => _save(),
          ),
        ),
        const SizedBox(height: 6),
        Row(mainAxisSize: MainAxisSize.min, children: [
          TextButton(
            onPressed: () => setState(() {
              _c.text = widget.value;
              _editing = false;
            }),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 6),
          FilledButton(
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
            onPressed: _save,
            child: const Text('Save'),
          ),
        ]),
      ]);
    }
    final empty = widget.value.isEmpty;
    final text = Text(
      empty ? (widget.enabled ? widget.placeholder : '—') : widget.value,
      textAlign: widget.center ? TextAlign.center : TextAlign.start,
      style: TextStyle(
        height: 1.5,
        fontSize: widget.multiline ? 13 : 14,
        fontWeight: widget.multiline ? FontWeight.w400 : FontWeight.w600,
        color: empty ? AppColors.muted : (widget.center ? AppColors.muted : AppColors.ink),
        fontStyle: empty ? FontStyle.italic : FontStyle.normal,
      ),
    );
    if (!widget.enabled) return text;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _editing = true),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: widget.multiline ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: widget.center ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Flexible(child: text),
            const SizedBox(width: 6),
            const Icon(Icons.edit_outlined, size: 14, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
