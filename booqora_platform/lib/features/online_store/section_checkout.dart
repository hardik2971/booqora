import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/session.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import 'store_common.dart';

const _defaultFields = [
  {'key': 'name', 'label': 'Name', 'required': true},
  {'key': 'email', 'label': 'Email', 'required': true},
  {'key': 'phone', 'label': 'Phone', 'required': true},
  {'key': 'address', 'label': 'Address', 'required': false},
];

class CheckoutSection extends StatefulWidget {
  const CheckoutSection({super.key});

  @override
  State<CheckoutSection> createState() => _CheckoutSectionState();
}

class _CheckoutSectionState extends State<CheckoutSection> with StoreSectionState {
  late final Map<String, dynamic> _m = Session.instance.settings('checkout');
  late final List<Map<String, dynamic>> _fields = _loadFields();
  late String _payment = (_m['paymentMode'] ?? 'none').toString();
  late final _downPct = ctl(_m, 'downPaymentPercent', '25');
  late final _laterTerms = ctl(_m, 'laterTerms');
  late final _depositText = ctl(_m, 'depositText');
  late bool _termsRequired = _m['termsRequired'] == true;
  late final _termsLabel = ctl(_m, 'termsLabel', 'I accept the Terms and conditions');
  late final _termsText = ctl(_m, 'termsText');
  late final _backUrl = ctl(_m, 'backUrl');
  late final _confirmation = ctl(_m, 'confirmationMessage', "Thanks! We've received your booking request and will confirm by email shortly.");

  List<Map<String, dynamic>> _loadFields() {
    final raw = _m['fields'];
    final list = raw is List ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];
    for (final d in _defaultFields) {
      if (!list.any((e) => e['key'] == d['key'])) list.add(Map<String, dynamic>.from(d));
    }
    return list;
  }

  @override
  void dispose() {
    for (final c in [_downPct, _laterTerms, _depositText, _termsLabel, _termsText, _backUrl, _confirmation]) {
      c.dispose();
    }
    super.dispose();
  }

  void _changed(String _) => setState(() => dirty = true);

  Future<void> _save() => runSave({
        'checkout': {
          'fields': _fields,
          'paymentMode': _payment,
          'downPaymentPercent': parseNum(_downPct.text, 25),
          'laterTerms': _laterTerms.text.trim(),
          'depositText': _depositText.text.trim(),
          'termsRequired': _termsRequired,
          'termsLabel': _termsLabel.text.trim().isEmpty ? 'I accept the Terms and conditions' : _termsLabel.text.trim(),
          'termsText': _termsText.text.trim(),
          'backUrl': _backUrl.text.trim(),
          'confirmationMessage': _confirmation.text.trim(),
        },
      });

  @override
  Widget build(BuildContext context) {
    return SectionFrame(onSave: _save, saving: saving, dirty: dirty, children: [
      TitledCard(
        icon: Icons.list_alt,
        title: 'Checkout form fields',
        subtitle: 'Drag to reorder. Name and email are always collected.',
        children: [
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorder: (a, b) => touch(() {
              if (b > a) b -= 1;
              _fields.insert(b, _fields.removeAt(a));
            }),
            children: [
              for (var i = 0; i < _fields.length; i++)
                Container(
                  key: ValueKey(_fields[i]['key']),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                  child: Row(children: [
                    ReorderableDragStartListener(
                      index: i,
                      child: const MouseRegion(
                        cursor: SystemMouseCursors.grab,
                        child: Padding(padding: EdgeInsets.all(6), child: Icon(Icons.drag_indicator, color: AppColors.muted)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: Text(_fields[i]['label'].toString(), style: const TextStyle(fontWeight: FontWeight.w600))),
                    const Text('Required', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                    Switch(
                      value: _fields[i]['required'] == true || const {'name', 'email'}.contains(_fields[i]['key']),
                      onChanged: const {'name', 'email'}.contains(_fields[i]['key'])
                          ? null
                          : (v) => touch(() => _fields[i]['required'] = v),
                    ),
                  ]),
                ),
            ],
          ),
        ],
      ).enter(0),
      TitledCard(
        icon: Icons.payments_outlined,
        title: 'Payments in checkout',
        children: [
          InfoBanner(
            'Online card payments need a connected payment provider in Settings → Payment providers.',
            actionLabel: 'Open',
            onAction: () => context.go('/settings/payments'),
          ),
          RadioCards<String>(
            value: _payment,
            options: const [
              ('full', 'Charge the full amount', 'Customers pay the order total when booking.'),
              ('down', 'Charge a down payment (%)', 'Customers pay part now and the rest later.'),
              ('deposit', 'Only charge the security deposit', 'The rental amount is collected later.'),
              ('none', 'Do not show payment options', 'Request only — you confirm and collect payment afterwards.'),
            ],
            expanded: {
              'down': SizedBox(width: 200, child: Field.number(label: 'Down payment', controller: _downPct, suffixText: '%', onChanged: _changed)),
            },
            onChanged: (v) => touch(() => _payment = v),
          ),
          Field(label: 'Terms for amounts due later', controller: _laterTerms, maxLength: 500, maxLines: 3, onChanged: _changed),
          Field(label: 'Security deposit explanation', controller: _depositText, maxLength: 500, maxLines: 3, onChanged: _changed),
        ],
      ).enter(1),
      TitledCard(
        icon: Icons.gavel_outlined,
        title: 'Terms and conditions',
        children: [
          CheckTile(
            value: _termsRequired,
            title: 'Require customers to accept terms',
            subtitle: 'A checkbox must be ticked before a booking can be requested.',
            onChanged: (v) => touch(() => _termsRequired = v),
          ),
          Field(label: 'Checkbox label', controller: _termsLabel, onChanged: _changed),
          Field(label: 'Terms text', controller: _termsText, maxLines: 6, onChanged: _changed),
        ],
      ).enter(2),
      TitledCard(
        icon: Icons.check_circle_outline,
        title: 'After checkout',
        children: [
          Field(label: 'Back to website URL', controller: _backUrl, hint: 'https://yourwebsite.com', onChanged: _changed),
          Field(label: 'Order confirmation message', controller: _confirmation, maxLines: 3, onChanged: _changed),
        ],
      ).enter(3),
    ]);
  }
}
