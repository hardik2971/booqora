import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;
import 'package:flutter/material.dart' hide Thumb;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../data/session.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/mobile.dart';
import 'inv_common.dart';
import 'product_tabs.dart' show section;

class CollectionFormPage extends StatelessWidget {
  final String? id;
  const CollectionFormPage({super.key, this.id});

  @override
  Widget build(BuildContext context) {
    return LiveData(
      key: ValueKey(id ?? 'new'),
      loading: Scaffold(backgroundColor: AppColors.bg, appBar: AppBar(backgroundColor: AppColors.bg, title: const Text('Collection')), body: const LoadingView()),
      streams: () => {
        C.products: Db.watch(C.products),
        C.collections: Db.watch(C.collections),
      },
      builder: (context, d) {
        final cols = d[C.collections]!;
        final col = id == null ? null : cols.where((c) => c.id == id).firstOrNull;
        if (id != null && col == null) {
          return Scaffold(
            backgroundColor: AppColors.bg,
            appBar: AppBar(backgroundColor: AppColors.bg),
            body: EmptyState(
              icon: Icons.collections_bookmark_outlined,
              title: 'Collection not found',
              message: 'It may have been deleted.',
              actionLabel: 'Go back',
              onAction: () => Navigator.of(context).maybePop(),
            ),
          );
        }
        return _CollectionForm(collection: col, collections: cols, products: d[C.products]!);
      },
    );
  }
}

class _CollectionForm extends StatefulWidget {
  final Doc? collection;
  final List<Doc> collections;
  final List<Doc> products;
  const _CollectionForm({this.collection, required this.collections, required this.products});

  @override
  State<_CollectionForm> createState() => _CollectionFormState();
}

class _CollectionFormState extends State<_CollectionForm> {
  final _form = GlobalKey<FormState>();
  Doc? get c => widget.collection;
  bool get _isNew => c == null;
  bool get _system => c?.b('isSystem') ?? false;

  late final _name = TextEditingController(text: c?.s('name') ?? '');
  late final _desc = TextEditingController(text: c?.s('description') ?? '');
  late final _title = TextEditingController(text: c?.s('seoTitle') ?? '');
  late final _meta = TextEditingController(text: c?.s('seoDescription') ?? '');
  late final _slug = TextEditingController(text: c?.s('slug') ?? '');
  late String? _parent = (c?.s('parentId').isEmpty ?? true) ? null : c!.s('parentId');
  late String? _image = c?.s('imageUrl');
  late bool _show = c?.b('showInStore', true) ?? true;
  bool _saving = false;
  bool _slugTouched = false;

  @override
  void initState() {
    super.initState();
    _slugTouched = _slug.text.isNotEmpty;
  }

  @override
  void dispose() {
    for (final x in [_name, _desc, _title, _meta, _slug]) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return toast(context, 'Please fill in the required fields', error: true);
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final data = {
        if (!_system) 'name': _name.text.trim(),
        'parentId': _parent ?? '',
        'imageUrl': _image ?? '',
        'showInStore': _show,
        'description': _desc.text.trim(),
        'seoTitle': _title.text.trim(),
        'seoDescription': _meta.text.trim(),
        'slug': Session.slugify(_slug.text.isEmpty ? _name.text : _slug.text),
      };
      if (_isNew) {
        await Db.create(C.collections, {...data, 'isSystem': false});
        if (mounted) {
          HapticFeedback.mediumImpact();
          toast(context, 'Collection created');
          Navigator.of(context).maybePop();
        }
      } else {
        await Db.update(C.collections, c!.id, data, label: _name.text.trim());
        if (mounted) {
          HapticFeedback.lightImpact();
          toast(context, 'Collection saved');
        }
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context,
        title: 'Delete ${c!.s('name')}?', message: 'Products stay in your inventory; only the grouping is removed.', confirmLabel: 'Delete', danger: true);
    if (!ok || !mounted) return;
    final nav = Navigator.of(context);
    final done = await runAction(context, () async {
      for (final p in widget.products.where((p) => p.l<String>('collectionIds').contains(c!.id))) {
        await Db.update(C.products, p.id, {'collectionIds': FieldValue.arrayRemove([c!.id])}, silent: true);
      }
      await Db.remove(C.collections, c!.id, label: c!.s('name'));
    }, 'Collection deleted');
    if (done) nav.maybePop();
  }

  Future<void> _addProduct() async {
    final inCol = widget.products.where((p) => p.l<String>('collectionIds').contains(c!.id)).map((p) => p.id).toSet();
    final p = await pickProductSheet(context, widget.products, exclude: inCol, title: 'Add product to collection');
    if (p == null || !mounted) return;
    await runAction(context, () => Db.update(C.products, p.id, {'collectionIds': FieldValue.arrayUnion([c!.id])}, label: p.s('name')), '${p.s('name')} added');
  }

  @override
  Widget build(BuildContext context) {
    final parents = widget.collections.where((x) => x.id != c?.id && !x.b('isSystem')).toList();
    final members = c == null
        ? <Doc>[]
        : (_system ? widget.products : widget.products.where((p) => p.l<String>('collectionIds').contains(c!.id)).toList());
    return FormScaffold(
      title: _isNew ? 'New collection' : c!.s('name'),
      formKey: _form,
      actions: [
        if (!_isNew && !_system) IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline, color: AppColors.danger), onPressed: _delete),
      ],
      bottom: GradientButton(label: _isNew ? 'Create collection' : 'Save', icon: Icons.check_rounded, busy: _saving, onPressed: _save),
      children: [
        if (_system)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: InfoBanner('This system collection always contains every product. Its name cannot be changed and it cannot be deleted.', icon: Icons.lock_outline),
          ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ImageBox(
              url: _image,
              size: 132,
              label: 'Add image',
              onUpload: (f) async {
                final url = await Db.upload('collections', f.name, f.bytes);
                if (mounted) setState(() => _image = url);
              },
              onRemove: () => setState(() => _image = null),
            ),
          ),
        ),
        section('General', [
          Field(
            label: 'Name',
            controller: _name,
            required: true,
            enabled: !_system,
            hint: 'e.g. Cameras',
            onChanged: (v) {
              if (!_slugTouched) _slug.text = Session.slugify(v);
            },
          ),
          DropdownX<String>(
            label: 'Parent collection',
            value: _parent ?? '',
            items: {'': 'None (top level)', for (final p in parents) p.id: p.s('name')},
            onChanged: (v) => setState(() => _parent = (v == null || v.isEmpty) ? null : v),
          ),
        ], subtitle: 'Group related products, e.g. "Cameras" or "Party tents".'),
        section('Online store', [
          SwitchTile(
            value: _show,
            title: 'Include in collections page',
            subtitle: 'Show this collection in your store navigation.',
            onChanged: (v) => setState(() => _show = v),
          ),
          Field(label: 'Description', controller: _desc, maxLines: 4),
        ]),
        section('SEO', [
          Field(label: 'Page title', controller: _title, maxLength: 60),
          Field(label: 'Meta description', controller: _meta, maxLength: 160, maxLines: 3),
          Field(label: 'Slug', controller: _slug, prefixText: '/', onChanged: (_) => _slugTouched = true),
        ], subtitle: 'Control how this collection appears in search results.'),
        if (!_isNew) ...[
          SectionLabel('Products · ${members.length}',
              trailing: _system ? null : TextButton.icon(onPressed: _addProduct, icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add'))),
          if (members.isEmpty)
            Group(children: [
              EmptyState(
                compact: true,
                icon: Icons.inventory_2_outlined,
                title: 'No products yet',
                message: 'Add products to show them in this collection.',
                actionLabel: _system ? null : 'Add product',
                onAction: _system ? null : _addProduct,
              ),
            ])
          else
            for (var i = 0; i < members.length && i < 100; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _memberTile(members[i]).enterX(i),
              ),
        ],
      ],
    );
  }

  Widget _memberTile(Doc p) {
    final tile = MTile(
      onTap: () => context.push('/inventory/products/${p.id}'),
      leading: Hero(tag: heroTagFor(p.id), child: Thumb(url: productThumb(p), size: 44)),
      title: p.s('name'),
      subtitle: priceLabel(p),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
    );
    if (_system) return tile;
    return swipeAction(
      key: ValueKey('m-${p.id}'),
      context: context,
      icon: Icons.remove_circle_outline,
      label: 'Remove',
      confirmTitle: 'Remove ${p.s('name')}?',
      confirmMessage: 'The product stays in your inventory.',
      onConfirmed: () =>
          runAction(context, () => Db.update(C.products, p.id, {'collectionIds': FieldValue.arrayRemove([c!.id])}, label: p.s('name')), '${p.s('name')} removed'),
      child: tile,
    );
  }
}
