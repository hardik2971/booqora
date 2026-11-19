import 'package:flutter/material.dart' hide Thumb;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/browser.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/pricing.dart';
import '../../data/schema.dart';
import '../../data/session.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/mobile.dart';
import 'inv_common.dart';

/// Shared save helper for product tabs.
Future<bool> saveProduct(BuildContext context, Doc p, Map<String, dynamic> data, String msg) async {
  try {
    await Db.update(C.products, p.id, data, label: (data['name'] ?? p.s('name')).toString());
    HapticFeedback.lightImpact();
    if (context.mounted) toast(context, msg);
    return true;
  } catch (e) {
    if (context.mounted) toast(context, friendlyError(e), error: true);
    return false;
  }
}

/// Section label + grouped white card.
Widget section(String title, List<Widget> children, {String? subtitle, Widget? trailing, int index = 0}) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionLabel(title, trailing: trailing),
        Group(children: [
          if (subtitle != null) Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4)),
          ...children,
        ]),
      ]).enter(index),
    );

Widget _saveBtn(bool saving, VoidCallback onSave, {String label = 'Save changes'}) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: GradientButton(label: label, icon: Icons.check_rounded, busy: saving, onPressed: onSave),
    );

Widget _segmented(String label, String value, Map<String, String> items, ValueChanged<String> onChanged) =>
    Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      FieldLabel(label),
      SegmentedButton<String>(
        showSelectedIcon: false,
        segments: [for (final e in items.entries) ButtonSegment(value: e.key, label: Text(e.value))],
        selected: {value},
        onSelectionChanged: (v) {
          HapticFeedback.selectionClick();
          onChanged(v.first);
        },
      ),
    ]);

// ===========================================================================
// Variations
// ===========================================================================

class VariationsTab extends StatelessWidget {
  final Doc product;
  const VariationsTab({super.key, required this.product});

  Doc get p => product;

  Future<void> _addProperty(BuildContext context) async {
    final c = TextEditingController();
    final name = await showAppSheet<String>(
      context,
      title: 'Add property',
      builder: (d) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('For example Colour, Size or Material.', style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 14),
        Field(label: 'Property name', controller: c, autofocus: true, onSubmitted: (v) => Navigator.pop(d, v.trim())),
        SheetActions(label: 'Add property', icon: Icons.add_rounded, onPressed: () => Navigator.pop(d, c.text.trim())),
      ]),
    );
    if (name == null || name.isEmpty || !context.mounted) return;
    final props = p.l<String>('properties');
    if (props.any((x) => x.toLowerCase() == name.toLowerCase())) return toast(context, 'Property already exists', error: true);
    await saveProduct(context, p, {'properties': [...props, name], 'variationsEnabled': true}, 'Property added');
  }

  Future<void> _removeProperty(BuildContext context, String prop) async {
    final ok = await confirmDialog(context,
        title: 'Remove "$prop"?', message: 'The property value is removed from every variation.', confirmLabel: 'Remove', danger: true);
    if (!ok || !context.mounted) return;
    final vars = p.maps('variations').map((v) {
      final values = Map<String, dynamic>.from((v['values'] as Map?) ?? {})..remove(prop);
      return {...v, 'values': values};
    }).toList();
    await saveProduct(context, p, {'properties': p.l<String>('properties').where((x) => x != prop).toList(), 'variations': vars}, 'Property removed');
  }

  Future<void> _editVariation(BuildContext context, [Map<String, dynamic>? existing]) async {
    final props = p.l<String>('properties');
    final ctrls = {for (final pr in props) pr: TextEditingController(text: ((existing?['values'] as Map?)?[pr] ?? '').toString())};
    final price = TextEditingController(text: existing?['price']?.toString() ?? '${p.n('price')}');
    final weight = TextEditingController(text: existing?['weight']?.toString() ?? '');
    final sku = TextEditingController(text: (existing?['sku'] ?? '').toString());
    final result = await showAppSheet<Map<String, dynamic>>(
      context,
      title: existing == null ? 'Add variation' : 'Edit variation',
      builder: (d) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final pr in props) ...[Field(label: pr, controller: ctrls[pr]), const SizedBox(height: 14)],
        Field.money(label: 'Price', controller: price),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: Field.number(label: 'Weight', controller: weight, suffixText: p.s('weightUnit', 'kg'))),
          const SizedBox(width: 12),
          Expanded(child: Field(label: 'SKU', controller: sku)),
        ]),
        SheetActions(
          label: 'Save variation',
          icon: Icons.check_rounded,
          onPressed: () {
            final values = {for (final e in ctrls.entries) e.key: e.value.text.trim()};
            if (values.values.every((v) => v.isEmpty)) return toast(d, 'Enter at least one property value', error: true);
            Navigator.pop(d, {
              'id': existing?['id'] ?? Db.newId(),
              'name': values.values.where((v) => v.isNotEmpty).join(' / '),
              'values': values,
              'price': parseNum(price.text),
              'weight': parseNum(weight.text),
              'sku': sku.text.trim(),
            });
          },
        ),
      ]),
    );
    if (result == null || !context.mounted) return;
    final list = p.maps('variations');
    final i = list.indexWhere((v) => v['id'] == result['id']);
    if (i >= 0) {
      list[i] = result;
    } else {
      list.add(result);
    }
    await saveProduct(context, p, {'variations': list, 'variationsEnabled': true}, existing == null ? 'Variation added' : 'Variation updated');
  }

  Future<void> _deleteVariation(BuildContext context, Map<String, dynamic> v) async {
    if (!context.mounted) return;
    await saveProduct(context, p, {'variations': p.maps('variations').where((x) => x['id'] != v['id']).toList()}, 'Variation deleted');
  }

  @override
  Widget build(BuildContext context) {
    final props = p.l<String>('properties');
    final vars = p.maps('variations');
    final enabled = p.b('variationsEnabled');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      section('Variations', [
        SwitchTile(
          value: enabled,
          title: 'Enable variations',
          subtitle: 'Customers choose a variation when booking this product.',
          onChanged: (v) => saveProduct(context, p, {'variationsEnabled': v}, v ? 'Variations enabled' : 'Variations disabled'),
        ),
        if (enabled) ...[
          const InfoBanner('First add a property (e.g. Colour, Size), then add variations.', tone: Tone.brand, icon: Icons.tips_and_updates_outlined),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const FieldLabel('Properties'),
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              for (final pr in props) InputChip(label: Text(pr), onDeleted: () => _removeProperty(context, pr)),
              ActionChip(
                avatar: const Icon(Icons.add, size: 16, color: AppColors.primary),
                label: const Text('Add property'),
                backgroundColor: Colors.white,
                side: const BorderSide(color: AppColors.border),
                onPressed: () => _addProperty(context),
              ),
            ]),
          ]),
        ],
      ]),
      if (enabled) ...[
        SectionLabel('Variation list · ${vars.length}',
            trailing: props.isEmpty
                ? null
                : TextButton.icon(onPressed: () => _editVariation(context), icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add'))),
        if (vars.isEmpty)
          Group(children: [
            EmptyState(
              compact: true,
              icon: Icons.style_outlined,
              title: props.isEmpty ? 'Add a property first' : 'No variations yet',
              message: props.isEmpty ? 'Properties describe how variations differ, e.g. Colour.' : 'Add a variation for each combination you offer.',
              actionLabel: props.isEmpty ? 'Add property' : 'Add variation',
              onAction: () => props.isEmpty ? _addProperty(context) : _editVariation(context),
            ),
          ])
        else
          for (var i = 0; i < vars.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: swipeAction(
                key: ValueKey('v-${vars[i]['id']}'),
                context: context,
                icon: Icons.delete_outline,
                label: 'Delete',
                confirmTitle: 'Delete ${vars[i]['name']}?',
                confirmMessage: 'This variation will no longer be bookable.',
                onConfirmed: () => _deleteVariation(context, vars[i]),
                child: MTile(
                  onTap: () => _editVariation(context, vars[i]),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.style_outlined, color: AppColors.primary, size: 20),
                  ),
                  title: (vars[i]['name'] ?? '').toString(),
                  subtitle: [
                    for (final pr in props) '$pr: ${((vars[i]['values'] as Map?)?[pr] ?? '—')}',
                    if ((vars[i]['sku'] ?? '').toString().isNotEmpty) 'SKU ${vars[i]['sku']}',
                  ].join(' · '),
                  trailing: Text(Fmt.money((vars[i]['price'] as num?) ?? 0), style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ).enterX(i),
            ),
      ],
    ]);
  }
}

// ===========================================================================
// Pricing
// ===========================================================================

class PricingTab extends StatelessWidget {
  final Doc product;
  const PricingTab({super.key, required this.product});

  @override
  Widget build(BuildContext context) => LiveData.of(const [C.pricingStructures, C.taxProfiles],
      loading: const LoadingView(rows: 4),
      builder: (context, d) => _PricingForm(
            product: product,
            structures: d[C.pricingStructures]!,
            taxProfiles: d[C.taxProfiles]!.where((t) => t.s('kind', 'product') == 'product').toList(),
          ));
}

class _PricingForm extends StatefulWidget {
  final Doc product;
  final List<Doc> structures;
  final List<Doc> taxProfiles;
  const _PricingForm({required this.product, required this.structures, required this.taxProfiles});

  @override
  State<_PricingForm> createState() => _PricingFormState();
}

class _PricingFormState extends State<_PricingForm> {
  Doc get p => widget.product;
  late bool _charge = p.b('chargeEnabled', true);
  late String _method = p.s('pricingMethod', 'flat');
  late String _per = p.s('pricePer', 'day');
  late String? _structureId = p.s('pricingStructureId').isEmpty ? null : p.s('pricingStructureId');
  late bool _taxable = p.b('taxable');
  late String? _taxId = p.s('taxProfileId').isEmpty ? null : p.s('taxProfileId');
  late bool _discount = p.b('discountEligible', true);
  late final _price = TextEditingController(text: _fmt(p.n('price')));
  late final _deposit = TextEditingController(text: _fmt(p.n('deposit')));
  late final _cost = TextEditingController(text: _fmt(p.n('purchaseCost')));
  bool _saving = false;

  static String _fmt(num v) => v == 0 ? '' : (v == v.roundToDouble() ? v.toInt().toString() : v.toString());

  @override
  void dispose() {
    _price.dispose();
    _deposit.dispose();
    _cost.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_method == 'structure' && _structureId == null) return toast(context, 'Select a pricing structure', error: true);
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    await saveProduct(context, p, {
      'chargeEnabled': _charge,
      'pricingMethod': _method,
      'price': parseNum(_price.text),
      'pricePer': _per,
      'pricingStructureId': _structureId ?? '',
      'taxable': _taxable,
      'taxProfileId': _taxable ? (_taxId ?? '') : '',
      'discountEligible': _discount,
      'deposit': parseNum(_deposit.text),
      'purchaseCost': parseNum(_cost.text),
    }, 'Pricing saved');
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final rental = p.s('type', 'rental') == 'rental';
    final preview = Doc(p.id, {
      ...p.data,
      'chargeEnabled': _charge,
      'pricingMethod': _method,
      'price': parseNum(_price.text),
      'pricePer': _per,
    });
    final structure = widget.structures.where((s) => s.id == _structureId).firstOrNull;
    final now = DateTime(2026, 1, 5, 9);
    final durations = <(String, Duration)>[
      ('1 hour', const Duration(hours: 1)),
      ('1 day', const Duration(days: 1)),
      ('3 days', const Duration(days: 3)),
      ('1 week', const Duration(days: 7)),
      ('1 month', const Duration(days: 30)),
    ];
    final flat = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Field.money(label: 'Price', controller: _price, onChanged: (_) => setState(() {})),
      if (rental) ...[const SizedBox(height: 12), _segmented('Per', _per, perLabels, (v) => setState(() => _per = v))],
    ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      section('Price', [
        SwitchTile(value: _charge, title: 'Charge for this product', subtitle: 'Turn off to include it in orders free of charge.', onChanged: (v) => setState(() => _charge = v)),
        if (_charge)
          RadioCards<String>(
            value: _method,
            onChanged: (v) => setState(() => _method = v),
            options: [
              ('flat', 'Flat fee', rental ? 'A price per hour, day, week or month' : 'A fixed price per unit'),
              ('fixed', 'Fixed price', 'Charged once per order, regardless of duration'),
              if (rental) ('structure', 'Pricing structure', 'Tiered pricing, e.g. cheaper per day for longer rentals'),
              ('none', 'No pricing', 'Free of charge'),
            ],
            expanded: {
              'flat': flat,
              'fixed': Field.money(label: 'Price per order', controller: _price, onChanged: (_) => setState(() {})),
              'structure': Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                DropdownX<String>(
                  label: 'Pricing structure',
                  value: _structureId,
                  hint: widget.structures.isEmpty ? 'No structures yet' : 'Select structure',
                  items: {for (final s in widget.structures) s.id: s.s('name')},
                  onChanged: (v) => setState(() => _structureId = v),
                ),
                TextButton.icon(
                  onPressed: () => context.push('/settings/pricing'),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Manage pricing structures'),
                ),
              ]),
            },
          ),
      ]),
      section('Preview pricing', [
        Container(
          decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (var i = 0; i < durations.length; i++)
              Container(
                color: i.isEven ? const Color(0xFFFAF8FE) : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: Row(children: [
                  Expanded(child: Text(durations[i].$1, style: const TextStyle(color: AppColors.inkSoft))),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      Fmt.money(Pricing.unitPrice(preview, now, now.add(durations[i].$2), structure: structure)),
                      key: ValueKey('${durations[i].$1}-${_price.text}-$_per-$_method-$_structureId-$_charge'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ]),
              ),
          ]),
        ),
      ], subtitle: 'Price for one unit over each rental period', index: 1),
      section('Taxes & discounts', [
        SwitchTile(value: _taxable, title: 'Taxable', onChanged: (v) => setState(() => _taxable = v)),
        if (_taxable)
          DropdownX<String>(
            label: 'Tax profile',
            value: _taxId,
            hint: widget.taxProfiles.isEmpty ? 'Create tax profiles in Settings' : 'Default tax',
            items: {for (final t in widget.taxProfiles) t.id: '${t.s('name')} (${t.n('rate')}%)'},
            onChanged: (v) => setState(() => _taxId = v),
          ),
        SwitchTile(
            value: _discount,
            title: 'Eligible for discounts',
            subtitle: 'Customer discounts and coupons apply to this product.',
            onChanged: (v) => setState(() => _discount = v)),
      ], index: 2),
      section('Deposit & cost', [
        Field.money(label: 'Security deposit value', controller: _deposit, helper: 'Collected per unit and refunded on return'),
        Field.money(label: 'Default purchase cost', controller: _cost, helper: 'Used for stock value and new stock items'),
      ], index: 3),
      _saveBtn(_saving, _save),
    ]);
  }
}

// ===========================================================================
// Settings
// ===========================================================================

class SettingsTab extends StatefulWidget {
  final Doc product;
  const SettingsTab({super.key, required this.product});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  Doc get p => widget.product;
  late final _name = TextEditingController(text: p.s('name'));
  late final _sku = TextEditingController(text: p.s('sku'));
  late final _desc = TextEditingController(text: p.s('documentDescription'));
  late final _weight = TextEditingController(text: p.n('weight') == 0 ? '' : '${p.n('weight')}');
  late final _before = TextEditingController(text: p.n('bufferBefore') == 0 ? '' : '${p.n('bufferBefore')}');
  late final _after = TextEditingController(text: p.n('bufferAfter') == 0 ? '' : '${p.n('bufferAfter')}');
  late String _unit = p.s('weightUnit', 'kg');
  late bool _shortage = p.b('allowShortage');
  late String _tracking = p.s('trackingType', 'trackable');
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _sku, _desc, _weight, _before, _after]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return toast(context, 'Product name is a required field', error: true);
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    await saveProduct(context, p, {
      'name': name,
      'sku': _sku.text.trim(),
      'documentDescription': _desc.text.trim(),
      'weight': parseNum(_weight.text),
      'weightUnit': _unit,
      'allowShortage': _shortage,
      'bufferBefore': parseNum(_before.text),
      'bufferAfter': parseNum(_after.text),
      'trackingType': _tracking,
    }, 'Settings saved');
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _upload(PickedFile f) async {
    final url = await Db.upload('products', f.name, f.bytes);
    if (!mounted) return;
    await saveProduct(context, p, {'imageUrls': [...p.l<String>('imageUrls'), url]}, 'Image added');
  }

  Future<void> _imageActions(List<String> imgs, int i) async {
    HapticFeedback.selectionClick();
    await showAppSheet<void>(context, title: 'Image ${i + 1}', builder: (c) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(aspectRatio: 4 / 3, child: Image.network(imgs[i], fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined))),
        ),
        const SizedBox(height: 12),
        if (i > 0)
          NavRow(
            icon: Icons.star_outline_rounded,
            title: 'Make main image',
            onTap: () {
              Navigator.pop(c);
              final l = [...imgs]..removeAt(i);
              saveProduct(context, p, {'imageUrls': [imgs[i], ...l]}, 'Main image updated');
            },
          ),
        NavRow(
          icon: Icons.delete_outline,
          title: 'Remove image',
          color: AppColors.danger,
          onTap: () {
            Navigator.pop(c);
            saveProduct(context, p, {'imageUrls': [...imgs]..removeAt(i)}, 'Image removed');
          },
        ),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final imgs = p.l<String>('imageUrls');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      section('General', [
        Field(label: 'Name', controller: _name, required: true),
        Field(label: 'SKU', controller: _sku, hint: 'e.g. CAM-R6', helper: 'Scan this code to open the product'),
        Field(label: 'Description on documents', controller: _desc, maxLines: 4, hint: 'Shown under the product on quotes, contracts and invoices'),
      ]),
      section('Images', [
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: imgs.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              if (i == imgs.length) return ImageBox(key: ValueKey(imgs.length), size: 104, label: 'Add image', onUpload: _upload);
              return PressScale(
                onTap: () => _imageActions(imgs, i),
                child: Stack(children: [
                  Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: i == 0 ? AppColors.primary : AppColors.border, width: i == 0 ? 2 : 1),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(imgs[i], fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined)),
                  ),
                  if (i == 0) Positioned(left: 6, bottom: 6, child: smallChip('Main', color: Colors.white, bg: AppColors.primary)),
                ]),
              ).pop(i);
            },
          ),
        ),
      ], subtitle: 'The first image is the main image. Tap an image for options.', index: 1),
      section('Stock & logistics', [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 3, child: Field.number(label: 'Weight', controller: _weight)),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: DropdownX<String>(label: 'Unit', value: _unit, items: const {'kg': 'kg', 'g': 'g', 'lb': 'lb', 'oz': 'oz'}, onChanged: (v) => setState(() => _unit = v ?? 'kg')),
          ),
        ]),
        Field.number(label: 'Buffer before (hours)', controller: _before, helper: 'Preparation time blocked before each rental'),
        Field.number(label: 'Buffer after (hours)', controller: _after, helper: 'Cleaning or check-in time after each return'),
        SwitchTile(
            value: _shortage,
            title: 'Allow shortage',
            subtitle: 'Allow bookings even when not enough stock is available.',
            onChanged: (v) => setState(() => _shortage = v)),
        _segmented('Tracking type', _tracking, const {'trackable': 'Trackable', 'bulk': 'Bulk'}, (v) => setState(() => _tracking = v)),
      ], index: 2),
      _saveBtn(_saving, _save),
    ]);
  }
}

// ===========================================================================
// Online store
// ===========================================================================

class StoreTab extends StatefulWidget {
  final Doc product;
  const StoreTab({super.key, required this.product});

  @override
  State<StoreTab> createState() => _StoreTabState();
}

class _StoreTabState extends State<StoreTab> {
  Doc get p => widget.product;
  late bool _show = p.b('showInStore', true);
  late final _desc = TextEditingController(text: p.s('description'));
  late final _excerpt = TextEditingController(text: p.s('excerpt'));
  late final _title = TextEditingController(text: p.s('seoTitle'));
  late final _meta = TextEditingController(text: p.s('seoDescription'));
  late final _slug = TextEditingController(text: p.s('slug', Session.slugify(p.s('name'))));
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_desc, _excerpt, _title, _meta, _slug]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    await saveProduct(context, p, {
      'showInStore': _show,
      'description': _desc.text.trim(),
      'excerpt': _excerpt.text.trim(),
      'seoTitle': _title.text.trim(),
      'seoDescription': _meta.text.trim(),
      'slug': Session.slugify(_slug.text.isEmpty ? p.s('name') : _slug.text),
    }, 'Online store settings saved');
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final storeSlug = Session.instance.workspace?.s('slug') ?? '';
    final url = '${Browser.origin}/s/$storeSlug/p/${p.id}';
    final title = _title.text.isEmpty ? p.s('name') : _title.text;
    final desc = _meta.text.isEmpty ? (_excerpt.text.isEmpty ? 'Book ${p.s('name')} online.' : _excerpt.text) : _meta.text;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      section('Visibility', [
        SwitchTile(
            value: _show,
            title: 'Show in online store',
            subtitle: 'Customers can find and book this product in your store.',
            onChanged: (v) => setState(() => _show = v)),
      ]),
      section('Share', [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            const Icon(Icons.link_rounded, color: Colors.white70),
            const SizedBox(width: 10),
            Expanded(child: Text(url, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.4))),
          ]),
        ),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: url));
                HapticFeedback.lightImpact();
                if (context.mounted) toast(context, 'Link copied');
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copy'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(onPressed: () => Browser.openUrl(url), icon: const Icon(Icons.open_in_new_rounded, size: 18), label: const Text('Open')),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => Browser.shareText('${p.s('name')} — book online: $url', subject: p.s('name')),
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: const Text('Share'),
            ),
          ),
        ]),
      ], subtitle: 'Send customers straight to this product\'s booking page.', index: 1),
      section('Content', [
        Field(label: 'Description', controller: _desc, maxLines: 6, hint: 'Describe the product, what is included and how it is used'),
        Field(label: 'Excerpt', controller: _excerpt, maxLines: 2, hint: 'Short summary shown on product cards', onChanged: (_) => setState(() {})),
      ], index: 2),
      section('Search engine optimisation', [
        Field(label: 'Page title', controller: _title, maxLength: 60, hint: p.s('name'), onChanged: (_) => setState(() {})),
        Field(label: 'Meta description', controller: _meta, maxLength: 160, maxLines: 3, onChanged: (_) => setState(() {})),
        Field(label: 'Slug', controller: _slug, prefixText: '/', onChanged: (_) => setState(() {})),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFFFAF8FE), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('SEARCH PREVIEW', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.muted)),
            const SizedBox(height: 10),
            Text(url, style: const TextStyle(fontSize: 12, color: Color(0xFF188038)), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(fontSize: 17, color: Color(0xFF1A0DAB)), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(desc, style: const TextStyle(fontSize: 13, color: Color(0xFF4D5156), height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ], index: 3),
      _saveBtn(_saving, _save),
    ]);
  }
}

// ===========================================================================
// Cross-sell
// ===========================================================================

class CrossSellTab extends StatelessWidget {
  final Doc product;
  final List<Doc> products;
  final List<Doc> bundles;
  const CrossSellTab({super.key, required this.product, required this.products, required this.bundles});

  Future<void> _set(BuildContext context, List<String> ids, String msg) => saveProduct(context, product, {'crossSellIds': ids}, msg);

  @override
  Widget build(BuildContext context) {
    final enabled = Session.instance.setting('crossSell', 'enabled') == true;
    final ids = product.l<String>('crossSellIds');
    final bundleIds = bundles.map((b) => b.id).toSet();
    final all = <String, Doc>{for (final p in products) p.id: p, for (final b in bundles) b.id: b};
    final items = ids.where(all.containsKey).map((id) => all[id]!).toList();
    final candidates = [...products.where((x) => x.id != product.id && x.s('status', 'active') == 'active'), ...bundles];
    Future<void> add() async {
      final picked = await pickProductSheet(context, candidates, exclude: ids.toSet(), title: 'Add recommendation', isBundle: (d) => bundleIds.contains(d.id));
      if (picked != null && context.mounted) await _set(context, [...items.map((e) => e.id), picked.id], 'Recommendation added');
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (!enabled) ...[
        const SizedBox(height: 8),
        InfoBanner(
          'Cross-selling is turned off. Recommendations are saved but not shown in your store until you enable it.',
          tone: Tone.warning,
          actionLabel: 'Enable',
          onAction: () => context.push('/online-store/cross-sell'),
        ).enter(),
      ],
      SectionLabel('Recommended · ${items.length}',
          trailing: TextButton.icon(onPressed: add, icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add'))),
      if (items.isEmpty)
        Group(children: [
          EmptyState(
            compact: true,
            icon: Icons.add_shopping_cart,
            title: 'No recommendations yet',
            message: 'Suggest accessories or related items customers often book together with ${product.s('name')}.',
            actionLabel: 'Add recommendation',
            onAction: add,
          ),
        ])
      else
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
          clipBehavior: Clip.antiAlias,
          child: ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: items.length,
            onReorderStart: (_) => HapticFeedback.mediumImpact(),
            onReorder: (a, b) {
              final l = [...items.map((e) => e.id)];
              if (b > a) b -= 1;
              l.insert(b, l.removeAt(a));
              _set(context, l, 'Order updated');
            },
            itemBuilder: (c, i) {
              final it = items[i];
              final isB = bundleIds.contains(it.id);
              return Material(
                key: ValueKey(it.id),
                color: Colors.white,
                child: ListTile(
                  leading: Thumb(url: isB ? it.s('imageUrl') : productThumb(it), size: 40, icon: isB ? Icons.workspaces_outline : Icons.inventory_2_outlined),
                  title: Text(it.s('name'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(isB ? 'Bundle' : priceLabel(it), style: const TextStyle(fontSize: 12)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      tooltip: 'Remove',
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => _set(context, items.where((e) => e.id != it.id).map((e) => e.id).toList(), 'Recommendation removed'),
                    ),
                    ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_indicator_rounded, color: AppColors.muted)),
                  ]),
                ),
              );
            },
          ),
        ),
      const Padding(
        padding: EdgeInsets.fromLTRB(4, 10, 4, 0),
        child: Text('Shown on the product page and in the cart, in this order. Drag to reorder.', style: TextStyle(color: AppColors.muted, fontSize: 12)),
      ),
    ]);
  }
}
