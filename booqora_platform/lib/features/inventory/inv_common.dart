import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue, Timestamp;
import 'package:flutter/material.dart' hide Thumb;

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/pricing.dart';
import '../../data/schema.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';

/// Subscribes to several live streams at once and rebuilds with the latest
/// snapshot of each. Shows a skeleton until every stream has emitted.
class LiveData extends StatefulWidget {
  final Map<String, Stream<List<Doc>>> Function() streams;
  final Widget Function(BuildContext context, Map<String, List<Doc>> data) builder;
  final Widget? loading;
  const LiveData({super.key, required this.streams, required this.builder, this.loading});

  /// Convenience: watches whole collections by name.
  factory LiveData.of(List<String> collections,
          {Key? key, required Widget Function(BuildContext, Map<String, List<Doc>>) builder, Widget? loading}) =>
      LiveData(key: key, streams: () => {for (final c in collections) c: Db.watch(c)}, builder: builder, loading: loading);

  @override
  State<LiveData> createState() => _LiveDataState();
}

class _LiveDataState extends State<LiveData> {
  final Map<String, List<Doc>> _data = {};
  final List<StreamSubscription> _subs = [];
  late final int _expected;
  Object? _error;

  @override
  void initState() {
    super.initState();
    final streams = widget.streams();
    _expected = streams.length;
    streams.forEach((k, s) {
      _subs.add(s.listen((v) {
        if (mounted) setState(() => _data[k] = v);
      }, onError: (Object e) {
        if (mounted) setState(() => _error = e);
      }));
    });
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return ErrorView(friendlyError(_error!));
    if (_data.length < _expected) return widget.loading ?? const LoadingView();
    return widget.builder(context, _data);
  }
}

// ---------------------------------------------------------------------------
// Product math helpers
// ---------------------------------------------------------------------------

int availableNow(Doc p, List<Doc> orders, List<Doc> downtimes) {
  final now = DateTime.now();
  return Pricing.available(p, now, now.add(const Duration(hours: 1)), orders, downtimes);
}

/// Units of [productId] currently out on started orders.
int unitsOut(String productId, List<Doc> orders) {
  var n = 0;
  for (final o in orders) {
    if (o.s('status') != 'started') continue;
    for (final l in o.maps('lines')) {
      if (l['productId'] == productId) n += ((l['qty'] as num?) ?? 0).toInt();
    }
  }
  return n;
}

bool orderHasProduct(Doc o, String productId) => o.maps('lines').any((l) => l['productId'] == productId);

int orderQtyFor(Doc o, String productId) =>
    o.maps('lines').where((l) => l['productId'] == productId).fold(0, (a, l) => a + ((l['qty'] as num?) ?? 0).toInt());

String productThumb(Doc p) {
  final imgs = p.l<String>('imageUrls');
  return imgs.isEmpty ? '' : imgs.first;
}

String priceLabel(Doc p) {
  switch (p.s('pricingMethod', 'flat')) {
    case 'none':
      return 'No pricing';
    case 'fixed':
      return '${Fmt.money(p.n('price'))} / order';
    case 'structure':
      return 'Pricing structure';
    default:
      if (p.s('type') == 'sale' || p.s('type') == 'service') return Fmt.money(p.n('price'));
      return '${Fmt.money(p.n('price'))} / ${p.s('pricePer', 'day')}';
  }
}

const productTypeLabels = {'rental': 'Rental', 'sale': 'Sales item', 'service': 'Service'};
const downtimeReasons = {'maintenance': 'Maintenance', 'repair': 'Repair', 'missing': 'Missing'};

String identifierPrefix(String name) {
  final letters = name.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (letters.isEmpty) return 'ITEM';
  return letters.length > 4 ? letters.substring(0, 4) : letters;
}

Widget storePill(bool visible) => StatusPill(visible ? 'active' : 'inactive', label: visible ? 'Visible' : 'Hidden');

Widget smallChip(String text, {Color color = AppColors.primaryDeep, Color bg = AppColors.primarySoft}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );

// ---------------------------------------------------------------------------
// Writes
// ---------------------------------------------------------------------------

/// Creates [count] stock items for [product] in one batch and bumps its quantity.
Future<void> createStockItems({
  required String productId,
  required String productName,
  required int count,
  String? prefix,
  String kind = 'regular',
  DateTime? availableFrom,
  DateTime? availableTill,
  num purchaseCost = 0,
  DateTime? purchaseDate,
  bool bumpQuantity = true,
}) async {
  if (count <= 0) return;
  final pre = (prefix == null || prefix.trim().isEmpty) ? identifierPrefix(productName) : prefix.trim().toUpperCase();
  final existing = await Db.listWhere(C.stockItems, 'productId', productId);
  var next = 1;
  final re = RegExp('^${RegExp.escape(pre)}-(\\d+)\$');
  for (final s in existing) {
    final m = re.firstMatch(s.s('identifier'));
    if (m != null) {
      final v = int.parse(m.group(1)!);
      if (v >= next) next = v + 1;
    }
  }
  final batch = Db.fs.batch();
  for (var i = 0; i < count; i++) {
    final ref = Db.col(C.stockItems).doc();
    batch.set(ref, {
      'productId': productId,
      'productName': productName,
      'identifier': '$pre-${(next + i).toString().padLeft(3, '0')}',
      'kind': kind,
      'availableFrom': Timestamp.fromDate(availableFrom ?? DateTime.now()),
      'availableTill': availableTill == null ? null : Timestamp.fromDate(availableTill),
      'purchaseCost': purchaseCost,
      'purchaseDate': purchaseDate == null ? null : Timestamp.fromDate(purchaseDate),
      'status': 'available',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
  if (bumpQuantity) {
    batch.update(Db.col(C.products).doc(productId), {'quantity': FieldValue.increment(count), 'updatedAt': FieldValue.serverTimestamp()});
  }
  await batch.commit();
  Db.log(C.products, productId, 'updated', '$productName: added $count stock item${count == 1 ? '' : 's'}');
}

/// Deletes a product together with its stock items.
Future<void> deleteProduct(Doc p) async {
  final items = await Db.listWhere(C.stockItems, 'productId', p.id);
  final batch = Db.fs.batch();
  for (final s in items) {
    batch.delete(Db.col(C.stockItems).doc(s.id));
  }
  await batch.commit();
  await Db.remove(C.products, p.id, label: p.s('name'));
}

Future<void> setDowntimeStatus(Doc d, String status) async {
  await Db.update(C.downtimes, d.id, {
    'status': status,
    if (status == 'started') 'startsAt': Timestamp.fromDate(DateTime.now()),
    if (status == 'ended') 'endsAt': Timestamp.fromDate(DateTime.now()),
  }, label: '${d.s('productName')} downtime ${status == 'started' ? 'started' : status}');
  final sid = d.s('stockItemId');
  if (sid.isNotEmpty) {
    try {
      await Db.update(C.stockItems, sid, {'status': status == 'started' ? 'downtime' : 'available'}, silent: true);
    } catch (_) {}
  }
}

// ---------------------------------------------------------------------------
// Dialogs
// ---------------------------------------------------------------------------

Widget dialogFrame(BuildContext context,
    {required String title, required Widget child, required List<Widget> actions, double width = 520, String? subtitle}) {
  final w = MediaQuery.sizeOf(context).width;
  return Dialog(
    insetPadding: EdgeInsets.symmetric(horizontal: w < 600 ? 12 : 40, vertical: 24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width, maxHeight: MediaQuery.sizeOf(context).height * 0.88),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 12, 8),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                ],
              ]),
            ),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ]),
        ),
        Flexible(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 16), child: child)),
        Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
          child: Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 8, children: actions),
        ),
      ]),
    ),
  );
}

/// Searchable product (and optionally bundle) picker. Returns the chosen doc.
Future<Doc?> pickProductDialog(BuildContext context, List<Doc> items,
    {Set<String> exclude = const {}, String title = 'Select product', bool Function(Doc)? isBundle}) {
  return showDialog<Doc>(
    context: context,
    builder: (c) {
      var q = '';
      return StatefulBuilder(builder: (c, setS) {
        final list = items
            .where((p) => !exclude.contains(p.id))
            .where((p) => q.isEmpty || p.s('name').toLowerCase().contains(q) || p.s('sku').toLowerCase().contains(q))
            .toList();
        return dialogFrame(c,
            title: title,
            actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel'))],
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Search by name or SKU', prefixIcon: Icon(Icons.search, size: 20)),
                onChanged: (v) => setS(() => q = v.trim().toLowerCase()),
              ),
              const SizedBox(height: 8),
              if (list.isEmpty)
                const EmptyState(icon: Icons.search_off, title: 'No matches', message: 'Try a different search term.', compact: true),
              for (final p in list.take(60))
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Thumb(
                      url: isBundle?.call(p) == true ? p.s('imageUrl') : productThumb(p),
                      size: 36,
                      icon: isBundle?.call(p) == true ? Icons.workspaces_outline : Icons.inventory_2_outlined),
                  title: Text(p.s('name'), style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(isBundle?.call(p) == true ? 'Bundle' : [p.s('sku'), priceLabel(p)].where((e) => e.isNotEmpty).join(' · '),
                      style: const TextStyle(fontSize: 12)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onTap: () => Navigator.pop(c, p),
                ),
            ]));
      });
    },
  );
}

/// Multi-select collections dialog. Returns the new selection or null.
Future<Set<String>?> pickCollectionsDialog(BuildContext context, List<Doc> collections, Set<String> selected) {
  return showDialog<Set<String>>(
    context: context,
    builder: (c) {
      final sel = {...selected};
      return StatefulBuilder(builder: (c, setS) {
        return dialogFrame(c,
            title: 'Add to collections',
            subtitle: 'Collections group products in your online store and reports.',
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(c, sel), child: const Text('Apply')),
            ],
            child: collections.isEmpty
                ? const Text('No collections yet.', style: TextStyle(color: AppColors.muted))
                : Column(children: [
                    for (final col in collections)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: col.b('isSystem') ? true : sel.contains(col.id),
                        onChanged: col.b('isSystem') ? null : (v) => setS(() => v == true ? sel.add(col.id) : sel.remove(col.id)),
                        title: Text(col.s('name')),
                        subtitle: col.b('isSystem') ? const Text('Includes every product', style: TextStyle(fontSize: 12)) : null,
                      ),
                  ]));
      });
    },
  );
}

/// Schedule downtime dialog. If [product] is null a product picker is shown.
Future<void> showDowntimeDialog(BuildContext context, {Doc? product, List<Doc>? products}) async {
  final all = products ?? (product == null ? await Db.list(C.products) : <Doc>[]);
  if (!context.mounted) return;
  await showDialog<void>(context: context, builder: (_) => _DowntimeDialog(product: product, products: all));
}

class _DowntimeDialog extends StatefulWidget {
  final Doc? product;
  final List<Doc> products;
  const _DowntimeDialog({this.product, required this.products});

  @override
  State<_DowntimeDialog> createState() => _DowntimeDialogState();
}

class _DowntimeDialogState extends State<_DowntimeDialog> {
  Doc? _product;
  List<Doc> _stock = [];
  String _mode = 'qty';
  String? _stockItemId;
  String _reason = 'maintenance';
  DateTime? _from = DateTime.now();
  DateTime? _until = DateTime.now().add(const Duration(days: 1));
  final _qty = TextEditingController(text: '1');
  final _note = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) _select(widget.product!);
  }

  @override
  void dispose() {
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _select(Doc p) async {
    setState(() {
      _product = p;
      _stock = [];
      _stockItemId = null;
    });
    final items = await Db.listWhere(C.stockItems, 'productId', p.id);
    if (mounted) setState(() => _stock = items..sort((a, b) => a.s('identifier').compareTo(b.s('identifier'))));
  }

  Future<void> _save() async {
    final p = _product;
    if (p == null) return toast(context, 'Select a product', error: true);
    if (_from == null) return toast(context, 'Select a start date', error: true);
    if (_until != null && !_until!.isAfter(_from!)) return toast(context, 'End must be after start', error: true);
    final useItem = _mode == 'item' && _stockItemId != null;
    final qty = useItem ? 1 : parseNum(_qty.text, 1).toInt();
    if (qty < 1) return toast(context, 'Quantity must be at least 1', error: true);
    setState(() => _saving = true);
    try {
      final item = useItem ? _stock.firstWhere((s) => s.id == _stockItemId) : null;
      await Db.create(C.downtimes, {
        'productId': p.id,
        'productName': p.s('name'),
        'stockItemId': item?.id,
        'stockIdentifier': item?.s('identifier'),
        'quantity': qty,
        'reason': _reason,
        'status': 'scheduled',
        'startsAt': Timestamp.fromDate(_from!),
        'endsAt': _until == null ? null : Timestamp.fromDate(_until!),
        'note': _note.text.trim(),
      }, label: '${p.s('name')} (${downtimeReasons[_reason]})');
      if (mounted) {
        Navigator.pop(context);
        toast(context, 'Downtime scheduled');
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trackable = _product?.s('trackingType', 'trackable') == 'trackable' && _stock.isNotEmpty;
    return dialogFrame(context,
        title: 'Schedule downtime',
        subtitle: 'Temporarily remove items so they can\'t be booked.',
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Schedule'),
          ),
        ],
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (widget.product == null) ...[
            const FieldLabel('Product', required: true),
            OutlinedButton(
              style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.all(12)),
              onPressed: () async {
                final p = await pickProductDialog(context, widget.products.where((p) => p.s('status') != 'archived').toList());
                if (p != null) _select(p);
              },
              child: Row(children: [
                Thumb(url: _product == null ? null : productThumb(_product!), size: 28),
                const SizedBox(width: 10),
                Expanded(child: Text(_product?.s('name') ?? 'Select product', overflow: TextOverflow.ellipsis)),
                const Icon(Icons.unfold_more, size: 18),
              ]),
            ),
            const SizedBox(height: 16),
          ],
          if (trackable) ...[
            RadioCards<String>(
              value: _mode,
              horizontal: false,
              onChanged: (v) => setState(() => _mode = v),
              options: const [
                ('qty', 'Quantity', 'Remove a number of units'),
                ('item', 'Specific stock item', 'Pick an individual identifier'),
              ],
              expanded: {
                'item': DropdownX<String>(
                  label: 'Stock item',
                  value: _stockItemId,
                  hint: 'Select identifier',
                  items: {for (final s in _stock) s.id: s.s('identifier')},
                  onChanged: (v) => setState(() => _stockItemId = v),
                ),
              },
            ),
            const SizedBox(height: 8),
          ],
          if (!trackable || _mode == 'qty') ...[
            Field.number(label: 'Quantity', controller: _qty, decimal: false),
            const SizedBox(height: 16),
          ],
          DropdownX<String>(
            label: 'Reason',
            value: _reason,
            items: downtimeReasons,
            onChanged: (v) => setState(() => _reason = v ?? 'maintenance'),
          ),
          const SizedBox(height: 16),
          FieldGrid(children: [
            DateTimeField(label: 'From', value: _from, onChanged: (v) => setState(() => _from = v)),
            DateTimeField(label: 'Until', value: _until, clearable: true, onChanged: (v) => setState(() => _until = v)),
          ]),
          const SizedBox(height: 16),
          Field(label: 'Note', controller: _note, maxLines: 3, hint: 'Optional details for your team'),
        ]));
  }
}

/// Add stock items dialog for [product].
Future<void> showAddStockDialog(BuildContext context, Doc product) =>
    showDialog<void>(context: context, builder: (_) => _AddStockDialog(product: product));

class _AddStockDialog extends StatefulWidget {
  final Doc product;
  const _AddStockDialog({required this.product});

  @override
  State<_AddStockDialog> createState() => _AddStockDialogState();
}

class _AddStockDialogState extends State<_AddStockDialog> {
  final _qty = TextEditingController(text: '1');
  late final _cost = TextEditingController(text: widget.product.n('purchaseCost') == 0 ? '' : '${widget.product.n('purchaseCost')}');
  late final _prefix = TextEditingController(text: identifierPrefix(widget.product.s('name')));
  String _kind = 'regular';
  DateTime? _from = DateTime.now();
  DateTime? _till;
  DateTime? _purchased = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _qty.dispose();
    _cost.dispose();
    _prefix.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final n = parseNum(_qty.text, 0).toInt();
    if (n < 1) return toast(context, 'Quantity must be at least 1', error: true);
    if (n > 500) return toast(context, 'Add at most 500 items at a time', error: true);
    if (_kind == 'temporary' && _till == null) return toast(context, 'Set an "Available till" date', error: true);
    setState(() => _saving = true);
    try {
      await createStockItems(
        productId: widget.product.id,
        productName: widget.product.s('name'),
        count: n,
        prefix: _prefix.text,
        kind: _kind,
        availableFrom: _from,
        availableTill: _kind == 'temporary' ? _till : null,
        purchaseCost: parseNum(_cost.text),
        purchaseDate: _purchased,
      );
      if (mounted) {
        Navigator.pop(context);
        toast(context, '$n stock item${n == 1 ? '' : 's'} added');
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      FieldGrid(children: [
        DateTimeField(label: 'Available from', value: _from, onChanged: (v) => setState(() => _from = v)),
        if (_kind == 'temporary') DateTimeField(label: 'Available till', value: _till, onChanged: (v) => setState(() => _till = v)),
        Field.money(label: 'Purchase cost per item', controller: _cost),
        DateTimeField(label: 'Purchase date', value: _purchased, withTime: false, clearable: true, onChanged: (v) => setState(() => _purchased = v)),
        Field(label: 'Identifier prefix', controller: _prefix, helper: 'Items are numbered automatically, e.g. ${_prefix.text.toUpperCase()}-001'),
      ]),
    ]);
    return dialogFrame(context,
        title: 'Add stock items',
        subtitle: widget.product.s('name'),
        width: 620,
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Add stock'),
          ),
        ],
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(width: 200, child: Field.number(label: 'Quantity', controller: _qty, decimal: false)),
          const SizedBox(height: 16),
          RadioCards<String>(
            value: _kind,
            onChanged: (v) => setState(() => _kind = v),
            options: const [
              ('regular', 'Regular stock', 'Items you own and keep in your inventory'),
              ('temporary', 'Temporary stock', 'Sub-rented or borrowed items available for a limited period'),
            ],
            expanded: {'regular': details, 'temporary': details},
          ),
        ]));
  }
}
