import 'package:flutter/material.dart';
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

class _FulfillmentSectionState extends State<FulfillmentSection> with StoreFormState {
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
    return guard(FormScaffold(
      title: 'Fulfillment',
      bottom: saveBar(_save),
      children: [
        StoreCard(
          icon: Icons.local_shipping_outlined,
          title: 'Default fulfillment method',
          subtitle: 'Pre-selected in checkout. Customers can still choose the other option.',
          children: [
            Row(children: [
              Expanded(child: _MethodCard(icon: Icons.storefront_outlined, title: 'Pickup', subtitle: 'Collect from your location', selected: _method == 'pickup', onTap: () => touch(() => _method = 'pickup'))),
              const SizedBox(width: 10),
              Expanded(child: _MethodCard(icon: Icons.local_shipping_outlined, title: 'Delivery', subtitle: 'You deliver to them', selected: _method == 'delivery', onTap: () => touch(() => _method = 'delivery'))),
            ]),
          ],
        ),
        StoreCard(
          icon: Icons.store_mall_directory_outlined,
          title: 'Pickup',
          children: [
            FutureBuilder<List<Doc>>(
              future: _locations,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const Skeleton(height: 48, radius: 12);
                final locs = (snap.data ?? []).where((l) => l.b('pickup', true)).toList();
                if (locs.isEmpty) {
                  return InfoBanner('No pickup locations yet.', actionLabel: 'Manage', onAction: () => context.push('/settings/locations'));
                }
                final ids = locs.map((l) => l.id).toSet();
                final value = _location != null && ids.contains(_location) ? _location! : locs.firstWhere((l) => l.b('isDefault'), orElse: () => locs.first).id;
                return DropdownX<String>(
                  label: 'Default pickup location',
                  value: value,
                  items: {for (final l in locs) l.id: l.s('name', 'Location')},
                  onChanged: (v) => touch(() => _location = v),
                );
              },
            ),
          ],
        ),
        StoreCard(
          icon: Icons.public_rounded,
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
                  onSelected: (v) {
                    HapticFeedback.selectionClick();
                    touch(() => v ? _countries.add(c) : _countries.remove(c));
                  },
                ),
            ]),
            CheckTile(
              value: _requireAddress,
              title: 'Require delivery address when selecting a rental period',
              subtitle: 'Ask for the address up front so delivery fees and availability are accurate.',
              onChanged: (v) => touch(() => _requireAddress = v),
            ),
            Field.money(label: 'Delivery fee', controller: _fee, onChanged: changed),
            Field.money(label: 'Free delivery over', controller: _free, helper: '0 = never free', onChanged: changed),
          ],
        ),
      ],
    ));
  }
}

class _MethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _MethodCard({required this.icon, required this.title, required this.subtitle, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.brandGradient : null,
          color: selected ? null : AppColors.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? Colors.transparent : AppColors.border),
          boxShadow: selected ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))] : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: selected ? Colors.white : AppColors.primary),
            const Spacer(),
            Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined, size: 18, color: selected ? Colors.white : AppColors.muted),
          ]),
          const SizedBox(height: 10),
          Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.ink)),
          Text(subtitle, style: TextStyle(fontSize: 11.5, color: selected ? Colors.white70 : AppColors.muted)),
        ]),
      ),
    );
  }
}
