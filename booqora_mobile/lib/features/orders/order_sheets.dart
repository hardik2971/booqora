import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/browser.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/payments.dart';
import '../../data/schema.dart';
import '../../data/session.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/mobile.dart';
import 'order_shared.dart';

/// Small rounded icon badge used across order sheets.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const IconBadge(this.icon, {super.key, this.color = AppColors.primary, this.size = 40});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.07)]),
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: Icon(icon, color: color, size: size * 0.5),
      );
}

/// Selectable chip with icon (single choice rows inside sheets).
class OptionChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final Color color;
  const OptionChip({super.key, required this.label, this.icon, required this.selected, required this.onTap, this.color = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? color : AppColors.border, width: selected ? 1.6 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 18, color: selected ? color : AppColors.inkSoft), const SizedBox(width: 8)],
          Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: selected ? color : AppColors.inkSoft)),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Customer picker
// ---------------------------------------------------------------------------

Future<Doc?> showCustomerPickerSheet(BuildContext context, List<Doc> customers) =>
    showAppSheet<Doc>(context, title: 'Select customer', scroll: false, builder: (_) => _CustomerPicker(customers: customers));

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
        .take(60)
        .toList();
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      MSearch(hint: 'Name, email or phone', onChanged: (v) => setState(() => _q = v.trim())),
      const SizedBox(height: 12),
      PressScale(
        onTap: () async {
          final c = await showNewCustomerSheet(context, name: _q);
          if (c != null && context.mounted) Navigator.pop(context, c);
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(gradient: AppColors.brandGradient, shape: BoxShape.circle),
              child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(_q.isEmpty ? 'New customer' : 'Create "$_q"',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryDeep)),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      Flexible(
        child: list.isEmpty
            ? const EmptyState(icon: Icons.person_search_outlined, title: 'No customers found', message: 'Create a new customer for this order.', compact: true)
            : ListView.builder(
                shrinkWrap: true,
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final c = list[i];
                  final sub = [c.s('email'), c.s('phone')].where((e) => e.isNotEmpty).join(' · ');
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.pop(context, c);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      child: Row(children: [
                        Avatar(c.s('name'), size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(c.s('name'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                            if (sub.isNotEmpty)
                              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                          ]),
                        ),
                        if (c.n('discountPercent') > 0) StatusPill('active', label: '${fmtNum(c.n('discountPercent'))}% off', dot: false),
                      ]),
                    ),
                  ).enter(i, 0.03);
                },
              ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Quick-create customer
// ---------------------------------------------------------------------------

Future<Doc?> showNewCustomerSheet(BuildContext context, {String name = '', String email = '', String phone = ''}) =>
    showAppSheet<Doc>(context, title: 'New customer', builder: (_) => _NewCustomer(name: name, email: email, phone: phone));

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
      HapticFeedback.mediumImpact();
      toast(context, 'Customer created');
      Navigator.pop(context, Doc(id, data));
    } catch (e) {
      if (!mounted) return;
      toast(context, friendlyError(e), error: true);
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
              child: OptionChip(
                  label: 'Individual', icon: Icons.person_outline, selected: _type == 'individual', onTap: () => setState(() => _type = 'individual'))),
          const SizedBox(width: 10),
          Expanded(
              child: OptionChip(
                  label: 'Company', icon: Icons.business_outlined, selected: _type == 'company', onTap: () => setState(() => _type = 'company'))),
        ]),
        const SizedBox(height: 16),
        Field(label: _type == 'company' ? 'Company name' : 'Full name', controller: _name, required: true, autofocus: widget.name.isEmpty),
        const SizedBox(height: 14),
        Field(
          label: 'Email',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          validator: (v) => (v != null && v.trim().isNotEmpty && !v.contains('@')) ? 'Enter a valid email' : null,
        ),
        const SizedBox(height: 14),
        Field(label: 'Phone', controller: _phone, keyboardType: TextInputType.phone),
        const SizedBox(height: 22),
        GradientButton(label: 'Create customer', icon: Icons.check_rounded, busy: _busy, onPressed: _save),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Address
// ---------------------------------------------------------------------------

/// Returns the edited address, an empty map to remove it, or null when dismissed.
Future<Map<String, dynamic>?> showAddressSheet(BuildContext context, String title, Map<String, dynamic> initial) =>
    showAppSheet<Map<String, dynamic>>(context, title: title, builder: (_) => _AddressForm(initial: initial));

class _AddressForm extends StatefulWidget {
  final Map<String, dynamic> initial;
  const _AddressForm({required this.initial});

  @override
  State<_AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends State<_AddressForm> {
  static const _keys = ['firstName', 'lastName', 'line1', 'line2', 'city', 'state', 'zip', 'country'];
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
    for (final k in _keys)
      k: TextEditingController(text: '${widget.initial[k] ?? (k == 'country' ? (Session.instance.setting('general', 'country', '') ?? '') : '')}'),
  };

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _pair(String a, String b) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Field(label: _labels[a]!, controller: _c[a])),
        const SizedBox(width: 12),
        Expanded(child: Field(label: _labels[b]!, controller: _c[b])),
      ]);

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _pair('firstName', 'lastName'),
      const SizedBox(height: 14),
      Field(label: _labels['line1']!, controller: _c['line1']),
      const SizedBox(height: 14),
      Field(label: _labels['line2']!, controller: _c['line2']),
      const SizedBox(height: 14),
      _pair('city', 'zip'),
      const SizedBox(height: 14),
      _pair('state', 'country'),
      const SizedBox(height: 22),
      GradientButton(
        label: 'Save address',
        icon: Icons.check_rounded,
        onPressed: () => Navigator.pop(context, {for (final k in _keys) k: _c[k]!.text.trim()}),
      ),
      if (widget.initial.isNotEmpty) ...[
        const SizedBox(height: 8),
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(context, <String, dynamic>{}),
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Remove address'),
        ),
      ],
    ]);
  }
}

// ---------------------------------------------------------------------------
// Manual payment
// ---------------------------------------------------------------------------

typedef PaymentInput = ({num amount, String method, String kind, String note});

Future<PaymentInput?> showPaymentSheet(BuildContext context, {num suggested = 0}) =>
    showAppSheet<PaymentInput>(context, title: 'Add payment', builder: (_) => _PaymentForm(suggested: suggested));

class _PaymentForm extends StatefulWidget {
  final num suggested;
  const _PaymentForm({required this.suggested});

  @override
  State<_PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends State<_PaymentForm> {
  late final _amount = TextEditingController(text: widget.suggested > 0 ? widget.suggested.toStringAsFixed(2) : '');
  final _note = TextEditingController();
  String _method = 'cash';
  String _kind = 'charge';

  static const _methods = [
    ('cash', 'Cash', Icons.payments_outlined),
    ('card', 'Card', Icons.credit_card_rounded),
    ('bank', 'Bank transfer', Icons.account_balance_outlined),
    ('upi', 'UPI', Icons.qr_code_2_rounded),
  ];
  static const _kinds = [
    ('charge', 'Charge', Icons.call_received_rounded, AppColors.success),
    ('refund', 'Refund', Icons.call_made_rounded, AppColors.danger),
    ('deposit', 'Deposit', Icons.shield_outlined, AppColors.info),
  ];

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('AMOUNT', style: TextStyle(fontSize: 11, letterSpacing: 0.8, fontWeight: FontWeight.w700, color: AppColors.muted)),
          TextField(
            controller: _amount,
            autofocus: widget.suggested <= 0,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.5),
            decoration: InputDecoration(
              prefixText: '${Fmt.symbol} ',
              prefixStyle: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.muted),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 6),
            ),
          ),
          if (widget.suggested > 0) Text('Due on this order: ${Fmt.money(widget.suggested)}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ]),
      ),
      const SizedBox(height: 18),
      const FieldLabel('Type'),
      Row(children: [
        for (var i = 0; i < _kinds.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: OptionChip(
              label: _kinds[i].$2,
              icon: _kinds[i].$3,
              color: _kinds[i].$4,
              selected: _kind == _kinds[i].$1,
              onTap: () => setState(() => _kind = _kinds[i].$1),
            ),
          ),
        ],
      ]),
      const SizedBox(height: 16),
      const FieldLabel('Method'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final m in _methods) OptionChip(label: m.$2, icon: m.$3, selected: _method == m.$1, onTap: () => setState(() => _method = m.$1)),
      ]),
      const SizedBox(height: 16),
      Field(label: 'Note', controller: _note, hint: 'Optional reference or remark'),
      AnimatedSize(
        duration: const Duration(milliseconds: 220),
        child: _kind == 'deposit'
            ? const Padding(
                padding: EdgeInsets.only(top: 12),
                child: InfoBanner('Deposits are held separately and do not reduce the amount due.', tone: Tone.brand),
              )
            : const SizedBox(width: double.infinity),
      ),
      const SizedBox(height: 22),
      GradientButton(
        label: _kind == 'refund' ? 'Record refund' : 'Record payment',
        icon: Icons.check_rounded,
        onPressed: () {
          final a = parseNum(_amount.text);
          if (a <= 0) {
            toast(context, 'Enter an amount greater than zero', error: true);
            return;
          }
          HapticFeedback.mediumImpact();
          Navigator.pop<PaymentInput>(context, (amount: a, method: _method, kind: _kind, note: _note.text.trim()));
        },
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Email
// ---------------------------------------------------------------------------

/// Composes an email from templates of [emailContext] and sends it through the
/// email Cloud Function. Returns true when sent (or handed to the mail app).
Future<bool> showEmailSheet(
  BuildContext context, {
  required String emailContext,
  required String to,
  required Map<String, String> vars,
  required String entityId,
  String defaultSubject = '',
  String defaultBody = '',
  String title = 'Send email',
}) async {
  final r = await showAppSheet<bool>(
    context,
    title: title,
    builder: (_) => _EmailForm(
      emailContext: emailContext,
      to: to,
      vars: vars,
      entityId: entityId,
      defaultSubject: defaultSubject,
      defaultBody: defaultBody,
    ),
  );
  return r == true;
}

class _EmailForm extends StatefulWidget {
  final String emailContext, to, entityId, defaultSubject, defaultBody;
  final Map<String, String> vars;
  const _EmailForm({
    required this.emailContext,
    required this.to,
    required this.vars,
    required this.entityId,
    required this.defaultSubject,
    required this.defaultBody,
  });

  @override
  State<_EmailForm> createState() => _EmailFormState();
}

class _EmailFormState extends State<_EmailForm> {
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
      await Payments.sendEmail(
        workspaceId: Db.wid,
        to: to,
        subject: _subject.text.trim(),
        body: _body.text,
        context: widget.emailContext,
        entityId: widget.entityId,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      toast(context, 'Email sent to $to');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final useMailApp = await confirmDialog(context,
          title: "Email couldn't be sent", message: '${friendlyError(e)}\n\nOpen it in your mail app instead?', confirmLabel: 'Open mail app');
      if (useMailApp) {
        await Browser.openUrl('mailto:$to?subject=${Uri.encodeComponent(_subject.text.trim())}&body=${Uri.encodeComponent(_body.text)}');
        if (mounted) Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_templates.isNotEmpty) ...[
        const FieldLabel('Template'),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _templates.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final t = _templates[i];
              return OptionChip(label: t.s('name'), icon: Icons.article_outlined, selected: _templateId == t.id, onTap: () => _apply(t));
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
      Field(label: 'To', controller: _to, keyboardType: TextInputType.emailAddress, prefix: const Icon(Icons.alternate_email_rounded, size: 18)),
      const SizedBox(height: 14),
      Field(label: 'Subject', controller: _subject),
      const SizedBox(height: 14),
      Field(label: 'Message', controller: _body, maxLines: 8),
      const SizedBox(height: 8),
      const Text('Sent from your workspace email and recorded in the email log.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
      const SizedBox(height: 20),
      GradientButton(label: 'Send email', icon: Icons.send_rounded, busy: _busy, onPressed: _send),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Online payment
// ---------------------------------------------------------------------------

/// Take an online payment now (Razorpay, native checkout) or create a hosted
/// payment link (Stripe / PayPal) to share with the customer.
Future<void> showOnlinePaymentSheet(
  BuildContext context, {
  required String orderId,
  required String orderLabel,
  required num due,
  required String customerName,
  required String customerEmail,
}) =>
    showAppSheet<void>(
      context,
      title: 'Collect online payment',
      builder: (_) => _OnlinePayment(orderId: orderId, orderLabel: orderLabel, due: due, customerName: customerName, customerEmail: customerEmail),
    );

class _OnlinePayment extends StatefulWidget {
  final String orderId, orderLabel, customerName, customerEmail;
  final num due;
  const _OnlinePayment({required this.orderId, required this.orderLabel, required this.due, required this.customerName, required this.customerEmail});

  @override
  State<_OnlinePayment> createState() => _OnlinePaymentState();
}

class _OnlinePaymentState extends State<_OnlinePayment> {
  late final _amount = TextEditingController(text: widget.due.toStringAsFixed(2));
  PayConfig? _cfg;
  String? _loadError;
  String? _busy;
  String? _link;
  String? _linkProvider;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    Payments.config(workspaceId: Db.wid).then((c) {
      if (mounted) setState(() => _cfg = c);
    }).catchError((Object e) {
      if (mounted) setState(() => _loadError = friendlyError(e));
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  num get _amt => parseNum(_amount.text);

  bool _validAmount() {
    if (_amt < 1 || _amt > widget.due + 0.001) {
      setState(() => _error = 'Enter an amount between ${Fmt.money(1)} and ${Fmt.money(widget.due)}.');
      return false;
    }
    return true;
  }

  Future<void> _chargeNow(PayProvider p) async {
    if (!_validAmount()) return;
    HapticFeedback.lightImpact();
    setState(() => (_busy = p.id, _error = null, _notice = null));
    try {
      final r = await Payments.pay(workspaceId: Db.wid, orderId: widget.orderId, provider: p.id, purpose: 'custom', amount: _amt);
      if (!mounted) return;
      if (r.ok) {
        HapticFeedback.heavyImpact();
        Navigator.pop(context);
        toast(context, 'Payment of ${Fmt.money(r.amount)} received via ${p.name}');
      } else if (r.pendingExternal) {
        setState(() => (_busy = null, _notice = r.message));
      } else {
        setState(() => (_busy = null, _error = r.cancelled ? null : r.message));
      }
    } catch (e) {
      if (mounted) setState(() => (_busy = null, _error = friendlyError(e)));
    }
  }

  Future<void> _createLink(PayProvider p) async {
    if (!_validAmount()) return;
    HapticFeedback.lightImpact();
    setState(() => (_busy = p.id, _error = null, _link = null, _notice = null));
    try {
      final s = await Payments.create(workspaceId: Db.wid, orderId: widget.orderId, provider: p.id, purpose: 'custom', amount: _amt);
      if (!mounted) return;
      final url = s['url']?.toString();
      if (url == null || url.isEmpty) throw Exception('The provider did not return a payment link.');
      HapticFeedback.mediumImpact();
      setState(() => (_busy = null, _link = url, _linkProvider = p.name));
    } catch (e) {
      if (mounted) setState(() => (_busy = null, _error = friendlyError(e)));
    }
  }

  String get _message => 'Hi ${widget.customerName.isEmpty ? 'there' : widget.customerName},\n\n'
      'Please use the secure link below to pay ${Fmt.money(_amt)} for order ${widget.orderLabel}:\n\n$_link\n\n'
      'Kind regards,\n$companyName';

  Future<void> _emailLink() async {
    final to = widget.customerEmail;
    if (!to.contains('@')) {
      toast(context, 'This customer has no email address', error: true);
      return;
    }
    setState(() => _busy = 'email');
    try {
      await Payments.sendEmail(
        workspaceId: Db.wid,
        to: to,
        subject: 'Payment request for order ${widget.orderLabel} — $companyName',
        body: _message,
        context: 'payments',
        entityId: widget.orderId,
      );
      if (mounted) toast(context, 'Payment link emailed to $to');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _cfg;
    if (_loadError != null) return InfoBanner(_loadError!, tone: Tone.danger, icon: Icons.error_outline);
    if (c == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Column(children: [
          Skeleton(height: 64, radius: 16),
          SizedBox(height: 12),
          Skeleton(height: 72, radius: 16),
          SizedBox(height: 10),
          Skeleton(height: 72, radius: 16),
        ]),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Field.money(label: 'Amount', controller: _amount, helper: 'Due on order ${widget.orderLabel}: ${Fmt.money(widget.due)}'),
      const SizedBox(height: 16),
      if (c.available.isEmpty)
        const InfoBanner('No payment provider is available for this store. Configure one in Settings → Payments.', tone: Tone.warning)
      else
        for (var i = 0; i < c.available.length; i++) _providerCard(c.available[i]).enter(i),
      if (c.available.any((p) => p.mode == 'test'))
        const Padding(
          padding: EdgeInsets.only(top: 2, bottom: 4),
          child: Row(children: [
            Icon(Icons.science_outlined, size: 14, color: AppColors.warning),
            SizedBox(width: 6),
            Expanded(child: Text('Test mode — use test cards or sandbox accounts.', style: TextStyle(fontSize: 12, color: AppColors.warning))),
          ]),
        ),
      if (_link != null) ...[const SizedBox(height: 12), _linkCard().pop()],
      if (_notice != null) ...[const SizedBox(height: 12), InfoBanner(_notice!, tone: Tone.brand, icon: Icons.open_in_browser_rounded)],
      if (_error != null) ...[const SizedBox(height: 12), InfoBanner(_error!, tone: Tone.danger, icon: Icons.error_outline)],
      if (c.providers.values.any((p) => !p.available)) ...[
        const SizedBox(height: 12),
        for (final p in c.providers.values.where((p) => !p.available))
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text('${p.name}: ${p.reason ?? 'unavailable'}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ),
      ],
    ]);
  }

  Widget _providerCard(PayProvider p) {
    final busy = _busy == p.id;
    final icon = switch (p.id) {
      'razorpay' => Icons.flash_on_rounded,
      'stripe' => Icons.credit_card_rounded,
      _ => Icons.account_balance_wallet_outlined,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x0A1C0938), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Row(children: [
        IconBadge(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            Text([p.blurb, if (p.currency.isNotEmpty) p.currency].join(' · '), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ]),
        ),
        const SizedBox(width: 8),
        if (busy)
          const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
        else if (p.id == 'razorpay')
          FilledButton(onPressed: _busy == null ? () => _chargeNow(p) : null, child: const Text('Charge now'))
        else
          OutlinedButton(onPressed: _busy == null ? () => _createLink(p) : null, child: const Text('Create link')),
      ]),
    );
  }

  Widget _linkCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.link_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text('$_linkProvider payment link', style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 6),
        Text(_link!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Browser.shareText(_message, subject: 'Payment for order ${widget.orderLabel}'),
              icon: const Icon(Icons.ios_share_rounded, size: 16),
              label: const Text('Share'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Payments.openPaymentPage(_link!),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Open'),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.outlined(
            tooltip: 'Copy link',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _link!));
              HapticFeedback.selectionClick();
              toast(context, 'Link copied');
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
          ),
        ]),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _busy == null ? _emailLink : null,
          icon: _busy == 'email'
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send_rounded, size: 16),
          label: Text(widget.customerEmail.contains('@') ? 'Email to ${widget.customerEmail}' : 'Email to customer', overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(height: 8),
        const Text('The order updates automatically once the customer pays.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
      ]),
    );
  }
}
