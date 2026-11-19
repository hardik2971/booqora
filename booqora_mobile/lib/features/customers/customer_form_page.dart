import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/browser.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../data/session.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/mobile.dart';
import '../../widgets/side_panel.dart';
import 'customer_kit.dart';

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
  int _number = 0;
  DateTime? _createdAt;

  bool _loading = true;
  bool _missing = false;
  bool _saving = false;

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
        _addresses = d.maps('addresses');
        _number = d.i('number');
        _createdAt = d.d('createdAt');
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
        'addresses': [for (final a in _addresses) {...a}],
      };

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_form.currentState?.validate() ?? false)) {
      HapticFeedback.heavyImpact();
      toast(context, 'Please fill in the required fields', error: true);
      return;
    }
    final email = _email.text.trim();
    if (email.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      HapticFeedback.heavyImpact();
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
        HapticFeedback.mediumImpact();
        toast(context, 'Customer created');
        context.pushReplacement('/customers/$id');
      } else {
        await Db.update(C.customers, widget.id!, _payload(), label: _name.text.trim());
        if (!mounted) return;
        HapticFeedback.mediumImpact();
        toast(context, 'Customer saved');
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    HapticFeedback.mediumImpact();
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
      context.pop();
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

  // ------------------------------------------------------------------ contact actions
  Future<void> _call() async {
    final p = phoneDigits(_phone.text);
    if (p.isEmpty) {
      toast(context, 'Add a phone number first', error: true);
      return;
    }
    await Browser.openUrl('tel:$p');
  }

  Future<void> _mail() async {
    final e = _email.text.trim();
    if (e.isEmpty) {
      toast(context, 'Add an email address first', error: true);
      return;
    }
    await Browser.openUrl('mailto:$e');
  }

  Future<void> _whatsapp() async {
    final p = _phone.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (p.isEmpty) {
      toast(context, 'Add a phone number first', error: true);
      return;
    }
    await Browser.openUrl('https://wa.me/$p');
  }

  // ------------------------------------------------------------------ addresses
  Future<void> _editAddress([int? index]) async {
    HapticFeedback.selectionClick();
    final initial = index == null
        ? <String, dynamic>{
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
          }
        : {..._addresses[index]};
    final result = await showAppSheet<Map<String, dynamic>>(
      context,
      title: index == null ? 'Add address' : 'Edit address',
      builder: (_) => _AddressEditor(initial: initial, editing: index != null, canUnsetMain: _addresses.length > 1 || index == null),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (result['_delete'] == true) {
        if (index != null) {
          final wasMain = _addresses[index]['isMain'] == true;
          _addresses.removeAt(index);
          if (wasMain && _addresses.isNotEmpty) _addresses.first['isMain'] = true;
        }
        return;
      }
      if (index == null) {
        _addresses.add(result);
      } else {
        _addresses[index] = result;
      }
      final i = index ?? _addresses.length - 1;
      if (result['isMain'] == true) {
        for (var j = 0; j < _addresses.length; j++) {
          _addresses[j]['isMain'] = j == i;
        }
      } else if (!_addresses.any((a) => a['isMain'] == true) && _addresses.isNotEmpty) {
        _addresses.first['isMain'] = true;
      }
    });
  }

  // ------------------------------------------------------------------ build
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const FormScaffold(title: 'Customer', children: [LoadingView()]);
    }
    if (_missing) {
      return FormScaffold(title: 'Customer not found', children: [
        EmptyState(
          icon: Icons.person_off_outlined,
          title: 'This customer no longer exists',
          message: 'It may have been deleted by a team member.',
          actionLabel: 'Back to customers',
          onAction: () => context.pop(),
        ),
      ]);
    }

    final name = _name.text.trim();
    return FormScaffold(
      title: _isNew ? 'New customer' : (name.isEmpty ? 'Customer' : name),
      formKey: _form,
      actions: [
        if (!_isNew)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (v) {
              if (v == 'order') context.push('/orders/new?customer=${widget.id}');
              if (v == 'delete') _delete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'order', child: ListTile(leading: Icon(Icons.add_rounded), title: Text('New order'), contentPadding: EdgeInsets.zero)),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline, color: AppColors.danger),
                  title: Text('Delete customer', style: TextStyle(color: AppColors.danger)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
      ],
      bottom: GradientButton(
        label: _isNew ? 'Create customer' : 'Save changes',
        icon: _isNew ? Icons.person_add_alt_1_rounded : Icons.check_rounded,
        busy: _saving,
        onPressed: _save,
      ),
      children: [
        if (!_isNew) ...[
          _ProfileHeader(
            name: name.isEmpty ? 'Customer' : name,
            number: _number,
            type: _type,
            since: _createdAt,
            onCall: _call,
            onEmail: _mail,
            onWhatsApp: _whatsapp,
            onNewOrder: () => context.push('/orders/new?customer=${widget.id}'),
          ),
          const SizedBox(height: 14),
          _OrdersOverview(stream: _ordersStream!, customerId: widget.id!),
          const SizedBox(height: 6),
        ],
        ..._sections(),
        if (!_isNew) ...[
          const SectionLabel('Tags, notes & activity'),
          StreamBuilder<Doc?>(
            stream: _docStream,
            builder: (context, s) => TagsCard(collection: C.customers, id: widget.id!, tags: s.data?.l<String>('tags') ?? const []),
          ),
          NotesCard(entity: 'customers', entityId: widget.id!),
          ActivityCard(entityId: widget.id),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: Color(0xFFF5C2C2))),
            onPressed: _saving ? null : _delete,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Delete customer'),
          ),
        ],
      ],
    );
  }

  List<Widget> _sections() => [
        const SectionLabel('Contact'),
        Group(children: [
          Field(label: 'Customer name', controller: _name, required: true, hint: 'e.g. Priya Sharma or Acme Events', onChanged: (_) => setState(() {})),
          Field(
            label: 'Email',
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            hint: 'name@example.com',
            prefix: const Icon(Icons.mail_outline_rounded, size: 20),
            autofillHints: const [AutofillHints.email],
          ),
          Field(
            label: 'Phone',
            controller: _phone,
            keyboardType: TextInputType.phone,
            hint: '+91 98765 43210',
            prefix: const Icon(Icons.phone_outlined, size: 20),
            autofillHints: const [AutofillHints.telephoneNumber],
          ),
          SwitchTile(
            value: _marketing,
            title: 'Marketing emails',
            subtitle: 'Only enable if the customer agreed to receive promotions.',
            onChanged: (v) {
              HapticFeedback.selectionClick();
              setState(() => _marketing = v);
            },
          ),
        ]),
        const SectionLabel('Customer type'),
        _TypePicker(value: _type, onChanged: (v) => setState(() => _type = v)),
        const SectionLabel('Pricing'),
        Group(children: [
          Field(
            label: 'Discount percentage',
            controller: _discount,
            suffixText: '%',
            helper: 'Applied automatically to new orders for this customer.',
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
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const FieldLabel('Tax profile'),
                  InkWell(
                    onTap: () => context.push('/settings/taxes'),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('No customer tax profiles yet — create one',
                          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, decoration: TextDecoration.underline)),
                    ),
                  ),
                ]);
              }
              final items = <String, String>{'': 'Default (product tax)'};
              for (final p in profiles) {
                items[p.id] = '${p.s('name')} · ${_numText(p.n('rate'))}%';
              }
              return DropdownX<String>(
                key: ValueKey('tax-${items.length}'),
                label: 'Tax profile',
                value: items.containsKey(_taxProfileId) ? _taxProfileId : '',
                items: items,
                onChanged: (v) => setState(() => _taxProfileId = v ?? ''),
              );
            },
          ),
        ]),
        StreamBuilder<List<Doc>>(
          stream: _cfStream,
          builder: (context, s) {
            final fields = [...(s.data ?? const <Doc>[])]..sort((a, b) => a.i('position').compareTo(b.i('position')));
            if (fields.isEmpty) return const SizedBox.shrink();
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SectionLabel('Custom fields'),
              Group(children: [for (final f in fields) _customField(f)]),
            ]);
          },
        ),
        SectionLabel(
          'Addresses',
          trailing: TextButton.icon(
            onPressed: () => _editAddress(),
            icon: const Icon(Icons.add_location_alt_outlined, size: 18),
            label: const Text('Add'),
          ),
        ),
        if (_addresses.isEmpty)
          PressScale(
            onTap: () => _editAddress(),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.lavender, width: 1.2),
              ),
              child: const Column(children: [
                Icon(Icons.add_location_alt_outlined, color: AppColors.primary, size: 28),
                SizedBox(height: 6),
                Text('Add a billing or delivery address', style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: 2),
                Text('The main address is pre-filled on new orders.', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
              ]),
            ),
          )
        else
          Column(children: [
            for (var i = 0; i < _addresses.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AddressTile(address: _addresses[i], onTap: () => _editAddress(i)),
              ),
          ]),
        const SectionLabel('Security deposit'),
        RadioCards<String>(
          value: _depositMode,
          onChanged: (v) {
            HapticFeedback.selectionClick();
            setState(() => _depositMode = v);
          },
          options: [
            ('default', 'Default setting', _defaultDepositText()),
            ('none', 'No deposit', 'Never charge a security deposit to this customer.'),
            ('percentage', 'Percentage of order total', 'Charge a share of each order’s total.'),
            ('product', 'Product-specific deposits', 'Charge the deposit configured on each product.'),
            ('fixed', 'Fixed amount', 'Charge the same deposit on every order.'),
          ],
          expanded: {
            'percentage': Field.number(label: 'Percentage', controller: _depositValue, suffixText: '%'),
            'fixed': Field.money(label: 'Amount', controller: _depositValue),
          },
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
        return SwitchTile(value: value == true, title: label, onChanged: (v) => setState(() => _custom[key] = v));
      default:
        return Field(label: label, initialValue: value?.toString() ?? '', onChanged: (v) => _custom[key] = v);
    }
  }
}

// ============================================================== profile header
class _ProfileHeader extends StatelessWidget {
  final String name;
  final int number;
  final String type;
  final DateTime? since;
  final VoidCallback onCall, onEmail, onWhatsApp, onNewOrder;
  const _ProfileHeader({
    required this.name,
    required this.number,
    required this.type,
    required this.since,
    required this.onCall,
    required this.onEmail,
    required this.onWhatsApp,
    required this.onNewOrder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [BoxShadow(color: AppColors.primaryDeep.withValues(alpha: 0.3), blurRadius: 26, offset: const Offset(0, 12))],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white24, width: 2)),
          child: Avatar(name, size: 74),
        ).pop(),
        const SizedBox(height: 12),
        Text(name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center, children: [
          _GlassChip(icon: type == 'company' ? Icons.business_rounded : Icons.person_rounded, text: Fmt.label(type)),
          if (number > 0) _GlassChip(icon: Icons.tag_rounded, text: 'Customer $number'),
          if (since != null) _GlassChip(icon: Icons.event_outlined, text: 'Since ${Fmt.shortDate(since)} ${since!.year}'),
        ]),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: _QuickAction(icon: Icons.call_rounded, label: 'Call', onTap: onCall)),
          Expanded(child: _QuickAction(icon: Icons.mail_rounded, label: 'Email', onTap: onEmail)),
          Expanded(child: _QuickAction(icon: Icons.chat_rounded, label: 'WhatsApp', onTap: onWhatsApp)),
          Expanded(child: _QuickAction(icon: Icons.add_rounded, label: 'New order', onTap: onNewOrder, primary: true)),
        ]),
      ]),
    );
  }
}

class _GlassChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _GlassChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: AppColors.lavender),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      );
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;
  const _QuickAction({required this.icon, required this.label, required this.onTap, this.primary = false});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: primary ? Colors.white : Colors.white.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: primary ? null : Border.all(color: Colors.white24),
          ),
          child: Icon(icon, color: primary ? AppColors.primaryDeep : Colors.white, size: 22),
        ),
        const SizedBox(height: 6),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _TypePicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _TypePicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget card(String v, IconData icon, String title, String sub) {
      final sel = v == value;
      return Expanded(
        child: PressScale(
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(v);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: sel ? AppColors.primarySoft : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: sel ? AppColors.primary : AppColors.border, width: sel ? 1.6 : 1),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: sel ? AppColors.brandGradient : null,
                    color: sel ? null : AppColors.bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: sel ? Colors.white : AppColors.muted, size: 20),
                ),
                const Spacer(),
                Icon(sel ? Icons.check_circle_rounded : Icons.circle_outlined, color: sel ? AppColors.primary : AppColors.border, size: 20),
              ]),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(sub, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ]),
          ),
        ),
      );
    }

    return Row(children: [
      card('individual', Icons.person_rounded, 'Individual', 'A private person'),
      const SizedBox(width: 12),
      card('company', Icons.business_rounded, 'Company', 'A business'),
    ]);
  }
}

// ============================================================== addresses
String _addressText(Map<String, dynamic> a) {
  String v(String k) => (a[k] ?? '').toString().trim();
  final who = [v('firstName'), v('lastName')].where((e) => e.isNotEmpty).join(' ');
  final cityLine = [v('city'), v('state'), v('zip')].where((e) => e.isNotEmpty).join(', ');
  return [who, v('line1'), v('line2'), cityLine, v('country')].where((e) => e.isNotEmpty).join('\n');
}

class _AddressTile extends StatelessWidget {
  final Map<String, dynamic> address;
  final VoidCallback onTap;
  const _AddressTile({required this.address, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final main = address['isMain'] == true;
    final label = (address['label'] ?? '').toString().trim();
    final text = _addressText(address);
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: main ? AppColors.primarySoft.withValues(alpha: 0.5) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: main ? AppColors.primary.withValues(alpha: 0.5) : AppColors.border),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: main ? AppColors.primary : AppColors.bg, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.place_outlined, size: 20, color: main ? Colors.white : AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(label.isEmpty ? 'Address' : label,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                if (main) ...[const SizedBox(width: 8), const StatusPill('active', label: 'Main', dot: false)],
              ]),
              const SizedBox(height: 4),
              Text(text.isEmpty ? 'Tap to add details' : text, style: const TextStyle(color: AppColors.inkSoft, fontSize: 13, height: 1.4)),
            ]),
          ),
          const Icon(Icons.edit_outlined, size: 18, color: AppColors.muted),
        ]),
      ),
    );
  }
}

class _AddressEditor extends StatefulWidget {
  final Map<String, dynamic> initial;
  final bool canUnsetMain;
  final bool editing;
  const _AddressEditor({required this.initial, required this.canUnsetMain, required this.editing});

  @override
  State<_AddressEditor> createState() => _AddressEditorState();
}

class _AddressEditorState extends State<_AddressEditor> {
  static const _keys = ['label', 'firstName', 'lastName', 'line1', 'line2', 'city', 'state', 'zip', 'country'];
  late final Map<String, TextEditingController> _c = {for (final k in _keys) k: TextEditingController(text: (widget.initial[k] ?? '').toString())};
  late bool _main = widget.initial['isMain'] == true;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _done() {
    HapticFeedback.lightImpact();
    Navigator.pop(context, {
      ...widget.initial,
      for (final k in _keys) k: _c[k]!.text.trim(),
      'isMain': _main,
    });
  }

  Widget _row(List<Widget> c) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: c[0]),
        const SizedBox(width: 12),
        Expanded(child: c[1]),
      ]);

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Field(label: 'Label', controller: _c['label'], hint: 'e.g. Home, Office, Warehouse'),
      const SizedBox(height: 14),
      _row([
        Field(label: 'First name', controller: _c['firstName']),
        Field(label: 'Last name', controller: _c['lastName']),
      ]),
      const SizedBox(height: 14),
      Field(label: 'Address line 1', controller: _c['line1'], hint: 'Street and number'),
      const SizedBox(height: 14),
      Field(label: 'Address line 2', controller: _c['line2'], hint: 'Apartment, suite, floor'),
      const SizedBox(height: 14),
      _row([
        Field(label: 'City', controller: _c['city']),
        Field(label: 'State', controller: _c['state']),
      ]),
      const SizedBox(height: 14),
      _row([
        Field(label: 'Pincode', controller: _c['zip'], keyboardType: TextInputType.number),
        Field(label: 'Country', controller: _c['country']),
      ]),
      const SizedBox(height: 14),
      SwitchTile(
        value: _main,
        title: 'Main address',
        subtitle: 'Pre-filled on new orders for this customer.',
        onChanged: (v) {
          if (!v && !widget.canUnsetMain) return;
          HapticFeedback.selectionClick();
          setState(() => _main = v);
        },
      ),
      const SizedBox(height: 18),
      GradientButton(label: 'Save address', icon: Icons.check_rounded, onPressed: _done),
      if (widget.editing) ...[
        const SizedBox(height: 10),
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          onPressed: () async {
            final ok = await confirmDialog(context,
                title: 'Remove address?', message: 'This address will be removed from the customer.', confirmLabel: 'Remove', danger: true);
            if (ok && context.mounted) Navigator.pop(context, {'_delete': true});
          },
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Remove address'),
        ),
      ],
    ]);
  }
}

// ============================================================== orders overview
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
        final due = counted.fold<num>(0, (a, o) => a + (o.n('due') < 0 ? 0 : o.n('due')));
        final latest = orders.isEmpty ? null : orders.map((o) => o.created).reduce((a, b) => a.isAfter(b) ? a : b);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.75,
            children: [
              MiniMetric(label: 'Orders', value: counted.length, format: Fmt.integer, icon: Icons.receipt_long_outlined).pop(0),
              MiniMetric(label: 'Revenue', value: revenue, format: Fmt.compactMoney, icon: Icons.payments_outlined, color: AppColors.success).pop(1),
              MiniMetric(
                label: 'Balance due',
                value: due,
                format: Fmt.compactMoney,
                icon: Icons.account_balance_wallet_outlined,
                color: due > 0 ? AppColors.danger : AppColors.success,
              ).pop(2),
              _LatestTile(latest: latest).pop(3),
            ],
          ),
          SectionLabel(
            'Orders',
            trailing: TextButton.icon(
              onPressed: () => context.push('/orders/new?customer=$customerId'),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New order'),
            ),
          ),
          if (orders.isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
              child: const Text('No orders yet. Create the first order for this customer.',
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
            )
          else ...[
            for (var i = 0; i < orders.length && i < 10; i++) Padding(padding: const EdgeInsets.only(bottom: 8), child: _OrderRow(orders[i]).enterX(i)),
            if (orders.length > 10)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('Showing the 10 most recent of ${orders.length} orders',
                    textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ),
          ],
        ]);
      },
    );
  }
}

class _LatestTile extends StatelessWidget {
  final DateTime? latest;
  const _LatestTile({required this.latest});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: Color(0x0D1C0938), blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
            child: const Icon(Icons.event_outlined, size: 17, color: AppColors.info),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Text('Latest order', style: TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w500))),
        ]),
        Text(latest == null ? '—' : Fmt.relative(latest),
            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
      ]),
    );
  }
}

class _OrderRow extends StatelessWidget {
  final Doc o;
  const _OrderRow(this.o);

  @override
  Widget build(BuildContext context) {
    final s = o.d('startsAt'), e = o.d('stopsAt');
    return MTile(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/orders/${o.id}');
      },
      leading: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(13)),
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Text('#${o.i('number')}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
          ),
        ),
      ),
      title: Fmt.money(o.n('total')),
      subtitle: s == null ? 'No dates set' : '${Fmt.shortDate(s)} → ${Fmt.shortDate(e)}',
      trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
        StatusPill(o.s('status', 'draft')),
        const SizedBox(height: 4),
        StatusPill(o.s('paymentStatus', 'payment_due'), dot: false),
      ]),
    );
  }
}
