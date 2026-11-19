import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/mobile.dart';
import 'settings_kit.dart';

const _scopes = [
  ('customer', 'Customer information', 'Extra details captured for each customer.', Icons.person_outline, AppColors.primary),
  ('order', 'Order information', 'Extra details captured on orders and at checkout.', Icons.receipt_long_outlined, AppColors.info),
  ('product', 'Product information', 'Extra attributes shown on products.', Icons.inventory_2_outlined, Color(0xFF0E7490)),
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
    final ok = await sheetForm(
      context: context,
      title: doc == null ? 'Add custom field' : 'Edit custom field',
      body: (c, setS) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Field(label: 'Name', controller: name, required: true, autofocus: doc == null, hint: 'e.g. Driving licence number'),
        const SizedBox(height: 16),
        const FieldLabel('Type'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in _types.entries)
            ChoiceChip(
              avatar: Icon(_typeIcons[e.key], size: 16, color: type == e.key ? Colors.white : AppColors.primary),
              label: Text(e.key == 'select' ? 'Dropdown' : e.value),
              selected: type == e.key,
              showCheckmark: false,
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(color: type == e.key ? Colors.white : AppColors.ink, fontWeight: FontWeight.w600),
              onSelected: (_) {
                HapticFeedback.selectionClick();
                setS(() => type = e.key);
              },
            ),
        ]),
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
        SwitchTile(
          value: showOnDocs,
          title: 'Show on documents',
          subtitle: 'Print this field on invoices, quotes and contracts.',
          onChanged: (v) => setS(() => showOnDocs = v),
        ),
        if (scope != 'product') ...[
          const SizedBox(height: 12),
          SwitchTile(
            value: inCheckout,
            title: 'Ask in checkout',
            subtitle: 'Customers fill this in when booking online.',
            onChanged: (v) => setS(() => inCheckout = v),
          ),
        ],
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
    if (ok && context.mounted) toast(context, doc == null ? 'Custom field added' : 'Custom field updated');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Doc>>(
      stream: Db.watch(C.customFields),
      builder: (context, s) {
        final all = s.data ?? [];
        return MPage(
          title: 'Custom fields',
          showBack: true,
          slivers: [
            const SPad(PageIntro('Capture extra information on customers, orders and products. Drag the handle to change the order.')),
            if (s.hasError)
              SPad(ErrorView(s.error!))
            else if (!s.hasData)
              const SPad(LoadingView(rows: 4))
            else
              for (var i = 0; i < _scopes.length; i++)
                SPad(
                  _ScopeCard(
                    scope: _scopes[i].$1,
                    title: _scopes[i].$2,
                    description: _scopes[i].$3,
                    icon: _scopes[i].$4,
                    color: _scopes[i].$5,
                    fields: all.where((d) => d.s('scope') == _scopes[i].$1).toList()
                      ..sort((a, b) {
                        final p = a.n('position').compareTo(b.n('position'));
                        return p != 0 ? p : a.created.compareTo(b.created);
                      }),
                  ).enter(i + 1),
                ),
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
  final IconData icon;
  final Color color;
  final List<Doc> fields;
  const _ScopeCard({required this.scope, required this.title, required this.description, required this.icon, required this.color, required this.fields});

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
    HapticFeedback.lightImpact();
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Group(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        children: [
          Row(children: [
            IconBubble(widget.icon, color: widget.color, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                Text(widget.description, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
              ]),
            ),
            if (fields.isNotEmpty) Badge2('${fields.length}', color: widget.color),
          ]),
          if (fields.isEmpty)
            const Text('No custom fields yet', style: TextStyle(color: AppColors.muted))
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: fields.length,
              onReorderStart: (_) => HapticFeedback.mediumImpact(),
              onReorder: _reorder,
              proxyDecorator: (child, _, _) => Material(elevation: 8, color: Colors.white, borderRadius: BorderRadius.circular(12), child: child),
              itemBuilder: (context, i) {
                final d = fields[i];
                final type = d.s('type', 'text');
                final tags = [if (d.b('showOnDocuments')) 'Documents', if (d.b('inCheckout')) 'Checkout'];
                return Container(
                  key: ValueKey(d.id),
                  color: Colors.white,
                  child: Row(children: [
                    ReorderableDragStartListener(
                      index: i,
                      child: const Padding(padding: EdgeInsets.fromLTRB(0, 10, 8, 10), child: Icon(Icons.drag_indicator, color: AppColors.muted)),
                    ),
                    Expanded(
                      child: ListRow(
                        leading: IconBubble(_typeIcons[type] ?? Icons.short_text, size: 34, color: widget.color),
                        title: d.s('name'),
                        subtitle: [
                          type == 'select' ? 'Dropdown · ${d.l<String>('options').join(', ')}' : (_types[type] ?? Fmt.label(type)),
                          ...tags,
                        ].join(' · '),
                        onTap: () => CustomFieldsSettings.edit(context, widget.scope, doc: d),
                        onLongPress: () => _delete(d),
                        trailing: IconButton(
                          tooltip: 'Delete',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
                          onPressed: () => _delete(d),
                        ),
                      ),
                    ),
                  ]),
                );
              },
            ),
          AddRowButton(label: 'Add field', onTap: () => CustomFieldsSettings.edit(context, widget.scope, nextPosition: nextPos)),
        ],
      ),
    );
  }
}
