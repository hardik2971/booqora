import 'package:flutter/material.dart' hide Thumb;
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/page.dart';
import '../../widgets/side_panel.dart';
import '../../widgets/table.dart';
import 'inv_common.dart';

const _tabs = ['products', 'bundles', 'collections', 'downtime', 'stock'];
const _tabLabels = ['Products', 'Bundles', 'Collections', 'Downtime', 'Stock items'];

class InventoryPage extends StatelessWidget {
  final String tab;
  const InventoryPage({super.key, this.tab = 'products'});

  @override
  Widget build(BuildContext context) {
    return LiveData.of(
      const [C.products, C.bundles, C.collections, C.downtimes, C.stockItems, C.orders],
      builder: (context, d) => _InventoryView(tab: _tabs.contains(tab) ? tab : 'products', data: d),
    );
  }
}

class _InventoryView extends StatefulWidget {
  final String tab;
  final Map<String, List<Doc>> data;
  const _InventoryView({required this.tab, required this.data});

  @override
  State<_InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<_InventoryView> {
  String _q = '';

  // Product filters
  Set<String> _type = {}, _tracking = {}, _status = {'active'}, _cols = {}, _tags = {}, _store = {};
  // Downtime filters
  Set<String> _attention = {}, _dtStatus = {'scheduled', 'started'}, _reason = {};
  DateTimeRange? _range;
  // Stock filters
  Set<String> _kind = {}, _stockStatus = {};

  List<Doc> get products => widget.data[C.products]!;
  List<Doc> get bundles => widget.data[C.bundles]!;
  List<Doc> get collections => widget.data[C.collections]!;
  List<Doc> get downtimes => widget.data[C.downtimes]!;
  List<Doc> get stock => widget.data[C.stockItems]!;
  List<Doc> get orders => widget.data[C.orders]!;

  @override
  void didUpdateWidget(covariant _InventoryView old) {
    super.didUpdateWidget(old);
    if (old.tab != widget.tab) _q = '';
  }

  bool _match(String s) => _q.isEmpty || s.toLowerCase().contains(_q);

  // ---------------------------------------------------------------- filtering
  List<Doc> get _filteredProducts => products.where((p) {
        if (!_match('${p.s('name')} ${p.s('sku')}')) return false;
        if (_type.isNotEmpty && !_type.contains(p.s('type', 'rental'))) return false;
        if (_tracking.isNotEmpty && !_tracking.contains(p.s('trackingType', 'trackable'))) return false;
        if (_status.isNotEmpty && !_status.contains(p.s('status', 'active'))) return false;
        if (_cols.isNotEmpty && !_cols.any((c) => c == 'all-products' || p.l<String>('collectionIds').contains(c))) return false;
        if (_tags.isNotEmpty && !_tags.any((t) => p.l<String>('tags').contains(t))) return false;
        if (_store.isNotEmpty && !_store.contains(p.b('showInStore', true) ? 'yes' : 'no')) return false;
        return true;
      }).toList();

  bool _sameDay(DateTime? a, DateTime b) => a != null && a.year == b.year && a.month == b.month && a.day == b.day;

  bool _attentionMatch(Doc d, String key) {
    final now = DateTime.now();
    final s = d.d('startsAt'), e = d.d('endsAt');
    final st = d.s('status');
    switch (key) {
      case 'starting_today':
        return st == 'scheduled' && _sameDay(s, now);
      case 'ending_today':
        return (st == 'scheduled' || st == 'started') && _sameDay(e, now);
      case 'overdue_start':
        return st == 'scheduled' && s != null && s.isBefore(now);
      case 'overdue_end':
        return st == 'started' && e != null && e.isBefore(now);
    }
    return false;
  }

  List<Doc> get _filteredDowntimes => downtimes.where((d) {
        if (!_match('${d.s('productName')} ${d.s('stockIdentifier')}')) return false;
        if (_dtStatus.isNotEmpty && !_dtStatus.contains(d.s('status'))) return false;
        if (_reason.isNotEmpty && !_reason.contains(d.s('reason'))) return false;
        if (_attention.isNotEmpty && !_attention.any((a) => _attentionMatch(d, a))) return false;
        if (_range != null) {
          final s = d.d('startsAt') ?? DateTime(2000), e = d.d('endsAt') ?? DateTime(2100);
          if (!(s.isBefore(_range!.end) && _range!.start.isBefore(e))) return false;
        }
        return true;
      }).toList();

  List<Doc> get _filteredStock => stock.where((s) {
        if (!_match('${s.s('identifier')} ${s.s('productName')}')) return false;
        if (_kind.isNotEmpty && !_kind.contains(s.s('kind', 'regular'))) return false;
        if (_stockStatus.isNotEmpty && !_stockStatus.contains(s.s('status', 'available'))) return false;
        return true;
      }).toList();

  Map<String, int> _count(Iterable<Doc> docs, String Function(Doc) key) {
    final m = <String, int>{};
    for (final d in docs) {
      final k = key(d);
      m[k] = (m[k] ?? 0) + 1;
    }
    return m;
  }

  // ---------------------------------------------------------------- actions
  void _goTab(String t) => context.go('/inventory?tab=$t');

  Future<void> _bulkUpdate(String c, List<Doc> rows, Map<String, dynamic> data, String msg) async {
    try {
      for (final r in rows) {
        await Db.update(c, r.id, data, label: r.s('name'));
      }
      if (mounted) toast(context, msg);
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  Future<void> _export() async {
    switch (widget.tab) {
      case 'products':
        await exportCsv('products', ['Name', 'SKU', 'Type', 'Tracking', 'Price', 'Per', 'Stock', 'Available now', 'Status', 'In store', 'Tags'], [
          for (final p in _filteredProducts)
            [
              p.s('name'),
              p.s('sku'),
              p.s('type'),
              p.s('trackingType'),
              p.n('price'),
              p.s('pricePer'),
              p.i('quantity'),
              availableNow(p, orders, downtimes),
              p.s('status'),
              p.b('showInStore', true) ? 'yes' : 'no',
              p.l<String>('tags').join('; '),
            ]
        ]);
      case 'bundles':
        await exportCsv('bundles', ['Name', 'Items', 'Price', 'In store'], [
          for (final b in bundles) [b.s('name'), b.maps('items').length, _bundlePrice(b), b.b('showInStore') ? 'yes' : 'no']
        ]);
      case 'collections':
        await exportCsv('collections', ['Name', 'Products', 'In store'], [
          for (final c in collections) [c.s('name'), _colCount(c), c.b('showInStore') ? 'yes' : 'no']
        ]);
      case 'downtime':
        await exportCsv('downtime', ['Product', 'Quantity', 'Reason', 'Status', 'From', 'Until', 'Note'], [
          for (final d in _filteredDowntimes)
            [d.s('productName'), d.i('quantity', 1), d.s('reason'), d.s('status'), Fmt.dateTime(d.d('startsAt')), Fmt.dateTime(d.d('endsAt')), d.s('note')]
        ]);
      default:
        await exportCsv('stock-items', ['Identifier', 'Product', 'Kind', 'Available from', 'Purchase cost', 'Status'], [
          for (final s in _filteredStock)
            [s.s('identifier'), s.s('productName'), s.s('kind'), Fmt.dateTime(s.d('availableFrom')), s.n('purchaseCost'), s.s('status')]
        ]);
    }
  }

  num _bundlePrice(Doc b) {
    if (b.data['price'] is num) return b.n('price');
    final byId = {for (final p in products) p.id: p};
    num sum = 0;
    for (final it in b.maps('items')) {
      final p = byId[it['productId']];
      if (p == null) continue;
      sum += p.n('price') * ((it['qty'] as num?) ?? 1) * (1 - ((it['discount'] as num?) ?? 0) / 100);
    }
    return sum;
  }

  int _colCount(Doc c) =>
      c.id == 'all-products' ? products.length : products.where((p) => p.l<String>('collectionIds').contains(c.id)).length;

  // ---------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    final idx = _tabs.indexOf(widget.tab);
    final narrow = MediaQuery.sizeOf(context).width < 700;
    final header = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Inventory',
        subtitle: 'Products, bundles, collections and stock in one place',
        actions: [
          SearchField(
            key: ValueKey('search-${widget.tab}'),
            width: narrow ? 220 : 260,
            hint: widget.tab == 'stock' ? 'Search identifier…' : 'Search…',
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
          ),
          OutlinedButton.icon(onPressed: _export, icon: const Icon(Icons.file_download_outlined, size: 18), label: const Text('Export')),
          _SplitAdd(
            onProduct: () => context.go('/inventory/products/new'),
            onBundle: () => context.go('/inventory/bundles/new'),
            onCollection: () => context.go('/inventory/collections/new'),
            onDowntime: () => showDowntimeDialog(context, products: products),
          ),
        ],
      ),
      Padding(
        padding: EdgeInsets.fromLTRB(narrow ? 16 : 28, 0, narrow ? 16 : 28, 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: PillTabs(
            tabs: _tabLabels,
            index: idx,
            badges: [products.length, bundles.length, collections.length, downtimes.where((d) => {'scheduled', 'started'}.contains(d.s('status'))).length, stock.length],
            onChanged: (i) => _goTab(_tabs[i]),
          ),
        ),
      ).enter(1),
    ]);

    return ListLayout(
      key: ValueKey(widget.tab),
      header: header,
      filters: _filters(),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(narrow ? 16 : 24, 4, narrow ? 16 : 28, 40),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: KeyedSubtree(key: ValueKey(widget.tab), child: _body()),
        ),
      ),
    );
  }

  List<Widget> _filters() {
    switch (widget.tab) {
      case 'products':
        final tags = {for (final p in products) ...p.l<String>('tags')}.toList()..sort();
        return [
          FilterSection(
            title: 'Product type',
            child: CheckFacet(
              options: const ['rental', 'sale', 'service'],
              labeler: (v) => productTypeLabels[v] ?? v,
              counts: _count(products, (p) => p.s('type', 'rental')),
              selected: _type,
              onChanged: (s) => setState(() => _type = s),
            ),
          ),
          FilterSection(
            title: 'Tracking',
            child: CheckFacet(
              options: const ['trackable', 'bulk'],
              counts: _count(products, (p) => p.s('trackingType', 'trackable')),
              selected: _tracking,
              onChanged: (s) => setState(() => _tracking = s),
            ),
          ),
          FilterSection(
            title: 'Status',
            child: CheckFacet(
              options: const ['active', 'archived'],
              counts: _count(products, (p) => p.s('status', 'active')),
              selected: _status,
              onChanged: (s) => setState(() => _status = s),
            ),
          ),
          if (collections.isNotEmpty)
            FilterSection(
              title: 'Collections',
              child: CheckFacet(
                options: [for (final c in collections) c.id],
                labeler: (id) => collections.firstWhere((c) => c.id == id).s('name'),
                counts: {for (final c in collections) c.id: _colCount(c)},
                selected: _cols,
                onChanged: (s) => setState(() => _cols = s),
              ),
            ),
          if (tags.isNotEmpty)
            FilterSection(
              title: 'Tags',
              child: CheckFacet(
                options: tags,
                labeler: (t) => t,
                counts: {for (final t in tags) t: products.where((p) => p.l<String>('tags').contains(t)).length},
                selected: _tags,
                onChanged: (s) => setState(() => _tags = s),
              ),
            ),
          FilterSection(
            title: 'Show in store',
            child: CheckFacet(
              options: const ['yes', 'no'],
              counts: _count(products, (p) => p.b('showInStore', true) ? 'yes' : 'no'),
              selected: _store,
              onChanged: (s) => setState(() => _store = s),
            ),
          ),
        ];
      case 'downtime':
        return [
          FilterSection(
            title: 'Attention',
            child: CheckFacet(
              options: const ['starting_today', 'ending_today', 'overdue_start', 'overdue_end'],
              counts: {
                for (final k in ['starting_today', 'ending_today', 'overdue_start', 'overdue_end'])
                  k: downtimes.where((d) => _attentionMatch(d, k)).length
              },
              selected: _attention,
              onChanged: (s) => setState(() => _attention = s),
            ),
          ),
          FilterSection(
            title: 'Status',
            child: CheckFacet(
              options: const ['scheduled', 'started', 'ended', 'cancelled'],
              counts: _count(downtimes, (d) => d.s('status')),
              selected: _dtStatus,
              onChanged: (s) => setState(() => _dtStatus = s),
            ),
          ),
          FilterSection(
            title: 'Reason',
            child: CheckFacet(
              options: const ['maintenance', 'repair', 'missing'],
              counts: _count(downtimes, (d) => d.s('reason')),
              selected: _reason,
              onChanged: (s) => setState(() => _reason = s),
            ),
          ),
          FilterSection(title: 'Date range', child: DateRangeFacet(value: _range, onChanged: (r) => setState(() => _range = r))),
        ];
      case 'stock':
        return [
          FilterSection(
            title: 'Kind',
            child: CheckFacet(
              options: const ['regular', 'temporary'],
              counts: _count(stock, (s) => s.s('kind', 'regular')),
              selected: _kind,
              onChanged: (s) => setState(() => _kind = s),
            ),
          ),
          FilterSection(
            title: 'Status',
            child: CheckFacet(
              options: const ['available', 'out', 'downtime'],
              counts: _count(stock, (s) => s.s('status', 'available')),
              selected: _stockStatus,
              onChanged: (s) => setState(() => _stockStatus = s),
            ),
          ),
        ];
    }
    return const [];
  }

  Widget _body() {
    switch (widget.tab) {
      case 'bundles':
        return _bundlesTab();
      case 'collections':
        return _collectionsTab();
      case 'downtime':
        return _downtimeTab();
      case 'stock':
        return _stockTab();
      default:
        return _productsTab();
    }
  }

  // ---------------------------------------------------------------- products
  Widget _productsTab() {
    final rows = _filteredProducts;
    final active = products.where((p) => p.s('status', 'active') == 'active');
    final units = active.fold<int>(0, (a, p) => a + p.i('quantity'));
    final value = active.fold<num>(0, (a, p) => a + p.i('quantity') * p.n('purchaseCost'));
    final out = active.fold<int>(0, (a, p) => a + unitsOut(p.id, orders));
    final avail = {for (final p in rows) p.id: availableNow(p, orders, downtimes)};
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      MetricRow(children: [
        MetricCard(label: 'Products', value: active.length, icon: Icons.inventory_2_outlined, index: 0),
        MetricCard(label: 'Total stock units', value: units, icon: Icons.widgets_outlined, color: AppColors.info, index: 1),
        MetricCard(
            label: 'Stock value',
            value: value,
            format: Fmt.money,
            icon: Icons.account_balance_wallet_outlined,
            color: AppColors.success,
            hint: 'Quantity × default purchase cost',
            index: 2),
        MetricCard(label: 'Currently out', value: out, icon: Icons.local_shipping_outlined, color: AppColors.warning, hint: 'Units on started orders', index: 3),
      ]),
      const SizedBox(height: 20),
      DataTableX<Doc>(
        rows: rows,
        idOf: (p) => p.id,
        noun: 'products',
        minWidth: 1060,
        onTap: (p) => context.go('/inventory/products/${p.id}'),
        empty: EmptyState(
          icon: Icons.inventory_2_outlined,
          title: products.isEmpty ? 'Add your first product' : 'No products match',
          message: products.isEmpty
              ? 'Products to rent, services and sale items. Add stock after creating a product.'
              : 'Adjust the search or filters to see more products.',
          actionLabel: products.isEmpty ? 'Add product' : null,
          onAction: products.isEmpty ? () => context.go('/inventory/products/new') : null,
        ),
        columns: [
          ColumnX('Name', (p) => CellText(p.s('name'), subtitle: p.s('sku'), leading: Thumb(url: productThumb(p), size: 36)),
              flex: 3, sort: (p) => p.s('name').toLowerCase()),
          ColumnX('Type', (p) => Text(productTypeLabels[p.s('type', 'rental')] ?? ''), sort: (p) => p.s('type')),
          ColumnX('Price', (p) => Text(priceLabel(p)), flex: 2, sort: (p) => p.n('price')),
          ColumnX('Stock', (p) => Text('${p.i('quantity')}'), numeric: true, width: 80, sort: (p) => p.i('quantity')),
          ColumnX('Available now', (p) {
            final a = avail[p.id] ?? 0;
            return Text('$a',
                style: TextStyle(fontWeight: FontWeight.w600, color: a <= 0 ? AppColors.danger : (a < p.i('quantity') ? AppColors.warning : AppColors.success)));
          }, numeric: true, width: 130, sort: (p) => avail[p.id] ?? 0),
          ColumnX('Online store', (p) => Padding(padding: const EdgeInsets.only(left: 20), child: storePill(p.b('showInStore', true))), width: 150, sort: (p) => p.b('showInStore', true) ? 1 : 0),
          ColumnX('Tags', (p) {
            final t = p.l<String>('tags');
            return Wrap(spacing: 4, runSpacing: 4, children: [
              for (final x in t.take(2)) smallChip(x),
              if (t.length > 2) smallChip('+${t.length - 2}', color: AppColors.muted, bg: const Color(0xFFF0EEF5)),
            ]);
          }, flex: 2),
        ],
        bulkActions: [
          BulkAction('Archive', Icons.archive_outlined, (r) => _bulkUpdate(C.products, r, {'status': 'archived'}, '${r.length} archived')),
          BulkAction('Show in store', Icons.visibility_outlined,
              (r) => _bulkUpdate(C.products, r, {'showInStore': true}, '${r.length} shown in store')),
          BulkAction('Hide from store', Icons.visibility_off_outlined,
              (r) => _bulkUpdate(C.products, r, {'showInStore': false}, '${r.length} hidden from store')),
          BulkAction('Delete', Icons.delete_outline, (r) async {
            final ok = await confirmDialog(context,
                title: 'Delete ${r.length} product${r.length == 1 ? '' : 's'}?',
                message: 'Their stock items will be deleted too. Existing orders keep their lines.',
                confirmLabel: 'Delete',
                danger: true);
            if (!ok) return;
            try {
              for (final p in r) {
                await deleteProduct(p);
              }
              if (mounted) toast(context, '${r.length} deleted');
            } catch (e) {
              if (mounted) toast(context, friendlyError(e), error: true);
            }
          }, danger: true),
        ],
      ).enter(2),
    ]);
  }

  // ---------------------------------------------------------------- bundles
  Widget _bundlesTab() {
    final rows = bundles.where((b) => _match(b.s('name'))).toList();
    return DataTableX<Doc>(
      rows: rows,
      idOf: (b) => b.id,
      noun: 'bundles',
      minWidth: 640,
      onTap: (b) => context.go('/inventory/bundles/${b.id}'),
      empty: EmptyState(
        icon: Icons.workspaces_outline,
        title: bundles.isEmpty ? 'Create your first bundle' : 'No bundles match',
        message: 'Bundles are products often rented together — offer them at a discount.',
        actionLabel: 'Add bundle',
        onAction: () => context.go('/inventory/bundles/new'),
      ),
      columns: [
        ColumnX('Name', (b) => CellText(b.s('name'), leading: Thumb(url: b.s('imageUrl'), size: 36, icon: Icons.workspaces_outline)),
            flex: 3, sort: (b) => b.s('name').toLowerCase()),
        ColumnX('Items', (b) => Text('${b.maps('items').fold<num>(0, (a, i) => a + ((i['qty'] as num?) ?? 1))}'),
            numeric: true, sort: (b) => b.maps('items').length),
        ColumnX('Price', (b) => Text(Fmt.money(_bundlePrice(b))), numeric: true, flex: 2, sort: _bundlePrice),
        ColumnX('Store visibility', (b) => storePill(b.b('showInStore')), flex: 2),
      ],
      bulkActions: [
        BulkAction('Show in store', Icons.visibility_outlined, (r) => _bulkUpdate(C.bundles, r, {'showInStore': true}, 'Bundles updated')),
        BulkAction('Hide from store', Icons.visibility_off_outlined, (r) => _bulkUpdate(C.bundles, r, {'showInStore': false}, 'Bundles updated')),
        BulkAction('Delete', Icons.delete_outline, (r) async {
          final ok = await confirmDialog(context, title: 'Delete ${r.length} bundle${r.length == 1 ? '' : 's'}?', message: 'This cannot be undone.', confirmLabel: 'Delete', danger: true);
          if (!ok) return;
          try {
            for (final b in r) {
              await Db.remove(C.bundles, b.id, label: b.s('name'));
            }
            if (mounted) toast(context, 'Bundles deleted');
          } catch (e) {
            if (mounted) toast(context, friendlyError(e), error: true);
          }
        }, danger: true),
      ],
    ).enter(1);
  }

  // ---------------------------------------------------------------- collections
  Widget _collectionsTab() {
    final rows = collections.where((c) => _match(c.s('name'))).toList()
      ..sort((a, b) => (b.b('isSystem') ? 1 : 0).compareTo(a.b('isSystem') ? 1 : 0));
    return DataTableX<Doc>(
      rows: rows,
      idOf: (c) => c.id,
      noun: 'collections',
      minWidth: 600,
      onTap: (c) => context.go('/inventory/collections/${c.id}'),
      empty: EmptyState(
        icon: Icons.collections_bookmark_outlined,
        title: 'Organise products into collections',
        message: 'Collections group related products in your online store, e.g. "Cameras" or "Party tents".',
        actionLabel: 'Add collection',
        onAction: () => context.go('/inventory/collections/new'),
      ),
      columns: [
        ColumnX(
            'Name',
            (c) => Row(children: [
                  Thumb(url: c.s('imageUrl'), size: 36, icon: Icons.collections_bookmark_outlined),
                  const SizedBox(width: 10),
                  Flexible(child: Text(c.s('name'), overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                  if (c.b('isSystem')) ...[const SizedBox(width: 8), smallChip('System', color: AppColors.inkSoft, bg: const Color(0xFFF0EEF5))],
                ]),
            flex: 3,
            sort: (c) => c.s('name').toLowerCase()),
        ColumnX('Products', (c) => Text('${_colCount(c)}'), numeric: true, sort: _colCount),
        ColumnX('Online store', (c) => storePill(c.b('showInStore')), flex: 2),
      ],
      bulkActions: [
        BulkAction('Show in store', Icons.visibility_outlined, (r) => _bulkUpdate(C.collections, r, {'showInStore': true}, 'Collections updated')),
        BulkAction('Hide from store', Icons.visibility_off_outlined, (r) => _bulkUpdate(C.collections, r, {'showInStore': false}, 'Collections updated')),
        BulkAction('Delete', Icons.delete_outline, (r) async {
          final del = r.where((c) => !c.b('isSystem')).toList();
          if (del.isEmpty) return toast(context, 'System collections cannot be deleted', error: true);
          final ok = await confirmDialog(context,
              title: 'Delete ${del.length} collection${del.length == 1 ? '' : 's'}?',
              message: 'Products stay in your inventory. System collections are skipped.',
              confirmLabel: 'Delete',
              danger: true);
          if (!ok) return;
          try {
            for (final c in del) {
              await Db.remove(C.collections, c.id, label: c.s('name'));
            }
            if (mounted) toast(context, 'Collections deleted');
          } catch (e) {
            if (mounted) toast(context, friendlyError(e), error: true);
          }
        }, danger: true),
      ],
    ).enter(1);
  }

  // ---------------------------------------------------------------- downtime
  Widget _downtimeTab() {
    final rows = _filteredDowntimes..sort((a, b) => (a.d('startsAt') ?? DateTime(2000)).compareTo(b.d('startsAt') ?? DateTime(2000)));
    return DowntimeTable(
      rows: rows,
      empty: EmptyState(
        icon: Icons.build_circle_outlined,
        title: downtimes.isEmpty ? 'Schedule downtime' : 'No downtime matches',
        message: 'All scheduled downtimes in one place — temporarily remove items for maintenance or repair so they can\'t be booked.',
        actionLabel: 'Schedule downtime',
        onAction: () => showDowntimeDialog(context, products: products),
      ),
    ).enter(1);
  }

  // ---------------------------------------------------------------- stock
  Widget _stockTab() {
    final rows = _filteredStock;
    return DataTableX<Doc>(
      rows: rows,
      idOf: (s) => s.id,
      noun: 'stock items',
      minWidth: 820,
      onTap: (s) => context.go('/inventory/products/${s.s('productId')}?tab=inventory'),
      empty: const EmptyState(
        icon: Icons.qr_code_2,
        title: 'No stock items',
        message: 'Stock items are the individual units of a product. Add them from a product\'s Inventory tab.',
      ),
      columns: [
        ColumnX('Identifier', (s) => Text(s.s('identifier'), style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'monospace')),
            flex: 2, sort: (s) => s.s('identifier')),
        ColumnX('Product', (s) => Text(s.s('productName'), overflow: TextOverflow.ellipsis), flex: 2, sort: (s) => s.s('productName')),
        ColumnX('Kind', (s) => Text(Fmt.label(s.s('kind', 'regular'))), sort: (s) => s.s('kind')),
        ColumnX('Available from', (s) => Text(Fmt.date(s.d('availableFrom'))), flex: 2, sort: (s) => s.d('availableFrom') ?? DateTime(2000)),
        ColumnX('Purchase cost', (s) => Text(Fmt.money(s.n('purchaseCost'))), numeric: true, flex: 2, sort: (s) => s.n('purchaseCost')),
        ColumnX('Status', (s) => StatusPill(s.s('status', 'available')), sort: (s) => s.s('status')),
      ],
    ).enter(1);
  }
}

/// Downtime table with inline Start / End / Cancel actions (shared with product detail).
class DowntimeTable extends StatelessWidget {
  final List<Doc> rows;
  final Widget empty;
  final bool showProduct;
  const DowntimeTable({super.key, required this.rows, required this.empty, this.showProduct = true});

  Future<void> _act(BuildContext context, Doc d, String status) async {
    try {
      await setDowntimeStatus(d, status);
      if (context.mounted) toast(context, 'Downtime ${status == 'started' ? 'started' : status}');
    } catch (e) {
      if (context.mounted) toast(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return DataTableX<Doc>(
      rows: rows,
      idOf: (d) => d.id,
      noun: 'downtimes',
      minWidth: 860,
      onTap: showProduct ? (d) => context.go('/inventory/products/${d.s('productId')}?tab=downtime') : null,
      empty: empty,
      columns: [
        if (showProduct)
          ColumnX('Product', (d) => CellText(d.s('productName'), subtitle: d.s('stockIdentifier')), flex: 3, sort: (d) => d.s('productName')),
        ColumnX('Qty', (d) => Text('${d.i('quantity', 1)}'), numeric: true, sort: (d) => d.i('quantity', 1)),
        ColumnX('Reason', (d) => StatusPill(d.s('reason'), dot: false), flex: 2, sort: (d) => d.s('reason')),
        ColumnX('Status', (d) {
          final s = d.s('status');
          final overdue = (s == 'scheduled' && (d.d('startsAt')?.isBefore(now) ?? false)) || (s == 'started' && (d.d('endsAt')?.isBefore(now) ?? false));
          return Row(mainAxisSize: MainAxisSize.min, children: [
            StatusPill(s),
            if (overdue) ...[const SizedBox(width: 4), const Tooltip(message: 'Overdue', child: Icon(Icons.error_outline, size: 16, color: AppColors.danger))],
          ]);
        }, flex: 2, sort: (d) => d.s('status')),
        ColumnX('From → Until', (d) => Text('${Fmt.dateTime(d.d('startsAt'))} → ${d.d('endsAt') == null ? 'Open-ended' : Fmt.dateTime(d.d('endsAt'))}', style: const TextStyle(fontSize: 13)),
            flex: 4, sort: (d) => d.d('startsAt') ?? DateTime(2000)),
        ColumnX('', (d) {
          final s = d.s('status');
          final btn = TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), visualDensity: VisualDensity.compact);
          return Wrap(spacing: 2, children: [
            if (s == 'scheduled') TextButton(style: btn, onPressed: () => _act(context, d, 'started'), child: const Text('Start')),
            if (s == 'started') TextButton(style: btn, onPressed: () => _act(context, d, 'ended'), child: const Text('End')),
            if (s == 'scheduled' || s == 'started')
              TextButton(
                  style: btn.copyWith(foregroundColor: const WidgetStatePropertyAll(AppColors.danger)),
                  onPressed: () => _act(context, d, 'cancelled'),
                  child: const Text('Cancel')),
          ]);
        }, flex: 3),
      ],
    );
  }
}

class _SplitAdd extends StatelessWidget {
  final VoidCallback onProduct, onBundle, onCollection, onDowntime;
  const _SplitAdd({required this.onProduct, required this.onBundle, required this.onCollection, required this.onDowntime});

  @override
  Widget build(BuildContext context) {
    const r = Radius.circular(10);
    return SizedBox(
        height: 46,
        child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      FilledButton.icon(
        style: FilledButton.styleFrom(shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(left: r))),
        onPressed: onProduct,
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Add product'),
      ),
      Container(width: 1, color: Colors.white24),
      MenuAnchor(
        alignmentOffset: const Offset(-160, 4),
        menuChildren: [
          MenuItemButton(leadingIcon: const Icon(Icons.inventory_2_outlined, size: 18), onPressed: onProduct, child: const Text('Add product')),
          MenuItemButton(leadingIcon: const Icon(Icons.workspaces_outline, size: 18), onPressed: onBundle, child: const Text('Add bundle')),
          MenuItemButton(leadingIcon: const Icon(Icons.collections_bookmark_outlined, size: 18), onPressed: onCollection, child: const Text('Add collection')),
          MenuItemButton(leadingIcon: const Icon(Icons.build_circle_outlined, size: 18), onPressed: onDowntime, child: const Text('Schedule downtime')),
        ],
        builder: (context, c, _) => FilledButton(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
            minimumSize: const Size(40, 48),
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: r)),
          ),
          onPressed: () => c.isOpen ? c.close() : c.open(),
          child: const Icon(Icons.keyboard_arrow_down, size: 20),
        ),
      ),
    ]));
  }
}
