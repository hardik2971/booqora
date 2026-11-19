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
import '../../widgets/side_panel.dart';
import 'inv_common.dart';
import 'inventory_page.dart' show StockTile;
import 'product_tabs.dart';

const _tabs = ['inventory', 'variations', 'pricing', 'settings', 'store', 'downtime', 'cross-sell', 'history'];
const _tabLabels = {
  'inventory': 'Inventory',
  'variations': 'Variations',
  'pricing': 'Pricing',
  'settings': 'Settings',
  'store': 'Online store',
  'downtime': 'Downtime',
  'cross-sell': 'Cross-sell',
  'history': 'History',
};

class ProductDetailPage extends StatelessWidget {
  final String id;
  final String? tab;
  const ProductDetailPage({super.key, required this.id, this.tab});

  @override
  Widget build(BuildContext context) {
    return LiveData(
      key: ValueKey(id),
      loading: _DetailLoading(id: id),
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
          return Scaffold(
            backgroundColor: AppColors.bg,
            appBar: AppBar(backgroundColor: AppColors.bg),
            body: EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'Product not found',
              message: 'It may have been deleted or you no longer have access.',
              actionLabel: 'Back to inventory',
              onAction: () => context.pop(),
            ),
          );
        }
        return _ProductView(product: d['product']!.first, initialTab: _tabs.contains(tab) ? tab! : 'inventory', data: d);
      },
    );
  }
}

class _DetailLoading extends StatelessWidget {
  final String id;
  const _DetailLoading({required this.id});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bg,
        body: ListView(padding: EdgeInsets.zero, children: [
          Hero(
            tag: heroTagFor(id),
            child: Container(height: 300, decoration: const BoxDecoration(gradient: AppColors.heroGradient)),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(child: Skeleton(height: 72, radius: 16)),
              SizedBox(width: 10),
              Expanded(child: Skeleton(height: 72, radius: 16)),
              SizedBox(width: 10),
              Expanded(child: Skeleton(height: 72, radius: 16)),
            ]),
          ),
          const LoadingView(rows: 5),
        ]),
      );
}

class _ProductView extends StatefulWidget {
  final Doc product;
  final String initialTab;
  final Map<String, List<Doc>> data;
  const _ProductView({required this.product, required this.initialTab, required this.data});

  @override
  State<_ProductView> createState() => _ProductViewState();
}

class _ProductViewState extends State<_ProductView> {
  late String _tab = widget.initialTab;

  Doc get p => widget.product;
  List<Doc> get orders => widget.data[C.orders]!;
  List<Doc> get downtimes => widget.data['downtimes']!;
  List<Doc> get stock => widget.data['stock']!;

  // ------------------------------------------------------------------ actions
  Future<void> _duplicate() async {
    try {
      final copy = Map<String, dynamic>.from(p.data)
        ..remove('createdAt')
        ..remove('updatedAt')
        ..remove('createdBy');
      copy['name'] = '${p.s('name')} (copy)';
      copy['slug'] = '${p.s('slug')}-copy';
      copy['quantity'] = 0;
      final id = await Db.create(C.products, copy);
      if (mounted) {
        toast(context, 'Product duplicated');
        // Works whether this page was opened as a router page or a container transform.
        final router = GoRouter.of(context);
        Navigator.of(context).pop();
        router.push('/inventory/products/$id');
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  Future<void> _toggleArchive() async {
    final archived = p.s('status') == 'archived';
    await runAction(context, () => Db.update(C.products, p.id, {'status': archived ? 'active' : 'archived'}, label: p.s('name')),
        archived ? 'Product restored' : 'Product archived');
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context,
        title: 'Delete ${p.s('name')}?',
        message: 'The product and its ${stock.length} stock items will be permanently deleted. Existing orders keep their lines.',
        confirmLabel: 'Delete',
        danger: true);
    if (!ok || !mounted) return;
    try {
      HapticFeedback.heavyImpact();
      final nav = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      await deleteProduct(p);
      nav.maybePop();
      messenger.showSnackBar(const SnackBar(content: Text('Product deleted')));
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  void _menu() {
    HapticFeedback.selectionClick();
    final archived = p.s('status') == 'archived';
    showAppSheet<void>(context, title: p.s('name'), builder: (c) {
      void go(VoidCallback f) {
        Navigator.pop(c);
        f();
      }

      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (p.s('trackingType', 'trackable') == 'trackable')
          NavRow(icon: Icons.add_box_outlined, title: 'Add stock items', onTap: () => go(() => showAddStockSheet(context, p))),
        NavRow(icon: Icons.build_circle_outlined, title: 'Schedule downtime', color: AppColors.warning, onTap: () => go(() => showDowntimeSheet(context, product: p))),
        NavRow(icon: Icons.copy_all_outlined, title: 'Duplicate product', color: AppColors.info, onTap: () => go(_duplicate)),
        NavRow(
          icon: archived ? Icons.unarchive_outlined : Icons.archive_outlined,
          title: archived ? 'Unarchive' : 'Archive',
          color: AppColors.inkSoft,
          onTap: () => go(_toggleArchive),
        ),
        NavRow(icon: Icons.delete_outline, title: 'Delete product', color: AppColors.danger, onTap: () => go(_delete)),
      ]);
    });
  }

  // ------------------------------------------------------------------ build
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final img = productThumb(p);
    final archived = p.s('status') == 'archived';
    final avail = availableNow(p, orders, downtimes);
    final out = unitsOut(p.id, orders);
    final qty = p.i('quantity');
    final activeDowntime = downtimes.where((d) => {'scheduled', 'started'}.contains(d.s('status'))).length;
    const expanded = 300.0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverAppBar(
            pinned: true,
            stretch: true,
            expandedHeight: expanded,
            backgroundColor: AppColors.bg,
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: false,
            leading: _CircleBtn(icon: Icons.arrow_back_ios_new_rounded, onTap: () => Navigator.of(context).maybePop()),
            actions: [_CircleBtn(icon: Icons.more_horiz_rounded, onTap: _menu), const SizedBox(width: 8)],
            flexibleSpace: LayoutBuilder(builder: (context, c) {
              final minH = kToolbarHeight + top;
              final t = ((c.maxHeight - minH) / (expanded - minH)).clamp(0.0, 1.0);
              return Stack(fit: StackFit.expand, children: [
                Opacity(
                  opacity: t,
                  child: Stack(fit: StackFit.expand, children: [
                    Hero(
                      tag: heroTagFor(p.id),
                      child: img.isEmpty
                          ? Container(
                              decoration: const BoxDecoration(gradient: AppColors.heroGradient),
                              child: const Center(child: Icon(Icons.inventory_2_outlined, size: 72, color: Colors.white24)),
                            )
                          : Image.network(img, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(decoration: const BoxDecoration(gradient: AppColors.heroGradient))),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x66000000), Color(0x00000000), Color(0x00000000), Color(0xCC1C0938)],
                          stops: [0, 0.3, 0.5, 1],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 18,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          smallChip(productTypeLabels[p.s('type', 'rental')] ?? '', color: Colors.white, bg: Colors.white24),
                          smallChip(Fmt.label(p.s('trackingType', 'trackable')), color: Colors.white, bg: Colors.white24),
                          if (archived) smallChip('Archived', color: Colors.white, bg: AppColors.warning),
                          if (p.s('sku').isNotEmpty) smallChip(p.s('sku'), color: Colors.white, bg: Colors.white24, icon: Icons.qr_code_rounded),
                        ]),
                        const SizedBox(height: 8),
                        Text(p.s('name'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1.15)),
                        const SizedBox(height: 4),
                        Text(priceLabel(p), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ]),
                ),
                Positioned(
                  left: 64,
                  right: 64,
                  top: top,
                  height: kToolbarHeight,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: (1 - t * 2.5).clamp(0.0, 1.0),
                      child: Center(
                        child: Text(p.s('name'), maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
                      ),
                    ),
                  ),
                ),
              ]);
            }),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(children: [
                Expanded(child: _Stat(label: 'In stock', value: qty, color: AppColors.ink, icon: Icons.inventory_2_outlined).pop(0)),
                const SizedBox(width: 10),
                Expanded(child: _Stat(label: 'Available now', value: avail, color: availColor(avail, qty), icon: Icons.bolt_rounded).pop(1)),
                const SizedBox(width: 10),
                Expanded(child: _Stat(label: 'Out now', value: out, color: AppColors.info, icon: Icons.local_shipping_outlined).pop(2)),
              ]),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: PinnedBox(
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ChoiceChipsBar<String>(
                  options: [for (final t in _tabs) (t, _tabLabels[t]!)],
                  value: _tab,
                  counts: {'inventory': stock.length, if (activeDowntime > 0) 'downtime': activeDowntime},
                  onChanged: (t) => setState(() => _tab = t),
                ),
              ),
              height: 60,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (c, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(a), child: c),
                ),
                layoutBuilder: (cur, prev) => Stack(alignment: Alignment.topCenter, children: [...prev, ?cur]),
                child: KeyedSubtree(key: ValueKey(_tab), child: _tabBody()),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _collectionsCard(),
                TagsCard(collection: C.products, id: p.id, tags: p.l<String>('tags')),
                NotesCard(entity: 'products', entityId: p.id),
                ActivityCard(entityId: p.id),
              ]),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 40 + MediaQuery.paddingOf(context).bottom)),
        ],
      ),
    );
  }

  Widget _tabBody() {
    switch (_tab) {
      case 'variations':
        return VariationsTab(product: p);
      case 'pricing':
        return PricingTab(product: p);
      case 'settings':
        return SettingsTab(product: p);
      case 'store':
        return StoreTab(product: p);
      case 'downtime':
        return _downtimeTab();
      case 'cross-sell':
        return CrossSellTab(product: p, products: widget.data[C.products]!, bundles: widget.data[C.bundles]!);
      case 'history':
        return _historyTab();
      default:
        return _InventoryTab(product: p, stock: stock);
    }
  }

  Widget _collectionsCard() {
    final cols = widget.data[C.collections]!;
    final ids = p.l<String>('collectionIds');
    final mine = cols.where((c) => c.b('isSystem') || ids.contains(c.id)).toList();
    return PanelCard(
      title: 'Collections',
      icon: Icons.collections_bookmark_outlined,
      trailing: TextButton(
        onPressed: () async {
          final sel = await pickCollectionsSheet(context, cols, ids.toSet());
          if (sel == null || !mounted) return;
          await runAction(context, () => Db.update(C.products, p.id, {'collectionIds': {'all-products', ...sel}.toList()}, label: p.s('name')),
              'Collections updated');
        },
        child: const Text('Edit'),
      ),
      child: mine.isEmpty
          ? const Text('Not in any collection', style: TextStyle(color: AppColors.muted, fontSize: 13))
          : Wrap(spacing: 6, runSpacing: 6, children: [
              for (final c in mine)
                InputChip(
                  label: Text(c.s('name')),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => context.push('/inventory/collections/${c.id}'),
                  onDeleted: c.b('isSystem')
                      ? null
                      : () => Db.update(C.products, p.id, {'collectionIds': ids.where((x) => x != c.id).toList()}, label: p.s('name')),
                ),
            ]),
    );
  }

  Widget _downtimeTab() {
    final rows = [...downtimes]..sort((a, b) => (b.d('startsAt') ?? DateTime(2000)).compareTo(a.d('startsAt') ?? DateTime(2000)));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionLabel('Downtime · ${rows.length}',
          trailing: TextButton.icon(
            onPressed: () => showDowntimeSheet(context, product: p),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Schedule'),
          )),
      if (rows.isEmpty)
        Group(children: [
          EmptyState(
            compact: true,
            icon: Icons.build_circle_outlined,
            title: 'No downtime scheduled',
            message: 'Temporarily remove items for maintenance or repair so they can\'t be booked.',
            actionLabel: 'Schedule downtime',
            onAction: () => showDowntimeSheet(context, product: p),
          ),
        ])
      else
        for (var i = 0; i < rows.length; i++) Padding(padding: const EdgeInsets.only(bottom: 10), child: DowntimeCard(d: rows[i], showProduct: false).enter(i)),
    ]);
  }

  Widget _historyTab() {
    final rows = orders.where((o) => orderHasProduct(o, p.id)).toList()
      ..sort((a, b) => (b.d('startsAt') ?? b.created).compareTo(a.d('startsAt') ?? a.created));
    final rentedUnits = rows.where((o) => !{'draft', 'canceled'}.contains(o.s('status'))).fold<int>(0, (a, o) => a + orderQtyFor(o, p.id));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _Stat(label: 'Orders', value: rows.length, color: AppColors.primary, icon: Icons.receipt_long_outlined)),
        const SizedBox(width: 10),
        Expanded(child: _Stat(label: 'Units booked', value: rentedUnits, color: AppColors.info, icon: Icons.widgets_outlined)),
      ]),
      const SectionLabel('Orders with this product'),
      if (rows.isEmpty)
        const Group(children: [
          EmptyState(compact: true, icon: Icons.receipt_long_outlined, title: 'No orders yet', message: 'Orders that include this product will appear here.'),
        ])
      else
        for (var i = 0; i < rows.length && i < 60; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: MTile(
              onTap: () => context.push('/orders/${rows[i].id}'),
              leading: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: statusColors(rows[i].s('status', 'draft')).$2, borderRadius: BorderRadius.circular(12)),
                child: Text('×${orderQtyFor(rows[i], p.id)}',
                    style: TextStyle(fontWeight: FontWeight.w800, color: statusColors(rows[i].s('status', 'draft')).$1)),
              ),
              title: '#${rows[i].i('number')} · ${rows[i].s('customerName', 'No customer')}',
              subtitle: '${Fmt.dateTime(rows[i].d('startsAt'))} → ${Fmt.dateTime(rows[i].d('stopsAt'))}',
              trailing: StatusPill(rows[i].s('status', 'draft')),
            ).enter(i),
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
  String _sub = 'current';
  late int _qty = widget.product.i('quantity');
  bool _saving = false;

  Doc get p => widget.product;

  Future<void> _saveQty() async {
    setState(() => _saving = true);
    await runAction(context, () => Db.update(C.products, p.id, {'quantity': _qty < 0 ? 0 : _qty}, label: '${p.s('name')}: quantity $_qty'), 'Quantity updated');
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    if (p.s('trackingType', 'trackable') == 'bulk') {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        section('Stock quantity', [
          Stepper2(value: _qty, min: 0, max: 99999, label: 'Units owned', onChanged: (v) => setState(() => _qty = v)),
          GradientButton(label: 'Update quantity', icon: Icons.check_rounded, busy: _saving, onPressed: _qty == p.i('quantity') ? null : _saveQty),
        ], subtitle: 'This product is tracked in bulk. Adjust the total number of units you own.'),
      ]);
    }
    final now = DateTime.now();
    final current = widget.stock.where((s) => !(s.d('availableFrom')?.isAfter(now) ?? false)).toList();
    final expected = widget.stock.where((s) => s.d('availableFrom')?.isAfter(now) ?? false).toList();
    final rows = (_sub == 'current' ? current : expected)..sort((a, b) => a.s('identifier').compareTo(b.s('identifier')));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 6),
      Row(children: [
        Expanded(
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 'current', label: Text('Current · ${current.length}')),
              ButtonSegment(value: 'expected', label: Text('Expected · ${expected.length}')),
            ],
            selected: {_sub},
            onSelectionChanged: (v) {
              HapticFeedback.selectionClick();
              setState(() => _sub = v.first);
            },
          ),
        ),
        const SizedBox(width: 10),
        SquareIconButton(icon: Icons.add_rounded, tooltip: 'Add stock items', onTap: () => showAddStockSheet(context, p)),
      ]),
      const SizedBox(height: 12),
      if (rows.isEmpty)
        Group(children: [
          EmptyState(
            compact: true,
            icon: Icons.qr_code_2,
            title: _sub == 'current' ? 'No stock yet' : 'No expected stock',
            message: _sub == 'current'
                ? 'Add stock items so this product can be booked. Each item gets its own identifier.'
                : 'Stock with an "Available from" date in the future appears here until it arrives.',
            actionLabel: 'Add stock items',
            onAction: () => showAddStockSheet(context, p),
          ),
        ])
      else ...[
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: swipeAction(
              key: ValueKey('s-${rows[i].id}'),
              context: context,
              icon: Icons.delete_outline,
              label: 'Delete',
              confirmTitle: 'Delete ${rows[i].s('identifier')}?',
              confirmMessage: 'The stock count of this product decreases by one.',
              onConfirmed: () => runAction(context, () => deleteStockItem(p, rows[i]), 'Stock item deleted'),
              child: StockTile(s: rows[i]),
            ).enterX(i),
          ),
        const Padding(
          padding: EdgeInsets.only(left: 4, top: 2),
          child: Text('Swipe left on an item to delete it.', style: TextStyle(color: AppColors.muted, fontSize: 12)),
        ),
      ],
    ]);
  }
}

// ---------------------------------------------------------------------------
// Small widgets
// ---------------------------------------------------------------------------

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  const _Stat({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: const [BoxShadow(color: Color(0x0A1C0938), blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          CountUp(value: value, format: Fmt.integer, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.5)),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w500)),
        ]),
      );
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => Center(
        child: PressScale(
          onTap: onTap,
          child: Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              shape: BoxShape.circle,
              boxShadow: const [BoxShadow(color: Color(0x221C0938), blurRadius: 10, offset: Offset(0, 3))],
            ),
            child: Icon(icon, size: 19, color: AppColors.ink),
          ),
        ),
      );
}
