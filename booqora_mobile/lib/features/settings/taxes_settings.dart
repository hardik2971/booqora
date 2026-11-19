import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../data/session.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import 'settings_kit.dart';

class TaxesSettings extends StatefulWidget {
  const TaxesSettings({super.key});

  @override
  State<TaxesSettings> createState() => _TaxesSettingsState();
}

class _TaxesSettingsState extends SettingsState<TaxesSettings> {
  @override
  String get section => 'taxes';

  final _price = TextEditingController(text: '100');
  final _rate = TextEditingController(text: '18');

  @override
  void dispose() {
    _price.dispose();
    _rate.dispose();
    super.dispose();
  }

  @override
  Future<void> persist() async {
    await super.persist();
    await Session.instance.markOnboarding('tax');
  }

  @override
  Widget build(BuildContext context) {
    final inclusive = val<bool>('pricesIncludeTax', false);
    final price = parseNum(_price.text);
    final rate = parseNum(_rate.text);
    final excl = inclusive ? price / (1 + rate / 100) : price;
    final tax = inclusive ? price - excl : price * rate / 100;
    final incl = excl + tax;

    return view(
      title: 'Taxes',
      subtitle: 'How prices are entered and which tax rates apply to products and customers.',
      children: [
        SGroup(
          title: 'Prices',
          description: 'Choose whether the prices you enter for products already include tax.',
          children: [
            RadioCards<bool>(
              value: inclusive,
              options: const [
                (true, 'Product prices include tax', 'Tax is calculated backwards from the price you enter (common for retail).'),
                (false, 'Product prices exclude tax', 'Tax is added on top of the price you enter (common for B2B).'),
              ],
              onChanged: (x) => put('pricesIncludeTax', x),
            ),
            SoftBox(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const MiniHeading('Preview'),
                const SizedBox(height: 10),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Field.money(label: 'Product price', controller: _price, onChanged: (_) => setState(() {}))),
                  const SizedBox(width: 12),
                  Expanded(child: Field.number(label: 'Tax rate', controller: _rate, suffixText: '%', onChanged: (_) => setState(() {}))),
                ]),
                const SizedBox(height: 10),
                KV('Total excl. taxes', Fmt.money(excl)),
                KV('Tax (${fmtNum(rate)}%)', Fmt.money(tax)),
                const Divider(height: 18),
                KV('Total incl. taxes', Fmt.money(incl), bold: true),
              ]),
            ),
          ],
        ),
        const SGroup(
          title: 'Product tax profiles',
          description: 'Rates you can assign to products, e.g. GST 18% or VAT 20%. Saved immediately.',
          children: [_ProfilesList(kind: 'product')],
        ),
        const SGroup(
          title: 'Customer tax profiles',
          description: 'Rates that override product taxes for specific customers, e.g. tax-exempt organisations. Saved immediately.',
          children: [_ProfilesList(kind: 'customer')],
        ),
      ],
    );
  }
}

class _ProfilesList extends StatelessWidget {
  final String kind;
  const _ProfilesList({required this.kind});

  Future<void> _delete(BuildContext context, Doc d) async {
    final ok = await confirmDialog(context,
        title: 'Delete tax profile?',
        message: 'Products or customers using "${d.s('name')}" will no longer be taxed by it.',
        confirmLabel: 'Delete',
        danger: true);
    if (ok) await Db.remove(C.taxProfiles, d.id, label: d.s('name'));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Doc>>(
      stream: Db.watch(C.taxProfiles, desc: false),
      builder: (context, snap) {
        if (snap.hasError) return ErrorView(snap.error!);
        if (!snap.hasData) return const LoadingView(rows: 2);
        final items = snap.data!.where((d) => d.s('kind', 'product') == kind).toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(kind == 'product' ? 'No product tax profiles yet.' : 'No customer tax profiles yet.',
                  style: const TextStyle(color: AppColors.muted)),
            ),
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Dismissible(
                key: ValueKey(items[i].id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) async {
                  await _delete(context, items[i]);
                  return false;
                },
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 18),
                  decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.delete_outline, color: AppColors.danger),
                ),
                child: ListRow(
                  leading: IconBubble(Icons.percent, size: 36, color: kind == 'product' ? AppColors.primary : AppColors.info),
                  title: items[i].s('name'),
                  subtitle: items[i].b('compound') ? 'Compound tax' : null,
                  onTap: () => _edit(context, kind, items[i]),
                  trailing: Badge2('${fmtNum(items[i].n('rate'))}%'),
                ),
              ),
            ).enter(i, 0.03),
          const SizedBox(height: 4),
          AddRowButton(
            label: kind == 'product' ? 'Add product tax profile' : 'Add customer tax profile',
            onTap: () => _edit(context, kind, null),
          ),
          if (items.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Tip: swipe left on a profile to delete it.', style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ),
        ]);
      },
    );
  }
}

Future<void> _edit(BuildContext context, String kind, Doc? d) async {
  final name = TextEditingController(text: d?.s('name') ?? '');
  final rate = TextEditingController(text: d == null ? '' : fmtNum(d.n('rate')));
  var compound = d?.b('compound') ?? false;
  final saved = await sheetForm(
    context: context,
    title: d == null ? 'Add ${kind == 'product' ? 'product' : 'customer'} tax profile' : 'Edit tax profile',
    onSave: () async {
      final data = {'name': name.text.trim(), 'kind': kind, 'rate': parseNum(rate.text), 'compound': compound};
      if (d == null) {
        await Db.create(C.taxProfiles, data);
      } else {
        await Db.update(C.taxProfiles, d.id, data);
      }
    },
    body: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Field(label: 'Name', controller: name, required: true, autofocus: d == null, hint: kind == 'product' ? 'e.g. GST 18%' : 'e.g. Tax exempt'),
      const SizedBox(height: 14),
      Field.number(label: 'Rate', controller: rate, suffixText: '%', required: true),
      const SizedBox(height: 10),
      SwitchTile(
        value: compound,
        title: 'Compound tax',
        subtitle: 'Calculated on top of other taxes.',
        onChanged: (x) => setS(() => compound = x),
      ),
    ]),
  );
  if (saved) await Session.instance.markOnboarding('tax');
}
