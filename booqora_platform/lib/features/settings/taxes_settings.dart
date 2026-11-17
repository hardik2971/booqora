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

    final preview = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const MiniHeading('Preview'),
        const SizedBox(height: 10),
        FieldGrid(children: [
          Field.money(label: 'Product price', controller: _price, onChanged: (_) => setState(() {})),
          Field.number(label: 'Tax rate', controller: _rate, suffixText: '%', onChanged: (_) => setState(() {})),
        ]),
        const SizedBox(height: 10),
        KV('Product price', Fmt.money(price)),
        KV('Total excl. taxes', Fmt.money(excl)),
        KV('Tax (${rate.toString().replaceAll(RegExp(r'\.0$'), '')}%)', Fmt.money(tax)),
        const Divider(height: 18),
        KV('Total incl. taxes', Fmt.money(incl), bold: true),
      ]),
    );

    return view(
      title: 'Taxes',
      subtitle: 'How prices are entered and which tax rates apply to products and customers.',
      children: [
        FormSection(
          index: 0,
          title: 'General',
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
            preview,
          ],
        ),
        const FormSection(
          index: 1,
          title: 'Product tax profiles',
          description: 'Tax rates you can assign to products, for example GST 18% or VAT 20%. Saved immediately.',
          children: [_ProfilesList(kind: 'product')],
        ),
        const FormSection(
          index: 2,
          title: 'Customer tax profiles',
          description: 'Rates that override product taxes for specific customers, for example tax-exempt organisations. Saved immediately.',
          children: [_ProfilesList(kind: 'customer')],
        ),
      ],
    );
  }
}

class _ProfilesList extends StatelessWidget {
  final String kind;
  const _ProfilesList({required this.kind});

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
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                kind == 'product' ? 'No product tax profiles yet.' : 'No customer tax profiles yet.',
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
          for (var i = 0; i < items.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              child: Row(children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(9)),
                  child: const Icon(Icons.percent, size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(items[i].s('name'), style: const TextStyle(fontWeight: FontWeight.w600))),
                Badge2('${items[i].n('rate').toString().replaceAll(RegExp(r'\.0$'), '')}%'),
                if (items[i].b('compound')) ...[const SizedBox(width: 6), const Badge2('Compound', color: AppColors.info)],
                IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () => _edit(context, kind, items[i])),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                  onPressed: () async {
                    final ok = await confirmDialog(context,
                        title: 'Delete tax profile?',
                        message: 'Products or customers using "${items[i].s('name')}" will no longer be taxed by it.',
                        confirmLabel: 'Delete',
                        danger: true);
                    if (ok) await Db.remove(C.taxProfiles, items[i].id, label: items[i].s('name'));
                  },
                ),
              ]),
            ).enter(i, 0.03),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _edit(context, kind, null),
              icon: const Icon(Icons.add, size: 18),
              label: Text(kind == 'product' ? 'Add product tax profile' : 'Add customer tax profile'),
            ),
          ),
        ]);
      },
    );
  }
}

Future<void> _edit(BuildContext context, String kind, Doc? d) async {
  final name = TextEditingController(text: d?.s('name') ?? '');
  final rate = TextEditingController(text: d == null ? '' : d.n('rate').toString().replaceAll(RegExp(r'\.0$'), ''));
  var compound = d?.b('compound') ?? false;
  final saved = await formDialog(
    context: context,
    title: d == null ? 'Add ${kind == 'product' ? 'product' : 'customer'} tax profile' : 'Edit tax profile',
    width: 440,
    onSave: () async {
      final data = {'name': name.text.trim(), 'kind': kind, 'rate': parseNum(rate.text), 'compound': compound};
      if (d == null) {
        await Db.create(C.taxProfiles, data);
      } else {
        await Db.update(C.taxProfiles, d.id, data);
      }
    },
    body: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Field(label: 'Name', controller: name, required: true, hint: kind == 'product' ? 'e.g. GST 18%' : 'e.g. Tax exempt'),
      const SizedBox(height: 14),
      Field.number(label: 'Rate', controller: rate, suffixText: '%', required: true),
      const SizedBox(height: 10),
      CheckTile(
        value: compound,
        title: 'Compound tax',
        subtitle: 'Calculated on top of other taxes.',
        onChanged: (x) => setS(() => compound = x),
      ),
    ]),
  );
  if (saved) await Session.instance.markOnboarding('tax');
}
