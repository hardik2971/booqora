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
import '../../widgets/table.dart';
import 'inv_common.dart';

/// Shared save helper for product tabs.
Future<bool> _saveProduct(BuildContext context, Doc p, Map<String, dynamic> data, String msg) async {
  try {
    await Db.update(C.products, p.id, data, label: (data['name'] ?? p.s('name')).toString());
    if (context.mounted) toast(context, msg);
    return true;
  } catch (e) {
    if (context.mounted) toast(context, friendlyError(e), error: true);
    return false;
  }
}

Widget _saveRow(bool saving, VoidCallback onSave, {String label = 'Save changes'}) => Align(
      alignment: Alignment.centerRight,
      child: FilledButton(
        onPressed: saving ? null : onSave,
        child: saving
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label),
      ),
    );

Widget _card(String title, List<Widget> children, {String? subtitle, int index = 0, Widget? trailing}) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionTitle(title, subtitle: subtitle, trailing: trailing),
          for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 16), children[i]],
        ]),
      ).enter(index),
    );

// ===========================================================================
// Variations
// ===========================================================================

class VariationsTab extends StatelessWidget {
  final Doc product;
  const VariationsTab({super.key, required this.product});

  Doc get p => product;

  Future<void> _addProperty(BuildContext context) async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (d) => dialogFrame(d,
          title: 'Add property',
          subtitle: 'For example Colour, Size or Material.',
          width: 420,
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: const Text('Add property')),
          ],
          child: Field(label: 'Property name', controller: c, autofocus: true, onSubmitted: (v) => Navigator.pop(d, v.trim()))),
    );
    c.dispose();
    if (name == null || name.isEmpty || !context.mounted) return;
    final props = p.l<String>('properties');
    if (props.any((x) => x.toLowerCase() == name.toLowerCase())) return toast(context, 'Property already exists', error: true);
    await _saveProduct(context, p, {'properties': [...props, name], 'variationsEnabled': true}, 'Property added');
  }

  Future<void> _removeProperty(BuildContext context, String prop) async {
    final ok = await confirmDialog(context,
        title: 'Remove "$prop"?', message: 'The property value is removed from every variation.', confirmLabel: 'Remove', danger: true);
    if (!ok || !context.mounted) return;
    final vars = p.maps('variations').map((v) {
      final values = Map<String, dynamic>.from((v['values'] as Map?) ?? {})..remove(prop);
      return {...v, 'values': values};
    }).toList();
    await _saveProduct(context, p, {'properties': p.l<String>('properties').where((x) => x != prop).toList(), 'variations': vars}, 'Property removed');
  }

  Future<void> _editVariation(BuildContext context, [Map<String, dynamic>? existing]) async {
    final props = p.l<String>('properties');
    final ctrls = {for (final pr in props) pr: TextEditingController(text: ((existing?['values'] as Map?)?[pr] ?? '').toString())};
    final price = TextEditingController(text: existing?['price']?.toString() ?? '${p.n('price')}');
    final weight = TextEditingController(text: existing?['weight']?.toString() ?? '');
    final sku = TextEditingController(text: (existing?['sku'] ?? '').toString());
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (d) => dialogFrame(d,
          title: existing == null ? 'Add variation' : 'Edit variation',
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
            FilledButton(
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
              child: const Text('Save variation'),
            ),
          ],
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            FieldGrid(children: [
              for (final pr in props) Field(label: pr, controller: ctrls[pr]),
            ]),
            const SizedBox(height: 16),
            FieldGrid(columns: 3, children: [
              Field.money(label: 'Price', controller: price),
              Field.number(label: 'Weight', controller: weight, suffixText: p.s('weightUnit', 'kg')),
              Field(label: 'SKU', controller: sku),
            ]),
          ])),
    );
    for (final c in [...ctrls.values, price, weight, sku]) {
      c.dispose();
    }
    if (result == null || !context.mounted) return;
    final list = p.maps('variations');
    final i = list.indexWhere((v) => v['id'] == result['id']);
    if (i >= 0) {
      list[i] = result;
    } else {
      list.add(result);
    }
    await _saveProduct(context, p, {'variations': list, 'variationsEnabled': true}, existing == null ? 'Variation added' : 'Variation updated');
  }

  Future<void> _deleteVariation(BuildContext context, Map<String, dynamic> v) async {
    final ok = await confirmDialog(context, title: 'Delete ${v['name']}?', message: 'This variation will no longer be bookable.', confirmLabel: 'Delete', danger: true);
    if (!ok || !context.mounted) return;
    await _saveProduct(context, p, {'variations': p.maps('variations').where((x) => x['id'] != v['id']).toList()}, 'Variation deleted');
  }

  @override
  Widget build(BuildContext context) {
    final props = p.l<String>('properties');
    final vars = p.maps('variations');
    final enabled = p.b('variationsEnabled');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _card('Variations', [
        SwitchTile(
          value: enabled,
          title: 'Enable variations',
          subtitle: 'Customers choose a variation when booking this product.',
          onChanged: (v) => _saveProduct(context, p, {'variationsEnabled': v}, v ? 'Variations enabled' : 'Variations disabled'),
        ),
        if (enabled) ...[
          const InfoBanner('Create variations: first add a property (e.g. Colour, Size), then add variations.', tone: Tone.brand, icon: Icons.tips_and_updates_outlined),
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
      if (enabled)
        _card('Variation list', [
          DataTableX<Map<String, dynamic>>(
            rows: vars,
            idOf: (v) => (v['id'] ?? v['name']).toString(),
            noun: 'variations',
            minWidth: 520 + props.length * 100,
            empty: EmptyState(
              compact: true,
              icon: Icons.style_outlined,
              title: props.isEmpty ? 'Add a property first' : 'No variations yet',
              message: props.isEmpty ? 'Properties describe how variations differ, e.g. Colour.' : 'Add a variation for each combination you offer.',
              actionLabel: props.isEmpty ? 'Add property' : 'Add variation',
              onAction: () => props.isEmpty ? _addProperty(context) : _editVariation(context),
            ),
            columns: [
              ColumnX('Name', (v) => Text((v['name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                  flex: 2, sort: (v) => (v['name'] ?? '').toString()),
              for (final pr in props) ColumnX(pr, (v) => Text(((v['values'] as Map?)?[pr] ?? '—').toString())),
              ColumnX('Price', (v) => Text(Fmt.money((v['price'] as num?) ?? 0)), numeric: true, sort: (v) => (v['price'] as num?) ?? 0),
              ColumnX('Weight', (v) => Text('${(v['weight'] as num?) ?? 0} ${p.s('weightUnit', 'kg')}'), numeric: true),
              ColumnX(
                  '',
                  (v) => Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () => _editVariation(context, v)),
                        IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline, size: 18), onPressed: () => _deleteVariation(context, v)),
                      ]),
                  width: 100),
            ],
          ),
        ],
            index: 1,
            trailing: props.isEmpty
                ? null
                : FilledButton.icon(onPressed: () => _editVariation(context), icon: const Icon(Icons.add, size: 18), label: const Text('Add variation'))),
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
    setState(() => _saving = true);
    await _saveProduct(context, p, {
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
    final flat = FieldGrid(children: [
      Field.money(label: 'Price', controller: _price, onChanged: (_) => setState(() {})),
      if (rental)
        DropdownX<String>(
          label: 'Per',
          value: _per,
          items: const {'hour': 'Hour', 'day': 'Day', 'week': 'Week', 'month': 'Month'},
          onChanged: (v) => setState(() => _per = v ?? 'day'),
        ),
    ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _card('Price', [
        CheckTile(value: _charge, title: 'Charge for this product', subtitle: 'Uncheck to include it in orders free of charge.', onChanged: (v) => setState(() => _charge = v)),
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
                  onPressed: () => context.go('/settings/pricing'),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Manage pricing structures'),
                ),
              ]),
            },
          ),
      ]),
      _card('Preview pricing', [
        Container(
          decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (var i = 0; i < durations.length; i++)
              Container(
                color: i.isEven ? const Color(0xFFFAF8FE) : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  Expanded(child: Text(durations[i].$1, style: const TextStyle(color: AppColors.inkSoft))),
                  Text(Fmt.money(Pricing.unitPrice(preview, now, now.add(durations[i].$2), structure: structure)),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
              ),
          ]),
        ),
      ], subtitle: 'Price for one unit over each rental period', index: 1),
      _card('Taxes & discounts', [
        CheckTile(value: _taxable, title: 'Taxable', onChanged: (v) => setState(() => _taxable = v)),
        if (_taxable)
          DropdownX<String>(
            label: 'Tax profile',
            value: _taxId,
            hint: widget.taxProfiles.isEmpty ? 'Create tax profiles in Settings' : 'Default tax',
            items: {for (final t in widget.taxProfiles) t.id: '${t.s('name')} (${t.n('rate')}%)'},
            onChanged: (v) => setState(() => _taxId = v),
          ),
        CheckTile(
            value: _discount,
            title: 'Eligible for discounts',
            subtitle: 'Customer discounts and coupons apply to this product.',
            onChanged: (v) => setState(() => _discount = v)),
      ], index: 2),
      _card('Deposit & cost', [
        FieldGrid(children: [
          Field.money(label: 'Security deposit value', controller: _deposit, helper: 'Collected per unit and refunded on return'),
          Field.money(label: 'Default purchase cost', controller: _cost, helper: 'Used for stock value and new stock items'),
        ]),
      ], index: 3),
      _saveRow(_saving, _save),
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
    setState(() => _saving = true);
    await _saveProduct(context, p, {
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
    await _saveProduct(context, p, {'imageUrls': [...p.l<String>('imageUrls'), url]}, 'Image added');
  }

  @override
  Widget build(BuildContext context) {
    final imgs = p.l<String>('imageUrls');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _card('General', [
        FieldGrid(children: [
          Field(label: 'Name', controller: _name, required: true),
          Field(label: 'SKU', controller: _sku, hint: 'e.g. CAM-R6'),
        ]),
        Field(label: 'Description on documents', controller: _desc, maxLines: 4, hint: 'Shown under the product on quotes, contracts and invoices'),
      ]),
      _card('Images', [
        Wrap(spacing: 12, runSpacing: 12, children: [
          for (var i = 0; i < imgs.length; i++)
            Stack(children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: i == 0 ? AppColors.primary : AppColors.border, width: i == 0 ? 2 : 1),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.network(imgs[i], fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined)),
              ).pop(i),
              if (i == 0) Positioned(left: 6, bottom: 6, child: smallChip('Main', color: Colors.white, bg: AppColors.primary)),
              Positioned(
                right: 4,
                top: 4,
                child: Row(children: [
                  if (i > 0)
                    _miniBtn(Icons.star_outline, 'Make main image', () {
                      final l = [...imgs]..removeAt(i);
                      _saveProduct(context, p, {'imageUrls': [imgs[i], ...l]}, 'Main image updated');
                    }),
                  const SizedBox(width: 4),
                  _miniBtn(Icons.close, 'Remove', () => _saveProduct(context, p, {'imageUrls': [...imgs]..removeAt(i)}, 'Image removed')),
                ]),
              ),
            ]),
          ImageBox(key: ValueKey(imgs.length), size: 110, label: 'Add image', onUpload: _upload),
        ]),
      ], subtitle: 'The first image is used as the main image', index: 1),
      _card('Stock & logistics', [
        FieldGrid(children: [
          Field.number(label: 'Weight', controller: _weight),
          DropdownX<String>(label: 'Unit', value: _unit, items: const {'kg': 'kg', 'g': 'g', 'lb': 'lb', 'oz': 'oz'}, onChanged: (v) => setState(() => _unit = v ?? 'kg')),
          Field.number(label: 'Buffer before (hours)', controller: _before, helper: 'Preparation time blocked before each rental'),
          Field.number(label: 'Buffer after (hours)', controller: _after, helper: 'Cleaning or check-in time after each return'),
        ]),
        CheckTile(
            value: _shortage,
            title: 'Allow shortage',
            subtitle: 'Allow bookings even when not enough stock is available.',
            onChanged: (v) => setState(() => _shortage = v)),
        DropdownX<String>(
          label: 'Tracking type',
          value: _tracking,
          items: const {'trackable': 'Trackable — individual identifiers', 'bulk': 'Bulk — quantity only'},
          onChanged: (v) => setState(() => _tracking = v ?? 'trackable'),
        ),
      ], index: 2),
      _saveRow(_saving, _save),
    ]);
  }

  Widget _miniBtn(IconData icon, String tip, VoidCallback onTap) => Tooltip(
        message: tip,
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(),
          child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: Padding(padding: const EdgeInsets.all(4), child: Icon(icon, size: 14))),
        ),
      );
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
    setState(() => _saving = true);
    await _saveProduct(context, p, {
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
    final snippet = '<iframe src="$url" width="100%" height="640" style="border:0;border-radius:12px" loading="lazy" title="${p.s('name')}"></iframe>';
    final title = _title.text.isEmpty ? p.s('name') : _title.text;
    final desc = _meta.text.isEmpty ? (_excerpt.text.isEmpty ? 'Book ${p.s('name')} online.' : _excerpt.text) : _meta.text;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _card('Visibility', [
        CheckTile(
            value: _show,
            title: 'Show in online store',
            subtitle: 'Customers can find and book this product in your store.',
            onChanged: (v) => setState(() => _show = v)),
      ]),
      _card('Content', [
        Field(label: 'Description', controller: _desc, maxLines: 6, hint: 'Describe the product, what is included and how it is used'),
        Field(label: 'Excerpt', controller: _excerpt, maxLines: 2, hint: 'Short summary shown on product cards'),
      ], index: 1),
      _card('Search engine optimisation', [
        Field(label: 'Page title', controller: _title, maxLength: 60, hint: p.s('name'), onChanged: (_) => setState(() {})),
        Field(label: 'Meta description', controller: _meta, maxLength: 160, maxLines: 3, onChanged: (_) => setState(() {})),
        Field(label: 'Slug', controller: _slug, prefixText: '/', onChanged: (_) => setState(() {})),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFFFAF8FE), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Search preview', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.muted)),
            const SizedBox(height: 10),
            Text(url, style: const TextStyle(fontSize: 12, color: Color(0xFF188038)), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(fontSize: 18, color: Color(0xFF1A0DAB)), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(desc, style: const TextStyle(fontSize: 13, color: Color(0xFF4D5156), height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ], index: 2),
      _card('Embed on your website', [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(12)),
          child: SelectableText(snippet, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFFE9E3FF), height: 1.5)),
        ),
        Wrap(spacing: 10, runSpacing: 10, children: [
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: snippet));
              if (context.mounted) toast(context, 'Embed code copied');
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy code'),
          ),
          OutlinedButton.icon(onPressed: () => Browser.openUrl(url), icon: const Icon(Icons.open_in_new, size: 16), label: const Text('Open product page')),
        ]),
      ], subtitle: 'Paste this snippet into any page to show a booking widget for this product', index: 3),
      _saveRow(_saving, _save),
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

  Future<void> _set(BuildContext context, List<String> ids, String msg) =>
      _saveProduct(context, product, {'crossSellIds': ids}, msg);

  @override
  Widget build(BuildContext context) {
    final enabled = Session.instance.setting('crossSell', 'enabled') == true;
    final ids = product.l<String>('crossSellIds');
    final bundleIds = bundles.map((b) => b.id).toSet();
    final all = <String, Doc>{for (final p in products) p.id: p, for (final b in bundles) b.id: b};
    final items = ids.where(all.containsKey).map((id) => all[id]!).toList();
    final candidates = [...products.where((x) => x.id != product.id && x.s('status', 'active') == 'active'), ...bundles];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (!enabled) ...[
        InfoBanner(
          'Cross-selling is turned off. Recommendations are saved but not shown in your online store until you enable it.',
          tone: Tone.warning,
          actionLabel: 'Go to settings',
          onAction: () => context.go('/online-store/cross-sell'),
        ).enter(),
        const SizedBox(height: 16),
      ],
      _card('Recommended products', [
        if (items.isEmpty)
          EmptyState(
            compact: true,
            icon: Icons.add_shopping_cart,
            title: 'No recommendations yet',
            message: 'Suggest accessories or related items customers often book together with ${product.s('name')}.',
          )
        else
          Column(children: [
            for (var i = 0; i < items.length; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: Row(children: [
                  Text('${i + 1}', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 12),
                  Thumb(
                      url: bundleIds.contains(items[i].id) ? items[i].s('imageUrl') : productThumb(items[i]),
                      size: 36,
                      icon: bundleIds.contains(items[i].id) ? Icons.workspaces_outline : Icons.inventory_2_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CellText(items[i].s('name'), subtitle: bundleIds.contains(items[i].id) ? 'Bundle' : priceLabel(items[i])),
                  ),
                  IconButton(
                    tooltip: 'Move up',
                    icon: const Icon(Icons.arrow_upward, size: 18),
                    onPressed: i == 0
                        ? null
                        : () {
                            final l = [...items.map((e) => e.id)];
                            l.insert(i - 1, l.removeAt(i));
                            _set(context, l, 'Order updated');
                          },
                  ),
                  IconButton(
                    tooltip: 'Move down',
                    icon: const Icon(Icons.arrow_downward, size: 18),
                    onPressed: i == items.length - 1
                        ? null
                        : () {
                            final l = [...items.map((e) => e.id)];
                            l.insert(i + 1, l.removeAt(i));
                            _set(context, l, 'Order updated');
                          },
                  ),
                  IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => _set(context, items.where((e) => e.id != items[i].id).map((e) => e.id).toList(), 'Recommendation removed'),
                  ),
                ]),
              ).enterX(i),
          ]),
      ],
          subtitle: 'Shown on the product page and in the cart, in this order',
          trailing: FilledButton.icon(
            onPressed: () async {
              final picked = await pickProductDialog(context, candidates,
                  exclude: ids.toSet(), title: 'Add recommendation', isBundle: (d) => bundleIds.contains(d.id));
              if (picked != null && context.mounted) await _set(context, [...items.map((e) => e.id), picked.id], 'Recommendation added');
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add'),
          )),
    ]);
  }
}
