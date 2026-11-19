import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/mobile.dart';
import 'coupon_kit.dart';

class CouponFormPage extends StatefulWidget {
  final String? id;
  const CouponFormPage({super.key, this.id});

  @override
  State<CouponFormPage> createState() => _CouponFormPageState();
}

class _CouponFormPageState extends State<CouponFormPage> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _value = TextEditingController(text: '10');
  final _minSpend = TextEditingController();
  final _maxUses = TextEditingController();

  bool _active = true;
  String _discountType = 'percentage';
  bool _dated = false;
  DateTime? _startsAt;
  DateTime? _endsAt;
  String _eligible = 'all';
  List<String> _productIds = [];
  List<String> _collectionIds = [];
  bool _hasMinSpend = false;
  bool _limitUses = false;
  bool _onePerCustomer = false;
  bool _stack = true;
  int _uses = 0;

  bool _loading = true;
  bool _missing = false;
  bool _saving = false;
  Map<String, String> _productNames = {};
  Map<String, String> _collectionNames = {};

  bool get _isNew => widget.id == null;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final results = await Future.wait([Db.list(C.products), Db.list(C.collections)]);
      _productNames = {for (final p in results[0]) p.id: p.s('name')};
      _collectionNames = {for (final c in results[1]) c.id: c.s('name')};
      if (!_isNew) {
        final d = await Db.get(C.coupons, widget.id!);
        if (d == null) {
          _missing = true;
        } else {
          _code.text = d.s('code');
          _active = d.b('active', true);
          _discountType = d.s('discountType', 'percentage');
          _value.text = numText(d.n('value'));
          _startsAt = d.d('startsAt');
          _endsAt = d.d('endsAt');
          _dated = _startsAt != null || _endsAt != null;
          _eligible = d.s('eligible', 'all');
          _productIds = d.l<String>('productIds');
          _collectionIds = d.l<String>('collectionIds');
          final ms = d.data['minimumSpend'];
          _hasMinSpend = ms is num && ms > 0;
          _minSpend.text = _hasMinSpend ? numText(ms) : '';
          final mu = d.data['maxUses'];
          _limitUses = mu is num && mu > 0;
          _maxUses.text = _limitUses ? (mu as num).toInt().toString() : '';
          _onePerCustomer = d.b('onePerCustomer');
          _stack = d.b('stackWithCustomerDiscount', true);
          _uses = d.i('uses');
        }
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    for (final c in [_code, _value, _minSpend, _maxUses]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fail(String msg) {
    HapticFeedback.heavyImpact();
    toast(context, msg, error: true);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_form.currentState?.validate() ?? false)) return _fail('Please check the highlighted fields');
    final code = _code.text.trim().toUpperCase();
    final value = parseNum(_value.text);
    if (_discountType == 'percentage' && (value <= 0 || value > 100)) return _fail('Enter a percentage between 1 and 100');
    if (_discountType == 'fixed' && value <= 0) return _fail('Enter a discount amount');
    if (_dated && _startsAt != null && _endsAt != null && !_endsAt!.isAfter(_startsAt!)) return _fail('The end date must be after the start date');
    if (_eligible == 'products' && _productIds.isEmpty) return _fail('Select at least one product');
    if (_eligible == 'collections' && _collectionIds.isEmpty) return _fail('Select at least one collection');
    if (_limitUses && parseNum(_maxUses.text) <= 0) return _fail('Enter the maximum number of uses');
    setState(() => _saving = true);
    try {
      final existing = await Db.listWhere(C.coupons, 'code', code);
      if (existing.any((c) => c.id != widget.id)) {
        _fail('A coupon with code $code already exists');
        return;
      }
      final data = <String, dynamic>{
        'code': code,
        'active': _active,
        'discountType': _discountType,
        'value': value,
        'startsAt': _dated ? _startsAt : null,
        'endsAt': _dated ? _endsAt : null,
        'eligible': _eligible,
        'productIds': _eligible == 'products' ? _productIds : <String>[],
        'collectionIds': _eligible == 'collections' ? _collectionIds : <String>[],
        'minimumSpend': _hasMinSpend ? parseNum(_minSpend.text) : null,
        'maxUses': _limitUses ? parseNum(_maxUses.text).toInt() : null,
        'onePerCustomer': _onePerCustomer,
        'stackWithCustomerDiscount': _stack,
      };
      if (_isNew) {
        await Db.create(C.coupons, {...data, 'uses': 0, 'tags': <String>[]}, label: code);
        if (!mounted) return;
        HapticFeedback.mediumImpact();
        toast(context, 'Coupon $code created');
      } else {
        await Db.update(C.coupons, widget.id!, data, label: code);
        if (!mounted) return;
        HapticFeedback.mediumImpact();
        toast(context, 'Coupon saved');
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    HapticFeedback.mediumImpact();
    final code = _code.text.trim().toUpperCase();
    final ok = await confirmDialog(
      context,
      title: 'Delete coupon $code?',
      message: 'Customers will no longer be able to redeem this code. Past orders are not affected.',
      confirmLabel: 'Delete coupon',
      danger: true,
    );
    if (!ok || !mounted) return;
    try {
      await Db.remove(C.coupons, widget.id!, label: code);
      if (!mounted) return;
      toast(context, 'Coupon deleted');
      context.pop();
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  Future<void> _pick({required bool products}) async {
    HapticFeedback.selectionClick();
    final result = await showAppSheet<List<String>>(
      context,
      title: products ? 'Select products' : 'Select collections',
      scroll: false,
      builder: (_) => _MultiSelectSheet(
        options: products ? _productNames : _collectionNames,
        selected: products ? _productIds : _collectionIds,
        noun: products ? 'product' : 'collection',
        emptyText: products ? 'No products yet. Add products in Inventory first.' : 'No collections yet. Create collections in Inventory first.',
      ),
    );
    if (result == null) return;
    setState(() => products ? _productIds = result : _collectionIds = result);
  }

  List<(IconData, String)> _previewLines() {
    final out = <(IconData, String)>[];
    out.add((Icons.event_outlined, _dated ? couponValidityText(_startsAt, _endsAt) : 'No expiry date'));
    out.add((
      Icons.sell_outlined,
      switch (_eligible) {
        'products' => 'On ${_productIds.length} selected product${_productIds.length == 1 ? '' : 's'}',
        'collections' => 'On ${_collectionIds.length} selected collection${_collectionIds.length == 1 ? '' : 's'}',
        _ => 'On all products',
      }
    ));
    if (_hasMinSpend && parseNum(_minSpend.text) > 0) out.add((Icons.shopping_bag_outlined, 'Minimum spend ${Fmt.money(parseNum(_minSpend.text))}'));
    if (_limitUses && parseNum(_maxUses.text) > 0) out.add((Icons.redeem_rounded, 'Limited to ${parseNum(_maxUses.text).toInt()} uses'));
    if (_onePerCustomer) out.add((Icons.person_outline_rounded, 'One redemption per customer'));
    if (!_stack) out.add((Icons.layers_clear_outlined, 'Not combined with customer discounts'));
    return out;
  }

  Widget _chips(List<String> ids, Map<String, String> names) => Wrap(spacing: 6, runSpacing: 6, children: [
        for (final id in ids)
          Chip(
            label: Text(names[id] ?? 'Removed item', style: const TextStyle(fontSize: 12)),
            visualDensity: VisualDensity.compact,
            onDeleted: () => setState(() => ids.remove(id)),
          ),
      ]);

  // ------------------------------------------------------------------ build
  @override
  Widget build(BuildContext context) {
    if (_loading) return const FormScaffold(title: 'Coupon', children: [LoadingView()]);
    if (_missing) {
      return FormScaffold(title: 'Coupon not found', children: [
        EmptyState(
          icon: Icons.confirmation_number_outlined,
          title: 'This coupon no longer exists',
          message: 'It may have been deleted by a team member.',
          actionLabel: 'Back to coupons',
          onAction: () => context.pop(),
        ),
      ]);
    }

    final code = _code.text.trim().isEmpty ? 'YOURCODE' : _code.text.trim().toUpperCase();
    final remaining = _limitUses ? (parseNum(_maxUses.text) - _uses).clamp(0, 1 << 31) : null;

    return FormScaffold(
      title: _isNew ? 'New coupon' : _code.text.trim().toUpperCase(),
      formKey: _form,
      actions: [
        if (!_isNew)
          IconButton(tooltip: 'Copy code', icon: const Icon(Icons.copy_rounded), onPressed: () => copyCode(context, _code.text.trim().toUpperCase())),
        if (!_isNew) IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger), onPressed: _delete),
      ],
      bottom: GradientButton(
        label: _isNew ? 'Create coupon' : 'Save changes',
        icon: _isNew ? Icons.add_rounded : Icons.check_rounded,
        busy: _saving,
        onPressed: _save,
      ),
      children: [
        const SectionLabel('Live preview'),
        CouponTicket(
          code: code,
          discount: couponDiscountLabel(_discountType, parseNum(_value.text)),
          live: _active,
          large: true,
          stubWidth: 112,
          badge: _active ? null : const StatusPill('inactive'),
          lines: _previewLines(),
        ),
        if (!_isNew) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _Stat(label: 'Times redeemed', value: Fmt.integer(_uses), icon: Icons.redeem_rounded)),
            const SizedBox(width: 10),
            Expanded(
              child: _Stat(
                label: 'Remaining',
                value: remaining == null ? 'Unlimited' : Fmt.integer(remaining),
                icon: Icons.hourglass_bottom_rounded,
              ),
            ),
          ]),
        ],
        const SectionLabel('Coupon code'),
        Group(children: [
          Field(
            label: 'Coupon code',
            controller: _code,
            required: true,
            hint: 'e.g. SUMMER20',
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_-]')),
              TextInputFormatter.withFunction((o, n) => n.copyWith(text: n.text.toUpperCase())),
            ],
            helper: 'Letters, numbers, dashes and underscores. Codes aren’t case-sensitive.',
            onChanged: (_) => setState(() {}),
          ),
          SwitchTile(
            value: _active,
            title: 'Active',
            subtitle: 'Inactive coupons can’t be redeemed.',
            onChanged: (v) {
              HapticFeedback.selectionClick();
              setState(() => _active = v);
            },
          ),
        ]),
        const SectionLabel('Discount'),
        _DiscountTypePicker(
          value: _discountType,
          onChanged: (v) => setState(() => _discountType = v),
        ),
        const SizedBox(height: 12),
        Group(children: [
          Field(
            label: _discountType == 'percentage' ? 'Percentage off' : 'Amount off',
            controller: _value,
            suffixText: _discountType == 'percentage' ? '%' : null,
            prefixText: _discountType == 'fixed' ? '${Fmt.symbol} ' : null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            onChanged: (_) => setState(() {}),
            validator: (v) {
              final n = num.tryParse((v ?? '').trim());
              if (_discountType == 'percentage') return (n == null || n <= 0 || n > 100) ? 'Enter 1–100' : null;
              return (n == null || n <= 0) ? 'Enter an amount' : null;
            },
          ),
        ]),
        const SectionLabel('Validity'),
        Group(children: [
          SwitchTile(
            value: _dated,
            title: 'Specific dates',
            subtitle: 'Only valid between these dates.',
            onChanged: (v) {
              HapticFeedback.selectionClick();
              setState(() => _dated = v);
            },
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _dated
                ? Column(children: [
                    DateTimeField(label: 'Valid from', value: _startsAt, clearable: true, onChanged: (d) => setState(() => _startsAt = d)),
                    const SizedBox(height: 14),
                    DateTimeField(label: 'Valid until', value: _endsAt, clearable: true, onChanged: (d) => setState(() => _endsAt = d)),
                  ])
                : const SizedBox(width: double.infinity),
          ),
        ]),
        const SectionLabel('Eligible items'),
        RadioCards<String>(
          value: _eligible,
          onChanged: (v) {
            HapticFeedback.selectionClick();
            setState(() => _eligible = v);
          },
          options: const [
            ('all', 'All products', 'The discount applies to the whole order.'),
            ('products', 'Specific products', 'Only selected products are discounted.'),
            ('collections', 'Specific collections', 'Only products in selected collections are discounted.'),
          ],
          expanded: {
            'products': Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _chips(_productIds, _productNames),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _pick(products: true),
                icon: const Icon(Icons.playlist_add_check_rounded, size: 18),
                label: Text(_productIds.isEmpty ? 'Select products' : 'Edit selection'),
              ),
            ]),
            'collections': Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _chips(_collectionIds, _collectionNames),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _pick(products: false),
                icon: const Icon(Icons.playlist_add_check_rounded, size: 18),
                label: Text(_collectionIds.isEmpty ? 'Select collections' : 'Edit selection'),
              ),
            ]),
          },
        ),
        const SectionLabel('Limits'),
        Group(children: [
          SwitchTile(
            value: _hasMinSpend,
            title: 'Minimum spend',
            subtitle: 'The order subtotal must reach this amount.',
            onChanged: (v) => setState(() => _hasMinSpend = v),
          ),
          if (_hasMinSpend) Field.money(label: 'Minimum spend', controller: _minSpend, onChanged: (_) => setState(() {})),
          SwitchTile(
            value: _limitUses,
            title: 'Limit total uses',
            subtitle: 'Stop accepting the code after a number of redemptions.',
            onChanged: (v) => setState(() => _limitUses = v),
          ),
          if (_limitUses) Field.number(label: 'Maximum uses', controller: _maxUses, decimal: false, onChanged: (_) => setState(() {})),
          SwitchTile(
            value: _onePerCustomer,
            title: 'One per customer',
            subtitle: 'Each customer can redeem the code once.',
            onChanged: (v) => setState(() => _onePerCustomer = v),
          ),
          SwitchTile(
            value: _stack,
            title: 'Stack with customer discount',
            subtitle: 'Apply on top of a customer’s personal discount percentage.',
            onChanged: (v) => setState(() => _stack = v),
          ),
        ]),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _Stat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ]),
          ),
        ]),
      );
}

class _DiscountTypePicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _DiscountTypePicker({required this.value, required this.onChanged});

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
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(sub, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ]),
          ),
        ),
      );
    }

    return Row(children: [
      card('percentage', Icons.percent_rounded, 'Percentage', 'Off eligible items'),
      const SizedBox(width: 12),
      card('fixed', Icons.payments_outlined, 'Fixed value', 'Off the order'),
    ]);
  }
}

class _MultiSelectSheet extends StatefulWidget {
  final Map<String, String> options;
  final List<String> selected;
  final String noun;
  final String emptyText;
  const _MultiSelectSheet({required this.options, required this.selected, required this.noun, required this.emptyText});

  @override
  State<_MultiSelectSheet> createState() => _MultiSelectSheetState();
}

class _MultiSelectSheetState extends State<_MultiSelectSheet> {
  late final Set<String> _sel = {...widget.selected};
  String _q = '';

  @override
  Widget build(BuildContext context) {
    if (widget.options.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(widget.emptyText, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
      );
    }
    final entries = widget.options.entries.where((e) => _q.isEmpty || e.value.toLowerCase().contains(_q.toLowerCase())).toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      MSearch(hint: 'Search ${widget.noun}s', onChanged: (v) => setState(() => _q = v)),
      const SizedBox(height: 8),
      Flexible(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: entries.length,
          itemBuilder: (_, i) {
            final e = entries[i];
            final on = _sel.contains(e.key);
            return CheckboxListTile(
              value: on,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              controlAffinity: ListTileControlAffinity.leading,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text(e.value, style: const TextStyle(fontWeight: FontWeight.w600)),
              onChanged: (v) {
                HapticFeedback.selectionClick();
                setState(() => v == true ? _sel.add(e.key) : _sel.remove(e.key));
              },
            );
          },
        ),
      ),
      const SizedBox(height: 12),
      GradientButton(
        label: _sel.isEmpty ? 'Done' : 'Select ${_sel.length} ${widget.noun}${_sel.length == 1 ? '' : 's'}',
        onPressed: () => Navigator.pop(context, _sel.toList()),
      ),
    ]);
  }
}
