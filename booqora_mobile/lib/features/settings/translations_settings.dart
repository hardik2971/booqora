import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/mobile.dart';
import 'settings_kit.dart';

class _TGroup {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final Map<String, String> defaults;
  const _TGroup(this.key, this.label, this.icon, this.color, this.defaults);
}

const _groups = [
  _TGroup('documents', 'Documents', Icons.description_outlined, AppColors.primary, {
    'invoice': 'Invoice',
    'quote': 'Quote',
    'contract': 'Contract',
    'packingSlip': 'Packing slip',
    'dueDate': 'Due date',
    'total': 'Total',
  }),
  _TGroup('cart', 'Cart', Icons.shopping_cart_outlined, AppColors.info, {
    'title': 'Your cart',
    'empty': 'Your cart is empty',
    'subtotal': 'Subtotal',
    'remove': 'Remove',
    'continue': 'Continue shopping',
    'checkout': 'Checkout',
  }),
  _TGroup('checkout', 'Checkout', Icons.shopping_bag_outlined, Color(0xFF0E7490), {
    'title': 'Checkout',
    'contact': 'Contact details',
    'billing': 'Billing address',
    'delivery': 'Delivery method',
    'placeOrder': 'Place order',
    'terms': 'I accept the Terms and conditions',
  }),
  _TGroup('payments', 'Payments', Icons.payments_outlined, AppColors.success, {
    'payNow': 'Pay now',
    'payLater': 'Pay later',
    'deposit': 'Security deposit',
    'amountDue': 'Amount due',
    'paid': 'Paid',
    'failed': 'Payment failed. Please try again.',
  }),
  _TGroup('bookings', 'Online bookings', Icons.event_available_outlined, AppColors.warning, {
    'pickup': 'Pickup',
    'return': 'Return',
    'selectDates': 'Select dates',
    'available': 'Available',
    'unavailable': 'Not available for the selected dates',
    'addToCart': 'Add to cart',
  }),
  _TGroup('accounts', 'Customer accounts', Icons.person_outline, Color(0xFFDB2777), {
    'signIn': 'Sign in',
    'signUp': 'Create account',
    'signOut': 'Sign out',
    'myOrders': 'My orders',
    'forgot': 'Forgot your password?',
    'profile': 'My details',
  }),
  _TGroup('errors', 'Errors', Icons.error_outline, AppColors.danger, {
    'required': 'This field is required',
    'invalidEmail': 'Please enter a valid email address',
    'generic': 'Something went wrong. Please try again.',
    'notFound': 'Page not found',
    'minimum': 'Minimum rental period not met',
    'closed': 'We are closed at the selected time',
  }),
];

class TranslationsSettings extends StatefulWidget {
  const TranslationsSettings({super.key});

  @override
  State<TranslationsSettings> createState() => _TranslationsSettingsState();
}

class _TranslationsSettingsState extends SettingsState<TranslationsSettings> {
  @override
  String get section => 'translations';

  final Map<String, TextEditingController> _ctls = {};
  bool _mute = false;
  String _q = '';

  @override
  void dispose() {
    for (final c in _ctls.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _stored(String g, String k) {
    final m = v[g];
    return m is Map ? (m[k] ?? '').toString() : '';
  }

  TextEditingController _ctl(String g, String k) => _ctls.putIfAbsent('$g.$k', () {
        final c = TextEditingController(text: _stored(g, k));
        c.addListener(() {
          if (_mute || _stored(g, k) == c.text) return;
          touch(() => sub(g)[k] = c.text);
        });
        return c;
      });

  void _syncControllers() {
    _mute = true;
    for (final e in _ctls.entries) {
      final i = e.key.indexOf('.');
      e.value.text = _stored(e.key.substring(0, i), e.key.substring(i + 1));
    }
    _mute = false;
  }

  @override
  void onDiscard() => _syncControllers();

  Future<void> _reset() async {
    final ok = await confirmDialog(context,
        title: 'Reset to default?',
        message: 'All custom translations will be cleared and the default English text will be used. Save to apply.',
        confirmLabel: 'Reset');
    if (!ok) return;
    touch(() {
      for (final g in _groups) {
        v[g.key] = <String, dynamic>{};
      }
    });
    _syncControllers();
  }

  bool _match(_TGroup g, String k) {
    if (_q.isEmpty) return true;
    final q = _q.toLowerCase();
    return g.label.toLowerCase().contains(q) ||
        k.toLowerCase().contains(q) ||
        g.defaults[k]!.toLowerCase().contains(q) ||
        _stored(g.key, k).toLowerCase().contains(q);
  }

  int _customized(_TGroup g) => g.defaults.keys.where((k) => _stored(g.key, k).trim().isNotEmpty).length;

  @override
  Widget build(BuildContext context) {
    final visible = [
      for (final g in _groups)
        if (g.defaults.keys.any((k) => _match(g, k))) g,
    ];
    return view(
      title: 'Translations',
      subtitle: 'Change the wording customers see on documents and in your online store. Leave a field empty to use the default.',
      actions: [IconButton(tooltip: 'Reset to default', onPressed: _reset, icon: const Icon(Icons.restart_alt_rounded))],
      children: [
        MSearch(hint: 'Search translations', onChanged: (x) => setState(() => _q = x.trim())),
        if (visible.isEmpty) const EmptyState(icon: Icons.search_off, title: 'No matches', message: 'Try a different search term.', compact: true),
        for (final g in visible)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
                boxShadow: const [BoxShadow(color: Color(0x0A1C0938), blurRadius: 14, offset: Offset(0, 6))],
              ),
              clipBehavior: Clip.antiAlias,
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: ValueKey('${g.key}-${_q.isNotEmpty}'),
                  initiallyExpanded: _q.isNotEmpty,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                  leading: IconBubble(g.icon, color: g.color, size: 38),
                  title: Text(g.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    _customized(g) == 0 ? 'Using default text' : '${_customized(g)} customized',
                    style: TextStyle(fontSize: 12, color: _customized(g) == 0 ? AppColors.muted : AppColors.primary),
                  ),
                  children: [
                    for (final k in g.defaults.keys)
                      if (_match(g, k)) _row(g, k),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _row(_TGroup g, String k) {
    final def = g.defaults[k]!;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(def, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          Text('${g.key}.$k', style: const TextStyle(fontSize: 10.5, color: AppColors.muted, fontFamily: 'monospace')),
        ]),
        const SizedBox(height: 6),
        TextField(controller: _ctl(g.key, k), decoration: InputDecoration(hintText: def, isDense: true)),
      ]),
    );
  }
}
