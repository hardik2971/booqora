import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart' hide Thumb;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';

import '../../core/browser.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/payments.dart';
import '../../data/pricing.dart';
import '../../data/schema.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/mobile.dart';
import '../../widgets/side_panel.dart';
import '../orders/order_sheets.dart';
import '../orders/order_shared.dart';
import 'doc_pdf.dart';

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
  String? _pdfBusy; // 'share' | 'print'

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
      HapticFeedback.lightImpact();
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
    if (ok) {
      HapticFeedback.mediumImpact();
      await _update({'finalized': true}, '$_title finalized');
    }
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

  Future<void> _sharePdf() async {
    final d = _doc;
    if (d == null) return;
    HapticFeedback.lightImpact();
    setState(() => _pdfBusy = 'share');
    try {
      final bytes = await buildDocumentPdf(d, _order);
      await Printing.sharePdf(bytes: bytes, filename: '$_number.pdf', subject: '$_title $_number — $companyName');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _pdfBusy = null);
    }
  }

  Future<void> _print() async {
    final d = _doc;
    if (d == null) return;
    HapticFeedback.lightImpact();
    setState(() => _pdfBusy = 'print');
    try {
      final order = _order;
      await Printing.layoutPdf(name: '$_title $_number', onLayout: (format) => buildDocumentPdf(d, order, format: format));
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _pdfBusy = null);
    }
  }

  String _summary(Doc d) {
    final b = StringBuffer();
    for (final l in d.maps('lines')) {
      final qty = (l['qty'] as num?) ?? 1;
      b.writeln(_type == 'packing' ? '• ${fmtNum(qty)} × ${l['name'] ?? ''}' : '• ${fmtNum(qty)} × ${l['name'] ?? ''} — ${Fmt.money(l['total'] as num?)}');
    }
    if (_type != 'packing') {
      b.writeln();
      if (d.n('discountTotal') > 0) b.writeln('Discount: -${Fmt.money(d.n('discountTotal'))}');
      b.writeln('Tax: ${Fmt.money(d.n('taxTotal'))}');
      b.writeln('Total: ${Fmt.money(d.n('total'))}');
      if (d.n('deposit') > 0) b.writeln('Security deposit: ${Fmt.money(d.n('deposit'))}');
      if (_type == 'invoice') b.writeln('Amount due: ${Fmt.money(d.n('due'))} by ${Fmt.date(d.d('dueDate'))}');
    }
    final o = _order;
    if (o != null) b.writeln('Rental period: ${periodText(o.d('startsAt'), o.d('stopsAt'))}');
    return b.toString().trimRight();
  }

  Future<void> _send() async {
    final d = _doc!;
    final sent = await showEmailSheet(
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
      defaultBody: 'Hi {{customer.name}},\n\nPlease find $_title {{document.number}} for order #{{order.number}} below.\n\n'
          '${_summary(d)}\n\nKind regards,\n{{company.name}}',
    );
    if (sent && !d.b('sent')) await _update({'sent': true}, 'Marked as sent', silent: true);
  }

  Future<void> _sign() async {
    final c = TextEditingController(text: _doc!.s('customerName'));
    final name = await showAppSheet<String>(
      context,
      title: 'Sign ${_title.toLowerCase()}',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Field(label: 'Full name', controller: c, autofocus: true, onChanged: (_) => setD(() {})),
          const SizedBox(height: 16),
          Container(
            height: 110,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: FittedBox(
                key: ValueKey(c.text),
                fit: BoxFit.scaleDown,
                child: Text(c.text.isEmpty ? 'Your signature' : c.text,
                    style: GoogleFonts.dancingScript(fontSize: 40, color: c.text.isEmpty ? AppColors.muted : CompanyInfo.current().brand)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text('By signing you agree to the terms of this document.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 20),
          GradientButton(label: 'Sign document', icon: Icons.draw_outlined, onPressed: () => Navigator.pop(ctx, c.text.trim())),
        ]),
      ),
    );
    c.dispose();
    if (name == null || name.isEmpty) return;
    HapticFeedback.heavyImpact();
    await _update({
      'signature': {'name': name, 'signedAt': Timestamp.now()}
    }, 'Document signed');
  }

  Future<void> _requestSignature() async {
    final to = _email;
    final subject = 'Signature requested: $_title $_number from $companyName';
    final body = 'Hi ${_doc!.s('customerName')},\n\nPlease review $_title $_number for order #${_doc!.i('orderNumber')} '
        'and reply to confirm your signature.\n\n${_summary(_doc!)}\n\nKind regards,\n$companyName';
    if (!to.contains('@')) {
      toast(context, 'Add an email address to the customer first', error: true);
      return;
    }
    try {
      await Payments.sendEmail(workspaceId: Db.wid, to: to, subject: subject, body: body, context: 'documents', entityId: _doc!.id);
      if (mounted) toast(context, 'Signature request sent to $to');
    } catch (e) {
      if (!mounted) return;
      toast(context, '${friendlyError(e)} — opening your mail app instead', error: true);
      Browser.openUrl('mailto:$to?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}');
    }
  }

  Future<void> _recordPayment() async {
    final d = _doc!;
    if (d.s('orderId').isEmpty) {
      toast(context, 'This invoice is not linked to an order', error: true);
      return;
    }
    final p = await showPaymentSheet(context, suggested: d.n('due'));
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
      if (mounted) toast(context, p.kind == 'refund' ? 'Refund recorded' : 'Payment recorded');
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
    try {
      await Db.remove(C.documents, widget.id, label: _number);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      toast(context, '$_title deleted');
      Navigator.of(context).maybePop();
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  Future<void> _togglePacked(String lineId) async {
    HapticFeedback.selectionClick();
    final packed = _doc!.l<String>('packed').toSet();
    packed.contains(lineId) ? packed.remove(lineId) : packed.add(lineId);
    try {
      await Db.update(C.documents, widget.id, {'packed': packed.toList()}, silent: true);
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  Future<void> _editText(String title, String key, String value, {bool multiline = false, String hint = ''}) async {
    final c = TextEditingController(text: value);
    final r = await showAppSheet<String>(
      context,
      title: title,
      builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Field(label: '', controller: c, autofocus: true, hint: hint, maxLines: multiline ? 6 : 1),
        const SizedBox(height: 20),
        GradientButton(label: 'Save', icon: Icons.check_rounded, onPressed: () => Navigator.pop(ctx, c.text.trim())),
      ]),
    );
    c.dispose();
    if (r == null || r == value) return;
    await _update({key: r}, '$title saved', silent: true);
  }

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final d = _doc;
    if (!_loaded || d == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: _appBar(_loaded ? 'Document' : '', null),
        body: !_loaded
            ? const Padding(padding: EdgeInsets.all(16), child: Skeleton(height: 520, radius: 18))
            : EmptyState(
                icon: Icons.search_off,
                title: 'Document not found',
                message: 'It may have been deleted.',
                actionLabel: 'Back to documents',
                onAction: () => context.pushReplacement('/documents'),
              ),
      );
    }
    final children = <Widget>[
      Wrap(spacing: 6, runSpacing: 6, children: [
        StatusPill(d.b('finalized') ? 'finalized' : 'draft'),
        if (d.b('sent')) const StatusPill('sent') else const StatusPill('not_sent', label: 'Not sent'),
        if (_type == 'invoice') StatusPill(d.s('paymentStatus', 'payment_due')),
      ]),
      if (!d.b('finalized'))
        InfoBanner('Draft — content can still change. Finalize to lock it.', tone: Tone.brand, icon: Icons.edit_note_rounded, actionLabel: 'Finalize', onAction: _busy ? null : _finalize),
      _Paper(brand: CompanyInfo.current().brand, child: _paperContent(d)),
      if (_type == 'invoice') _paymentCard(d),
      _orderCard(),
      TagsCard(collection: C.documents, id: widget.id, tags: d.l<String>('tags')),
      NotesCard(entity: 'documents', entityId: widget.id),
      ActivityCard(entityId: widget.id),
    ];
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _appBar('$_title $_number', d),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          for (var i = 0; i < children.length; i++) Padding(padding: const EdgeInsets.only(bottom: 14), child: children[i].enter(i, 0.04)),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [BoxShadow(color: Color(0x141C0938), blurRadius: 18, offset: Offset(0, -6))],
        ),
        child: Row(children: [
          SquareIconButton(icon: _pdfBusy == 'print' ? Icons.hourglass_top_rounded : Icons.print_outlined, tooltip: 'Print', onTap: _pdfBusy == null ? _print : () {}),
          const SizedBox(width: 10),
          SquareIconButton(icon: Icons.send_rounded, tooltip: 'Send by email', onTap: _busy ? () {} : _send),
          const SizedBox(width: 12),
          Expanded(child: GradientButton(label: 'Share PDF', icon: Icons.picture_as_pdf_outlined, busy: _pdfBusy == 'share', onPressed: _pdfBusy == null ? _sharePdf : null)),
        ]),
      ),
    );
  }

  PreferredSizeWidget _appBar(String title, Doc? d) => AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => Navigator.of(context).maybePop()),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (d != null) IconButton(tooltip: 'More actions', icon: const Icon(Icons.more_horiz_rounded), onPressed: () => _moreMenu(d)),
          const SizedBox(width: 4),
        ],
      );

  Future<void> _moreMenu(Doc d) async {
    HapticFeedback.selectionClick();
    final signable = _type == 'quote' || _type == 'contract';
    final items = <(String, String, IconData, bool)>[
      if (!d.b('finalized')) ('finalize', 'Finalize', Icons.lock_outline_rounded, false),
      if (_type == 'invoice') ('payment', 'Record payment', Icons.payments_outlined, false),
      if (signable) ('sign', 'Sign now', Icons.draw_outlined, false),
      if (signable && (d.m('signature')['name'] ?? '').toString().isEmpty) ('request', 'Request signature', Icons.forward_to_inbox_outlined, false),
      ('sent', d.b('sent') ? 'Mark as not sent' : 'Mark as sent', Icons.mark_email_read_outlined, false),
      if (!d.b('finalized') && _order != null) ('refresh', 'Update from order', Icons.sync_rounded, false),
      ('print', 'Print', Icons.print_outlined, false),
      ('delete', 'Delete', Icons.delete_outline_rounded, true),
    ];
    final v = await showAppSheet<String>(
      context,
      title: '$_title $_number',
      builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < items.length; i++)
          NavRow(
            icon: items[i].$3,
            title: items[i].$2,
            color: items[i].$4 ? AppColors.danger : AppColors.primary,
            trailing: const SizedBox.shrink(),
            onTap: () => Navigator.pop(ctx, items[i].$1),
          ).enterX(i),
      ]),
    );
    if (v == null || !mounted) return;
    switch (v) {
      case 'finalize':
        await _finalize();
      case 'payment':
        await _recordPayment();
      case 'sign':
        await _sign();
      case 'request':
        await _requestSignature();
      case 'sent':
        await _update({'sent': !d.b('sent')}, d.b('sent') ? 'Marked as not sent' : 'Marked as sent');
      case 'refresh':
        await _refreshFromOrder();
      case 'print':
        await _print();
      case 'delete':
        await _delete();
    }
  }

  Widget _orderCard() {
    final o = _order;
    return PanelCard(
      title: 'Order',
      icon: Icons.receipt_long_outlined,
      child: o == null
          ? const Text('The linked order is no longer available.', style: TextStyle(color: AppColors.muted, fontSize: 13))
          : PressScale(
              onTap: () => context.push('/orders/${o.id}'),
              child: Row(children: [
                Avatar(o.s('customerName').isEmpty ? '?' : o.s('customerName'), size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(OrderX.label(o), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(width: 8),
                      StatusPill(o.s('status', 'draft')),
                    ]),
                    const SizedBox(height: 4),
                    Text(periodText(o.d('startsAt'), o.d('stopsAt')),
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
              ]),
            ),
    );
  }

  Widget _paymentCard(Doc d) {
    final total = d.n('total');
    final paid = d.n('paid');
    final ratio = total <= 0 ? 1.0 : (paid / total).clamp(0, 1).toDouble();
    return PanelCard(
      title: 'Payment',
      icon: Icons.payments_outlined,
      trailing: StatusPill(d.s('paymentStatus', 'payment_due')),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: ratio),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder: (_, v, _) => ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: v, minHeight: 8, backgroundColor: AppColors.bg, color: AppColors.success),
          ),
        ),
        const SizedBox(height: 10),
        KV('Total', Fmt.money(total)),
        KV('Paid', Fmt.money(paid), color: AppColors.success),
        KV('Due', Fmt.money(d.n('due')), bold: true, color: d.n('due') > 0 ? AppColors.danger : null),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
          onPressed: _busy ? null : _recordPayment,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Record payment'),
        ),
      ]),
    );
  }

  // ---- Paper ----
  Widget _paperContent(Doc d) {
    final c = CompanyInfo.current();
    final brand = c.brand;
    final type = _type;
    final o = _order;
    final editable = !d.b('finalized');
    final billing = o == null ? '' : addressText(o.m('billingAddress'));

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (c.logoUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 40, maxWidth: 140),
                  child: Image.network(c.logoUrl, fit: BoxFit.contain, errorBuilder: (_, _, _) => const SizedBox.shrink()),
                ),
              ),
            Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            if (c.address.isNotEmpty) Text(c.address, style: const TextStyle(color: AppColors.muted, fontSize: 11, height: 1.4)),
            if (c.email.isNotEmpty || c.phone.isNotEmpty)
              Text([c.email, c.phone].where((e) => e.isNotEmpty).join(' · '), style: const TextStyle(color: AppColors.muted, fontSize: 11)),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_title.toUpperCase(), style: TextStyle(color: brand, letterSpacing: 1.1, fontWeight: FontWeight.w900, fontSize: 17)),
          Text(_number, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700, fontSize: 12)),
        ]),
      ]),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Row(children: [
            Expanded(child: _meta('Date', Text(Fmt.date(d.d('date') ?? d.created), style: _metaStyle))),
            Expanded(
              child: type == 'invoice'
                  ? _meta('Due date', Text(Fmt.date(d.d('dueDate')), style: _metaStyle))
                  : _meta('Order', Text(d.i('orderNumber') > 0 ? '#${d.i('orderNumber')}' : '—', style: _metaStyle)),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            if (type == 'invoice') Expanded(child: _meta('Order', Text(d.i('orderNumber') > 0 ? '#${d.i('orderNumber')}' : '—', style: _metaStyle))),
            Expanded(
              child: _meta(
                'Reference',
                _Editable(
                  text: d.s('reference'),
                  placeholder: editable ? 'Add reference' : '—',
                  enabled: editable,
                  style: _metaStyle,
                  onTap: () => _editText('Reference', 'reference', d.s('reference'), hint: 'PO number or internal reference'),
                ),
              ),
            ),
          ]),
        ]),
      ),
      const SizedBox(height: 16),
      _meta(
        'Bill to',
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(d.s('customerName').isEmpty ? 'No customer' : d.s('customerName'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          if (billing.isNotEmpty) Text(billing, style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.inkSoft)),
          if (_email.isNotEmpty) Text(_email, style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
        ]),
      ),
      if (o != null) ...[
        const SizedBox(height: 12),
        _meta('Rental period', Text(periodText(o.d('startsAt'), o.d('stopsAt')), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
      ],
      const SizedBox(height: 18),
      _lines(d, brand),
      if (type != 'packing') ...[const SizedBox(height: 12), _totals(d, brand)],
      const SizedBox(height: 18),
      _meta(
        'Notes',
        _Editable(
          text: d.s('text'),
          placeholder: 'Add terms, instructions or a personal message',
          enabled: true,
          multiline: true,
          onTap: () => _editText('Notes', 'text', d.s('text'), multiline: true),
        ),
      ),
      if (type == 'quote' || type == 'contract') ...[const SizedBox(height: 20), _signature(d, brand)],
      const SizedBox(height: 16),
      const Divider(color: AppColors.border),
      _Editable(
        text: d.s('footer'),
        placeholder: 'Add footer (bank details, registration number…)',
        enabled: true,
        multiline: true,
        center: true,
        onTap: () => _editText('Footer', 'footer', d.s('footer'), multiline: true),
      ),
    ]);
  }

  static const _metaStyle = TextStyle(fontWeight: FontWeight.w700, fontSize: 13);

  Widget _meta(String label, Widget child) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.muted)),
        ),
        child,
      ]);

  Widget _lines(Doc d, Color brand) {
    final packing = _type == 'packing';
    final lines = d.maps('lines');
    final packed = d.l<String>('packed').toSet();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: brand.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Expanded(child: Text(packing ? 'ITEM' : 'ITEM', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: brand))),
          Text(packing ? 'PACKED ${packed.length}/${lines.length}' : 'TOTAL',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: brand)),
        ]),
      ),
      if (lines.isEmpty) const Padding(padding: EdgeInsets.all(14), child: Text('No lines', style: TextStyle(color: AppColors.muted))),
      for (final l in lines)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEEE9F7)))),
          child: packing
              ? InkWell(
                  onTap: l['id'] == null ? null : () => _togglePacked('${l['id']}'),
                  child: Row(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: packed.contains(l['id']) ? AppColors.success : Colors.white,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: packed.contains(l['id']) ? AppColors.success : AppColors.border, width: 1.5),
                      ),
                      child: packed.contains(l['id']) ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
                    ),
                    const SizedBox(width: 12),
                    Text('${l['qty'] ?? 1}×', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.inkSoft)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('${l['name'] ?? ''}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            decoration: packed.contains(l['id']) ? TextDecoration.lineThrough : null,
                            color: packed.contains(l['id']) ? AppColors.muted : AppColors.ink,
                          )),
                    ),
                  ]),
                )
              : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${l['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(
                        '${fmtNum((l['qty'] as num?) ?? 1)} × ${Fmt.money(l['unitPrice'] as num?)}'
                        '${((l['taxRate'] as num?) ?? 0) > 0 ? ' · tax ${fmtNum(l['taxRate'] as num)}%' : ''}',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Text(Fmt.money(l['total'] as num?), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ]),
        ),
    ]);
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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _meta(
        'Signature',
        Container(
          height: 64,
          width: double.infinity,
          alignment: Alignment.bottomLeft,
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.ink))),
          child: signed
              ? FittedBox(fit: BoxFit.scaleDown, child: Text('${sig['name']}', style: GoogleFonts.dancingScript(fontSize: 34, color: brand))).pop()
              : const SizedBox.shrink(),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        signed ? 'Signed by ${sig['name']} on ${Fmt.dateTime(Doc.toDate(sig['signedAt']))}' : 'Awaiting signature',
        style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _busy ? null : _sign,
            icon: const Icon(Icons.draw_outlined, size: 18),
            label: Text(signed ? 'Sign again' : 'Sign now'),
          ),
        ),
        if (!signed) ...[
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _requestSignature,
              icon: const Icon(Icons.forward_to_inbox_outlined, size: 18),
              label: const Text('Request', overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ]),
    ]);
  }
}

/// Paper-style sheet with a brand-coloured top edge.
class _Paper extends StatelessWidget {
  final Widget child;
  final Color brand;
  const _Paper({required this.child, required this.brand});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x1A1C0938), blurRadius: 30, offset: Offset(0, 14)),
          BoxShadow(color: Color(0x0A1C0938), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(height: 6, color: brand),
        Padding(padding: const EdgeInsets.fromLTRB(18, 18, 18, 18), child: child),
      ]),
    );
  }
}

/// Tap-to-edit text on the paper preview.
class _Editable extends StatelessWidget {
  final String text;
  final String placeholder;
  final bool enabled;
  final bool multiline;
  final bool center;
  final TextStyle? style;
  final VoidCallback onTap;
  const _Editable({required this.text, required this.placeholder, required this.enabled, required this.onTap, this.multiline = false, this.center = false, this.style});

  @override
  Widget build(BuildContext context) {
    final empty = text.isEmpty;
    final t = Text(
      empty ? placeholder : text,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: (style ?? const TextStyle()).copyWith(
        height: 1.45,
        fontSize: multiline ? 12.5 : style?.fontSize,
        fontWeight: multiline ? FontWeight.w400 : style?.fontWeight,
        color: empty ? AppColors.muted : (center ? AppColors.muted : AppColors.ink),
        fontStyle: empty ? FontStyle.italic : FontStyle.normal,
      ),
    );
    if (!enabled) return t;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: multiline ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: center ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Flexible(child: t),
            const SizedBox(width: 6),
            const Icon(Icons.edit_outlined, size: 13, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
