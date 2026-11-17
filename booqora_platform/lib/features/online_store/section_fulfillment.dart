import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../data/session.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import 'store_common.dart';

const deliveryCountries = [
  'India', 'United States', 'United Kingdom', 'Canada', 'Australia', 'United Arab Emirates',
  'Singapore', 'Germany', 'France', 'Netherlands', 'New Zealand', 'South Africa',
];

class FulfillmentSection extends StatefulWidget {
  const FulfillmentSection({super.key});

  @override
  State<FulfillmentSection> createState() => _FulfillmentSectionState();
}

class _FulfillmentSectionState extends State<FulfillmentSection> with StoreSectionState {
  late final Map<String, dynamic> _m = Session.instance.settings('fulfillment');
  late String _method = (_m['defaultMethod'] ?? 'pickup').toString();
  late String? _location = _m['pickupLocationId'] as String?;
  late final Set<String> _countries = {
    ...((_m['deliveryCountries'] as List?)?.whereType<String>() ??
        [(Session.instance.setting('general', 'country', 'India') ?? 'India').toString()]),
  };
  late bool _requireAddress = _m['requireAddress'] == true;
  late final _fee = ctl(_m, 'deliveryFee', '0');
  late final _free = ctl(_m, 'freeDeliveryThreshold', '0');
  late final Future<List<Doc>> _locations = Db.list(C.locations);

  @override
  void dispose() {
    _fee.dispose();
    _free.dispose();
    super.dispose();
  }

  Future<void> _save() => runSave({
        'fulfillment': {
          'defaultMethod': _method,
          'pickupLocationId': _location,
          'deliveryCountries': _countries.toList(),
          'requireAddress': _requireAddress,
          'deliveryFee': parseNum(_fee.text),
          'freeDeliveryThreshold': parseNum(_free.text),
        },
      });

  @override
  Widget build(BuildContext context) {
    return SectionFrame(onSave: _save, saving: saving, dirty: dirty, children: [
      TitledCard(
        icon: Icons.local_shipping_outlined,
        title: 'Default fulfillment method',
        subtitle: 'Pre-selected in checkout. Customers can still choose the other option.',
        children: [
          RadioCards<String>(
            value: _method,
            horizontal: true,
            options: const [
              ('pickup', 'Pickup', 'Customers collect from your location.'),
              ('delivery', 'Delivery', 'You deliver to the customer.'),
            ],
            onChanged: (v) => touch(() => _method = v),
          ),
        ],
      ).enter(0),
      TitledCard(
        icon: Icons.store_mall_directory_outlined,
        title: 'Pickup',
        children: [
          FutureBuilder<List<Doc>>(
            future: _locations,
            builder: (context, snap) {
              final locs = (snap.data ?? []).where((l) => l.b('pickup', true)).toList();
              if (snap.connectionState != ConnectionState.done) return const LinearProgressIndicator(minHeight: 2);
              if (locs.isEmpty) {
                return InfoBanner('No pickup locations yet.', actionLabel: 'Manage locations', onAction: () => context.go('/settings/locations'));
              }
              return DropdownX<String>(
                label: 'Default pickup location',
                value: _location ?? locs.firstWhere((l) => l.b('isDefault'), orElse: () => locs.first).id,
                items: {for (final l in locs) l.id: l.s('name', 'Location')},
                onChanged: (v) => touch(() => _location = v),
              );
            },
          ),
        ],
      ).enter(1),
      TitledCard(
        icon: Icons.public,
        title: 'Delivery',
        subtitle: 'Countries you deliver to and how delivery is charged.',
        children: [
          const FieldLabel('Delivery countries'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in deliveryCountries)
              FilterChip(
                label: Text(c),
                selected: _countries.contains(c),
                showCheckmark: true,
                selectedColor: AppColors.primarySoft,
                checkmarkColor: AppColors.primary,
                backgroundColor: Colors.white,
                side: BorderSide(color: _countries.contains(c) ? AppColors.primary : AppColors.border),
                onSelected: (v) => touch(() => v ? _countries.add(c) : _countries.remove(c)),
              ),
          ]),
          CheckTile(
            value: _requireAddress,
            title: 'Require delivery address when selecting a rental period',
            subtitle: 'Ask for the address up front so delivery fees and availability are accurate.',
            onChanged: (v) => touch(() => _requireAddress = v),
          ),
          FieldGrid(children: [
            Field.money(label: 'Delivery fee', controller: _fee, onChanged: (_) => setState(() => dirty = true)),
            Field.money(
              label: 'Free delivery over',
              controller: _free,
              helper: '0 = never free',
              onChanged: (_) => setState(() => dirty = true),
            ),
          ]),
        ],
      ).enter(2),
    ]);
  }
}
