import 'package:flutter/material.dart' hide Thumb;
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/mobile.dart';
import 'inv_common.dart';
import 'product_tabs.dart' show section;

class BundleFormPage extends StatelessWidget {
  final String? id;
  const BundleFormPage({super.key, this.id});

  @override
  Widget build(BuildContext context) {
    return LiveData(
      key: ValueKey(id ?? 'new'),
      loading: Scaffold(backgroundColor: AppColors.bg, appBar: AppBar(backgroundColor: AppColors.bg, title: const Text('Bundle')), body: const LoadingView()),
      streams: () => {
        C.products: Db.watch(C.products),
        C.collections: Db.watch(C.collections),
        if (id != null) 'bundle': Db.watchDoc(C.bundles, id!).map((d) => d == null ? <Doc>[] : [d]),
      },
      builder: (context, d) {
        if (id != null && d['bundle']!.isEmpty) {
          return Scaffold(
            backgroundColor: AppColors.bg,
            appBar: AppBar(backgroundColor: AppColors.bg),
            body: EmptyState(
              icon: Icons.workspaces_outline,
              title: 'Bundle not found',
              message: 'It may have been deleted.',
              actionLabel: 'Go back',
              onAction: () => Navigator.of(context).maybePop(),
            ),
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
    final p = await pickProductSheet(context, widget.products.where((p) => p.s('status', 'active') == 'active').toList(),
        exclude: _items.map((e) => e['productId'] as String).toSet(), title: 'Add product to bundle');
    if (p == null) return;
    setState(() => _items = [..._items, {'productId': p.id, 'name': p.s('name'), 'qty': 1, 'discount': 0}]);
  }

  void _set(int i, String k, num v) => setState(() => _items = [for (var j = 0; j < _items.length; j++) j == i ? {..._items[j], k: v} : _items[j]]);

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return toast(context, 'Please fill in the required fields', error: true);
    if (_items.isEmpty) return toast(context, 'Add at least one product to the bundle', error: true);
    FocusScope.of(context).unfocus();
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
        await Db.create(C.bundles, data);
        if (mounted) {
          HapticFeedback.mediumImpact();
          toast(context, 'Bundle created');
          Navigator.of(context).maybePop();
        }
      } else {
        await Db.update(C.bundles, widget.bundle!.id, data);
        if (mounted) {
          HapticFeedback.lightImpact();
          toast(context, 'Bundle saved');
        }
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context, title: 'Delete ${widget.bundle!.s('name')}?', message: 'This cannot be undone.', confirmLabel: 'Delete', danger: true);
    if (!ok || !mounted) return;
    final nav = Navigator.of(context);
    final done = await runAction(context, () => Db.remove(C.bundles, widget.bundle!.id, label: widget.bundle!.s('name')), 'Bundle deleted');
    if (done) nav.maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final userCols = widget.collections.where((c) => !c.b('isSystem')).toList();
    final override = _price.text.trim().isNotEmpty;
    return FormScaffold(
      title: _isNew ? 'New bundle' : widget.bundle!.s('name'),
      formKey: _form,
      actions: [
        if (!_isNew) IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline, color: AppColors.danger), onPressed: _delete),
      ],
      bottom: Row(children: [
        Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Bundle price', style: TextStyle(color: AppColors.muted, fontSize: 12)),
            Text(Fmt.money(override ? parseNum(_price.text) : _sum), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ]),
        ),
        Expanded(
          flex: 2,
          child: GradientButton(label: _isNew ? 'Create bundle' : 'Save', icon: Icons.check_rounded, busy: _saving, onPressed: _save),
        ),
      ]),
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ImageBox(
              url: _image,
              size: 132,
              label: 'Add photo',
              onUpload: (f) async {
                final url = await Db.upload('bundles', f.name, f.bytes);
                if (mounted) setState(() => _image = url);
              },
              onRemove: () => setState(() => _image = null),
            ),
          ),
        ),
        section('General', [
          Field(label: 'Name', controller: _name, required: true, hint: 'e.g. Wedding photo kit'),
          Field(label: 'Description', controller: _desc, maxLines: 4),
        ], subtitle: 'Bundles are products often rented together — offer them at a discount.'),
        SectionLabel('Items · ${_items.length}',
            trailing: TextButton.icon(onPressed: _addItem, icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add product'))),
        if (_items.isEmpty)
          Group(children: [
            EmptyState(
              compact: true,
              icon: Icons.add_box_outlined,
              title: 'No products yet',
              message: 'Add the products customers rent together.',
              actionLabel: 'Add product',
              onAction: _addItem,
            ),
          ])
        else
          for (var i = 0; i < _items.length; i++) _itemCard(i).enterX(i),
        section('Price', [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.primarySoft.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.calculate_outlined, color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              const Expanded(child: Text('Sum of items', style: TextStyle(fontWeight: FontWeight.w600))),
              Text(Fmt.money(_sum), style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
          ),
          Field.money(label: 'Bundle price override', controller: _price, helper: 'Optional — leave empty to charge the sum of the items', onChanged: (_) => setState(() {})),
        ]),
        section('Online store', [
          SwitchTile(value: _show, title: 'Show in online store', onChanged: (v) => setState(() => _show = v)),
          const FieldLabel('Collections'),
          if (userCols.isEmpty)
            const Text('No collections yet.', style: TextStyle(color: AppColors.muted))
          else
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in userCols)
                FilterChip(
                  label: Text(c.s('name')),
                  selected: _cols.contains(c.id),
                  onSelected: (v) {
                    HapticFeedback.selectionClick();
                    setState(() => v ? _cols.add(c.id) : _cols.remove(c.id));
                  },
                ),
            ]),
        ]),
      ],
    );
  }

  Widget _itemCard(int i) {
    final it = _items[i];
    final p = _product(it['productId'] as String?);
    final qty = ((it['qty'] as num?) ?? 1).toInt();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey('bi-${it['productId']}'),
        direction: DismissDirection.endToStart,
        background: swipeBg(Icons.delete_outline, 'Remove'),
        onDismissed: (_) {
          HapticFeedback.mediumImpact();
          setState(() => _items = [..._items]..removeAt(i));
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Thumb(url: p == null ? null : productThumb(p), size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p?.s('name') ?? (it['name'] ?? 'Deleted product').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(p == null ? 'Unavailable' : priceLabel(p), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ]),
              ),
              Text(Fmt.money(_lineTotal(it)), style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _MiniStepper(value: qty, onChanged: (v) => _set(i, 'qty', v)),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  key: ValueKey('d-${it['productId']}'),
                  initialValue: '${it['discount'] ?? 0}',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: const InputDecoration(labelText: 'Discount', suffixText: '%', isDense: true),
                  onChanged: (v) => _set(i, 'discount', parseNum(v).clamp(0, 100)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _MiniStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _MiniStepper({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget b(IconData icon, int d) => PressScale(
          onTap: value + d < 1
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onChanged(value + d);
                },
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: value + d < 1 ? AppColors.muted : AppColors.primary),
          ),
        );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      b(Icons.remove_rounded, -1),
      SizedBox(width: 40, child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
      b(Icons.add_rounded, 1),
    ]);
  }
}
