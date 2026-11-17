import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;
import 'package:flutter/material.dart' hide Thumb;
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../data/session.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/page.dart';
import 'inv_common.dart';

class CollectionFormPage extends StatelessWidget {
  final String? id;
  const CollectionFormPage({super.key, this.id});

  @override
  Widget build(BuildContext context) {
    return LiveData(
      key: ValueKey(id ?? 'new'),
      streams: () => {
        C.products: Db.watch(C.products),
        C.collections: Db.watch(C.collections),
      },
      builder: (context, d) {
        final cols = d[C.collections]!;
        final col = id == null ? null : cols.where((c) => c.id == id).firstOrNull;
        if (id != null && col == null) {
          return EmptyState(
            icon: Icons.collections_bookmark_outlined,
            title: 'Collection not found',
            message: 'It may have been deleted.',
            actionLabel: 'Back to collections',
            onAction: () => context.go('/inventory?tab=collections'),
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
        final id = await Db.create(C.collections, {...data, 'isSystem': false});
        if (mounted) {
          toast(context, 'Collection created');
          context.go('/inventory/collections/$id');
        }
      } else {
        await Db.update(C.collections, c!.id, data, label: _name.text.trim());
        if (mounted) toast(context, 'Collection saved');
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
    if (!ok) return;
    try {
      for (final p in widget.products.where((p) => p.l<String>('collectionIds').contains(c!.id))) {
        await Db.update(C.products, p.id, {'collectionIds': FieldValue.arrayRemove([c!.id])}, silent: true);
      }
      await Db.remove(C.collections, c!.id, label: c!.s('name'));
      if (mounted) {
        toast(context, 'Collection deleted');
        context.go('/inventory?tab=collections');
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  Future<void> _addProduct() async {
    final inCol = widget.products.where((p) => p.l<String>('collectionIds').contains(c!.id)).map((p) => p.id).toSet();
    final p = await pickProductDialog(context, widget.products, exclude: inCol, title: 'Add product to collection');
    if (p == null) return;
    try {
      await Db.update(C.products, p.id, {'collectionIds': FieldValue.arrayUnion([c!.id])}, label: p.s('name'));
      if (mounted) toast(context, '${p.s('name')} added');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  Future<void> _removeProduct(Doc p) async {
    try {
      await Db.update(C.products, p.id, {'collectionIds': FieldValue.arrayRemove([c!.id])}, label: p.s('name'));
      if (mounted) toast(context, '${p.s('name')} removed');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parents = widget.collections.where((x) => x.id != c?.id && !x.b('isSystem')).toList();
    final members = c == null
        ? <Doc>[]
        : (_system ? widget.products : widget.products.where((p) => p.l<String>('collectionIds').contains(c!.id)).toList());
    return Form(
      key: _form,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PageHeader(
          title: _isNew ? 'New collection' : c!.s('name'),
          breadcrumbs: const [('Inventory', '/inventory'), ('Collections', '/inventory?tab=collections')],
          titleTrailing: _system ? smallChip('System', color: AppColors.inkSoft, bg: const Color(0xFFF0EEF5)) : null,
          actions: [
            if (!_isNew && !_system)
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
            if (_system)
              const Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: InfoBanner('This system collection always contains every product. Its name cannot be changed and it cannot be deleted.',
                    icon: Icons.lock_outline),
              ),
            FormSection(
              title: 'General',
              description: 'Group related products, e.g. "Cameras" or "Party tents".',
              index: 0,
              children: [
                Field(
                  label: 'Name',
                  controller: _name,
                  required: true,
                  enabled: !_system,
                  onChanged: (v) {
                    if (!_slugTouched) _slug.text = Session.slugify(v);
                  },
                ),
                DropdownX<String>(
                  label: 'Parent collection',
                  value: _parent,
                  hint: 'None (top level)',
                  items: {'': 'None (top level)', for (final p in parents) p.id: p.s('name')},
                  onChanged: (v) => setState(() => _parent = (v == null || v.isEmpty) ? null : v),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const FieldLabel('Image'),
                  ImageBox(
                    url: _image,
                    onUpload: (f) async {
                      final url = await Db.upload('collections', f.name, f.bytes);
                      if (mounted) setState(() => _image = url);
                    },
                    onRemove: () => setState(() => _image = null),
                  ),
                ]),
              ],
            ),
            FormSection(
              title: 'Appearance in online store',
              description: 'How this collection is presented to customers.',
              index: 1,
              children: [
                CheckTile(
                  value: _show,
                  title: 'Include in collections page',
                  subtitle: 'Show this collection in your store navigation.',
                  onChanged: (v) => setState(() => _show = v),
                ),
                Field(label: 'Description', controller: _desc, maxLines: 4),
              ],
            ),
            FormSection(
              title: 'SEO',
              description: 'Control how this collection appears in search results.',
              index: 2,
              children: [
                Field(label: 'Page title', controller: _title, maxLength: 60),
                Field(label: 'Meta description', controller: _meta, maxLength: 160, maxLines: 3),
                Field(label: 'Slug', controller: _slug, prefixText: '/', onChanged: (_) => _slugTouched = true),
              ],
            ),
            if (!_isNew)
              FormSection(
                title: 'Products',
                description: _system ? 'Every product is part of this collection.' : '${members.length} product${members.length == 1 ? '' : 's'} in this collection.',
                index: 3,
                trailing: _system ? null : OutlinedButton.icon(onPressed: _addProduct, icon: const Icon(Icons.add, size: 18), label: const Text('Add product')),
                children: [
                  if (members.isEmpty)
                    EmptyState(
                      compact: true,
                      icon: Icons.inventory_2_outlined,
                      title: 'No products yet',
                      message: 'Add products to show them in this collection.',
                      actionLabel: _system ? null : 'Add product',
                      onAction: _system ? null : _addProduct,
                    )
                  else
                    Column(children: [
                      for (var i = 0; i < members.length && i < 100; i++)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Thumb(url: productThumb(members[i]), size: 36),
                          title: Text(members[i].s('name'), style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(priceLabel(members[i]), style: const TextStyle(fontSize: 12)),
                          onTap: () => context.go('/inventory/products/${members[i].id}'),
                          trailing: _system
                              ? null
                              : IconButton(tooltip: 'Remove from collection', icon: const Icon(Icons.close, size: 18), onPressed: () => _removeProduct(members[i])),
                        ).enterX(i),
                    ]),
                ],
              ),
          ]),
        ),
        SaveBar(
          saving: _saving,
          saveLabel: _isNew ? 'Create collection' : 'Save',
          onCancel: () => context.go('/inventory?tab=collections'),
          onSave: _save,
        ),
      ]),
    );
  }
}
