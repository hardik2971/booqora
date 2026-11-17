import 'package:flutter/material.dart' hide Thumb;
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../data/session.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/page.dart';
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
  final _qty = TextEditingController(text: '0');
  String? _imageUrl;
  String _type = 'rental';
  String _tracking = 'trackable';
  String _pricing = 'flat';
  String _per = 'day';
  bool _variations = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _qty.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      toast(context, 'Please fill in the required fields', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final name = _name.text.trim();
      final qty = parseNum(_qty.text, 0).toInt().clamp(0, 500);
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
      toast(context, 'Product created');
      context.go('/inventory/products/$id');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rental = _type == 'rental';
    final priceFields = FieldGrid(children: [
      Field.money(label: 'Price', controller: _price),
      if (rental)
        DropdownX<String>(
          label: 'Per',
          value: _per,
          items: const {'hour': 'Hour', 'day': 'Day', 'week': 'Week', 'month': 'Month'},
          onChanged: (v) => setState(() => _per = v ?? 'day'),
        ),
    ]);
    return Form(
      key: _form,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const PageHeader(
          title: 'New product',
          breadcrumbs: [('Inventory', '/inventory'), ('Products', '/inventory?tab=products')],
        ),
        Expanded(
          child: PageBody(maxWidth: 1100, children: [
            FormSection(
              title: 'General',
              description: 'The name and image customers see on documents and in your online store.',
              index: 0,
              children: [
                Field(label: 'Product name', controller: _name, required: true, hint: 'e.g. Canon EOS R6 camera', autofocus: true),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const FieldLabel('Image'),
                  ImageBox(
                    url: _imageUrl,
                    onUpload: (f) async {
                      final url = await Db.upload('products', f.name, f.bytes);
                      if (mounted) setState(() => _imageUrl = url);
                    },
                    onRemove: () => setState(() => _imageUrl = null),
                  ),
                ]),
              ],
            ),
            FormSection(
              title: 'Product type',
              description: 'Determines how the product is priced and whether it returns to stock.',
              index: 1,
              children: [
                RadioCards<String>(
                  value: _type,
                  onChanged: (v) => setState(() => _type = v),
                  options: const [
                    ('rental', 'Rental product', 'Items meant to be rented and returned'),
                    ('sale', 'Sales item', 'For sale or giveaways'),
                    ('service', 'Service', 'e.g. setup costs'),
                  ],
                ),
              ],
            ),
            FormSection(
              title: 'Tracking',
              description: 'Track every unit with its own identifier, or manage a simple quantity.',
              index: 2,
              children: [
                RadioCards<String>(
                  value: _tracking,
                  onChanged: (v) => setState(() => _tracking = v),
                  options: const [
                    ('trackable', 'Trackable', 'Individual identifiers per item, e.g. serial numbers'),
                    ('bulk', 'Bulk', 'Track quantity only, e.g. chairs or cables'),
                  ],
                ),
              ],
            ),
            FormSection(
              title: 'Pricing',
              description: 'You can switch to a tiered pricing structure later from the product\'s Pricing tab.',
              index: 3,
              children: [
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
              ],
            ),
            FormSection(
              title: 'Stock',
              description: _tracking == 'trackable'
                  ? 'Stock items are created with automatic identifiers. You can add more, temporary or expected stock later.'
                  : 'Set the number of units you have available.',
              index: 4,
              children: [
                SizedBox(width: 240, child: Field.number(label: 'Initial stock quantity', controller: _qty, decimal: false)),
                CheckTile(
                  value: _variations,
                  title: 'Enable variations',
                  subtitle: 'Offer this product in different properties, such as colour or size.',
                  onChanged: (v) => setState(() => _variations = v),
                ),
              ],
            ),
            const InfoBanner('After saving you can add a SKU, descriptions, more images, security deposits and online store settings.',
                tone: Tone.brand, icon: Icons.lightbulb_outline),
          ]),
        ),
        SaveBar(
          saving: _saving,
          saveLabel: 'Create product',
          onCancel: () => context.go('/inventory'),
          onSave: _save,
          leading: MediaQuery.sizeOf(context).width < 640 ? null : const Text('Fields marked * are required', style: TextStyle(color: AppColors.muted, fontSize: 13)),
        ),
      ]),
    );
  }
}
