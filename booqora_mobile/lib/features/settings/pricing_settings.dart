import 'package:cloud_firestore/cloud_firestore.dart' show SetOptions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/pricing.dart';
import '../../data/schema.dart';
import '../../data/session.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/mobile.dart';
import 'settings_kit.dart';

const _currencies = {
  'INR': ('₹', 'Indian rupee'),
  'USD': (r'$', 'US dollar'),
  'EUR': ('€', 'Euro'),
  'GBP': ('£', 'British pound'),
  'AED': ('د.إ', 'UAE dirham'),
  'AUD': (r'A$', 'Australian dollar'),
  'CAD': (r'C$', 'Canadian dollar'),
  'SGD': (r'S$', 'Singapore dollar'),
};

const _intervals = {'hour': 'Hour', 'day': 'Day', 'week': 'Week'};

/// Suggested starter templates (example prices — adjust to your own rates).
final _suggested = <Map<String, dynamic>>[
  {
    'name': 'Charge per hour (3 hours minimum)',
    'interval': 'hour',
    'minimum': 3,
    'description': 'Hourly rate with a 3 hour minimum charge.',
    'tiers': [
      {'upTo': 3, 'price': 300},
    ],
  },
  {
    'name': 'Charge per day (50% off extra days after 3)',
    'interval': 'day',
    'minimum': 1,
    'description': 'Full daily rate for the first 3 days, half price for every extra day.',
    'tiers': [
      {'upTo': 1, 'price': 1000},
      {'upTo': 2, 'price': 2000},
      {'upTo': 3, 'price': 3000},
      {'upTo': 4, 'price': 3500},
      {'upTo': 5, 'price': 4000},
      {'upTo': 6, 'price': 4500},
      {'upTo': 7, 'price': 5000},
      {'upTo': 30, 'price': 16500},
    ],
  },
  {
    'name': 'Charge per day (1 week minimum)',
    'interval': 'day',
    'minimum': 7,
    'description': 'Daily rate, charged for at least 7 days.',
    'tiers': [
      {'upTo': 7, 'price': 7000},
    ],
  },
  {
    'name': 'Charge per week (20% off extra weeks after 4)',
    'interval': 'week',
    'minimum': 1,
    'description': 'Full weekly rate for 4 weeks, 20% off every extra week.',
    'tiers': [
      {'upTo': 1, 'price': 5000},
      {'upTo': 2, 'price': 10000},
      {'upTo': 3, 'price': 15000},
      {'upTo': 4, 'price': 20000},
      {'upTo': 5, 'price': 24000},
      {'upTo': 6, 'price': 28000},
      {'upTo': 8, 'price': 36000},
      {'upTo': 52, 'price': 212000},
    ],
  },
];

class PricingSettings extends StatefulWidget {
  const PricingSettings({super.key});

  @override
  State<PricingSettings> createState() => _PricingSettingsState();
}

class _PricingSettingsState extends SettingsState<PricingSettings> {
  @override
  String get section => 'pricing';

  String get _code => val<String>('currency', 'INR');
  bool get _asSymbol => val<bool>('displaySymbol', true);
  bool get _after => val<String>('position', 'before') == 'after';

  String get _displaySymbol => _asSymbol ? (_currencies[_code]?.$1 ?? _code) : _code;

  String _example() {
    const n = '125.99';
    final s = _displaySymbol;
    if (_after) return '$n $s';
    return _asSymbol ? '$s$n' : '$s $n';
  }

  @override
  Future<void> persist() async {
    v['symbol'] = _asSymbol ? _displaySymbol : '$_code${_after ? '' : ' '}';
    v['depositValue'] = numVal('depositValue', 100);
    await super.persist();
    final slug = Session.instance.workspace?.s('slug') ?? '';
    if (slug.isEmpty) return;
    try {
      await Db.fs.collection(C.publicStores).doc(slug).set({
        'currency': _code,
        'symbol': v['symbol'],
        'position': val<String>('position', 'before'),
        'currencyPosition': val<String>('position', 'before'),
        'showPrices': val<bool>('enabled', true),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final depositMode = val<String>('depositMode', 'product');
    return view(
      title: 'Pricing',
      subtitle: 'Currency, reusable pricing structures and default security deposits.',
      children: [
        SGroup(
          title: 'Currency',
          description: 'Used for products, orders and documents.',
          children: [
            SwitchTile(
              value: val<bool>('enabled', true),
              title: 'Enable pricing',
              subtitle: 'Turn off if you only manage availability and do not charge through Booqora.',
              onChanged: (x) => put('enabled', x),
            ),
            DropdownX<String>(
              label: 'Currency',
              value: _code,
              items: {for (final e in _currencies.entries) e.key: '${e.key} — ${e.value.$2} (${e.value.$1})'},
              onChanged: (x) => put('currency', x ?? 'INR'),
            ),
            SwitchTile(
              value: _asSymbol,
              title: 'Display as symbol',
              subtitle: 'Show ${_currencies[_code]?.$1 ?? _code} instead of $_code.',
              onChanged: (x) => put('displaySymbol', x),
            ),
            const MiniHeading('Symbol position'),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'before', label: Text('Before amount')),
                ButtonSegment(value: 'after', label: Text('After amount')),
              ],
              selected: {val<String>('position', 'before')},
              onSelectionChanged: (s) {
                HapticFeedback.selectionClick();
                put('position', s.first);
              },
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const Text('Example', style: TextStyle(color: Colors.white70)),
                const Spacer(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: c)),
                  child: Text(_example(),
                      key: ValueKey(_example()), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: Colors.white)),
                ),
              ]),
            ),
          ],
        ),
        const SGroup(
          title: 'Pricing structure templates',
          description: 'Tiered prices you can assign to products, e.g. a weekly rate cheaper than seven daily rates. Saved immediately.',
          children: [_StructuresList()],
        ),
        SGroup(
          title: 'Security deposits',
          description: 'Default deposit for new orders. Can be overridden per customer.',
          children: [
            RadioCards<String>(
              value: depositMode,
              options: const [
                ('none', 'No deposit', 'Do not charge a security deposit.'),
                ('percentage', 'Percentage of order total', 'Charge a share of the order total as deposit.'),
                ('product', 'Product-specific', 'Use the deposit set on each product, multiplied by a percentage.'),
                ('fixed', 'Fixed amount', 'Charge the same deposit on every order.'),
              ],
              onChanged: (x) => put('depositMode', x),
              expanded: {
                'percentage': Field.number(label: 'Percentage', controller: number('depositValue', 100), suffixText: '%'),
                'product': Field.number(label: 'Percentage of product deposit', controller: number('depositValue', 100), suffixText: '%'),
                'fixed': Field.number(label: 'Amount', controller: number('depositValue', 100), prefixText: '$_displaySymbol '),
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _StructuresList extends StatelessWidget {
  const _StructuresList();

  Future<void> _seed(BuildContext context, List<Doc> existing) async {
    final names = existing.map((e) => e.s('name')).toSet();
    final todo = _suggested.where((s) => !names.contains(s['name'])).toList();
    if (todo.isEmpty) {
      toast(context, 'Suggested templates are already added');
      return;
    }
    try {
      for (final s in todo) {
        await Db.create(C.pricingStructures, s);
      }
      if (context.mounted) toast(context, 'Added ${todo.length} suggested template${todo.length == 1 ? '' : 's'}');
    } catch (e) {
      if (context.mounted) toast(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Doc>>(
      stream: Db.watch(C.pricingStructures, desc: false),
      builder: (context, snap) {
        if (snap.hasError) return ErrorView(snap.error!);
        if (!snap.hasData) return const LoadingView(rows: 2);
        final items = snap.data!;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (items.isEmpty)
            const EmptyState(
              compact: true,
              icon: Icons.stacked_line_chart,
              title: 'No pricing templates yet',
              message: 'Create a template or start from our suggestions.',
            ),
          for (var i = 0; i < items.length; i++)
            Padding(padding: const EdgeInsets.only(bottom: 6), child: _StructureTile(items[i]).enter(i, 0.03)),
          const SizedBox(height: 6),
          AddRowButton(label: 'Add template', onTap: () => _editStructure(context, null)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _seed(context, items),
            icon: const Icon(Icons.auto_awesome_outlined, size: 18),
            label: const Text('Add suggested templates'),
          ),
        ]);
      },
    );
  }
}

class _StructureTile extends StatelessWidget {
  final Doc d;
  const _StructureTile(this.d);

  Future<void> _more(BuildContext context) async {
    final a = await showActionSheet<String>(context, title: d.s('name', 'Template'), actions: const [
      ('preview', Icons.visibility_outlined, 'Preview prices', false),
      ('edit', Icons.edit_outlined, 'Edit template', false),
      ('delete', Icons.delete_outline, 'Delete template', true),
    ]);
    if (!context.mounted || a == null) return;
    if (a == 'preview') _preview(context, d);
    if (a == 'edit') _editStructure(context, d);
    if (a == 'delete') {
      final ok = await confirmDialog(context,
          title: 'Delete template?',
          message: 'Products using "${d.s('name')}" will fall back to their flat price.',
          confirmLabel: 'Delete',
          danger: true);
      if (ok) await Db.remove(C.pricingStructures, d.id, label: d.s('name'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tiers = d.maps('tiers');
    final interval = d.s('interval', 'day');
    final min = d.n('minimum', 0);
    return ListRow(
      leading: const IconBubble(Icons.stacked_line_chart, size: 38),
      title: d.s('name', 'Untitled'),
      subtitle: 'Per $interval · ${tiers.length} tier${tiers.length == 1 ? '' : 's'}'
          '${min > 0 ? ' · min ${fmtNum(min)} ${interval}s' : ''}',
      onTap: () => _editStructure(context, d),
      onLongPress: () => _more(context),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          tooltip: 'Preview',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.visibility_outlined, size: 20, color: AppColors.primary),
          onPressed: () => _preview(context, d),
        ),
        IconButton(
          tooltip: 'More',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.more_horiz, color: AppColors.muted),
          onPressed: () => _more(context),
        ),
      ]),
    );
  }
}

void _preview(BuildContext context, Doc d) {
  final interval = d.s('interval', 'day');
  final hours = Pricing.unitHours[interval] ?? 24;
  final start = DateTime(2026, 1, 1, 9);
  showAppSheet<void>(
    context,
    title: 'Preview — ${d.s('name')}',
    builder: (c) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var n = 1; n <= 7; n++)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
          child: Row(children: [
            Text('$n $interval${n == 1 ? '' : 's'}', style: const TextStyle(fontWeight: FontWeight.w500)),
            const Spacer(),
            Text(Fmt.money(Pricing.structurePrice(d, start, start.add(Duration(hours: hours * n)))),
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
        ).enterX(n),
      const SizedBox(height: 12),
      const Text("Durations beyond the last tier are charged at the last tier's average rate.",
          style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
    ]),
  );
}

Future<void> _editStructure(BuildContext context, Doc? d) async {
  final name = TextEditingController(text: d?.s('name') ?? '');
  final desc = TextEditingController(text: d?.s('description') ?? '');
  final min = TextEditingController(text: d == null ? '' : fmtNum(d.n('minimum', 0)));
  var interval = d?.s('interval', 'day') ?? 'day';
  final rows = <(TextEditingController, TextEditingController)>[
    for (final t in d?.maps('tiers') ?? <Map<String, dynamic>>[])
      (
        TextEditingController(text: '${t['upTo'] ?? ''}'.replaceAll(RegExp(r'\.0$'), '')),
        TextEditingController(text: '${t['price'] ?? ''}'.replaceAll(RegExp(r'\.0$'), '')),
      ),
  ];
  if (rows.isEmpty) rows.add((TextEditingController(text: '1'), TextEditingController()));

  await sheetForm(
    context: context,
    title: d == null ? 'Add pricing template' : 'Edit pricing template',
    onSave: () async {
      final tiers = [
        for (final r in rows)
          if (r.$1.text.trim().isNotEmpty) {'upTo': parseNum(r.$1.text), 'price': parseNum(r.$2.text)},
      ]..sort((a, b) => (a['upTo'] as num).compareTo(b['upTo'] as num));
      if (tiers.isEmpty) throw Exception('Add at least one tier');
      final data = {
        'name': name.text.trim(),
        'description': desc.text.trim(),
        'interval': interval,
        'minimum': parseNum(min.text),
        'tiers': tiers,
      };
      if (d == null) {
        await Db.create(C.pricingStructures, data);
      } else {
        await Db.update(C.pricingStructures, d.id, data);
      }
    },
    body: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Field(label: 'Name', controller: name, required: true, hint: 'e.g. Weekend special'),
      const SizedBox(height: 14),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: DropdownX<String>(label: 'Charge per', value: interval, items: _intervals, onChanged: (x) => setS(() => interval = x ?? 'day')),
        ),
        const SizedBox(width: 12),
        Expanded(child: Field.number(label: 'Minimum', controller: min, suffixText: '${interval}s', hint: '0')),
      ]),
      const SizedBox(height: 14),
      Field(label: 'Description', controller: desc, maxLines: 2),
      const SizedBox(height: 18),
      const MiniHeading('Tiers'),
      const SizedBox(height: 4),
      Text('Total price for rentals up to the given number of ${interval}s.', style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
      const SizedBox(height: 12),
      for (var i = 0; i < rows.length; i++)
        Padding(
          key: ObjectKey(rows[i]),
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(bottom: 14, right: 8),
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
              child: Text('${i + 1}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
            Expanded(child: Field.number(label: i == 0 ? 'Up to' : '', controller: rows[i].$1, suffixText: '${interval}s')),
            const SizedBox(width: 10),
            Expanded(child: Field.money(label: i == 0 ? 'Price' : '', controller: rows[i].$2)),
            IconButton(
              tooltip: 'Remove tier',
              onPressed: rows.length == 1
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      setS(() => rows.removeAt(i));
                    },
              icon: const Icon(Icons.remove_circle_outline, color: AppColors.muted),
            ),
          ]),
        ).enterX(0, 0.03),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setS(() {
            HapticFeedback.selectionClick();
            final last = rows.isEmpty ? 0 : parseNum(rows.last.$1.text);
            rows.add((TextEditingController(text: '${(last + 1).toInt()}'), TextEditingController()));
          }),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add tier'),
        ),
      ),
    ]),
  );
}
