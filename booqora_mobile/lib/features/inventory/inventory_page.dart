import 'package:animations/animations.dart';
import 'package:flutter/material.dart' hide Thumb;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/mobile.dart';
import 'bundle_form_page.dart';
import 'collection_form_page.dart';
import 'inv_common.dart';
import 'product_detail_page.dart';

const _tabs = ['products', 'bundles', 'collections', 'downtime', 'stock'];
const _tabLabels = {'products': 'Products', 'bundles': 'Bundles', 'collections': 'Collections', 'downtime': 'Downtime', 'stock': 'Stock items'};

class InventoryPage extends StatefulWidget {
  final String tab;
  const InventoryPage({super.key, this.tab = 'products'});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  late String _tab = _tabs.contains(widget.tab) ? widget.tab : 'products';
  String _q = '';
  int _searchKey = 0;

  // Product filters
  Set<String> _type = {}, _tracking = {}, _status = {'active'}, _cols = {}, _tags = {}, _store = {};
  // Downtime filters
  Set<String> _attention = {}, _dtStatus = {'scheduled', 'started'}, _reason = {};
  // Stock filters
  Set<String> _kind = {}, _stockStatus = {};

  @override
  void didUpdateWidget(covariant InventoryPage old) {
    super.didUpdateWidget(old);
    if (old.tab != widget.tab && _tabs.contains(widget.tab)) _setTab(widget.tab);
  }

  void _setTab(String t) => setState(() {
        _tab = t;
        _q = '';
        _searchKey++;
      });

  @override
  Widget build(BuildContext context) {
    return LiveData.of(
      const [C.products, C.bundles, C.collections, C.downtimes, C.stockItems, C.orders],
      loading: MPage(title: 'Inventory', slivers: const [SliverToBoxAdapter(child: LoadingView())]),
      builder: (context, d) => _build(context, d),
    );
  }

  bool _match(String s) => _q.isEmpty || s.toLowerCase().contains(_q);

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

  Map<String, int> _count(Iterable<Doc> docs, String Function(Doc) key) {
    final m = <String, int>{};
    for (final d in docs) {
      final k = key(d);
      m[k] = (m[k] ?? 0) + 1;
    }
    return m;
  }

  int _filterCount() => switch (_tab) {
        'products' => [_type, _tracking, _cols, _tags, _store].where((s) => s.isNotEmpty).length + (_status.length == 1 && _status.first == 'active' ? 0 : (_status.isEmpty ? 0 : 1)),
        'downtime' => [_attention, _reason].where((s) => s.isNotEmpty).length + (_dtStatus.length == 2 && _dtStatus.containsAll({'scheduled', 'started'}) ? 0 : (_dtStatus.isEmpty ? 0 : 1)),
        'stock' => [_kind, _stockStatus].where((s) => s.isNotEmpty).length,
        _ => 0,
      };

  Widget _build(BuildContext context, Map<String, List<Doc>> d) {
    final products = d[C.products]!, bundles = d[C.bundles]!, collections = d[C.collections]!;
    final downtimes = d[C.downtimes]!, stock = d[C.stockItems]!, orders = d[C.orders]!;
    final hasFilters = {'products', 'downtime', 'stock'}.contains(_tab);
    final counts = {
      'products': products.length,
      'bundles': bundles.length,
      'collections': collections.length,
      'downtime': downtimes.where((x) => {'scheduled', 'started'}.contains(x.s('status'))).length,
      'stock': stock.length,
    };

    final List<Widget> body = switch (_tab) {
      'bundles' => _bundles(context, bundles, products),
      'collections' => _collections(context, collections, products),
      'downtime' => _downtime(context, downtimes, products),
      'stock' => _stock(context, stock),
      _ => _products(context, products, collections, orders, downtimes),
    };

    return MPage(
      title: 'Inventory',
      headerHeight: 118,
      actions: [
        IconButton(
          tooltip: 'Scan barcode',
          icon: const Icon(Icons.qr_code_scanner_rounded),
          onPressed: () {
            HapticFeedback.selectionClick();
            context.push('/scan');
          },
        ),
        IconButton(
          tooltip: 'Add',
          icon: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
          ),
          onPressed: () => _addMenu(context, products),
        ),
      ],
      header: Column(mainAxisSize: MainAxisSize.min, children: [
        MSearch(
          key: ValueKey('search-$_searchKey'),
          hint: switch (_tab) {
            'stock' => 'Search identifier or product',
            'bundles' => 'Search bundles',
            'collections' => 'Search collections',
            'downtime' => 'Search downtime',
            _ => 'Search name or SKU',
          },
          onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
          trailing: hasFilters
              ? SquareIconButton(
                  icon: Icons.tune_rounded,
                  tooltip: 'Filters',
                  badge: _filterCount(),
                  onTap: () => _filters(context, products, collections, downtimes, stock),
                )
              : null,
        ),
        const SizedBox(height: 10),
        ChoiceChipsBar<String>(
          options: [for (final t in _tabs) (t, _tabLabels[t]!)],
          value: _tab,
          counts: counts,
          onChanged: _setTab,
        ),
      ]),
      slivers: [const SliverToBoxAdapter(child: SizedBox(height: 4)), ...body],
    );
  }

  // ------------------------------------------------------------------ add menu
  void _addMenu(BuildContext context, List<Doc> products) {
    HapticFeedback.lightImpact();
    showAppSheet<void>(context, title: 'Create', builder: (c) {
      void go(VoidCallback f) {
        Navigator.pop(c);
        f();
      }

      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        NavRow(icon: Icons.inventory_2_outlined, title: 'Product', subtitle: 'Rental, sales item or service', onTap: () => go(() => context.push('/inventory/products/new'))),
        NavRow(icon: Icons.workspaces_outline, title: 'Bundle', subtitle: 'Products rented together', color: AppColors.info, onTap: () => go(() => context.push('/inventory/bundles/new'))),
        NavRow(
            icon: Icons.collections_bookmark_outlined,
            title: 'Collection',
            subtitle: 'Group products in your store',
            color: AppColors.success,
            onTap: () => go(() => context.push('/inventory/collections/new'))),
        NavRow(
            icon: Icons.build_circle_outlined,
            title: 'Schedule downtime',
            subtitle: 'Maintenance, repair or missing items',
            color: AppColors.warning,
            onTap: () => go(() => showDowntimeSheet(context, products: products))),
      ].map((w) => w.enterX(0)).toList());
    });
  }

  // ------------------------------------------------------------------ filters
  void _filters(BuildContext context, List<Doc> products, List<Doc> collections, List<Doc> downtimes, List<Doc> stock) {
    showAppSheet<void>(context, title: 'Filters', builder: (c) {
      return StatefulBuilder(builder: (c, setS) {
        void upd(VoidCallback f) {
          setState(f);
          setS(() {});
        }

        final List<Widget> facets;
        switch (_tab) {
          case 'downtime':
            const att = ['starting_today', 'ending_today', 'overdue_start', 'overdue_end'];
            facets = [
              ChipFacet(
                title: 'Attention',
                options: att,
                counts: {for (final k in att) k: downtimes.where((d) => _attentionMatch(d, k)).length},
                selected: _attention,
                onChanged: (s) => upd(() => _attention = s),
              ),
              ChipFacet(
                title: 'Status',
                options: const ['scheduled', 'started', 'ended', 'cancelled'],
                counts: _count(downtimes, (d) => d.s('status')),
                selected: _dtStatus,
                onChanged: (s) => upd(() => _dtStatus = s),
              ),
              ChipFacet(
                title: 'Reason',
                options: const ['maintenance', 'repair', 'missing'],
                counts: _count(downtimes, (d) => d.s('reason')),
                selected: _reason,
                onChanged: (s) => upd(() => _reason = s),
              ),
            ];
          case 'stock':
            facets = [
              ChipFacet(
                title: 'Kind',
                options: const ['regular', 'temporary'],
                counts: _count(stock, (s) => s.s('kind', 'regular')),
                selected: _kind,
                onChanged: (s) => upd(() => _kind = s),
              ),
              ChipFacet(
                title: 'Status',
                options: const ['available', 'out', 'downtime'],
                counts: _count(stock, (s) => s.s('status', 'available')),
                selected: _stockStatus,
                onChanged: (s) => upd(() => _stockStatus = s),
              ),
            ];
          default:
            final tags = {for (final p in products) ...p.l<String>('tags')}.toList()..sort();
            facets = [
              ChipFacet(
                title: 'Product type',
                options: const ['rental', 'sale', 'service'],
                labeler: (v) => productTypeLabels[v] ?? v,
                counts: _count(products, (p) => p.s('type', 'rental')),
                selected: _type,
                onChanged: (s) => upd(() => _type = s),
              ),
              ChipFacet(
                title: 'Tracking',
                options: const ['trackable', 'bulk'],
                counts: _count(products, (p) => p.s('trackingType', 'trackable')),
                selected: _tracking,
                onChanged: (s) => upd(() => _tracking = s),
              ),
              ChipFacet(
                title: 'Status',
                options: const ['active', 'archived'],
                counts: _count(products, (p) => p.s('status', 'active')),
                selected: _status,
                onChanged: (s) => upd(() => _status = s),
              ),
              ChipFacet(
                title: 'Online store',
                options: const ['yes', 'no'],
                labeler: (v) => v == 'yes' ? 'Visible' : 'Hidden',
                counts: _count(products, (p) => p.b('showInStore', true) ? 'yes' : 'no'),
                selected: _store,
                onChanged: (s) => upd(() => _store = s),
              ),
              if (collections.isNotEmpty)
                ChipFacet(
                  title: 'Collections',
                  options: [for (final c in collections) c.id],
                  labeler: (id) => collections.firstWhere((c) => c.id == id).s('name'),
                  selected: _cols,
                  onChanged: (s) => upd(() => _cols = s),
                ),
              if (tags.isNotEmpty)
                ChipFacet(title: 'Tags', options: tags, labeler: (t) => t, selected: _tags, onChanged: (s) => upd(() => _tags = s)),
            ];
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ...facets,
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => upd(() {
                  switch (_tab) {
                    case 'downtime':
                      _attention = {};
                      _dtStatus = {'scheduled', 'started'};
                      _reason = {};
                    case 'stock':
                      _kind = {};
                      _stockStatus = {};
                    default:
                      _type = {};
                      _tracking = {};
                      _status = {'active'};
                      _cols = {};
                      _tags = {};
                      _store = {};
                  }
                }),
                child: const Text('Reset'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: GradientButton(label: 'Show results', height: 50, onPressed: () => Navigator.pop(c))),
          ]),
        ]);
      });
    });
  }

  // ------------------------------------------------------------------ products
  List<Widget> _products(BuildContext context, List<Doc> products, List<Doc> collections, List<Doc> orders, List<Doc> downtimes) {
    final rows = products.where((p) {
      if (!_match('${p.s('name')} ${p.s('sku')}')) return false;
      if (_type.isNotEmpty && !_type.contains(p.s('type', 'rental'))) return false;
      if (_tracking.isNotEmpty && !_tracking.contains(p.s('trackingType', 'trackable'))) return false;
      if (_status.isNotEmpty && !_status.contains(p.s('status', 'active'))) return false;
      if (_cols.isNotEmpty && !_cols.any((c) => c == 'all-products' || p.l<String>('collectionIds').contains(c))) return false;
      if (_tags.isNotEmpty && !_tags.any((t) => p.l<String>('tags').contains(t))) return false;
      if (_store.isNotEmpty && !_store.contains(p.b('showInStore', true) ? 'yes' : 'no')) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.s('name').toLowerCase().compareTo(b.s('name').toLowerCase()));
    final active = products.where((p) => p.s('status', 'active') == 'active');
    final units = active.fold<int>(0, (a, p) => a + p.i('quantity'));
    final value = active.fold<num>(0, (a, p) => a + p.i('quantity') * p.n('purchaseCost'));
    final out = active.fold<int>(0, (a, p) => a + unitsOut(p.id, orders));
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 12),
          child: MetricScroller(items: [
            MiniMetric(label: 'Products', value: active.length, format: Fmt.integer, icon: Icons.inventory_2_outlined),
            MiniMetric(label: 'Stock units', value: units, format: Fmt.integer, icon: Icons.widgets_outlined, color: AppColors.info),
            MiniMetric(label: 'Stock value', value: value, format: Fmt.compactMoney, icon: Icons.account_balance_wallet_outlined, color: AppColors.success),
            MiniMetric(label: 'Out now', value: out, format: Fmt.integer, icon: Icons.local_shipping_outlined, color: AppColors.warning),
          ]),
        ),
      ),
      if (rows.isEmpty)
        SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.inventory_2_outlined,
            title: products.isEmpty ? 'Add your first product' : 'No products match',
            message: products.isEmpty
                ? 'Products to rent, services and sale items. Add stock after creating a product.'
                : 'Adjust the search or filters to see more products.',
            actionLabel: products.isEmpty ? 'Add product' : null,
            onAction: products.isEmpty ? () => context.push('/inventory/products/new') : null,
          ),
        )
      else
        SList(
          count: rows.length,
          builder: (c, i) {
            final p = rows[i];
            final archived = p.s('status') == 'archived';
            return swipeAction(
              key: ValueKey('p-${p.id}'),
              context: context,
              icon: archived ? Icons.unarchive_outlined : Icons.archive_outlined,
              label: archived ? 'Restore' : 'Archive',
              color: archived ? AppColors.success : AppColors.warning,
              danger: false,
              confirmTitle: archived ? 'Restore ${p.s('name')}?' : 'Archive ${p.s('name')}?',
              confirmMessage: archived ? 'The product becomes bookable again.' : 'Archived products are hidden from new orders and your store.',
              onConfirmed: () => runAction(context, () => Db.update(C.products, p.id, {'status': archived ? 'active' : 'archived'}, label: p.s('name')),
                  archived ? 'Product restored' : 'Product archived'),
              child: _OpenCard(open: (_) => ProductDetailPage(id: p.id), child: _ProductCard(p: p, avail: availableNow(p, orders, downtimes))),
            );
          },
        ),
    ];
  }

  // ------------------------------------------------------------------ bundles
  num _bundlePrice(Doc b, List<Doc> products) {
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

  List<Widget> _bundles(BuildContext context, List<Doc> bundles, List<Doc> products) {
    final rows = bundles.where((b) => _match(b.s('name'))).toList();
    if (rows.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.workspaces_outline,
            title: bundles.isEmpty ? 'Create your first bundle' : 'No bundles match',
            message: 'Bundles are products often rented together — offer them at a discount.',
            actionLabel: 'Add bundle',
            onAction: () => context.push('/inventory/bundles/new'),
          ),
        ),
      ];
    }
    return [
      SList(
        count: rows.length,
        builder: (c, i) {
          final b = rows[i];
          final qty = b.maps('items').fold<num>(0, (a, it) => a + ((it['qty'] as num?) ?? 1));
          return swipeAction(
            key: ValueKey('b-${b.id}'),
            context: context,
            icon: Icons.delete_outline,
            label: 'Delete',
            confirmTitle: 'Delete ${b.s('name')}?',
            confirmMessage: 'This cannot be undone.',
            onConfirmed: () => runAction(context, () => Db.remove(C.bundles, b.id, label: b.s('name')), 'Bundle deleted'),
            child: _OpenCard(
              open: (_) => BundleFormPage(id: b.id),
              child: MTile(
                leading: Thumb(url: b.s('imageUrl'), size: 52, icon: Icons.workspaces_outline),
                title: b.s('name'),
                subtitle: '${Fmt.integer(qty)} item${qty == 1 ? '' : 's'} · ${Fmt.money(_bundlePrice(b, products))}',
                trailing: storePill(b.b('showInStore')),
              ),
            ),
          );
        },
      ),
    ];
  }

  // ------------------------------------------------------------------ collections
  List<Widget> _collections(BuildContext context, List<Doc> collections, List<Doc> products) {
    int colCount(Doc c) => c.id == 'all-products' ? products.length : products.where((p) => p.l<String>('collectionIds').contains(c.id)).length;
    final rows = collections.where((c) => _match(c.s('name'))).toList()
      ..sort((a, b) => (b.b('isSystem') ? 1 : 0).compareTo(a.b('isSystem') ? 1 : 0));
    if (rows.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.collections_bookmark_outlined,
            title: 'Organise products into collections',
            message: 'Collections group related products in your online store, e.g. "Cameras" or "Party tents".',
            actionLabel: 'Add collection',
            onAction: () => context.push('/inventory/collections/new'),
          ),
        ),
      ];
    }
    return [
      SList(
        count: rows.length,
        builder: (c, i) {
          final col = rows[i];
          final n = colCount(col);
          final tile = _OpenCard(
            open: (_) => CollectionFormPage(id: col.id),
            child: MTile(
              leading: Thumb(url: col.s('imageUrl'), size: 52, icon: Icons.collections_bookmark_outlined),
              title: col.s('name'),
              subtitle: '$n product${n == 1 ? '' : 's'}${col.b('isSystem') ? ' · System collection' : ''}',
              trailing: storePill(col.b('showInStore')),
            ),
          );
          if (col.b('isSystem')) return tile;
          return swipeAction(
            key: ValueKey('c-${col.id}'),
            context: context,
            icon: Icons.delete_outline,
            label: 'Delete',
            confirmTitle: 'Delete ${col.s('name')}?',
            confirmMessage: 'Products stay in your inventory; only the grouping is removed.',
            onConfirmed: () => runAction(context, () => Db.remove(C.collections, col.id, label: col.s('name')), 'Collection deleted'),
            child: tile,
          );
        },
      ),
    ];
  }

  // ------------------------------------------------------------------ downtime
  List<Widget> _downtime(BuildContext context, List<Doc> downtimes, List<Doc> products) {
    final rows = downtimes.where((d) {
      if (!_match('${d.s('productName')} ${d.s('stockIdentifier')}')) return false;
      if (_dtStatus.isNotEmpty && !_dtStatus.contains(d.s('status'))) return false;
      if (_reason.isNotEmpty && !_reason.contains(d.s('reason'))) return false;
      if (_attention.isNotEmpty && !_attention.any((a) => _attentionMatch(d, a))) return false;
      return true;
    }).toList()
      ..sort((a, b) => (a.d('startsAt') ?? DateTime(2000)).compareTo(b.d('startsAt') ?? DateTime(2000)));
    return [
      SPad(
        Row(children: [
          Expanded(child: Text('${rows.length} downtime${rows.length == 1 ? '' : 's'}', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600))),
          TextButton.icon(
            onPressed: () => showDowntimeSheet(context, products: products),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Schedule'),
          ),
        ]),
        padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
      ),
      if (rows.isEmpty)
        SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.build_circle_outlined,
            title: downtimes.isEmpty ? 'Schedule downtime' : 'No downtime matches',
            message: 'Temporarily remove items for maintenance or repair so they can\'t be booked.',
            actionLabel: 'Schedule downtime',
            onAction: () => showDowntimeSheet(context, products: products),
          ),
        )
      else
        SList(
          count: rows.length,
          builder: (c, i) => DowntimeCard(
            d: rows[i],
            onTap: () => context.push('/inventory/products/${rows[i].s('productId')}?tab=downtime'),
          ),
        ),
    ];
  }

  // ------------------------------------------------------------------ stock
  List<Widget> _stock(BuildContext context, List<Doc> stock) {
    final rows = stock.where((s) {
      if (!_match('${s.s('identifier')} ${s.s('productName')}')) return false;
      if (_kind.isNotEmpty && !_kind.contains(s.s('kind', 'regular'))) return false;
      if (_stockStatus.isNotEmpty && !_stockStatus.contains(s.s('status', 'available'))) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.s('identifier').compareTo(b.s('identifier')));
    if (rows.isEmpty) {
      return const [
        SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.qr_code_2,
            title: 'No stock items',
            message: 'Stock items are the individual units of a product. Add them from a product\'s Inventory tab.',
          ),
        ),
      ];
    }
    return [
      SList(
        count: rows.length,
        builder: (c, i) {
          final s = rows[i];
          return StockTile(s: s, showProduct: true, onTap: () => context.push('/inventory/products/${s.s('productId')}?tab=inventory'));
        },
      ),
    ];
  }
}

/// Product list card with hero thumbnail, price and availability.
class _ProductCard extends StatelessWidget {
  final Doc p;
  final int avail;
  const _ProductCard({required this.p, required this.avail});

  @override
  Widget build(BuildContext context) {
    final qty = p.i('quantity');
    final c = availColor(avail, qty);
    final archived = p.s('status') == 'archived';
    final bulk = p.s('trackingType', 'trackable') == 'bulk';
    return MTile(
      leading: Hero(tag: heroTagFor(p.id), child: Thumb(url: productThumb(p), size: 60)),
      title: p.s('name'),
      subtitle: [if (p.s('sku').isNotEmpty) p.s('sku'), productTypeLabels[p.s('type', 'rental')] ?? ''].where((e) => e.isNotEmpty).join(' · '),
      trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(priceLabel(p), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.ink)),
        const SizedBox(height: 4),
        if (archived) const StatusPill('archived', dot: false) else storePill(p.b('showInStore', true)),
      ]),
      footer: Row(children: [
        smallChip('$qty in stock', color: AppColors.inkSoft, bg: const Color(0xFFF2F0F7), icon: bulk ? Icons.stacked_bar_chart_rounded : Icons.qr_code_2_rounded),
        const SizedBox(width: 6),
        smallChip('$avail available now', color: c, bg: c.withValues(alpha: 0.12), icon: Icons.bolt_rounded),
        const Spacer(),
        for (final t in p.l<String>('tags').take(1)) smallChip(t),
      ]),
    );
  }
}

/// Stock item card (shared with product detail).
class StockTile extends StatelessWidget {
  final Doc s;
  final bool showProduct;
  final VoidCallback? onTap;
  const StockTile({super.key, required this.s, this.showProduct = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final till = s.d('availableTill');
    final status = s.s('status', 'available');
    final (fg, bg) = statusColors(status);
    return MTile(
      onTap: onTap,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Icon(Icons.qr_code_2_rounded, color: fg),
      ),
      title: s.s('identifier'),
      subtitle: [
        if (showProduct) s.s('productName'),
        Fmt.label(s.s('kind', 'regular')),
        if (till != null) 'until ${Fmt.date(till)}' else 'from ${Fmt.date(s.d('availableFrom'))}',
        if (s.n('purchaseCost') > 0) Fmt.money(s.n('purchaseCost')),
      ].join(' · '),
      trailing: StatusPill(status),
    );
  }
}

/// Container-transform (OpenContainer) wrapper opening a full-screen page on the root navigator.
class _OpenCard extends StatelessWidget {
  final Widget child;
  final Widget Function(BuildContext) open;
  const _OpenCard({required this.child, required this.open});

  @override
  Widget build(BuildContext context) => OpenContainer(
        useRootNavigator: true,
        transitionDuration: const Duration(milliseconds: 460),
        closedElevation: 0,
        openElevation: 0,
        closedColor: Colors.transparent,
        middleColor: AppColors.bg,
        openColor: AppColors.bg,
        closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        tappable: false,
        closedBuilder: (c, openIt) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            openIt();
          },
          child: AbsorbPointer(child: child),
        ),
        openBuilder: (c, _) => open(c),
      );
}
