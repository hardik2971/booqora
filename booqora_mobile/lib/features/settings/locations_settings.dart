import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/mobile.dart';
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
    final ok = await sheetForm(
      context: context,
      title: doc == null ? 'Add location' : 'Edit location',
      body: (c, setS) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Field(label: 'Name', controller: name, required: true, autofocus: doc == null, hint: 'e.g. Downtown store'),
        const SizedBox(height: 16),
        Field(label: 'Address', controller: address, maxLines: 3, hint: 'Street, city, postcode'),
        const SizedBox(height: 18),
        const MiniHeading('Fulfilment'),
        const SizedBox(height: 8),
        SwitchTile(value: pickup, title: 'Pickup', subtitle: 'Customers can collect and return items here.', onChanged: (v) => setS(() => pickup = v)),
        const SizedBox(height: 10),
        SwitchTile(
            value: delivery, title: 'Delivery', subtitle: 'Orders can be delivered from this location.', onChanged: (v) => setS(() => delivery = v)),
        const SizedBox(height: 10),
        SwitchTile(
          value: showInStore,
          title: 'Show in online store',
          subtitle: 'Customers can choose this location when booking online.',
          onChanged: (v) => setS(() => showInStore = v),
        ),
        const SizedBox(height: 10),
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

  static Future<void> _more(BuildContext context, List<Doc> all, Doc d) async {
    final a = await showActionSheet<String>(context, title: d.s('name'), actions: [
      ('edit', Icons.edit_outlined, 'Edit location', false),
      if (!d.b('isDefault')) ('default', Icons.star_outline_rounded, 'Make default', false),
      if (all.length > 1) ('delete', Icons.delete_outline, 'Delete location', true),
    ]);
    if (!context.mounted || a == null) return;
    if (a == 'edit') return _edit(context, all, doc: d);
    if (a == 'delete') return _delete(context, all, d);
    if (a == 'default') {
      await Db.update(C.locations, d.id, {'isDefault': true}, label: d.s('name'));
      for (final o in all) {
        if (o.id != d.id && o.b('isDefault')) await Db.update(C.locations, o.id, {'isDefault': false}, silent: true);
      }
      if (context.mounted) toast(context, '${d.s('name')} is now the default location');
    }
  }

  Widget _chip(String label, bool on, IconData icon) => Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: on ? AppColors.primarySoft : const Color(0xFFF3F1F7), borderRadius: BorderRadius.circular(20)),
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
        return MPage(
          title: 'Locations',
          showBack: true,
          fab: s.hasData
              ? FloatingActionButton.extended(
                  onPressed: () => _edit(context, all),
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Add location'),
                ).pop()
              : null,
          slivers: [
            const SPad(PageIntro('Where items are stored, picked up and delivered from.')),
            if (s.hasError)
              SPad(ErrorView(s.error!))
            else if (!s.hasData)
              const SPad(LoadingView(rows: 3))
            else if (all.isEmpty)
              SPad(EmptyState(
                icon: Icons.place_outlined,
                title: 'No locations yet',
                message: 'Add the places where you store and hand over rental items.',
                actionLabel: 'Add location',
                onAction: () => _edit(context, all),
              ))
            else
              SList(
                count: all.length,
                builder: (context, i) {
                  final d = all[i];
                  return MTile(
                    leading: IconBubble(Icons.place_outlined, size: 44, color: d.b('isDefault') ? AppColors.primary : AppColors.inkSoft),
                    title: d.s('name'),
                    subtitle: d.s('address').isEmpty ? 'No address' : d.s('address'),
                    trailing: d.b('isDefault') ? const Badge2('Default') : const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                    onTap: () => _edit(context, all, doc: d),
                    onLongPress: () => _more(context, all, d),
                    footer: Row(children: [
                      _chip('Pickup', d.b('pickup'), Icons.storefront_outlined),
                      _chip('Delivery', d.b('delivery'), Icons.local_shipping_outlined),
                      const Spacer(),
                      StatusPill(d.b('showInStore') ? 'active' : 'inactive', label: d.b('showInStore') ? 'In store' : 'Hidden'),
                    ]),
                  );
                },
              ),
            if (all.length == 1)
              const SPad(InfoBanner('Your only location cannot be deleted. Add another location first.'), padding: EdgeInsets.fromLTRB(16, 14, 16, 6))
            else if (all.length > 1)
              const SPad(
                Text('Tip: long-press a location for more actions.', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                padding: EdgeInsets.fromLTRB(20, 14, 20, 6),
              ),
          ],
        );
      },
    );
  }
}
