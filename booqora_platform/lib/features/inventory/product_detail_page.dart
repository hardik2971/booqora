import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;
import 'package:flutter/material.dart' hide Thumb;
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/page.dart';
import '../../widgets/side_panel.dart';
import '../../widgets/table.dart';
import 'inv_common.dart';
import 'inventory_page.dart' show DowntimeTable;
import 'product_tabs.dart';

const _tabs = ['inventory', 'variations', 'pricing', 'settings', 'store', 'downtime', 'cross-sell', 'history'];
const _tabLabels = ['Inventory', 'Variations', 'Pricing', 'Settings', 'Online store', 'Downtime', 'Cross-sell', 'History'];

class ProductDetailPage extends StatelessWidget {
  final String id;
  final String? tab;
  const ProductDetailPage({super.key, required this.id, this.tab});

  @override
  Widget build(BuildContext context) {
    return LiveData(
      key: ValueKey(id),
      streams: () => {
        'product': Db.watchDoc(C.products, id).map((d) => d == null ? <Doc>[] : [d]),
        'stock': Db.watchWhere(C.stockItems, 'productId', id),
        'downtimes': Db.watchWhere(C.downtimes, 'productId', id),
        C.orders: Db.watch(C.orders),
        C.collections: Db.watch(C.collections),
        C.products: Db.watch(C.products),
        C.bundles: Db.watch(C.bundles),
      },
      builder: (context, d) {
        if (d['product']!.isEmpty) {
          return EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'Product not found',
            message: 'It may have been deleted or you no longer have access.',
            actionLabel: 'Back to inventory',
            onAction: () => context.go('/inventory'),
          );
        }
        final t = _tabs.contains(tab) ? tab! : 'inventory';
        return _ProductView(product: d['product']!.first, tab: t, data: d);
      },
    );
  }
}

class _ProductView extends StatelessWidget {
  final Doc product;
  final String tab;
  final Map<String, List<Doc>> data;
  const _ProductView({required this.product, required this.tab, required this.data});

  Doc get p => product;
  List<Doc> get orders => data[C.orders]!;
  List<Doc> get downtimes => data['downtimes']!;

  Future<void> _duplicate(BuildContext context) async {
    try {
      final copy = Map<String, dynamic>.from(p.data)
        ..remove('createdAt')
        ..remove('updatedAt')
        ..remove('createdBy');
      copy['name'] = '${p.s('name')} (copy)';
      copy['slug'] = '${p.s('slug')}-copy';
      copy['quantity'] = 0;
      final id = await Db.create(C.products, copy);
      if (context.mounted) {
        toast(context, 'Product duplicated');
        context.go('/inventory/products/$id');
      }
    } catch (e) {
      if (context.mounted) toast(context, friendlyError(e), error: true);
    }
  }

  Future<void> _toggleArchive(BuildContext context) async {
    final archived = p.s('status') == 'archived';
    try {
      await Db.update(C.products, p.id, {'status': archived ? 'active' : 'archived'}, label: p.s('name'));
      if (context.mounted) toast(context, archived ? 'Product restored' : 'Product archived');
    } catch (e) {
      if (context.mounted) toast(context, friendlyError(e), error: true);
    }
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await confirmDialog(context,
        title: 'Delete ${p.s('name')}?',
        message: 'The product and its ${data['stock']!.length} stock items will be permanently deleted. Existing orders keep their lines.',
        confirmLabel: 'Delete',
        danger: true);
    if (!ok) return;
    try {
      await deleteProduct(p);
      if (context.mounted) {
        toast(context, 'Product deleted');
        context.go('/inventory');
      }
    } catch (e) {
      if (context.mounted) toast(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final archived = p.s('status') == 'archived';
    final idx = _tabs.indexOf(tab);
    final main = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PillTabs(
        tabs: _tabLabels,
        index: idx,
        badges: [data['stock']!.length, null, null, null, null, downtimes.where((d) => {'scheduled', 'started'}.contains(d.s('status'))).length, null, null],
        onChanged: (i) => context.go('/inventory/products/${p.id}?tab=${_tabs[i]}'),
      ).enter(1),
      const SizedBox(height: 20),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: KeyedSubtree(key: ValueKey(tab), child: _tabBody(context)),
      ),
    ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: p.s('name'),
        breadcrumbs: const [('Inventory', '/inventory')],
        titleTrailing: archived ? const StatusPill('archived', label: 'Archived') : null,
        actions: [
          OutlinedButton.icon(onPressed: () => _duplicate(context), icon: const Icon(Icons.copy_all_outlined, size: 18), label: const Text('Duplicate product')),
          OutlinedButton.icon(
            onPressed: () => _toggleArchive(context),
            icon: Icon(archived ? Icons.unarchive_outlined : Icons.archive_outlined, size: 18),
            label: Text(archived ? 'Unarchive' : 'Archive'),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => _delete(context),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Delete'),
          ),
        ],
      ),
      Expanded(
        child: PageBody(maxWidth: 1400, children: [
          DetailLayout(main: main, side: _side(context)),
        ]),
      ),
    ]);
  }

  Widget _tabBody(BuildContext context) {
    switch (tab) {
      case 'variations':
        return VariationsTab(product: p);
      case 'pricing':
        return PricingTab(product: p);
      case 'settings':
        return SettingsTab(product: p);
      case 'store':
        return StoreTab(product: p);
      case 'downtime':
        return _downtimeTab(context);
      case 'cross-sell':
        return CrossSellTab(product: p, products: data[C.products]!, bundles: data[C.bundles]!);
      case 'history':
        return _historyTab(context);
      default:
        return _InventoryTab(product: p, stock: data['stock']!);
    }
  }

  List<Widget> _side(BuildContext context) {
    final cols = data[C.collections]!;
    final ids = p.l<String>('collectionIds');
    final mine = cols.where((c) => c.b('isSystem') || ids.contains(c.id)).toList();
    return [
      PanelCard(
        title: 'Summary',
        icon: Icons.insights_outlined,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Thumb(url: productThumb(p), size: 64),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.s('name'), style: const TextStyle(fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(priceLabel(p), style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  smallChip(productTypeLabels[p.s('type', 'rental')] ?? ''),
                  smallChip(Fmt.label(p.s('trackingType', 'trackable')), color: AppColors.inkSoft, bg: const Color(0xFFF0EEF5)),
                ]),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 6),
          KV('Stock', '${p.i('quantity')}'),
          KV('Available now', '${availableNow(p, orders, downtimes)}', bold: true, color: AppColors.success),
          KV('Out now', '${unitsOut(p.id, orders)}', color: AppColors.info),
        ]),
      ).enter(2),
      TagsCard(collection: C.products, id: p.id, tags: p.l<String>('tags')).enter(3),
      PanelCard(
        title: 'Collections',
        icon: Icons.collections_bookmark_outlined,
        trailing: TextButton(
          onPressed: () async {
            final sel = await pickCollectionsDialog(context, cols, ids.toSet());
            if (sel == null) return;
            try {
              await Db.update(C.products, p.id, {'collectionIds': {'all-products', ...sel}.toList()}, label: p.s('name'));
              if (context.mounted) toast(context, 'Collections updated');
            } catch (e) {
              if (context.mounted) toast(context, friendlyError(e), error: true);
            }
          },
          child: const Text('Add to collections'),
        ),
        child: mine.isEmpty
            ? const Text('Not in any collection', style: TextStyle(color: AppColors.muted, fontSize: 13))
            : Wrap(spacing: 6, runSpacing: 6, children: [
                for (final c in mine)
                  InputChip(
                    label: Text(c.s('name')),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => context.go('/inventory/collections/${c.id}'),
                    onDeleted: c.b('isSystem')
                        ? null
                        : () => Db.update(C.products, p.id, {'collectionIds': ids.where((x) => x != c.id).toList()}, label: p.s('name')),
                  ),
              ]),
      ).enter(4),
      NotesCard(entity: 'products', entityId: p.id).enter(5),
      ActivityCard(entityId: p.id).enter(6),
    ];
  }

  Widget _downtimeTab(BuildContext context) {
    final rows = [...downtimes]..sort((a, b) => (b.d('startsAt') ?? DateTime(2000)).compareTo(a.d('startsAt') ?? DateTime(2000)));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle('Downtime',
          subtitle: 'Units in downtime cannot be booked',
          trailing: FilledButton.icon(
            onPressed: () => showDowntimeDialog(context, product: p),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Schedule downtime'),
          )),
      DowntimeTable(
        rows: rows,
        showProduct: false,
        empty: AppCard(
          child: EmptyState(
            compact: true,
            icon: Icons.build_circle_outlined,
            title: 'No downtime scheduled',
            message: 'Temporarily remove items for maintenance or repair so they can\'t be booked.',
            actionLabel: 'Schedule downtime',
            onAction: () => showDowntimeDialog(context, product: p),
          ),
        ),
      ),
    ]);
  }

  Widget _historyTab(BuildContext context) {
    final rows = orders.where((o) => orderHasProduct(o, p.id)).toList()
      ..sort((a, b) => (b.d('startsAt') ?? b.created).compareTo(a.d('startsAt') ?? a.created));
    final rentedUnits = rows.where((o) => !{'draft', 'canceled'}.contains(o.s('status'))).fold<int>(0, (a, o) => a + orderQtyFor(o, p.id));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      MetricRow(children: [
        MetricCard(label: 'Orders', value: rows.length, icon: Icons.receipt_long_outlined, index: 0),
        MetricCard(label: 'Units booked', value: rentedUnits, icon: Icons.widgets_outlined, color: AppColors.info, index: 1),
      ]),
      const SizedBox(height: 20),
      const SectionTitle('Orders', subtitle: 'Every order that includes this product'),
      DataTableX<Doc>(
        rows: rows,
        idOf: (o) => o.id,
        noun: 'orders',
        minWidth: 720,
        onTap: (o) => context.go('/orders/${o.id}'),
        empty: const AppCard(
          child: EmptyState(compact: true, icon: Icons.receipt_long_outlined, title: 'No orders yet', message: 'Orders that include this product will appear here.'),
        ),
        columns: [
          ColumnX('Order', (o) => CellText('#${o.i('number')}', subtitle: o.s('customerName')), flex: 2, sort: (o) => o.i('number')),
          ColumnX('Status', (o) => StatusPill(o.s('status', 'draft')), sort: (o) => o.s('status')),
          ColumnX('Period', (o) => Text('${Fmt.dateTime(o.d('startsAt'))} → ${Fmt.dateTime(o.d('stopsAt'))}', style: const TextStyle(fontSize: 13)),
              flex: 4, sort: (o) => o.d('startsAt') ?? o.created),
          ColumnX('Qty', (o) => Text('${orderQtyFor(o, p.id)}'), numeric: true, sort: (o) => orderQtyFor(o, p.id)),
        ],
      ),
      const SizedBox(height: 24),
      const SectionTitle('Activity'),
      AppCard(
        child: StreamBuilder<List<Doc>>(
          stream: Db.watchWhere(C.activity, 'entityId', p.id),
          builder: (context, s) {
            final items = s.data ?? [];
            if (items.isEmpty) return const Text('No activity yet', style: TextStyle(color: AppColors.muted));
            return Column(children: [
              for (var i = 0; i < items.length && i < 40; i++) ActivityTile(items[i], last: i == items.length - 1 || i == 39),
            ]);
          },
        ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Inventory tab
// ---------------------------------------------------------------------------

class _InventoryTab extends StatefulWidget {
  final Doc product;
  final List<Doc> stock;
  const _InventoryTab({required this.product, required this.stock});

  @override
  State<_InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<_InventoryTab> {
  int _sub = 0;
  late final _qty = TextEditingController(text: '${widget.product.i('quantity')}');
  bool _saving = false;

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  Doc get p => widget.product;

  Future<void> _saveQty() async {
    setState(() => _saving = true);
    try {
      final q = parseNum(_qty.text).toInt();
      await Db.update(C.products, p.id, {'quantity': q < 0 ? 0 : q}, label: '${p.s('name')}: quantity $q');
      if (mounted) toast(context, 'Quantity updated');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteItem(Doc s) async {
    final ok = await confirmDialog(context,
        title: 'Delete ${s.s('identifier')}?', message: 'The stock count of this product decreases by one.', confirmLabel: 'Delete', danger: true);
    if (!ok) return;
    try {
      await Db.remove(C.stockItems, s.id, label: s.s('identifier'));
      await Db.update(C.products, p.id, {'quantity': FieldValue.increment(-1)}, label: '${p.s('name')}: removed ${s.s('identifier')}');
      if (mounted) toast(context, 'Stock item deleted');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (p.s('trackingType', 'trackable') == 'bulk') {
      return AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Stock quantity', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('This product is tracked in bulk. Adjust the total number of units you own.', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.end, children: [
            SizedBox(width: 200, child: Field.number(label: 'Quantity', controller: _qty, decimal: false)),
            FilledButton(onPressed: _saving ? null : _saveQty, child: const Text('Update quantity')),
          ]),
        ]),
      ).enter();
    }
    final now = DateTime.now();
    final current = widget.stock.where((s) => !(s.d('availableFrom')?.isAfter(now) ?? false)).toList();
    final expected = widget.stock.where((s) => s.d('availableFrom')?.isAfter(now) ?? false).toList();
    final rows = (_sub == 0 ? current : expected)..sort((a, b) => a.s('identifier').compareTo(b.s('identifier')));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
        PillTabs(tabs: const ['Current stock', 'Expected stock'], index: _sub, badges: [current.length, expected.length], onChanged: (i) => setState(() => _sub = i)),
        FilledButton.icon(onPressed: () => showAddStockDialog(context, p), icon: const Icon(Icons.add, size: 18), label: const Text('Add stock items')),
      ]),
      const SizedBox(height: 16),
      DataTableX<Doc>(
        key: ValueKey(_sub),
        rows: rows,
        idOf: (s) => s.id,
        noun: 'items',
        minWidth: 720,
        empty: AppCard(
          child: EmptyState(
            compact: true,
            icon: Icons.qr_code_2,
            title: _sub == 0 ? 'No stock yet' : 'No expected stock',
            message: _sub == 0
                ? 'Add stock items so this product can be booked. Each item gets its own identifier.'
                : 'Stock with an "Available from" date in the future appears here until it arrives.',
            actionLabel: 'Add stock items',
            onAction: () => showAddStockDialog(context, p),
          ),
        ),
        columns: [
          ColumnX('Identifier', (s) => Text(s.s('identifier'), style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'monospace')),
              flex: 2, sort: (s) => s.s('identifier')),
          ColumnX('Kind', (s) {
            final till = s.d('availableTill');
            return CellText(Fmt.label(s.s('kind', 'regular')), subtitle: till == null ? null : 'until ${Fmt.date(till)}');
          }, sort: (s) => s.s('kind')),
          ColumnX('Available from', (s) => Text(Fmt.dateTime(s.d('availableFrom')), style: const TextStyle(fontSize: 13)),
              flex: 2, sort: (s) => s.d('availableFrom') ?? DateTime(2000)),
          ColumnX('Cost', (s) => Text(Fmt.money(s.n('purchaseCost'))), numeric: true, sort: (s) => s.n('purchaseCost')),
          ColumnX('Status', (s) => StatusPill(s.s('status', 'available')), sort: (s) => s.s('status')),
          ColumnX('', (s) => IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline, size: 18), onPressed: () => _deleteItem(s)), width: 56),
        ],
      ),
    ]).enter();
  }
}
