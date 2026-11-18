import 'package:flutter/material.dart';

import '../../core/browser.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/payments.dart';
import '../../data/schema.dart';
import '../../data/session.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import 'order_shared.dart';

/// Shared dialog shell with a constrained width.
class _DialogShell extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget> actions;
  final double width;
  const _DialogShell({required this.title, required this.child, required this.actions, this.width = 480});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return AlertDialog(
      title: Text(title),
      insetPadding: EdgeInsets.symmetric(horizontal: w < 500 ? 12 : 40, vertical: 24),
      content: SizedBox(width: width, child: SingleChildScrollView(child: child)),
      actions: actions,
    );
  }
}

// ---------------------------------------------------------------------------
// Customer picker
// ---------------------------------------------------------------------------

/// Result of the customer picker: either an existing/new customer doc.
Future<Doc?> showCustomerPicker(BuildContext context, List<Doc> customers) =>
    showDialog<Doc>(context: context, builder: (_) => _CustomerPicker(customers: customers));

class _CustomerPicker extends StatefulWidget {
  final List<Doc> customers;
  const _CustomerPicker({required this.customers});

  @override
  State<_CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends State<_CustomerPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase();
    final list = widget.customers
        .where((c) => q.isEmpty || '${c.s('name')} ${c.s('email')} ${c.s('phone')}'.toLowerCase().contains(q))
        .take(40)
        .toList();
    return _DialogShell(
      title: 'Select customer',
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        FilledButton.icon(
          icon: const Icon(Icons.person_add_alt, size: 18),
          label: const Text('New customer'),
          onPressed: () async {
            final c = await showNewCustomerDialog(context, name: _q);
            if (c != null && context.mounted) Navigator.pop(context, c);
          },
        ),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Search by name, email or phone', prefixIcon: Icon(Icons.search, size: 20)),
          onChanged: (v) => setState(() => _q = v.trim()),
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          const EmptyState(
            icon: Icons.person_search_outlined,
            title: 'No customers found',
            message: 'Create a new customer to attach to this order.',
            compact: true,
          )
        else
          for (final c in list)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              leading: Avatar(c.s('name'), size: 36),
              title: Text(c.s('name'), style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text([c.s('email'), c.s('phone')].where((e) => e.isNotEmpty).join(' · '),
                  overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              trailing: c.n('discountPercent') > 0 ? StatusPill('active', label: '${c.n('discountPercent')}% off', dot: false) : null,
              onTap: () => Navigator.pop(context, c),
            ),
      ]),
    );
  }
}

/// Quick-create customer dialog. Writes to `customers` and returns the new doc.
Future<Doc?> showNewCustomerDialog(BuildContext context, {String name = '', String email = '', String phone = ''}) =>
    showDialog<Doc>(context: context, builder: (_) => _NewCustomer(name: name, email: email, phone: phone));

class _NewCustomer extends StatefulWidget {
  final String name, email, phone;
  const _NewCustomer({required this.name, required this.email, required this.phone});

  @override
  State<_NewCustomer> createState() => _NewCustomerState();
}

class _NewCustomerState extends State<_NewCustomer> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.name);
  late final _email = TextEditingController(text: widget.email);
  late final _phone = TextEditingController(text: widget.phone);
  String _type = 'individual';
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final data = <String, dynamic>{
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'type': _type,
        'marketing': false,
        'discountPercent': 0,
        'depositMode': 'default',
        'depositValue': 0,
        'addresses': <Map<String, dynamic>>[],
        'balanceDue': 0,
        'orderCount': 0,
        'revenue': 0,
        'tags': <String>[],
      };
      final id = await Db.create(C.customers, data, numberKey: 'customer');
      if (!mounted) return;
      toast(context, 'Customer created');
      Navigator.pop(context, Doc(id, data));
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DialogShell(
      title: 'New customer',
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Create customer')),
      ],
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          RadioCards<String>(
            value: _type,
            horizontal: false,
            options: const [('individual', 'Individual', null), ('company', 'Company', null)],
            onChanged: (v) => setState(() => _type = v),
          ),
          const SizedBox(height: 6),
          Field(label: _type == 'company' ? 'Company name' : 'Full name', controller: _name, required: true, autofocus: true),
          const SizedBox(height: 14),
          Field(
            label: 'Email',
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            validator: (v) => (v != null && v.trim().isNotEmpty && !v.contains('@')) ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 14),
          Field(label: 'Phone', controller: _phone, keyboardType: TextInputType.phone),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Address
// ---------------------------------------------------------------------------

String addressText(Map<String, dynamic> a) {
  if (a.isEmpty) return '';
  final name = '${a['firstName'] ?? ''} ${a['lastName'] ?? ''}'.trim();
  final cityLine = [a['zip'], a['city'], a['state']].where((e) => e != null && '$e'.isNotEmpty).join(' ');
  return [name, a['line1'], a['line2'], cityLine, a['country']].where((e) => e != null && '$e'.trim().isNotEmpty).join('\n');
}

Future<Map<String, dynamic>?> showAddressDialog(BuildContext context, String title, Map<String, dynamic> initial) =>
    showDialog<Map<String, dynamic>>(context: context, builder: (_) => _AddressDialog(title: title, initial: initial));

class _AddressDialog extends StatefulWidget {
  final String title;
  final Map<String, dynamic> initial;
  const _AddressDialog({required this.title, required this.initial});

  @override
  State<_AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends State<_AddressDialog> {
  static const _keys = ['country', 'firstName', 'lastName', 'line1', 'line2', 'city', 'state', 'zip'];
  static const _labels = {
    'country': 'Country',
    'firstName': 'First name',
    'lastName': 'Last name',
    'line1': 'Address line 1',
    'line2': 'Address line 2',
    'city': 'City',
    'state': 'State / Region',
    'zip': 'Postal code',
  };
  late final Map<String, TextEditingController> _c = {
    for (final k in _keys) k: TextEditingController(text: '${widget.initial[k] ?? (k == 'country' ? (Session.instance.setting('general', 'country', '') ?? '') : '')}'),
  };

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _DialogShell(
      title: widget.title,
      width: 560,
      actions: [
        if (widget.initial.isNotEmpty)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, <String, dynamic>{}),
            child: const Text('Remove'),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, {for (final k in _keys) k: _c[k]!.text.trim()}),
          child: const Text('Save address'),
        ),
      ],
      child: FieldGrid(children: [for (final k in _keys) Field(label: _labels[k]!, controller: _c[k])]),
    );
  }
}

// ---------------------------------------------------------------------------
// Payment
// ---------------------------------------------------------------------------

typedef PaymentInput = ({num amount, String method, String kind, String note});

Future<PaymentInput?> showPaymentDialog(BuildContext context, {num suggested = 0}) =>
    showDialog<PaymentInput>(context: context, builder: (_) => _PaymentDialog(suggested: suggested));

class _PaymentDialog extends StatefulWidget {
  final num suggested;
  const _PaymentDialog({required this.suggested});

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  late final _amount = TextEditingController(text: widget.suggested > 0 ? widget.suggested.toStringAsFixed(2) : '');
  final _note = TextEditingController();
  String _method = 'cash';
  String _kind = 'charge';

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _DialogShell(
      title: 'Add payment',
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final a = parseNum(_amount.text);
            if (a <= 0) {
              toast(context, 'Enter an amount greater than zero', error: true);
              return;
            }
            Navigator.pop<PaymentInput>(context, (amount: a, method: _method, kind: _kind, note: _note.text.trim()));
          },
          child: const Text('Record payment'),
        ),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Field.money(label: 'Amount', controller: _amount),
        const SizedBox(height: 14),
        FieldGrid(children: [
          DropdownX<String>(
            label: 'Method',
            value: _method,
            items: const {'cash': 'Cash', 'card': 'Card', 'bank': 'Bank transfer', 'upi': 'UPI'},
            onChanged: (v) => setState(() => _method = v ?? 'cash'),
          ),
          DropdownX<String>(
            label: 'Type',
            value: _kind,
            items: const {'charge': 'Charge', 'refund': 'Refund', 'deposit': 'Security deposit'},
            onChanged: (v) => setState(() => _kind = v ?? 'charge'),
          ),
        ]),
        const SizedBox(height: 14),
        Field(label: 'Note', controller: _note, hint: 'Optional reference or remark'),
        if (_kind == 'deposit') ...[
          const SizedBox(height: 12),
          const InfoBanner('Deposits are held separately and do not reduce the amount due.', tone: Tone.brand),
        ],
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Email
// ---------------------------------------------------------------------------

/// Composes an email from templates of [emailContext], logs it to `emailLog`
/// and opens a mailto: link. Returns true when sent.
Future<bool> showEmailDialog(
  BuildContext context, {
  required String emailContext,
  required String to,
  required Map<String, String> vars,
  required String entityId,
  String defaultSubject = '',
  String defaultBody = '',
  String title = 'Send email',
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (_) => _EmailDialog(
      emailContext: emailContext,
      to: to,
      vars: vars,
      entityId: entityId,
      defaultSubject: defaultSubject,
      defaultBody: defaultBody,
      title: title,
    ),
  );
  return r == true;
}

class _EmailDialog extends StatefulWidget {
  final String emailContext, to, entityId, defaultSubject, defaultBody, title;
  final Map<String, String> vars;
  const _EmailDialog({
    required this.emailContext,
    required this.to,
    required this.vars,
    required this.entityId,
    required this.defaultSubject,
    required this.defaultBody,
    required this.title,
  });

  @override
  State<_EmailDialog> createState() => _EmailDialogState();
}

class _EmailDialogState extends State<_EmailDialog> {
  late final _to = TextEditingController(text: widget.to);
  late final _subject = TextEditingController(text: fillTemplate(widget.defaultSubject, widget.vars));
  late final _body = TextEditingController(text: fillTemplate(widget.defaultBody, widget.vars));
  List<Doc> _templates = [];
  String? _templateId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final t = (await Db.listWhere(C.emailTemplates, 'context', widget.emailContext)).where((e) => e.data['enabled'] != false).toList();
      if (!mounted) return;
      setState(() => _templates = t);
      if (t.isNotEmpty) _apply(t.first);
    } catch (_) {}
  }

  void _apply(Doc t) {
    setState(() {
      _templateId = t.id;
      _subject.text = fillTemplate(t.s('subject'), widget.vars);
      _body.text = fillTemplate(t.s('body'), widget.vars);
    });
  }

  @override
  void dispose() {
    _to.dispose();
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final to = _to.text.trim();
    if (!to.contains('@')) {
      toast(context, 'Enter a valid recipient email', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      // Sent server-side over SMTP; the function also writes the email log.
      await Payments.sendEmail(
        workspaceId: Db.wid,
        to: to,
        subject: _subject.text.trim(),
        body: _body.text,
        context: widget.emailContext,
        entityId: widget.entityId,
      );
      if (!mounted) return;
      toast(context, 'Email sent to $to');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final useMailApp = await confirmDialog(context,
          title: "Email couldn't be sent",
          message: '${friendlyError(e)}\n\nOpen it in your own mail app instead?',
          confirmLabel: 'Open mail app');
      if (useMailApp) {
        Browser.openUrl('mailto:$to?subject=${Uri.encodeComponent(_subject.text.trim())}&body=${Uri.encodeComponent(_body.text)}');
        if (mounted) Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DialogShell(
      title: widget.title,
      width: 560,
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton.icon(
          onPressed: _busy ? null : _send,
          icon: const Icon(Icons.send_rounded, size: 18),
          label: const Text('Send'),
        ),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_templates.isNotEmpty) ...[
          DropdownX<String>(
            key: ValueKey(_templateId),
            label: 'Template',
            value: _templateId,
            items: {for (final t in _templates) t.id: t.s('name')},
            onChanged: (v) {
              final t = _templates.where((e) => e.id == v).firstOrNull;
              if (t != null) _apply(t);
            },
          ),
          const SizedBox(height: 14),
        ],
        Field(label: 'To', controller: _to, keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 14),
        Field(label: 'Subject', controller: _subject),
        const SizedBox(height: 14),
        Field(label: 'Message', controller: _body, maxLines: 8),
        const SizedBox(height: 10),
        Text('Opens in your default mail app and is recorded in the email log.',
            style: TextStyle(fontSize: 12, color: AppColors.muted.withValues(alpha: 0.9))),
      ]),
    );
  }
}

/// Formats a short "Fri 12 Jan 09:00 → Sat 13 Jan 17:00" period.
String periodText(DateTime? s, DateTime? e) => '${Fmt.dateTime(s)} → ${Fmt.dateTime(e)}';

/// Human readable duration such as "2 days 4 hours".
String durationText(DateTime? s, DateTime? e) {
  if (s == null || e == null || !e.isAfter(s)) return '—';
  final d = e.difference(s);
  final days = d.inDays, hours = d.inHours % 24, mins = d.inMinutes % 60;
  final parts = <String>[
    if (days > 0) '$days day${days == 1 ? '' : 's'}',
    if (hours > 0) '$hours hour${hours == 1 ? '' : 's'}',
    if (mins > 0 && days == 0) '$mins min',
  ];
  return parts.isEmpty ? '0 min' : parts.join(' ');
}
