import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue, Timestamp;
import 'package:flutter/material.dart' hide Thumb;
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/pricing.dart';
import '../../data/schema.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/mobile.dart';

/// Subscribes to several live streams at once and rebuilds with the latest
/// snapshot of each. Shows [loading] until every stream has emitted.
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
    if (_error != null) {
      return Scaffold(backgroundColor: AppColors.bg, appBar: AppBar(backgroundColor: AppColors.bg), body: ErrorView(friendlyError(_error!)));
    }
    if (_data.length < _expected) return widget.loading ?? const Scaffold(backgroundColor: AppColors.bg, body: SafeArea(child: LoadingView()));
    return widget.builder(context, _data);
  }
}

/// Simple loading scaffold used while live data arrives.
class LoadingPage extends StatelessWidget {
  final String title;
  const LoadingPage(this.title, {super.key});
  @override
  Widget build(BuildContext context) => MPage(title: title, slivers: const [SliverToBoxAdapter(child: LoadingView())]);
}

// ---------------------------------------------------------------------------
// Product math helpers (ported from web)
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
const perLabels = {'hour': 'Hour', 'day': 'Day', 'week': 'Week', 'month': 'Month'};

String identifierPrefix(String name) {
  final letters = name.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (letters.isEmpty) return 'ITEM';
  return letters.length > 4 ? letters.substring(0, 4) : letters;
}

String heroTagFor(String productId) => 'product-image-$productId';

Widget storePill(bool visible) => StatusPill(visible ? 'active' : 'hidden', label: visible ? 'In store' : 'Hidden');

Widget smallChip(String text, {Color color = AppColors.primaryDeep, Color bg = AppColors.primarySoft, IconData? icon}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
        Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
      ]),
    );

/// Colour for an availability count relative to total stock.
Color availColor(int avail, int total) => avail <= 0 ? AppColors.danger : (avail < total ? AppColors.warning : AppColors.success);

// ---------------------------------------------------------------------------
// Writes (identical to web)
// ---------------------------------------------------------------------------

/// Creates [count] stock items for a product in one batch and bumps its quantity.
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

Future<void> deleteStockItem(Doc product, Doc s) async {
  await Db.remove(C.stockItems, s.id, label: s.s('identifier'));
  await Db.update(C.products, product.id, {'quantity': FieldValue.increment(-1)}, label: '${product.s('name')}: removed ${s.s('identifier')}');
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

/// Runs [action] showing a success toast or a friendly error.
Future<bool> runAction(BuildContext context, Future<void> Function() action, String success) async {
  try {
    await action();
    if (context.mounted) toast(context, success);
    return true;
  } catch (e) {
    if (context.mounted) toast(context, friendlyError(e), error: true);
    return false;
  }
}

// ---------------------------------------------------------------------------
// Shared mobile UI bits
// ---------------------------------------------------------------------------

/// Pinned header delegate for custom scroll views.
class PinnedBox extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;
  final Color color;
  PinnedBox(this.child, {this.height = 56, this.color = AppColors.bg});
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(color: color, alignment: Alignment.center, child: child);
  @override
  bool shouldRebuild(covariant PinnedBox old) => true;
}

/// Primary sheet / form action with busy state.
class SheetActions extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool busy;
  final VoidCallback? onPressed;
  const SheetActions({super.key, required this.label, this.icon, this.busy = false, this.onPressed});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20),
        child: GradientButton(label: label, icon: icon, busy: busy, onPressed: onPressed),
      );
}

/// Red swipe-to-act background for [Dismissible].
Widget swipeBg(IconData icon, String label, {Color color = AppColors.danger, bool end = true}) => Container(
      alignment: end ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(18)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
      ]),
    );

/// Wraps [child] in a swipe-left action that asks for confirmation and runs [onConfirmed].
/// The card always snaps back; the live stream removes it if needed.
Widget swipeAction({
  required Key key,
  required BuildContext context,
  required Widget child,
  required IconData icon,
  required String label,
  required String confirmTitle,
  required String confirmMessage,
  required Future<void> Function() onConfirmed,
  Color color = AppColors.danger,
  bool danger = true,
}) {
  return Dismissible(
    key: key,
    direction: DismissDirection.endToStart,
    background: swipeBg(icon, label, color: color),
    confirmDismiss: (_) async {
      HapticFeedback.mediumImpact();
      final ok = await confirmDialog(context, title: confirmTitle, message: confirmMessage, confirmLabel: label, danger: danger);
      if (ok) await onConfirmed();
      return false;
    },
    child: child,
  );
}

/// Searchable product (and optionally bundle) picker sheet. Returns the chosen doc.
Future<Doc?> pickProductSheet(BuildContext context, List<Doc> items,
    {Set<String> exclude = const {}, String title = 'Select product', bool Function(Doc)? isBundle}) {
  var q = '';
  return showAppSheet<Doc>(
    context,
    title: title,
    scroll: false,
    builder: (c) => StatefulBuilder(builder: (c, setS) {
      final list = items
          .where((p) => !exclude.contains(p.id))
          .where((p) => q.isEmpty || p.s('name').toLowerCase().contains(q) || p.s('sku').toLowerCase().contains(q))
          .toList();
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        MSearch(hint: 'Search by name or SKU', onChanged: (v) => setS(() => q = v.trim().toLowerCase())),
        const SizedBox(height: 10),
        Flexible(
          child: list.isEmpty
              ? const EmptyState(icon: Icons.search_off, title: 'No matches', message: 'Try a different search term.', compact: true)
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (_, i) {
                    final p = list[i];
                    final bundle = isBundle?.call(p) == true;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      leading: Thumb(url: bundle ? p.s('imageUrl') : productThumb(p), size: 42, icon: bundle ? Icons.workspaces_outline : Icons.inventory_2_outlined),
                      title: Text(p.s('name'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(bundle ? 'Bundle' : [p.s('sku'), priceLabel(p)].where((e) => e.isNotEmpty).join(' · '), style: const TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.pop(c, p);
                      },
                    ).enterX(i);
                  },
                ),
        ),
      ]);
    }),
  );
}

/// Multi-select collections sheet. Returns the new selection or null.
Future<Set<String>?> pickCollectionsSheet(BuildContext context, List<Doc> collections, Set<String> selected) {
  final sel = {...selected};
  return showAppSheet<Set<String>>(
    context,
    title: 'Collections',
    builder: (c) => StatefulBuilder(builder: (c, setS) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Collections group products in your online store and reports.', style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 12),
        if (collections.isEmpty) const Text('No collections yet.', style: TextStyle(color: AppColors.muted)),
        for (final col in collections)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: col.b('isSystem') ? true : sel.contains(col.id),
            onChanged: col.b('isSystem') ? null : (v) => setS(() => v == true ? sel.add(col.id) : sel.remove(col.id)),
            title: Text(col.s('name')),
            subtitle: col.b('isSystem') ? const Text('Includes every product', style: TextStyle(fontSize: 12)) : null,
          ),
        SheetActions(label: 'Apply', icon: Icons.check_rounded, onPressed: () => Navigator.pop(c, sel)),
      ]);
    }),
  );
}

// ---------------------------------------------------------------------------
// Downtime sheet
// ---------------------------------------------------------------------------

/// Schedule downtime sheet. If [product] is null a product picker is shown.
Future<void> showDowntimeSheet(BuildContext context, {Doc? product, List<Doc>? products}) async {
  final all = products ?? (product == null ? await Db.list(C.products) : <Doc>[]);
  if (!context.mounted) return;
  await showAppSheet<void>(context, title: 'Schedule downtime', builder: (_) => _DowntimeForm(product: product, products: all));
}

class _DowntimeForm extends StatefulWidget {
  final Doc? product;
  final List<Doc> products;
  const _DowntimeForm({this.product, required this.products});

  @override
  State<_DowntimeForm> createState() => _DowntimeFormState();
}

class _DowntimeFormState extends State<_DowntimeForm> {
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
        HapticFeedback.mediumImpact();
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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Temporarily remove items so they can\'t be booked.', style: TextStyle(color: AppColors.muted)),
      const SizedBox(height: 16),
      if (widget.product == null) ...[
        const FieldLabel('Product', required: true),
        PressScale(
          onTap: () async {
            final p = await pickProductSheet(context, widget.products.where((p) => p.s('status') != 'archived').toList());
            if (p != null) _select(p);
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: Row(children: [
              Thumb(url: _product == null ? null : productThumb(_product!), size: 32),
              const SizedBox(width: 10),
              Expanded(child: Text(_product?.s('name') ?? 'Select product', overflow: TextOverflow.ellipsis, style: TextStyle(color: _product == null ? AppColors.muted : AppColors.ink, fontWeight: FontWeight.w600))),
              const Icon(Icons.unfold_more, size: 18, color: AppColors.muted),
            ]),
          ),
        ),
        const SizedBox(height: 16),
      ],
      if (trackable) ...[
        RadioCards<String>(
          value: _mode,
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
        const SizedBox(height: 6),
      ],
      if (!trackable || _mode == 'qty') ...[
        Field.number(label: 'Quantity', controller: _qty, decimal: false),
        const SizedBox(height: 16),
      ],
      const FieldLabel('Reason'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final r in downtimeReasons.entries)
          ChoiceChip(
            label: Text(r.value),
            selected: _reason == r.key,
            onSelected: (_) {
              HapticFeedback.selectionClick();
              setState(() => _reason = r.key);
            },
          ),
      ]),
      const SizedBox(height: 16),
      DateTimeField(label: 'From', value: _from, onChanged: (v) => setState(() => _from = v)),
      const SizedBox(height: 16),
      DateTimeField(label: 'Until (leave empty for open-ended)', value: _until, clearable: true, onChanged: (v) => setState(() => _until = v)),
      const SizedBox(height: 16),
      Field(label: 'Note', controller: _note, maxLines: 3, hint: 'Optional details for your team'),
      SheetActions(label: 'Schedule downtime', icon: Icons.build_circle_outlined, busy: _saving, onPressed: _save),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Add stock sheet
// ---------------------------------------------------------------------------

Future<void> showAddStockSheet(BuildContext context, Doc product) =>
    showAppSheet<void>(context, title: 'Add stock items', builder: (_) => _AddStockForm(product: product));

class _AddStockForm extends StatefulWidget {
  final Doc product;
  const _AddStockForm({required this.product});

  @override
  State<_AddStockForm> createState() => _AddStockFormState();
}

class _AddStockFormState extends State<_AddStockForm> {
  int _n = 1;
  late final _cost = TextEditingController(text: widget.product.n('purchaseCost') == 0 ? '' : '${widget.product.n('purchaseCost')}');
  late final _prefix = TextEditingController(text: identifierPrefix(widget.product.s('name')));
  String _kind = 'regular';
  DateTime? _from = DateTime.now();
  DateTime? _till;
  DateTime? _purchased = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _cost.dispose();
    _prefix.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final n = _n;
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
        HapticFeedback.mediumImpact();
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
    final pre = _prefix.text.trim().isEmpty ? identifierPrefix(widget.product.s('name')) : _prefix.text.trim().toUpperCase();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(widget.product.s('name'), style: const TextStyle(color: AppColors.muted)),
      const SizedBox(height: 16),
      Stepper2(value: _n, min: 1, max: 500, label: 'Quantity', onChanged: (v) => setState(() => _n = v)),
      const SizedBox(height: 16),
      RadioCards<String>(
        value: _kind,
        onChanged: (v) => setState(() => _kind = v),
        options: const [
          ('regular', 'Regular stock', 'Items you own and keep in your inventory'),
          ('temporary', 'Temporary stock', 'Sub-rented or borrowed items for a limited period'),
        ],
      ),
      const SizedBox(height: 6),
      DateTimeField(label: 'Available from', value: _from, onChanged: (v) => setState(() => _from = v)),
      if (_kind == 'temporary') ...[
        const SizedBox(height: 16),
        DateTimeField(label: 'Available till', value: _till, onChanged: (v) => setState(() => _till = v)),
      ],
      const SizedBox(height: 16),
      Field.money(label: 'Purchase cost per item', controller: _cost),
      const SizedBox(height: 16),
      DateTimeField(label: 'Purchase date', value: _purchased, withTime: false, clearable: true, onChanged: (v) => setState(() => _purchased = v)),
      const SizedBox(height: 16),
      Field(label: 'Identifier prefix', controller: _prefix, onChanged: (_) => setState(() {})),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.primarySoft.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.qr_code_2_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text('Items are numbered automatically, e.g. $pre-001', style: const TextStyle(fontSize: 13, color: AppColors.inkSoft))),
        ]),
      ),
      SheetActions(label: 'Add $_n item${_n == 1 ? '' : 's'}', icon: Icons.add_rounded, busy: _saving, onPressed: _save),
    ]);
  }
}

/// Large +/- quantity stepper.
class Stepper2 extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final String? label;
  final ValueChanged<int> onChanged;
  const Stepper2({super.key, required this.value, required this.onChanged, this.min = 0, this.max = 9999, this.label});

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, int delta) {
      final enabled = (value + delta) >= min && (value + delta) <= max;
      return PressScale(
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onChanged(value + delta);
              }
            : null,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: enabled ? AppColors.primarySoft : const Color(0xFFF2F0F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: enabled ? AppColors.primary : AppColors.muted),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      if (label != null) FieldLabel(label!),
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          btn(Icons.remove_rounded, -1),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: Text('$value', key: ValueKey(value), textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ),
          ),
          btn(Icons.add_rounded, 1),
        ]),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Downtime card
// ---------------------------------------------------------------------------

class DowntimeCard extends StatelessWidget {
  final Doc d;
  final bool showProduct;
  final VoidCallback? onTap;
  const DowntimeCard({super.key, required this.d, this.showProduct = true, this.onTap});

  Future<void> _act(BuildContext context, String status) async {
    if (status == 'cancelled') {
      final ok = await confirmDialog(context,
          title: 'Cancel downtime?', message: 'The units become bookable again for this period.', confirmLabel: 'Cancel downtime', danger: true);
      if (!ok || !context.mounted) return;
    }
    HapticFeedback.mediumImpact();
    if (!context.mounted) return;
    await runAction(context, () => setDowntimeStatus(d, status), 'Downtime ${status == 'started' ? 'started' : status}');
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final s = d.s('status');
    final overdue = (s == 'scheduled' && (d.d('startsAt')?.isBefore(now) ?? false)) || (s == 'started' && (d.d('endsAt')?.isBefore(now) ?? false));
    final until = d.d('endsAt') == null ? 'Open-ended' : Fmt.dateTime(d.d('endsAt'));
    final active = s == 'scheduled' || s == 'started';
    return MTile(
      onTap: onTap,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: statusColors(d.s('reason')).$2, borderRadius: BorderRadius.circular(12)),
        child: Icon(
          switch (d.s('reason')) { 'repair' => Icons.handyman_outlined, 'missing' => Icons.help_outline_rounded, _ => Icons.build_circle_outlined },
          color: statusColors(d.s('reason')).$1,
        ),
      ),
      title: showProduct ? d.s('productName') : '${downtimeReasons[d.s('reason')] ?? 'Downtime'} · ${d.i('quantity', 1)} unit${d.i('quantity', 1) == 1 ? '' : 's'}',
      subtitle: [
        if (showProduct) '${d.i('quantity', 1)} × ${downtimeReasons[d.s('reason')] ?? 'Downtime'}',
        if (d.s('stockIdentifier').isNotEmpty) d.s('stockIdentifier'),
        if (d.s('note').isNotEmpty) d.s('note'),
      ].join(' · '),
      trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        StatusPill(s),
        if (overdue) ...[const SizedBox(height: 4), smallChip('Overdue', color: AppColors.danger, bg: AppColors.dangerSoft, icon: Icons.error_outline)],
      ]),
      footer: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.schedule_rounded, size: 14, color: AppColors.muted),
          const SizedBox(width: 6),
          Expanded(child: Text('${Fmt.dateTime(d.d('startsAt'))} → $until', style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft))),
        ]),
        if (active) ...[
          const SizedBox(height: 10),
          Row(children: [
            if (s == 'scheduled')
              Expanded(child: _ActBtn(label: 'Start', icon: Icons.play_arrow_rounded, color: AppColors.primary, onTap: () => _act(context, 'started'))),
            if (s == 'started')
              Expanded(child: _ActBtn(label: 'End', icon: Icons.stop_rounded, color: AppColors.success, onTap: () => _act(context, 'ended'))),
            const SizedBox(width: 8),
            Expanded(child: _ActBtn(label: 'Cancel', icon: Icons.close_rounded, color: AppColors.danger, onTap: () => _act(context, 'cancelled'))),
          ]),
        ],
      ]),
    );
  }
}

class _ActBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActBtn({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => PressScale(
        onTap: onTap,
        child: Container(
          height: 38,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(11)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
        ),
      );
}

/// Toggle-chip facet used in filter sheets.
class ChipFacet extends StatelessWidget {
  final String title;
  final List<String> options;
  final String Function(String)? labeler;
  final Map<String, int> counts;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  const ChipFacet({super.key, required this.title, required this.options, this.labeler, this.counts = const {}, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionLabel(title),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final o in options)
          FilterChip(
            label: Text('${labeler?.call(o) ?? Fmt.label(o)}${counts[o] == null ? '' : '  ${counts[o]}'}'),
            selected: selected.contains(o),
            showCheckmark: false,
            selectedColor: AppColors.primary,
            labelStyle: TextStyle(color: selected.contains(o) ? Colors.white : AppColors.inkSoft, fontWeight: FontWeight.w600),
            backgroundColor: Colors.white,
            side: BorderSide(color: selected.contains(o) ? AppColors.primary : AppColors.border),
            onSelected: (v) {
              HapticFeedback.selectionClick();
              final s = {...selected};
              v ? s.add(o) : s.remove(o);
              onChanged(s);
            },
          ),
      ]),
    ]);
  }
}
