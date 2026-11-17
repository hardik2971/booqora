import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import 'settings_kit.dart';

const _scopes = [
  ('customer', 'Customer information', 'Extra details captured for each customer.'),
  ('order', 'Order information', 'Extra details captured on orders and at checkout.'),
  ('product', 'Product information', 'Extra attributes shown on products.'),
];

const _types = {
  'text': 'Text',
  'number': 'Number',
  'date': 'Date',
  'select': 'Dropdown (select)',
  'checkbox': 'Checkbox',
};

const _typeIcons = {
  'text': Icons.short_text,
  'number': Icons.pin_outlined,
  'date': Icons.event_outlined,
  'select': Icons.arrow_drop_down_circle_outlined,
  'checkbox': Icons.check_box_outlined,
};

class CustomFieldsSettings extends StatelessWidget {
  const CustomFieldsSettings({super.key});

  static Future<void> edit(BuildContext context, String scope, {Doc? doc, int nextPosition = 0}) async {
    final name = TextEditingController(text: doc?.s('name') ?? '');
    var type = doc?.s('type', 'text') ?? 'text';
    var options = doc?.l<String>('options') ?? <String>[];
    var showOnDocs = doc?.b('showOnDocuments') ?? false;
    var inCheckout = doc?.b('inCheckout') ?? false;
    final ok = await formDialog(
      context: context,
      title: doc == null ? 'Add custom field' : 'Edit custom field',
      body: (c, setS) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Field(label: 'Name', controller: name, required: true, autofocus: doc == null, hint: 'e.g. Driving licence number'),
        const SizedBox(height: 16),
        DropdownX<String>(label: 'Type', value: type, items: _types, onChanged: (t) => setS(() => type = t ?? 'text')),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: type == 'select'
              ? Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const FieldLabel('Options', required: true),
                    TagEditor(tags: options, onChanged: (o) => setS(() => options = o)),
                  ]),
                )
              : const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: 16),
        CheckTile(
          value: showOnDocs,
          title: 'Show on documents',
          subtitle: 'Print this field on invoices, quotes and contracts.',
          onChanged: (v) => setS(() => showOnDocs = v),
        ),
        if (scope != 'product')
          CheckTile(
            value: inCheckout,
            title: 'Ask in checkout',
            subtitle: 'Customers fill this in when booking online.',
            onChanged: (v) => setS(() => inCheckout = v),
          ),
      ]),
      onSave: () async {
        if (type == 'select' && options.isEmpty) throw Exception('Add at least one option for a dropdown field');
        final data = {
          'scope': scope,
          'name': name.text.trim(),
          'type': type,
          'options': type == 'select' ? options : <String>[],
          'showOnDocuments': showOnDocs,
          'inCheckout': scope == 'product' ? false : inCheckout,
        };
        if (doc == null) {
          await Db.create(C.customFields, {...data, 'position': nextPosition});
        } else {
          await Db.update(C.customFields, doc.id, data);
        }
      },
    );
    name.dispose();
    if (ok && context.mounted) toast(context, doc == null ? 'Custom field added' : 'Custom field updated');
  }


  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Doc>>(
      stream: Db.watch(C.customFields),
      builder: (context, s) {
        final all = s.data ?? [];
        return SettingsView(
          title: 'Custom fields',
          subtitle: 'Capture extra information on customers, orders and products. Drag to change the order fields appear in.',
          children: [
            if (s.hasError)
              ErrorView(s.error!)
            else if (!s.hasData)
              const LoadingView(rows: 4)
            else
              for (var i = 0; i < _scopes.length; i++)
                _ScopeCard(
                  scope: _scopes[i].$1,
                  title: _scopes[i].$2,
                  description: _scopes[i].$3,
                  fields: all.where((d) => d.s('scope') == _scopes[i].$1).toList()
                    ..sort((a, b) {
                      final p = a.n('position').compareTo(b.n('position'));
                      return p != 0 ? p : a.created.compareTo(b.created);
                    }),
                ).enter(i + 1),
          ],
        );
      },
    );
  }
}

class _ScopeCard extends StatefulWidget {
  final String scope;
  final String title;
  final String description;
  final List<Doc> fields;
  const _ScopeCard({required this.scope, required this.title, required this.description, required this.fields});

  @override
  State<_ScopeCard> createState() => _ScopeCardState();
}

class _ScopeCardState extends State<_ScopeCard> {
  List<Doc>? _local; // optimistic order while persisting

  @override
  void didUpdateWidget(covariant _ScopeCard old) {
    super.didUpdateWidget(old);
    _local = null;
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    final list = [...(_local ?? widget.fields)];
    if (newIndex > oldIndex) newIndex--;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    setState(() => _local = list);
    try {
      for (var i = 0; i < list.length; i++) {
        if (list[i].i('position', -1) != i) await Db.update(C.customFields, list[i].id, {'position': i}, silent: true);
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  Future<void> _delete(Doc d) async {
    final ok = await confirmDialog(context,
        title: 'Delete "${d.s('name')}"?',
        message: 'Values already stored on records are kept, but the field will no longer be shown or editable.',
        confirmLabel: 'Delete',
        danger: true);
    if (!ok) return;
    try {
      await Db.remove(C.customFields, d.id, label: d.s('name'));
      if (mounted) toast(context, 'Custom field deleted');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = _local ?? widget.fields;
    final nextPos = fields.isEmpty ? 0 : fields.map((f) => f.i('position')).reduce((a, b) => a > b ? a : b) + 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
                  Text(widget.description, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                ]),
              ),
              OutlinedButton.icon(
                onPressed: () => CustomFieldsSettings.edit(context, widget.scope, nextPosition: nextPos),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add field'),
              ),
            ]),
          ),
          const Divider(height: 1),
          if (fields.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              child: Text('No custom fields yet', style: TextStyle(color: AppColors.muted)),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: fields.length,
              onReorder: _reorder,
              proxyDecorator: (child, _, _) => Material(elevation: 6, borderRadius: BorderRadius.circular(10), child: child),
              itemBuilder: (context, i) {
                final d = fields[i];
                return _FieldRow(
                  key: ValueKey(d.id),
                  index: i,
                  doc: d,
                  last: i == fields.length - 1,
                  onEdit: () => CustomFieldsSettings.edit(context, widget.scope, doc: d),
                  onDelete: () => _delete(d),
                );
              },
            ),
        ]),
      ),
    );
  }
}

class _FieldRow extends StatefulWidget {
  final int index;
  final Doc doc;
  final bool last;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _FieldRow({super.key, required this.index, required this.doc, required this.last, required this.onEdit, required this.onDelete});

  @override
  State<_FieldRow> createState() => _FieldRowState();
}

class _FieldRowState extends State<_FieldRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.doc;
    final type = d.s('type', 'text');
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: _hover ? const Color(0xFFFAF8FF) : Colors.white,
          border: widget.last ? null : const Border(bottom: BorderSide(color: Color(0xFFF1EEF7))),
        ),
        child: Row(children: [
          ReorderableDragStartListener(
            index: widget.index,
            child: const MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: Padding(padding: EdgeInsets.all(8), child: Icon(Icons.drag_indicator, color: AppColors.muted, size: 20)),
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(8)),
            child: Icon(_typeIcons[type] ?? Icons.short_text, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: widget.onEdit,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.s('name'), style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                Text(
                  type == 'select' ? '${_types[type]} · ${d.l<String>('options').join(', ')}' : (_types[type] ?? Fmt.label(type)),
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ]),
            ),
          ),
          if (!narrow) ...[
            if (d.b('showOnDocuments')) const Padding(padding: EdgeInsets.only(left: 6), child: Badge2('Documents')),
            if (d.b('inCheckout')) const Padding(padding: EdgeInsets.only(left: 6), child: Badge2('Checkout', color: AppColors.info)),
          ],
          IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined, size: 18), onPressed: widget.onEdit),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
            onPressed: widget.onDelete,
          ),
                  ]),
      ),
    );
  }
}
