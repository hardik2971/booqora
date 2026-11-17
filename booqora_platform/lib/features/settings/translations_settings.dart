import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/page.dart';
import 'settings_kit.dart';

class _Group {
  final String key;
  final String label;
  final IconData icon;
  final Map<String, String> defaults;
  const _Group(this.key, this.label, this.icon, this.defaults);
}

const _groups = [
  _Group('documents', 'Documents', Icons.description_outlined, {
    'invoice': 'Invoice',
    'quote': 'Quote',
    'contract': 'Contract',
    'packingSlip': 'Packing slip',
    'dueDate': 'Due date',
    'total': 'Total',
  }),
  _Group('cart', 'Cart', Icons.shopping_cart_outlined, {
    'title': 'Your cart',
    'empty': 'Your cart is empty',
    'subtotal': 'Subtotal',
    'remove': 'Remove',
    'continue': 'Continue shopping',
    'checkout': 'Checkout',
  }),
  _Group('checkout', 'Checkout', Icons.shopping_bag_outlined, {
    'title': 'Checkout',
    'contact': 'Contact details',
    'billing': 'Billing address',
    'delivery': 'Delivery method',
    'placeOrder': 'Place order',
    'terms': 'I accept the Terms and conditions',
  }),
  _Group('payments', 'Payments', Icons.payments_outlined, {
    'payNow': 'Pay now',
    'payLater': 'Pay later',
    'deposit': 'Security deposit',
    'amountDue': 'Amount due',
    'paid': 'Paid',
    'failed': 'Payment failed. Please try again.',
  }),
  _Group('bookings', 'Online bookings', Icons.event_available_outlined, {
    'pickup': 'Pickup',
    'return': 'Return',
    'selectDates': 'Select dates',
    'available': 'Available',
    'unavailable': 'Not available for the selected dates',
    'addToCart': 'Add to cart',
  }),
  _Group('accounts', 'Customer accounts', Icons.person_outline, {
    'signIn': 'Sign in',
    'signUp': 'Create account',
    'signOut': 'Sign out',
    'myOrders': 'My orders',
    'forgot': 'Forgot your password?',
    'profile': 'My details',
  }),
  _Group('errors', 'Errors', Icons.error_outline, {
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

  bool _match(_Group g, String k) {
    if (_q.isEmpty) return true;
    final q = _q.toLowerCase();
    return g.label.toLowerCase().contains(q) ||
        k.toLowerCase().contains(q) ||
        g.defaults[k]!.toLowerCase().contains(q) ||
        _stored(g.key, k).toLowerCase().contains(q);
  }

  int _customized(_Group g) => g.defaults.keys.where((k) => _stored(g.key, k).trim().isNotEmpty).length;

  @override
  Widget build(BuildContext context) {
    final visible = [
      for (final g in _groups)
        if (g.defaults.keys.any((k) => _match(g, k))) g,
    ];
    return view(
      title: 'Translations',
      subtitle: 'Change the wording customers see on documents and in your online store. Leave a field empty to use the default.',
      actions: [
        OutlinedButton.icon(onPressed: _reset, icon: const Icon(Icons.restart_alt, size: 18), label: const Text('Reset to default')),
      ],
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SearchField(hint: 'Search translations…', width: 340, onChanged: (x) => setState(() => _q = x.trim())),
          ),
        ).enter(0),
        if (visible.isEmpty)
          const EmptyState(icon: Icons.search_off, title: 'No matches', message: 'Try a different search term.', compact: true),
        for (var i = 0; i < visible.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              padding: EdgeInsets.zero,
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: ValueKey('${visible[i].key}-${_q.isNotEmpty}'),
                  initiallyExpanded: _q.isNotEmpty,
                  shape: const RoundedRectangleBorder(),
                  tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
                    child: Icon(visible[i].icon, size: 18, color: AppColors.primary),
                  ),
                  title: Text(visible[i].label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    _customized(visible[i]) == 0 ? 'Using default text' : '${_customized(visible[i])} customized',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  children: [
                    for (final k in visible[i].defaults.keys)
                      if (_match(visible[i], k)) _row(visible[i], k),
                  ],
                ),
              ),
            ),
          ).enter(i + 1),
      ],
    );
  }

  Widget _row(_Group g, String k) {
    final def = g.defaults[k]!;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: LayoutBuilder(builder: (context, c) {
        final label = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(def, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Text('${g.key}.$k', style: const TextStyle(fontSize: 11, color: AppColors.muted, fontFamily: 'monospace')),
        ]);
        final field = TextField(controller: _ctl(g.key, k), decoration: InputDecoration(hintText: def, isDense: true));
        if (c.maxWidth < 520) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [label, const SizedBox(height: 6), field]);
        }
        return Row(children: [SizedBox(width: 220, child: label), const SizedBox(width: 16), Expanded(child: field)]);
      }),
    );
  }
}
