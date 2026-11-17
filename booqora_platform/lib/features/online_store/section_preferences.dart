import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/session.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import 'store_common.dart';

const brandSwatches = [
  '#6431DD', '#351DB1', '#2563EB', '#0891B2', '#059669',
  '#16A34A', '#D97706', '#DC2626', '#DB2777', '#1C0938',
];

class PreferencesSection extends StatefulWidget {
  const PreferencesSection({super.key});

  @override
  State<PreferencesSection> createState() => _PreferencesSectionState();
}

class _PreferencesSectionState extends State<PreferencesSection> with StoreSectionState {
  late final Map<String, dynamic> _m = Session.instance.settings('store');
  late bool _accounts = _m['customerAccounts'] == true;
  late String _accountMode = (_m['accountMode'] ?? 'optional').toString();
  late bool _availability = _m['availability'] != false;
  late bool _calendar = _m['showCalendar'] != false;
  late bool _hideQty = _m['hideQuantities'] == true;
  late bool _leadEnabled = _m['leadTimeEnabled'] == true;
  late final _leadHours = ctl(_m, 'leadTimeHours', '24');
  late String _addToCart = (_m['addToCart'] ?? 'cart').toString();
  late bool _coupons = _m['couponsEnabled'] != false;
  late final _brand = ctl(_m, 'brandColor', '#6431DD');
  late String _checkoutBg = (_m['checkoutBackground'] ?? 'white').toString();
  late bool _powered = _m['poweredBy'] != false;
  late String _sort = (_m['productSort'] ?? 'relevance').toString();
  late bool _showPrices = _m['showPrices'] != false;
  late String _priceDisplay = (_m['priceDisplay'] ?? 'period').toString();
  late bool _enabled = _m['enabled'] != false;

  @override
  void dispose() {
    _leadHours.dispose();
    _brand.dispose();
    super.dispose();
  }

  Future<void> _save() {
    final c = parseHex(_brand.text);
    if (c == null) {
      toast(context, 'Enter a valid hex colour, e.g. #6431DD', error: true);
      return Future.value();
    }
    return runSave({
      'store': {
        'customerAccounts': _accounts,
        'accountMode': _accountMode,
        'availability': _availability,
        'showCalendar': _calendar,
        'hideQuantities': _hideQty,
        'leadTimeEnabled': _leadEnabled,
        'leadTimeHours': parseNum(_leadHours.text, 24),
        'addToCart': _addToCart,
        'couponsEnabled': _coupons,
        'brandColor': toHex(c),
        'brandCustomized': true,
        'checkoutBackground': _checkoutBg,
        'poweredBy': _powered,
        'productSort': _sort,
        'showPrices': _showPrices,
        'priceDisplay': _priceDisplay,
        'enabled': _enabled,
      },
    });
  }

  @override
  Widget build(BuildContext context) {
    final brand = parseHex(_brand.text) ?? AppColors.primary;
    var i = 0;
    return SectionFrame(onSave: _save, saving: saving, dirty: dirty, children: [
      WithPreview(
        preview: StorePreview.fromSettings(store: {'brandColor': toHex(brand)}),
        children: [
          TitledCard(
            icon: Icons.power_settings_new,
            title: 'Online store status',
            trailing: StatusPill(_enabled ? 'live' : 'inactive', label: _enabled ? 'Live' : 'Offline'),
            children: [
              SwitchTile(
                value: _enabled,
                title: 'Enable online bookings',
                subtitle: 'Customers can send booking requests from your online store.',
                onChanged: (v) => touch(() => _enabled = v),
              ),
            ],
          ).enter(i++),
          TitledCard(
            icon: Icons.palette_outlined,
            title: 'Branding',
            subtitle: 'Your brand colour is used for buttons, links and the hero banner.',
            children: [
              Wrap(spacing: 10, runSpacing: 10, children: [
                for (final h in brandSwatches)
                  _Swatch(
                    color: parseHex(h)!,
                    selected: _brand.text.toUpperCase() == h,
                    onTap: () => touch(() => _brand.text = h),
                  ),
              ]),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Field(
                    label: 'Brand colour (hex)',
                    controller: _brand,
                    hint: '#6431DD',
                    onChanged: (_) => setState(() => dirty = true),
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: brand, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                ),
              ]),
              DropdownX<String>(
                label: 'Checkout background',
                value: _checkoutBg,
                items: const {'white': 'White', 'light': 'Light grey', 'brand': 'Brand tint'},
                onChanged: (v) => touch(() => _checkoutBg = v ?? 'white'),
              ),
              SwitchTile(
                value: _powered,
                title: 'Show "Powered by Booqora" link',
                subtitle: 'Displayed in the footer of your online store.',
                onChanged: (v) => touch(() => _powered = v),
              ),
            ],
          ).enter(i++),
          TitledCard(
            icon: Icons.event_available_outlined,
            title: 'Availability',
            children: [
              RadioCards<bool>(
                value: _availability,
                options: const [
                  (true, 'Enable availability', 'Customers only see and book products that are available for their selected period.'),
                  (false, 'Disable availability', 'All products can be requested; you confirm availability manually before accepting.'),
                ],
                expanded: {
                  true: Column(children: [
                    CheckTile(value: _calendar, title: 'Show availability calendar', onChanged: (v) => touch(() => _calendar = v)),
                    CheckTile(
                      value: _hideQty,
                      title: 'Hide available quantities',
                      subtitle: 'Show "Available" instead of the exact number.',
                      onChanged: (v) => touch(() => _hideQty = v),
                    ),
                  ]),
                },
                onChanged: (v) => touch(() => _availability = v),
              ),
            ],
          ).enter(i++),
          TitledCard(
            icon: Icons.timer_outlined,
            title: 'Prevent last-minute bookings',
            children: [
              SwitchTile(
                value: _leadEnabled,
                title: 'Require a minimum lead time',
                subtitle: 'Customers cannot book a period that starts sooner than this.',
                onChanged: (v) => touch(() => _leadEnabled = v),
              ),
              if (_leadEnabled)
                SizedBox(
                  width: 220,
                  child: Field.number(label: 'Lead time', controller: _leadHours, suffixText: 'hours', decimal: false, onChanged: (_) => setState(() => dirty = true)),
                ).enter(),
            ],
          ).enter(i++),
          TitledCard(
            icon: Icons.person_outline,
            title: 'Customer accounts',
            children: [
              SwitchTile(
                value: _accounts,
                title: 'Enable customer accounts',
                subtitle: 'Let customers sign in to view their bookings.',
                onChanged: (v) => touch(() => _accounts = v),
              ),
              if (_accounts)
                RadioCards<String>(
                  value: _accountMode,
                  horizontal: true,
                  options: const [
                    ('optional', 'Optional', 'Guests can still check out.'),
                    ('required', 'Required', 'Sign-in needed to book.'),
                  ],
                  onChanged: (v) => touch(() => _accountMode = v),
                ),
            ],
          ).enter(i++),
          TitledCard(
            icon: Icons.add_shopping_cart,
            title: 'Cart and coupons',
            children: [
              const FieldLabel('After "Add to cart"'),
              RadioCards<String>(
                value: _addToCart,
                horizontal: true,
                options: const [
                  ('cart', 'Add to cart', 'Stay on the page and keep browsing.'),
                  ('checkout', 'Go to checkout', 'Open the cart right away.'),
                ],
                onChanged: (v) => touch(() => _addToCart = v),
              ),
              CheckTile(value: _coupons, title: 'Enable coupon codes in checkout', onChanged: (v) => touch(() => _coupons = v)),
            ],
          ).enter(i++),
          TitledCard(
            icon: Icons.sell_outlined,
            title: 'Products and prices',
            children: [
              DropdownX<String>(
                label: 'Product sorting',
                value: _sort,
                items: const {'relevance': 'Relevance', 'name': 'Name', 'price': 'Price'},
                onChanged: (v) => touch(() => _sort = v ?? 'relevance'),
              ),
              SwitchTile(value: _showPrices, title: 'Show prices', subtitle: 'Hide prices to run a quote-only store.', onChanged: (v) => touch(() => _showPrices = v)),
              if (_showPrices)
                DropdownX<String>(
                  label: 'Display prices as',
                  value: _priceDisplay,
                  items: const {'period': 'Charge period (e.g. ₹500 / day)', 'base': 'Base price'},
                  onChanged: (v) => touch(() => _priceDisplay = v ?? 'period'),
                ),
            ],
          ).enter(i++),
        ],
      ),
    ]);
  }
}

class _Swatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _Swatch({required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [BoxShadow(color: selected ? color : AppColors.border, spreadRadius: selected ? 2 : 1)],
          ),
          child: selected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
        ),
      ),
    );
  }
}
