import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../data/session.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/mobile.dart';
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

class _PreferencesSectionState extends State<PreferencesSection> with StoreFormState {
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
    return guard(FormScaffold(
      title: 'Preferences',
      bottom: saveBar(_save),
      children: [
        PreviewPanel(preview: LiveStorePreview(width: 210, store: {'brandColor': toHex(brand), 'showPrices': _showPrices})),
        StoreCard(
          icon: Icons.power_settings_new_rounded,
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
        ),
        StoreCard(
          icon: Icons.palette_outlined,
          title: 'Branding',
          subtitle: 'Your brand colour is used for buttons, links and the hero banner.',
          children: [
            Wrap(spacing: 12, runSpacing: 12, children: [
              for (var i = 0; i < brandSwatches.length; i++)
                _Swatch(
                  color: parseHex(brandSwatches[i])!,
                  selected: _brand.text.trim().toUpperCase() == brandSwatches[i],
                  onTap: () {
                    HapticFeedback.selectionClick();
                    touch(() => _brand.text = brandSwatches[i]);
                  },
                ).pop(i),
            ]),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: Field(label: 'Brand colour (hex)', controller: _brand, hint: '#6431DD', onChanged: changed)),
              const SizedBox(width: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: brand,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: brand.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))],
                ),
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
        ),
        StoreCard(
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
        ),
        StoreCard(
          icon: Icons.timer_outlined,
          title: 'Prevent last-minute bookings',
          children: [
            SwitchTile(
              value: _leadEnabled,
              title: 'Require a minimum lead time',
              subtitle: 'Customers cannot book a period that starts sooner than this.',
              onChanged: (v) => touch(() => _leadEnabled = v),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: _leadEnabled
                  ? Field.number(label: 'Lead time', controller: _leadHours, suffixText: 'hours', decimal: false, onChanged: changed)
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
        StoreCard(
          icon: Icons.person_outline_rounded,
          title: 'Customer accounts',
          children: [
            SwitchTile(
              value: _accounts,
              title: 'Enable customer accounts',
              subtitle: 'Let customers sign in to view their bookings.',
              onChanged: (v) => touch(() => _accounts = v),
            ),
            if (_accounts)
              ChoiceChipsBar<String>(
                options: const [('optional', 'Optional — guests can check out'), ('required', 'Required to book')],
                value: _accountMode,
                onChanged: (v) => touch(() => _accountMode = v),
              ).enter(),
          ],
        ),
        StoreCard(
          icon: Icons.add_shopping_cart_rounded,
          title: 'Cart and coupons',
          children: [
            const FieldLabel('After "Add to cart"'),
            RadioCards<String>(
              value: _addToCart,
              options: const [
                ('cart', 'Add to cart', 'Stay on the page and keep browsing.'),
                ('checkout', 'Go to checkout', 'Open the cart right away.'),
              ],
              onChanged: (v) => touch(() => _addToCart = v),
            ),
            SwitchTile(value: _coupons, title: 'Enable coupon codes in checkout', onChanged: (v) => touch(() => _coupons = v)),
          ],
        ),
        StoreCard(
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
        ),
      ],
    ));
  }
}

class _Swatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _Swatch({required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      scale: 0.9,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        width: selected ? 42 : 38,
        height: selected ? 42 : 38,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [BoxShadow(color: selected ? color.withValues(alpha: 0.6) : AppColors.border, spreadRadius: selected ? 2 : 1, blurRadius: selected ? 8 : 0)],
        ),
        child: selected ? const Icon(Icons.check_rounded, size: 18, color: Colors.white) : null,
      ),
    );
  }
}
