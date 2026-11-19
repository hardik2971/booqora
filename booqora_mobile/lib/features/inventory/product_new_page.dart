import 'package:flutter/material.dart' hide Thumb;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../data/session.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/mobile.dart';
import 'inv_common.dart';

class ProductNewPage extends StatefulWidget {
  const ProductNewPage({super.key});

  @override
  State<ProductNewPage> createState() => _ProductNewPageState();
}

class _ProductNewPageState extends State<ProductNewPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _price = TextEditingController();
  String? _imageUrl;
  String _type = 'rental';
  String _tracking = 'trackable';
  String _pricing = 'flat';
  String _per = 'day';
  int _qty = 1;
  bool _variations = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      toast(context, 'Please fill in the required fields', error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final name = _name.text.trim();
      final qty = _qty.clamp(0, 500);
      final id = await Db.create(C.products, {
        'name': name,
        'sku': '',
        'type': _type,
        'trackingType': _tracking,
        'description': '',
        'excerpt': '',
        'imageUrls': [if (_imageUrl != null) _imageUrl],
        'status': 'active',
        'pricingMethod': _pricing,
        'price': _pricing == 'none' ? 0 : parseNum(_price.text),
        'pricePer': _per,
        'chargeEnabled': true,
        'taxable': false,
        'discountEligible': true,
        'deposit': 0,
        'purchaseCost': 0,
        'weight': 0,
        'weightUnit': Session.instance.setting('general', 'weightUnit', 'kg'),
        'allowShortage': false,
        'bufferBefore': 0,
        'bufferAfter': 0,
        'quantity': qty,
        'collectionIds': ['all-products'],
        'crossSellIds': <String>[],
        'variationsEnabled': _variations,
        'properties': <String>[],
        'variations': <Map<String, dynamic>>[],
        'showInStore': true,
        'slug': Session.slugify(name),
        'seoTitle': '',
        'seoDescription': '',
        'tags': <String>[],
      });
      if (qty > 0 && _tracking == 'trackable') {
        await createStockItems(productId: id, productName: name, count: qty, bumpQuantity: false);
      }
      Session.instance.markOnboarding('product');
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      toast(context, 'Product created');
      context.pushReplacement('/inventory/products/$id');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _section(String title, String? description, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionLabel(title),
          Group(children: [
            if (description != null) Text(description, style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4)),
            ...children,
          ]),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final rental = _type == 'rental';
    final priceFields = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Field.money(label: 'Price', controller: _price),
      if (rental) ...[
        const SizedBox(height: 12),
        const FieldLabel('Per'),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [for (final e in perLabels.entries) ButtonSegment(value: e.key, label: Text(e.value))],
          selected: {_per},
          onSelectionChanged: (v) {
            HapticFeedback.selectionClick();
            setState(() => _per = v.first);
          },
        ),
      ],
    ]);
    return FormScaffold(
      title: 'New product',
      formKey: _form,
      bottom: GradientButton(label: 'Create product', icon: Icons.check_rounded, busy: _saving, onPressed: _save),
      children: [
        // Photo hero
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Column(children: [
              ImageBox(
                url: _imageUrl,
                size: 148,
                label: 'Add photo',
                onUpload: (f) async {
                  final url = await Db.upload('products', f.name, f.bytes);
                  if (mounted) setState(() => _imageUrl = url);
                },
                onRemove: () => setState(() => _imageUrl = null),
              ),
              const SizedBox(height: 8),
              const Text('Take a photo or choose from your gallery', style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ]),
          ),
        ),
        _section('General', null, [
          Field(label: 'Product name', controller: _name, required: true, hint: 'e.g. Canon EOS R6 camera', onChanged: (_) => setState(() {})),
        ]),
        _section('Product type', 'Determines how the product is priced and whether it returns to stock.', [
          RadioCards<String>(
            value: _type,
            onChanged: (v) => setState(() => _type = v),
            options: const [
              ('rental', 'Rental product', 'Items meant to be rented and returned'),
              ('sale', 'Sales item', 'For sale or giveaways'),
              ('service', 'Service', 'e.g. setup or delivery costs'),
            ],
          ),
        ]),
        _section('Tracking', 'Track every unit with its own identifier, or manage a simple quantity.', [
          RadioCards<String>(
            value: _tracking,
            onChanged: (v) => setState(() => _tracking = v),
            options: const [
              ('trackable', 'Trackable', 'Individual identifiers per item, e.g. serial numbers'),
              ('bulk', 'Bulk', 'Track quantity only, e.g. chairs or cables'),
            ],
          ),
        ]),
        _section('Pricing', 'You can switch to a tiered pricing structure later from the product\'s Pricing tab.', [
          RadioCards<String>(
            value: _pricing,
            onChanged: (v) => setState(() => _pricing = v),
            options: [
              ('flat', 'Flat fee', rental ? 'Charge a price per hour, day, week or month' : 'Charge a fixed price per unit'),
              ('fixed', 'Fixed price per order', 'Same price regardless of the rental period'),
              ('none', 'No pricing', 'This product is free of charge'),
            ],
            expanded: {'flat': priceFields, 'fixed': Field.money(label: 'Price', controller: _price)},
          ),
        ]),
        _section(
          'Stock',
          _tracking == 'trackable'
              ? 'Stock items are created with automatic identifiers, e.g. ${identifierPrefix(_name.text)}-001. You can add more later.'
              : 'Set the number of units you have available.',
          [
            Stepper2(value: _qty, min: 0, max: 500, label: 'Initial stock quantity', onChanged: (v) => setState(() => _qty = v)),
            SwitchTile(
              value: _variations,
              title: 'Enable variations',
              subtitle: 'Offer this product in different properties, such as colour or size.',
              onChanged: (v) => setState(() => _variations = v),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(top: 14),
          child: InfoBanner('After saving you can add a SKU, descriptions, more images, security deposits and online store settings.',
              tone: Tone.brand, icon: Icons.lightbulb_outline),
        ),
      ],
    );
  }
}
