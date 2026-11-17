import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/table.dart';
import 'settings_kit.dart';

class LocationsSettings extends StatelessWidget {
  const LocationsSettings({super.key});

  static Future<void> _edit(BuildContext context, List<Doc> all, {Doc? doc}) async {
    final name = TextEditingController(text: doc?.s('name') ?? '');
    final address = TextEditingController(text: doc?.s('address') ?? '');
    var pickup = doc?.b('pickup', true) ?? true;
    var delivery = doc?.b('delivery') ?? false;
    var showInStore = doc?.b('showInStore', true) ?? true;
    var isDefault = doc?.b('isDefault') ?? all.isEmpty;
    final wasDefault = doc?.b('isDefault') ?? false;
    final ok = await formDialog(
      context: context,
      title: doc == null ? 'Add location' : 'Edit location',
      body: (c, setS) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Field(label: 'Name', controller: name, required: true, autofocus: doc == null, hint: 'e.g. Downtown store'),
        const SizedBox(height: 16),
        Field(label: 'Address', controller: address, maxLines: 3, hint: 'Street, city, postcode'),
        const SizedBox(height: 16),
        const MiniHeading('Fulfilment'),
        const SizedBox(height: 6),
        CheckTile(value: pickup, title: 'Pickup', subtitle: 'Customers can collect and return items here.', onChanged: (v) => setS(() => pickup = v)),
        CheckTile(value: delivery, title: 'Delivery', subtitle: 'Orders can be delivered from this location.', onChanged: (v) => setS(() => delivery = v)),
        const SizedBox(height: 8),
        SwitchTile(
          value: showInStore,
          title: 'Show in online store',
          subtitle: 'Customers can choose this location when booking online.',
          onChanged: (v) => setS(() => showInStore = v),
        ),
        const SizedBox(height: 8),
        SwitchTile(
          value: isDefault,
          title: 'Default location',
          subtitle: wasDefault ? 'Choose another location as default to change this.' : 'Used for new orders by default.',
          onChanged: wasDefault ? (_) {} : (v) => setS(() => isDefault = v),
        ),
      ]),
      onSave: () async {
        final data = {
          'name': name.text.trim(),
          'address': address.text.trim(),
          'pickup': pickup,
          'delivery': delivery,
          'showInStore': showInStore,
          'isDefault': isDefault,
        };
        String id;
        if (doc == null) {
          id = await Db.create(C.locations, data);
        } else {
          id = doc.id;
          await Db.update(C.locations, id, data);
        }
        if (isDefault) {
          for (final o in all) {
            if (o.id != id && o.b('isDefault')) await Db.update(C.locations, o.id, {'isDefault': false}, silent: true);
          }
        }
      },
    );
    name.dispose();
    address.dispose();
    if (ok && context.mounted) toast(context, doc == null ? 'Location added' : 'Location updated');
  }

  static Future<void> _delete(BuildContext context, List<Doc> all, Doc d) async {
    if (all.length <= 1) {
      toast(context, 'You need at least one location. Add another before deleting this one.', error: true);
      return;
    }
    final ok = await confirmDialog(context,
        title: 'Delete "${d.s('name')}"?',
        message: 'Existing orders keep their reference, but this location can no longer be selected.',
        confirmLabel: 'Delete',
        danger: true);
    if (!ok) return;
    try {
      await Db.remove(C.locations, d.id, label: d.s('name'));
      if (d.b('isDefault')) {
        final next = all.firstWhere((o) => o.id != d.id);
        await Db.update(C.locations, next.id, {'isDefault': true}, silent: true);
      }
      if (context.mounted) toast(context, 'Location deleted');
    } catch (e) {
      if (context.mounted) toast(context, friendlyError(e), error: true);
    }
  }

  Widget _chip(String label, bool on, IconData icon) => Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: on ? AppColors.primarySoft : const Color(0xFFF3F1F7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(on ? icon : Icons.block, size: 13, color: on ? AppColors.primary : AppColors.muted),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: on ? AppColors.primaryDeep : AppColors.muted)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Doc>>(
      stream: Db.watch(C.locations, desc: false),
      builder: (context, s) {
        final all = s.data ?? [];
        return SettingsView(
          title: 'Locations',
          subtitle: 'Where items are stored, picked up and delivered from.',
          actions: [
            FilledButton.icon(
              onPressed: s.hasData ? () => _edit(context, all) : null,
              icon: const Icon(Icons.add_location_alt_outlined, size: 18),
              label: const Text('Add location'),
            ),
          ],
          children: [
            if (s.hasError)
              ErrorView(s.error!)
            else if (!s.hasData)
              const LoadingView(rows: 3)
            else
              DataTableX<Doc>(
                rows: all,
                idOf: (d) => d.id,
                noun: 'locations',
                minWidth: 760,
                onTap: (d) => _edit(context, all, doc: d),
                empty: EmptyState(
                  icon: Icons.place_outlined,
                  title: 'No locations yet',
                  message: 'Add the places where you store and hand over rental items.',
                  actionLabel: 'Add location',
                  onAction: () => _edit(context, all),
                ),
                columns: [
                  ColumnX('Location', (d) => CellText(d.s('name'), leading: Avatar(d.s('name'), size: 34)),
                      flex: 3, sort: (d) => d.s('name').toLowerCase()),
                  ColumnX('Address', (d) => Text(d.s('address', '—'), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.inkSoft)),
                      flex: 3),
                  ColumnX('Fulfilment', (d) => Wrap(runSpacing: 4, children: [
                        _chip('Pickup', d.b('pickup'), Icons.storefront_outlined),
                        _chip('Delivery', d.b('delivery'), Icons.local_shipping_outlined),
                      ]), flex: 3),
                  ColumnX('Online store', (d) => StatusPill(d.b('showInStore') ? 'active' : 'inactive', label: d.b('showInStore') ? 'Visible' : 'Hidden'),
                      flex: 2),
                  ColumnX('', (d) => d.b('isDefault') ? const Badge2('Default') : const SizedBox.shrink(), width: 80),
                  ColumnX('', (d) => PopupMenuButton<String>(
                        icon: const Icon(Icons.more_horiz, size: 20),
                        onSelected: (a) => a == 'edit' ? _edit(context, all, doc: d) : _delete(context, all, d),
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(
                            value: 'delete',
                            enabled: all.length > 1,
                            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
                          ),
                        ],
                      ), width: 56, numeric: true),
                ],
              ).enter(1),
            if (all.length == 1) ...[
              const SizedBox(height: 16),
              const InfoBanner('Your only location cannot be deleted. Add another location first.').enter(2),
            ],
          ],
        );
      },
    );
  }
}
