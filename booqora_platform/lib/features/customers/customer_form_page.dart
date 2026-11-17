import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../data/session.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/page.dart';
import '../../widgets/side_panel.dart';
import 'customers_page.dart' show newCustomerData;

class CustomerFormPage extends StatefulWidget {
  final String? id;
  const CustomerFormPage({super.key, this.id});

  @override
  State<CustomerFormPage> createState() => _CustomerFormPageState();
}

class _CustomerFormPageState extends State<CustomerFormPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _discount = TextEditingController(text: '0');
  final _depositValue = TextEditingController(text: '0');

  bool _marketing = false;
  String _type = 'individual';
  String _taxProfileId = '';
  String _depositMode = 'default';
  Map<String, dynamic> _custom = {};
  List<Map<String, dynamic>> _addresses = [];

  bool _loading = true;
  bool _missing = false;
  bool _saving = false;
  int _keySeq = 0;

  late final Stream<List<Doc>> _taxStream = Db.watch(C.taxProfiles);
  late final Stream<List<Doc>> _cfStream = Db.watchWhere(C.customFields, 'scope', 'customer');
  Stream<Doc?>? _docStream;
  Stream<List<Doc>>? _ordersStream;

  bool get _isNew => widget.id == null;

  @override
  void initState() {
    super.initState();
    if (_isNew) {
      _loading = false;
    } else {
      _docStream = Db.watchDoc(C.customers, widget.id!);
      _ordersStream = Db.watchWhere(C.orders, 'customerId', widget.id);
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final d = await Db.get(C.customers, widget.id!);
      if (!mounted) return;
      if (d == null) {
        setState(() {
          _missing = true;
          _loading = false;
        });
        return;
      }
      setState(() {
        _name.text = d.s('name');
        _email.text = d.s('email');
        _phone.text = d.s('phone');
        _discount.text = _numText(d.n('discountPercent'));
        _depositValue.text = _numText(d.n('depositValue'));
        _marketing = d.b('marketing');
        _type = d.s('type', 'individual');
        _taxProfileId = d.s('taxProfileId');
        _depositMode = d.s('depositMode', 'default');
        _custom = d.m('customFields');
        _addresses = d.maps('addresses').map((a) => {...a, '_k': _keySeq++}).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      toast(context, friendlyError(e), error: true);
    }
  }

  String _numText(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _discount, _depositValue]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _payload() => {
    'name': _name.text.trim(),
    'email': _email.text.trim(),
    'phone': _phone.text.trim(),
    'marketing': _marketing,
    'type': _type,
    'discountPercent': parseNum(_discount.text),
    'taxProfileId': _taxProfileId.isEmpty ? null : _taxProfileId,
    'depositMode': _depositMode,
    'depositValue': parseNum(_depositValue.text),
    'customFields': _custom,
    'addresses': [
      for (final a in _addresses) {...a}..remove('_k'),
    ],
  };

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) {
      toast(context, 'Please fill in the required fields', error: true);
      return;
    }
    final email = _email.text.trim();
    if (email.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      toast(context, 'Please enter a valid email address', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      if (_isNew) {
        final data = {...newCustomerData(name: _name.text.trim()), ..._payload()};
        final id = await Db.create(C.customers, data, numberKey: 'customer');
        await Session.instance.markOnboarding('customer');
        if (!mounted) return;
        toast(context, 'Customer created');
        context.go('/customers/$id');
      } else {
        await Db.update(C.customers, widget.id!, _payload(), label: _name.text.trim());
        if (mounted) toast(context, 'Customer saved');
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: 'Delete customer?',
      message: '“${_name.text.trim()}” will be removed. Existing orders and documents keep the customer name.',
      confirmLabel: 'Delete customer',
      danger: true,
    );
    if (!ok || !mounted) return;
    try {
      await Db.remove(C.customers, widget.id!, label: _name.text.trim());
      if (!mounted) return;
      toast(context, 'Customer deleted');
      context.go('/customers');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  String _defaultDepositText() {
    final mode = Session.instance.setting('pricing', 'depositMode', 'product')?.toString() ?? 'product';
    final v = Session.instance.setting('pricing', 'depositValue', 100);
    final value = v is num ? v : num.tryParse('$v') ?? 0;
    switch (mode) {
      case 'none':
        return 'Workspace default: no security deposit.';
      case 'percentage':
        return 'Workspace default: ${_numText(value)}% of the order total.';
      case 'fixed':
        return 'Workspace default: fixed amount of ${Fmt.money(value)}.';
      default:
        return 'Workspace default: product-specific deposits (${_numText(value)}%).';
    }
  }

  // ------------------------------------------------------------------ build
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(title: 'Customer', breadcrumbs: [('Customers', '/customers')]),
          Padding(padding: EdgeInsets.symmetric(horizontal: 28), child: LoadingView()),
        ],
      );
    }
    if (_missing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeader(title: 'Customer not found', breadcrumbs: [('Customers', '/customers')]),
          Expanded(
            child: EmptyState(
              icon: Icons.person_off_outlined,
              title: 'This customer no longer exists',
              message: 'It may have been deleted by a team member.',
              actionLabel: 'Back to customers',
              onAction: () => context.go('/customers'),
            ),
          ),
        ],
      );
    }

    final sections = _formSections();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: _isNew ? 'New customer' : (_name.text.trim().isEmpty ? 'Customer' : _name.text.trim()),
          subtitle: _isNew ? 'Add contact details, addresses and pricing preferences.' : null,
          breadcrumbs: const [('Customers', '/customers')],
          titleTrailing: _isNew ? null : StatusPill(_type == 'company' ? 'reserved' : 'default', label: Fmt.label(_type), dot: false),
          actions: [
            if (!_isNew)
              FilledButton.icon(
                onPressed: () => context.go('/orders/new?customer=${widget.id}'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New order'),
              ),
          ],
        ),
        Expanded(
          child: Form(
            key: _form,
            child: PageBody(
              children: [
                if (_isNew)
                  ...sections
                else
                  DetailLayout(
                    main: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _OrdersOverview(stream: _ordersStream!, customerId: widget.id!),
                        const SizedBox(height: 28),
                        ...sections,
                      ],
                    ),
                    side: [
                      StreamBuilder<Doc?>(
                        stream: _docStream,
                        builder: (context, s) => TagsCard(collection: C.customers, id: widget.id!, tags: s.data?.l<String>('tags') ?? const []),
                      ),
                      NotesCard(entity: 'customers', entityId: widget.id!),
                      ActivityCard(entityId: widget.id),
                    ],
                  ),
              ],
            ),
          ),
        ),
        SaveBar(
          saving: _saving,
          saveLabel: _isNew ? 'Create customer' : 'Save',
          onSave: _save,
          onCancel: () => context.go('/customers'),
          leading: _isNew
              ? null
              : TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                  onPressed: _saving ? null : _delete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete customer'),
                ),
        ),
      ],
    );
  }

  List<Widget> _formSections() => [
    FormSection(
      index: 0,
      title: 'General',
      description: 'The name shown on orders, documents and emails.',
      children: [
        Field(label: 'Customer name', controller: _name, required: true, hint: 'e.g. Priya Sharma or Acme Events', onChanged: (_) => setState(() {})),
      ],
    ),
    FormSection(
      index: 1,
      title: 'Information',
      description: 'How to reach this customer.',
      children: [
        FieldGrid(
          children: [
            Field(label: 'Email', controller: _email, keyboardType: TextInputType.emailAddress, hint: 'name@example.com'),
            Field(label: 'Phone', controller: _phone, keyboardType: TextInputType.phone, hint: '+91 98765 43210'),
          ],
        ),
        CheckTile(
          value: _marketing,
          title: 'Subscribed to marketing emails',
          subtitle: 'Only tick this if the customer agreed to receive promotions.',
          onChanged: (v) => setState(() => _marketing = v),
        ),
        const FieldLabel('Customer type'),
        RadioCards<String>(
          horizontal: true,
          value: _type,
          options: const [('individual', 'Individual', 'A private person'), ('company', 'Company', 'A business or organisation')],
          onChanged: (v) => setState(() => _type = v),
        ),
      ],
    ),
    FormSection(
      index: 2,
      title: 'Settings',
      description: 'A default discount and tax profile applied to new orders for this customer.',
      children: [
        FieldGrid(
          children: [
            Field(
              label: 'Discount percentage',
              controller: _discount,
              suffixText: '%',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              validator: (v) {
                final n = num.tryParse((v ?? '').trim());
                if ((v ?? '').trim().isEmpty) return null;
                if (n == null || n < 0 || n > 100) return 'Enter a value between 0 and 100';
                return null;
              },
            ),
            StreamBuilder<List<Doc>>(
              stream: _taxStream,
              builder: (context, s) {
                final profiles = (s.data ?? const <Doc>[]).where((p) => p.s('kind') == 'customer').toList();
                if (s.hasData && profiles.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FieldLabel('Tax profile'),
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: InkWell(
                          onTap: () => context.go('/settings/taxes'),
                          child: const Text(
                            'No customer tax profiles yet — create one',
                            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, decoration: TextDecoration.underline),
                          ),
                        ),
                      ),
                    ],
                  );
                }
                final items = <String, String>{'': 'Default (product tax)'};
                for (final p in profiles) {
                  items[p.id] = '${p.s('name')} · ${_numText(p.n('rate'))}%';
                }
                return DropdownX<String>(
                  label: 'Tax profile',
                  value: items.containsKey(_taxProfileId) ? _taxProfileId : '',
                  items: items,
                  onChanged: (v) => setState(() => _taxProfileId = v ?? ''),
                );
              },
            ),
          ],
        ),
      ],
    ),
    StreamBuilder<List<Doc>>(
      stream: _cfStream,
      builder: (context, s) {
        final fields = [...(s.data ?? const <Doc>[])]..sort((a, b) => a.i('position').compareTo(b.i('position')));
        if (fields.isEmpty) return const SizedBox.shrink();
        return FormSection(
          index: 3,
          title: 'Custom fields',
          description: 'Extra details you collect for every customer.',
          children: [
            FieldGrid(children: [for (final f in fields) _customField(f)]),
          ],
        );
      },
    ),
    FormSection(
      index: 4,
      title: 'Addresses',
      description: 'Billing and delivery addresses. The main address is pre-filled on new orders.',
      children: [
        if (_addresses.isEmpty) const Text('No addresses yet.', style: TextStyle(color: AppColors.muted)),
        for (var i = 0; i < _addresses.length; i++)
          _AddressCard(
            key: ValueKey(_addresses[i]['_k']),
            address: _addresses[i],
            index: i,
            onChanged: () => setState(() {}),
            onMain: () => setState(() {
              for (var j = 0; j < _addresses.length; j++) {
                _addresses[j]['isMain'] = j == i;
              }
            }),
            onRemove: () => setState(() {
              final wasMain = _addresses[i]['isMain'] == true;
              _addresses.removeAt(i);
              if (wasMain && _addresses.isNotEmpty) _addresses.first['isMain'] = true;
            }),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => setState(
              () => _addresses.add({
                '_k': _keySeq++,
                'label': '',
                'country': Session.instance.setting('general', 'country', '') ?? '',
                'firstName': '',
                'lastName': '',
                'line1': '',
                'line2': '',
                'city': '',
                'state': '',
                'zip': '',
                'isMain': _addresses.isEmpty,
              }),
            ),
            icon: const Icon(Icons.add_location_alt_outlined, size: 18),
            label: const Text('Add address'),
          ),
        ),
      ],
    ),
    FormSection(
      index: 5,
      title: 'Security deposit',
      description: 'Override the workspace deposit rule for this customer.',
      children: [
        RadioCards<String>(
          value: _depositMode,
          onChanged: (v) => setState(() => _depositMode = v),
          options: [
            ('default', 'Default setting', _defaultDepositText()),
            ('none', 'No deposit', 'Never charge a security deposit to this customer.'),
            ('percentage', 'Percentage of order total', 'Charge a share of each order’s total.'),
            ('product', 'Use product-specific security deposits', 'Charge the deposit configured on each product.'),
            ('fixed', 'Fixed amount', 'Charge the same deposit on every order.'),
          ],
          expanded: {
            'percentage': SizedBox(
              width: 220,
              child: Field.number(label: 'Percentage', controller: _depositValue, suffixText: '%'),
            ),
            'fixed': SizedBox(
              width: 220,
              child: Field.money(label: 'Amount', controller: _depositValue),
            ),
          },
        ),
      ],
    ),
  ];

  Widget _customField(Doc f) {
    final key = f.id;
    final label = f.s('name');
    final value = _custom[key];
    switch (f.s('type', 'text')) {
      case 'number':
        return Field(
          label: label,
          initialValue: value?.toString() ?? '',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))],
          onChanged: (v) => _custom[key] = num.tryParse(v.trim()),
        );
      case 'date':
        return DateTimeField(
          label: label,
          value: Doc.toDate(value),
          withTime: false,
          clearable: true,
          onChanged: (d) => setState(() => _custom[key] = d),
        );
      case 'select':
        final opts = f.l<String>('options');
        return DropdownX<String>(
          label: label,
          value: opts.contains(value) ? value as String : null,
          hint: 'Select…',
          items: {for (final o in opts) o: o},
          onChanged: (v) => setState(() => _custom[key] = v),
        );
      case 'checkbox':
        return Padding(
          padding: const EdgeInsets.only(top: 18),
          child: CheckTile(value: value == true, title: label, onChanged: (v) => setState(() => _custom[key] = v)),
        );
      default:
        return Field(label: label, initialValue: value?.toString() ?? '', onChanged: (v) => _custom[key] = v);
    }
  }
}

class _AddressCard extends StatelessWidget {
  final Map<String, dynamic> address;
  final int index;
  final VoidCallback onChanged;
  final VoidCallback onMain;
  final VoidCallback onRemove;
  const _AddressCard({super.key, required this.address, required this.index, required this.onChanged, required this.onMain, required this.onRemove});

  Widget _f(String label, String key, {String? hint}) =>
      Field(label: label, hint: hint, initialValue: (address[key] ?? '').toString(), onChanged: (v) => address[key] = v);

  @override
  Widget build(BuildContext context) {
    final main = address['isMain'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: main ? AppColors.primarySoft.withValues(alpha: 0.35) : const Color(0xFFFBFAFE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: main ? AppColors.primary.withValues(alpha: 0.5) : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.place_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Address ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
              if (main) ...[const SizedBox(width: 8), const StatusPill('active', label: 'Main address', dot: false)],
              const Spacer(),
              IconButton(
                tooltip: 'Remove address',
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.muted),
                onPressed: onRemove,
              ),
            ],
          ),
          const SizedBox(height: 8),
          FieldGrid(
            children: [
              _f('Country', 'country'),
              _f('First name', 'firstName'),
              _f('Last name', 'lastName'),
              _f('Address line 1', 'line1', hint: 'Street and number'),
              _f('Address line 2', 'line2', hint: 'Apartment, suite, floor'),
              _f('City', 'city'),
              _f('State', 'state'),
              _f('Pincode', 'zip'),
            ],
          ),
          const SizedBox(height: 8),
          CheckTile(value: main, title: 'Main address', onChanged: (v) => v ? onMain() : null),
        ],
      ),
    ).enter(index);
  }
}

/// Summary strip + order list for an existing customer.
class _OrdersOverview extends StatelessWidget {
  final Stream<List<Doc>> stream;
  final String customerId;
  const _OrdersOverview({required this.stream, required this.customerId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Doc>>(
      stream: stream,
      builder: (context, s) {
        if (s.hasError) return ErrorView(s.error!);
        if (!s.hasData) return const LoadingView(rows: 3);
        final orders = s.data!;
        final counted = orders.where((o) => !const {'draft', 'canceled'}.contains(o.s('status'))).toList();
        final revenue = counted.fold<num>(0, (a, o) => a + o.n('total'));
        final due = counted.fold<num>(0, (a, o) => a + o.n('due'));
        final latest = orders.isEmpty ? null : orders.map((o) => o.created).reduce((a, b) => a.isAfter(b) ? a : b);
        final t = Theme.of(context).textTheme;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              gradient: AppColors.heroGradient,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: LayoutBuilder(
                builder: (context, c) {
                  final cols = c.maxWidth > 620 ? 4 : 2;
                  final w = (c.maxWidth - (cols - 1) * 16) / cols;
                  Widget stat(String label, Widget value) => SizedBox(
                    width: w,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(color: Color(0xFFCBB8F5), fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        value,
                      ],
                    ),
                  );
                  final vs = t.titleLarge?.copyWith(color: Colors.white, fontSize: 20);
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      stat('Orders', CountUp(value: counted.length, format: Fmt.integer, style: vs)),
                      stat('Revenue', CountUp(value: revenue, format: Fmt.money, style: vs)),
                      stat(
                        'Balance due',
                        CountUp(
                          value: due,
                          format: Fmt.money,
                          style: vs?.copyWith(color: due > 0 ? const Color(0xFFFCA5A5) : Colors.white),
                        ),
                      ),
                      stat('Latest order', Text(latest == null ? '—' : Fmt.date(latest), style: vs)),
                    ],
                  );
                },
              ),
            ).enter(0),
            const SizedBox(height: 16),
            AppCard(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_long_outlined, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Orders', style: t.titleMedium)),
                      TextButton.icon(
                        onPressed: () => context.go('/orders/new?customer=$customerId'),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('New order'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (orders.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Text('No orders yet. Create the first order for this customer.', style: TextStyle(color: AppColors.muted)),
                    )
                  else
                    for (var i = 0; i < orders.length && i < 10; i++) _OrderRow(orders[i], last: i == orders.length - 1 || i == 9).enter(i),
                  if (orders.length > 10)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Showing the 10 most recent of ${orders.length} orders',
                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ).enter(1),
          ],
        );
      },
    );
  }
}

class _OrderRow extends StatelessWidget {
  final Doc o;
  final bool last;
  const _OrderRow(this.o, {this.last = false});

  @override
  Widget build(BuildContext context) {
    final s = o.d('startsAt'), e = o.d('stopsAt');
    return InkWell(
      onTap: () => context.go('/orders/${o.id}'),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          border: last ? null : const Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '#${o.i('number')}',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Text(s == null ? 'No dates set' : '${Fmt.shortDate(s)} → ${Fmt.shortDate(e)}', style: const TextStyle(color: AppColors.inkSoft)),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(Fmt.money(o.n('total')), style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                StatusPill(o.s('status', 'draft')),
                const SizedBox(width: 6),
                StatusPill(o.s('paymentStatus', 'payment_due'), dot: false),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
