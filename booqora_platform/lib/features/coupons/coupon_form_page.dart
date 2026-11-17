import 'package:flutter/material.dart' hide Thumb;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/page.dart';
import 'coupons_page.dart';

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
          _value.text = _numText(d.n('value'));
          _startsAt = d.d('startsAt');
          _endsAt = d.d('endsAt');
          _dated = _startsAt != null || _endsAt != null;
          _eligible = d.s('eligible', 'all');
          _productIds = d.l<String>('productIds');
          _collectionIds = d.l<String>('collectionIds');
          final ms = d.data['minimumSpend'];
          _hasMinSpend = ms is num && ms > 0;
          _minSpend.text = _hasMinSpend ? _numText(ms) : '';
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

  String _numText(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    for (final c in [_code, _value, _minSpend, _maxUses]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) {
      toast(context, 'Please check the highlighted fields', error: true);
      return;
    }
    final code = _code.text.trim().toUpperCase();
    final value = parseNum(_value.text);
    if (_dated && _startsAt != null && _endsAt != null && !_endsAt!.isAfter(_startsAt!)) {
      toast(context, 'The end date must be after the start date', error: true);
      return;
    }
    if (_eligible == 'products' && _productIds.isEmpty) {
      toast(context, 'Select at least one product', error: true);
      return;
    }
    if (_eligible == 'collections' && _collectionIds.isEmpty) {
      toast(context, 'Select at least one collection', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final existing = await Db.listWhere(C.coupons, 'code', code);
      if (existing.any((c) => c.id != widget.id)) {
        if (mounted) toast(context, 'A coupon with code $code already exists', error: true);
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
        final id = await Db.create(C.coupons, {...data, 'uses': 0, 'tags': <String>[]}, label: code);
        if (!mounted) return;
        toast(context, 'Coupon $code created');
        context.go('/coupons/$id');
      } else {
        await Db.update(C.coupons, widget.id!, data, label: code);
        if (mounted) toast(context, 'Coupon saved');
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
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
      context.go('/coupons');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  Future<void> _pick({required bool products}) async {
    final source = products ? _productNames : _collectionNames;
    final result = await showDialog<List<String>>(
      context: context,
      builder: (_) => _MultiSelectDialog(
        title: products ? 'Select products' : 'Select collections',
        options: source,
        selected: products ? _productIds : _collectionIds,
        emptyText: products ? 'No products yet. Add products in Inventory first.' : 'No collections yet. Create collections in Inventory first.',
      ),
    );
    if (result == null) return;
    setState(() => products ? _productIds = result : _collectionIds = result);
  }

  // ------------------------------------------------------------------ build
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(title: 'Coupon', breadcrumbs: [('Coupons', '/coupons')]),
          Padding(padding: EdgeInsets.symmetric(horizontal: 28), child: LoadingView()),
        ],
      );
    }
    if (_missing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeader(title: 'Coupon not found', breadcrumbs: [('Coupons', '/coupons')]),
          Expanded(
            child: EmptyState(
              icon: Icons.confirmation_number_outlined,
              title: 'This coupon no longer exists',
              message: 'It may have been deleted by a team member.',
              actionLabel: 'Back to coupons',
              onAction: () => context.go('/coupons'),
            ),
          ),
        ],
      );
    }

    final preview = _CouponTicket(
      code: _code.text.trim().isEmpty ? 'YOURCODE' : _code.text.trim().toUpperCase(),
      discount: couponDiscountLabel(_discountType, parseNum(_value.text)),
      active: _active,
      lines: _previewLines(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: _isNew ? 'New coupon' : _code.text.trim().toUpperCase(),
          subtitle: _isNew ? 'Create a discount code for online checkout and manual orders.' : null,
          breadcrumbs: const [('Coupons', '/coupons')],
          titleTrailing: _isNew ? null : StatusPill(_active ? 'active' : 'inactive'),
        ),
        Expanded(
          child: Form(
            key: _form,
            child: PageBody(
              children: [
                LayoutBuilder(
                  builder: (context, c) {
                    final form = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _sections());
                    if (c.maxWidth < 1040) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: preview),
                          ),
                          const SizedBox(height: 24),
                          form,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: form),
                        const SizedBox(width: 28),
                        SizedBox(
                          width: 340,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'LIVE PREVIEW',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: AppColors.muted),
                              ),
                              const SizedBox(height: 10),
                              preview,
                              if (!_isNew) ...[
                                const SizedBox(height: 16),
                                AppCard(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    children: [
                                      KV('Times redeemed', Fmt.integer(_uses), bold: true),
                                      const SizedBox(height: 6),
                                      KV('Remaining', _limitUses ? Fmt.integer((parseNum(_maxUses.text) - _uses).clamp(0, 1 << 31)) : 'Unlimited'),
                                    ],
                                  ),
                                ).enter(2),
                              ],
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        SaveBar(
          saving: _saving,
          saveLabel: _isNew ? 'Create coupon' : 'Save',
          onSave: _save,
          onCancel: () => context.go('/coupons'),
          leading: _isNew
              ? null
              : TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                  onPressed: _saving ? null : _delete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                ),
        ),
      ],
    );
  }

  List<String> _previewLines() {
    final out = <String>[];
    if (_dated && (_startsAt != null || _endsAt != null)) {
      if (_startsAt != null && _endsAt != null) {
        out.add('Valid ${Fmt.date(_startsAt)} – ${Fmt.date(_endsAt)}');
      } else if (_startsAt != null) {
        out.add('Valid from ${Fmt.date(_startsAt)}');
      } else {
        out.add('Valid until ${Fmt.date(_endsAt)}');
      }
    } else {
      out.add('No expiry date');
    }
    out.add(switch (_eligible) {
      'products' => 'On ${_productIds.length} selected product${_productIds.length == 1 ? '' : 's'}',
      'collections' => 'On ${_collectionIds.length} selected collection${_collectionIds.length == 1 ? '' : 's'}',
      _ => 'On all products',
    });
    if (_hasMinSpend && parseNum(_minSpend.text) > 0) out.add('Minimum spend ${Fmt.money(parseNum(_minSpend.text))}');
    if (_limitUses && parseNum(_maxUses.text) > 0) out.add('Limited to ${parseNum(_maxUses.text).toInt()} uses');
    if (_onePerCustomer) out.add('One redemption per customer');
    if (!_stack) out.add('Not combined with customer discounts');
    return out;
  }

  Widget _chips(List<String> ids, Map<String, String> names) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final id in ids)
        Chip(
          label: Text(names[id] ?? 'Removed item', style: const TextStyle(fontSize: 12)),
          visualDensity: VisualDensity.compact,
          onDeleted: () => setState(() {
            ids.remove(id);
          }),
        ),
    ],
  );

  List<Widget> _sections() => [
    FormSection(
      index: 0,
      title: 'Coupon code',
      description: 'Customers enter this code at checkout. Codes aren’t case-sensitive.',
      children: [
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
        SwitchTile(value: _active, title: 'Active', subtitle: 'Inactive coupons can’t be redeemed.', onChanged: (v) => setState(() => _active = v)),
      ],
    ),
    FormSection(
      index: 1,
      title: 'Discount',
      description: 'A percentage off the order or a fixed amount.',
      children: [
        RadioCards<String>(
          value: _discountType,
          onChanged: (v) => setState(() => _discountType = v),
          options: const [('percentage', 'Percentage', 'A percentage off eligible items'), ('fixed', 'Fixed value', 'A fixed amount off the order')],
          expanded: {
            'percentage': SizedBox(
              width: 220,
              child: Field(
                label: 'Value',
                controller: _value,
                suffixText: '%',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final n = num.tryParse((v ?? '').trim());
                  if (n == null || n <= 0 || n > 100) return 'Enter 1–100';
                  return null;
                },
              ),
            ),
            'fixed': SizedBox(
              width: 220,
              child: Field(
                label: 'Value',
                controller: _value,
                prefixText: '${Fmt.symbol} ',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final n = num.tryParse((v ?? '').trim());
                  if (n == null || n <= 0) return 'Enter an amount';
                  return null;
                },
              ),
            ),
          },
        ),
      ],
    ),
    FormSection(
      index: 2,
      title: 'Usage & limitations',
      description: 'When the coupon is valid and what it applies to.',
      children: [
        CheckTile(value: _dated, title: 'Specific dates', subtitle: 'Only valid between these dates.', onChanged: (v) => setState(() => _dated = v)),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: _dated
              ? FieldGrid(
                  children: [
                    DateTimeField(label: 'Valid from', value: _startsAt, clearable: true, onChanged: (d) => setState(() => _startsAt = d)),
                    DateTimeField(label: 'Valid until', value: _endsAt, clearable: true, onChanged: (d) => setState(() => _endsAt = d)),
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
        const FieldLabel('Eligible items'),
        RadioCards<String>(
          value: _eligible,
          onChanged: (v) => setState(() => _eligible = v),
          options: const [
            ('all', 'All products', 'The discount applies to the whole order.'),
            ('products', 'Specific products', 'Only selected products are discounted.'),
            ('collections', 'Specific collections', 'Only products in selected collections are discounted.'),
          ],
          expanded: {
            'products': Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _chips(_productIds, _productNames),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _pick(products: true),
                  icon: const Icon(Icons.playlist_add_check_rounded, size: 18),
                  label: Text(_productIds.isEmpty ? 'Select products' : 'Edit selection'),
                ),
              ],
            ),
            'collections': Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _chips(_collectionIds, _collectionNames),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _pick(products: false),
                  icon: const Icon(Icons.playlist_add_check_rounded, size: 18),
                  label: Text(_collectionIds.isEmpty ? 'Select collections' : 'Edit selection'),
                ),
              ],
            ),
          },
        ),
        CheckTile(
          value: _hasMinSpend,
          title: 'Minimum spend',
          subtitle: 'The order subtotal must reach this amount.',
          onChanged: (v) => setState(() => _hasMinSpend = v),
        ),
        if (_hasMinSpend)
          SizedBox(
            width: 240,
            child: Field.money(label: 'Minimum spend', controller: _minSpend, onChanged: (_) => setState(() {})),
          ),
      ],
    ),
    FormSection(
      index: 3,
      title: 'Redemption limits',
      description: 'Control how often the coupon can be used.',
      children: [
        CheckTile(
          value: _limitUses,
          title: 'Limit total number of uses',
          subtitle: 'Stop accepting the code after a number of redemptions.',
          onChanged: (v) => setState(() => _limitUses = v),
        ),
        if (_limitUses)
          SizedBox(
            width: 240,
            child: Field.number(label: 'Maximum uses', controller: _maxUses, decimal: false, onChanged: (_) => setState(() {})),
          ),
        CheckTile(value: _onePerCustomer, title: 'Limit to one redemption per customer', onChanged: (v) => setState(() => _onePerCustomer = v)),
        CheckTile(
          value: _stack,
          title: 'Stack with customer discount',
          subtitle: 'Apply on top of a customer’s personal discount percentage.',
          onChanged: (v) => setState(() => _stack = v),
        ),
      ],
    ),
  ];
}

const double _ticketHead = 112;

/// Ticket-style live preview of the coupon.
class _CouponTicket extends StatelessWidget {
  final String code;
  final String discount;
  final bool active;
  final List<String> lines;
  const _CouponTicket({required this.code, required this.discount, required this.active, required this.lines});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: active ? 1 : 0.55,
      child: ClipPath(
        clipper: _TicketClipper(),
        child: Container(
          decoration: const BoxDecoration(gradient: AppColors.brandGradient),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: _ticketHead,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.confirmation_number_rounded, color: Colors.white70, size: 18),
                        const SizedBox(width: 6),
                        const Text(
                          'COUPON',
                          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4),
                        ),
                        const Spacer(),
                        if (!active)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                            child: const Text(
                              'Inactive',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (c, a) => FadeTransition(
                        opacity: a,
                        child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(a), child: c),
                      ),
                      child: FittedBox(
                        key: ValueKey(discount),
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '$discount OFF',
                          style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 1,
                child: LayoutBuilder(
                  builder: (context, c) {
                    final n = (c.maxWidth / 10).floor();
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [for (var i = 0; i < n; i++) Container(width: 5, height: 1, color: Colors.white38)],
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        code,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: 2,
                          color: AppColors.primaryDeep,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (final l in lines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 3),
                              child: Icon(Icons.check_rounded, color: AppColors.lavender, size: 14),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(l, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).enter(1);
  }
}

class _TicketClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const r = 14.0;
    const notch = 12.0;
    const y = _ticketHead;
    final rect = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(r)));
    final holes = Path()
      ..addOval(Rect.fromCircle(center: Offset(0, y), radius: notch))
      ..addOval(Rect.fromCircle(center: Offset(size.width, y), radius: notch));
    return Path.combine(PathOperation.difference, rect, holes);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => true;
}

class _MultiSelectDialog extends StatefulWidget {
  final String title;
  final Map<String, String> options;
  final List<String> selected;
  final String emptyText;
  const _MultiSelectDialog({required this.title, required this.options, required this.selected, required this.emptyText});

  @override
  State<_MultiSelectDialog> createState() => _MultiSelectDialogState();
}

class _MultiSelectDialogState extends State<_MultiSelectDialog> {
  late final Set<String> _sel = {...widget.selected};
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final entries = widget.options.entries.where((e) => e.value.toLowerCase().contains(_q.toLowerCase())).toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 440,
        height: 420,
        child: widget.options.isEmpty
            ? Center(
                child: Text(
                  widget.emptyText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted),
                ),
              )
            : Column(
                children: [
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(hintText: 'Search…', prefixIcon: Icon(Icons.search, size: 20)),
                    onChanged: (v) => setState(() => _q = v),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: entries.length,
                      itemBuilder: (_, i) {
                        final e = entries[i];
                        return CheckboxListTile(
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _sel.contains(e.key),
                          title: Text(e.value),
                          onChanged: (v) => setState(() => v == true ? _sel.add(e.key) : _sel.remove(e.key)),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        Text('${_sel.length} selected', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, _sel.toList()), child: const Text('Done')),
      ],
    );
  }
}
