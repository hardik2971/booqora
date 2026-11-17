import 'package:flutter/material.dart' hide Thumb;
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/page.dart';
import 'inv_common.dart';

class BundleFormPage extends StatelessWidget {
  final String? id;
  const BundleFormPage({super.key, this.id});

  @override
  Widget build(BuildContext context) {
    return LiveData(
      key: ValueKey(id ?? 'new'),
      streams: () => {
        C.products: Db.watch(C.products),
        C.collections: Db.watch(C.collections),
        if (id != null) 'bundle': Db.watchDoc(C.bundles, id!).map((d) => d == null ? <Doc>[] : [d]),
      },
      builder: (context, d) {
        if (id != null && d['bundle']!.isEmpty) {
          return EmptyState(
            icon: Icons.workspaces_outline,
            title: 'Bundle not found',
            message: 'It may have been deleted.',
            actionLabel: 'Back to bundles',
            onAction: () => context.go('/inventory?tab=bundles'),
          );
        }
        return _BundleForm(bundle: id == null ? null : d['bundle']!.first, products: d[C.products]!, collections: d[C.collections]!);
      },
    );
  }
}

class _BundleForm extends StatefulWidget {
  final Doc? bundle;
  final List<Doc> products;
  final List<Doc> collections;
  const _BundleForm({this.bundle, required this.products, required this.collections});

  @override
  State<_BundleForm> createState() => _BundleFormState();
}

class _BundleFormState extends State<_BundleForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.bundle?.s('name') ?? '');
  late final _desc = TextEditingController(text: widget.bundle?.s('description') ?? '');
  late final _price = TextEditingController(text: widget.bundle?.data['price'] is num ? '${widget.bundle!.n('price')}' : '');
  late String? _image = widget.bundle?.s('imageUrl');
  late List<Map<String, dynamic>> _items = widget.bundle?.maps('items') ?? [];
  late final Set<String> _cols = (widget.bundle?.l<String>('collectionIds') ?? <String>[]).toSet();
  late bool _show = widget.bundle?.b('showInStore', true) ?? true;
  late final List<String> _tags = widget.bundle?.l<String>('tags') ?? [];
  bool _saving = false;

  bool get _isNew => widget.bundle == null;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _price.dispose();
    super.dispose();
  }

  Doc? _product(String? id) => widget.products.where((p) => p.id == id).firstOrNull;

  num _lineTotal(Map<String, dynamic> it) {
    final p = _product(it['productId'] as String?);
    if (p == null) return 0;
    return p.n('price') * ((it['qty'] as num?) ?? 1) * (1 - ((it['discount'] as num?) ?? 0) / 100);
  }

  num get _sum => _items.fold<num>(0, (a, it) => a + _lineTotal(it));

  Future<void> _addItem() async {
    final p = await pickProductDialog(context, widget.products.where((p) => p.s('status', 'active') == 'active').toList(),
        exclude: _items.map((e) => e['productId'] as String).toSet(), title: 'Add product to bundle');
    if (p == null) return;
    setState(() => _items = [..._items, {'productId': p.id, 'name': p.s('name'), 'qty': 1, 'discount': 0}]);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return toast(context, 'Please fill in the required fields', error: true);
    if (_items.isEmpty) return toast(context, 'Add at least one product to the bundle', error: true);
    setState(() => _saving = true);
    try {
      final data = {
        'name': _name.text.trim(),
        'description': _desc.text.trim(),
        'imageUrl': _image ?? '',
        'items': _items,
        'price': _price.text.trim().isEmpty ? null : parseNum(_price.text),
        'collectionIds': _cols.toList(),
        'showInStore': _show,
        'tags': _tags,
      };
      if (_isNew) {
        final id = await Db.create(C.bundles, data);
        if (mounted) {
          toast(context, 'Bundle created');
          context.go('/inventory/bundles/$id');
        }
      } else {
        await Db.update(C.bundles, widget.bundle!.id, data);
        if (mounted) toast(context, 'Bundle saved');
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context, title: 'Delete ${widget.bundle!.s('name')}?', message: 'This cannot be undone.', confirmLabel: 'Delete', danger: true);
    if (!ok) return;
    try {
      await Db.remove(C.bundles, widget.bundle!.id, label: widget.bundle!.s('name'));
      if (mounted) {
        toast(context, 'Bundle deleted');
        context.go('/inventory?tab=bundles');
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 640;
    final userCols = widget.collections.where((c) => !c.b('isSystem')).toList();
    return Form(
      key: _form,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PageHeader(
          title: _isNew ? 'New bundle' : widget.bundle!.s('name'),
          breadcrumbs: const [('Inventory', '/inventory'), ('Bundles', '/inventory?tab=bundles')],
          actions: [
            if (!_isNew)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete'),
              ),
          ],
        ),
        Expanded(
          child: PageBody(maxWidth: 1100, children: [
            FormSection(
              title: 'General',
              description: 'Bundles are products often rented together — offer them at a discount.',
              index: 0,
              children: [
                Field(label: 'Name', controller: _name, required: true, hint: 'e.g. Wedding photo kit'),
                Field(label: 'Description', controller: _desc, maxLines: 4),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const FieldLabel('Image'),
                  ImageBox(
                    url: _image,
                    onUpload: (f) async {
                      final url = await Db.upload('bundles', f.name, f.bytes);
                      if (mounted) setState(() => _image = url);
                    },
                    onRemove: () => setState(() => _image = null),
                  ),
                ]),
              ],
            ),
            FormSection(
              title: 'Items',
              description: 'Choose the products in this bundle, their quantity and an optional discount per item.',
              index: 1,
              trailing: OutlinedButton.icon(onPressed: _addItem, icon: const Icon(Icons.add, size: 18), label: const Text('Add product')),
              children: [
                if (_items.isEmpty)
                  EmptyState(
                    compact: true,
                    icon: Icons.add_box_outlined,
                    title: 'No products yet',
                    message: 'Add the products customers rent together.',
                    actionLabel: 'Add product',
                    onAction: _addItem,
                  )
                else
                  for (var i = 0; i < _items.length; i++) _itemRow(i, narrow).enterX(i),
              ],
            ),
            FormSection(
              title: 'Price',
              description: 'Leave the price empty to charge the sum of the items (after per-item discounts).',
              index: 2,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.primarySoft.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(Icons.calculate_outlined, color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('Sum of items', style: TextStyle(fontWeight: FontWeight.w600))),
                    Text(Fmt.money(_sum), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                ),
                SizedBox(
                  width: 280,
                  child: Field.money(label: 'Bundle price override', controller: _price, helper: 'Optional — per rental period of the items'),
                ),
              ],
            ),
            FormSection(
              title: 'Online store',
              description: 'Where this bundle appears in your store.',
              index: 3,
              children: [
                CheckTile(value: _show, title: 'Show in online store', onChanged: (v) => setState(() => _show = v)),
                const FieldLabel('Collections'),
                if (userCols.isEmpty)
                  const Text('No collections yet.', style: TextStyle(color: AppColors.muted))
                else
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final c in userCols)
                      FilterChip(
                        label: Text(c.s('name')),
                        selected: _cols.contains(c.id),
                        onSelected: (v) => setState(() => v ? _cols.add(c.id) : _cols.remove(c.id)),
                      ),
                  ]),
              ],
            ),
          ]),
        ),
        SaveBar(
          saving: _saving,
          saveLabel: _isNew ? 'Create bundle' : 'Save',
          onCancel: () => context.go('/inventory?tab=bundles'),
          onSave: _save,
        ),
      ]),
    );
  }

  Widget _itemRow(int i, bool narrow) {
    final it = _items[i];
    final p = _product(it['productId'] as String?);
    void set(String k, num v) => setState(() => _items = [for (var j = 0; j < _items.length; j++) j == i ? {..._items[j], k: v} : _items[j]]);
    final qty = SizedBox(
      width: 90,
      child: TextFormField(
        key: ValueKey('q-${it['productId']}'),
        initialValue: '${it['qty'] ?? 1}',
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Qty'),
        onChanged: (v) => set('qty', parseNum(v, 1)),
      ),
    );
    final disc = SizedBox(
      width: 110,
      child: TextFormField(
        key: ValueKey('d-${it['productId']}'),
        initialValue: '${it['discount'] ?? 0}',
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Discount', suffixText: '%'),
        onChanged: (v) => set('discount', parseNum(v).clamp(0, 100)),
      ),
    );
    final remove = IconButton(
      tooltip: 'Remove',
      icon: const Icon(Icons.close, size: 18),
      onPressed: () => setState(() => _items = [..._items]..removeAt(i)),
    );
    final info = Row(children: [
      Thumb(url: p == null ? null : productThumb(p), size: 40),
      const SizedBox(width: 12),
      Expanded(child: CellTextLite(p?.s('name') ?? (it['name'] ?? 'Deleted product').toString(), p == null ? 'Unavailable' : priceLabel(p))),
    ]);
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: narrow
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [Expanded(child: info), remove]),
              const SizedBox(height: 10),
              Row(children: [qty, const SizedBox(width: 10), disc, const Spacer(), Text(Fmt.money(_lineTotal(it)), style: const TextStyle(fontWeight: FontWeight.w600))]),
            ])
          : Row(children: [
              Expanded(child: info),
              qty,
              const SizedBox(width: 10),
              disc,
              const SizedBox(width: 16),
              SizedBox(width: 100, child: Text(Fmt.money(_lineTotal(it)), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600))),
              remove,
            ]),
    );
  }
}

/// Compact title + subtitle text pair.
class CellTextLite extends StatelessWidget {
  final String title;
  final String subtitle;
  const CellTextLite(this.title, this.subtitle, {super.key});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(subtitle, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      ]);
}
