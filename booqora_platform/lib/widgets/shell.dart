import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/db.dart';
import '../data/schema.dart';
import '../data/session.dart';
import 'common.dart';

class NavItem {
  final String label;
  final IconData icon;
  final String route;
  final String? badge;
  const NavItem(this.label, this.icon, this.route, {this.badge});
}

const _main = [
  NavItem('Dashboard', Icons.space_dashboard_outlined, '/'),
  NavItem('Calendar', Icons.calendar_month_outlined, '/calendar'),
];
const _ops = [
  NavItem('Orders', Icons.receipt_long_outlined, '/orders'),
  NavItem('Customers', Icons.people_alt_outlined, '/customers'),
  NavItem('Inventory', Icons.inventory_2_outlined, '/inventory'),
  NavItem('Coupons', Icons.local_offer_outlined, '/coupons'),
  NavItem('Documents', Icons.description_outlined, '/documents'),
];
const _grow = [
  NavItem('Online store', Icons.storefront_outlined, '/online-store'),
  NavItem('Apps', Icons.extension_outlined, '/apps'),
  NavItem('Reports', Icons.insights_outlined, '/reports'),
];
const _bottom = [
  NavItem('Ask Bora', Icons.auto_awesome_outlined, '/assistant', badge: 'AI'),
  NavItem('Help', Icons.help_outline, '/help'),
  NavItem('Settings', Icons.settings_outlined, '/settings'),
];

/// Main application shell with sidebar navigation.
class AppShell extends StatefulWidget {
  final Widget child;
  final String location;
  const AppShell({super.key, required this.child, required this.location});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _collapsed = false;
  final _scaffold = GlobalKey<ScaffoldState>();

  bool _active(String route) {
    final loc = widget.location;
    if (route == '/') return loc == '/' || loc.startsWith('/setup');
    return loc == route || loc.startsWith('$route/');
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final mobile = w < 900;
    final session = context.watch<Session>();
    final collapsed = !mobile && (_collapsed || w < 1100);

    final sidebar = _Sidebar(
      collapsed: collapsed,
      isActive: _active,
      onToggle: w < 1100 ? null : () => setState(() => _collapsed = !_collapsed),
      onNavigate: (r) {
        if (mobile) Navigator.of(context).maybePop();
        context.go(r);
      },
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () => showGlobalSearch(context),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () => showGlobalSearch(context),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          key: _scaffold,
          drawer: mobile ? Drawer(width: 280, child: sidebar) : null,
          body: Column(children: [
            _TrialBanner(session: session),
            Expanded(
              child: Row(children: [
                if (!mobile) sidebar,
                Expanded(
                  child: Column(children: [
                    _TopBar(mobile: mobile, onMenu: () => _scaffold.currentState?.openDrawer()),
                    Expanded(child: widget.child),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _TrialBanner extends StatelessWidget {
  final Session session;
  const _TrialBanner({required this.session});

  @override
  Widget build(BuildContext context) {
    final ws = session.workspace;
    if (ws == null || ws.s('plan') != 'trial') return const SizedBox.shrink();
    final ends = ws.d('trialEndsAt');
    final days = ends == null ? 14 : ends.difference(DateTime.now()).inDays.clamp(0, 999);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: const BoxDecoration(gradient: AppColors.brandGradient),
      child: Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 4, children: [
        const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
        Text('Your free trial ends in $days days. Upgrade now and save 20% with a yearly plan.',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13)),
        SizedBox(
          height: 28,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primaryDeep,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            onPressed: () => context.go('/settings/billing'),
            child: const Text('Choose a plan'),
          ),
        ),
      ]),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final bool collapsed;
  final bool Function(String) isActive;
  final VoidCallback? onToggle;
  final ValueChanged<String> onNavigate;
  const _Sidebar({required this.collapsed, required this.isActive, required this.onToggle, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final onboarding = session.workspace?.m('onboarding') ?? {};
    final done = onboarding.values.where((v) => v == true).length;
    const totalSteps = 8;

    Widget group(List<NavItem> items) => Column(children: [
          for (final it in items) _NavTile(item: it, active: isActive(it.route), collapsed: collapsed, onTap: () => onNavigate(it.route)),
        ]);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      width: collapsed ? 76 : 248,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(children: [
        SizedBox(
          height: 64,
          child: Row(mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween, children: [
            if (!collapsed)
              Padding(
                padding: const EdgeInsets.only(left: 18),
                child: InkWell(onTap: () => onNavigate('/'), child: const AppLogo(height: 30)),
              )
            else
              InkWell(onTap: onToggle, child: const AppLogo(mark: true, height: 34)),
            if (!collapsed && onToggle != null)
              IconButton(icon: const Icon(Icons.keyboard_double_arrow_left, size: 20, color: AppColors.muted), onPressed: onToggle, tooltip: 'Collapse'),
          ]),
        ),
        const Divider(),
        Expanded(
          child: ListView(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10), children: [
            if (done < totalSteps)
              _SetupProgress(done: done, total: totalSteps, collapsed: collapsed, onTap: () => onNavigate('/setup')),
            _NewOrderButton(collapsed: collapsed, onTap: () => onNavigate('/orders/new')),
            const SizedBox(height: 6),
            group(_main),
            const _Sep(),
            group(_ops),
            const _Sep(),
            group(_grow),
            const _Sep(),
            group(_bottom),
            _NavTile(
              item: const NavItem('Scan a barcode', Icons.qr_code_scanner, ''),
              active: false,
              collapsed: collapsed,
              onTap: () => showBarcodeLookup(context),
            ),
          ]),
        ),
        const Divider(),
        _UserTile(collapsed: collapsed),
      ]),
    );
  }
}

class _Sep extends StatelessWidget {
  const _Sep();
  @override
  Widget build(BuildContext context) => const Padding(padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8), child: Divider());
}

class _SetupProgress extends StatelessWidget {
  final int done, total;
  final bool collapsed;
  final VoidCallback onTap;
  const _SetupProgress({required this.done, required this.total, required this.collapsed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ring = SizedBox(
      width: 30,
      height: 30,
      child: Stack(alignment: Alignment.center, children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: done / total),
          duration: const Duration(milliseconds: 900),
          builder: (_, v, __) => CircularProgressIndicator(value: v, strokeWidth: 3, backgroundColor: AppColors.primarySoft),
        ),
        const Icon(Icons.rocket_launch_outlined, size: 14, color: AppColors.primary),
      ]),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Tooltip(
        message: collapsed ? 'Continue setup ($done/$total)' : '',
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.primarySoft.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(12)),
            child: collapsed
                ? ring
                : Row(children: [
                    ring,
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Continue setup', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary, fontSize: 13)),
                        Text('$done/$total completed', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                      ]),
                    ),
                  ]),
          ),
        ),
      ),
    );
  }
}

class _NewOrderButton extends StatelessWidget {
  final bool collapsed;
  final VoidCallback onTap;
  const _NewOrderButton({required this.collapsed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: collapsed ? 'New order' : '',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 6))],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.add_rounded, color: Colors.white, size: 20),
            if (!collapsed) ...[
              const SizedBox(width: 8),
              const Text('New order', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ],
          ]),
        ),
      ),
    ).animate().shimmer(delay: 800.ms, duration: 1400.ms, color: Colors.white24);
  }
}

class _NavTile extends StatefulWidget {
  final NavItem item;
  final bool active;
  final bool collapsed;
  final VoidCallback onTap;
  const _NavTile({required this.item, required this.active, required this.collapsed, required this.onTap});

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.active;
    final color = a ? AppColors.primary : AppColors.inkSoft;
    return Tooltip(
      message: widget.collapsed ? widget.item.label : '',
      waitDuration: const Duration(milliseconds: 300),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: EdgeInsets.symmetric(horizontal: widget.collapsed ? 0 : 12, vertical: 10),
            decoration: BoxDecoration(
              color: a ? AppColors.primarySoft : (_hover ? const Color(0xFFF7F4FD) : Colors.transparent),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(mainAxisAlignment: widget.collapsed ? MainAxisAlignment.center : MainAxisAlignment.start, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 3,
                height: a && !widget.collapsed ? 18 : 0,
                margin: EdgeInsets.only(right: widget.collapsed ? 0 : 9),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2)),
              ),
              AnimatedScale(
                scale: _hover ? 1.12 : 1,
                duration: const Duration(milliseconds: 180),
                child: Icon(widget.item.icon, size: 20, color: color),
              ),
              if (!widget.collapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(widget.item.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: color, fontWeight: a ? FontWeight.w700 : FontWeight.w500, fontSize: 14)),
                ),
                if (widget.item.badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(6)),
                    child: Text(widget.item.badge!, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final bool collapsed;
  const _UserTile({required this.collapsed});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    return PopupMenuButton<String>(
      tooltip: 'Account',
      offset: const Offset(0, -150),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (v) async {
        if (v == 'profile') context.go('/profile');
        if (v == 'settings') context.go('/settings');
        if (v == 'logout') {
          await Session.instance.signOut();
          if (context.mounted) context.go('/login');
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'profile', child: ListTile(leading: Icon(Icons.person_outline), title: Text('My profile'), dense: true)),
        PopupMenuItem(value: 'settings', child: ListTile(leading: Icon(Icons.settings_outlined), title: Text('Settings'), dense: true)),
        PopupMenuItem(value: 'logout', child: ListTile(leading: Icon(Icons.logout, color: AppColors.danger), title: Text('Sign out'), dense: true)),
      ],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start, children: [
          Avatar(s.displayName, url: s.profile?.s('avatarUrl'), size: 34),
          if (!collapsed) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.displayName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(s.workspace?.s('name') ?? '', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              ]),
            ),
            const Icon(Icons.unfold_more, size: 16, color: AppColors.muted),
          ],
        ]),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final bool mobile;
  final VoidCallback onMenu;
  const _TopBar({required this.mobile, required this.onMenu});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: EdgeInsets.symmetric(horizontal: mobile ? 8 : 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        border: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(children: [
        if (mobile) ...[
          IconButton(icon: const Icon(Icons.menu), onPressed: onMenu),
          const AppLogo(mark: true, height: 28),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => showGlobalSearch(context),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                  child: Row(children: [
                    const Icon(Icons.search, size: 18, color: AppColors.muted),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Search orders, customers, products…', overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.muted, fontSize: 13))),
                    if (!mobile)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
                        child: const Text('Ctrl K', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                      ),
                  ]),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(tooltip: 'Scan a barcode', icon: const Icon(Icons.qr_code_scanner, color: AppColors.inkSoft), onPressed: () => showBarcodeLookup(context)),
        IconButton(tooltip: 'Ask Bora', icon: const Icon(Icons.auto_awesome, color: AppColors.primary), onPressed: () => context.go('/assistant')),
        if (!mobile) ...[
          const SizedBox(width: 6),
          FilledButton.icon(
            onPressed: () => context.go('/orders/new'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New order'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
          ),
        ],
      ]),
    );
  }
}

// ---------------- Global search ----------------

Future<void> showGlobalSearch(BuildContext context) => showDialog(
      context: context,
      barrierColor: AppColors.ink.withValues(alpha: 0.35),
      builder: (_) => const _SearchDialog(),
    );

class _SearchDialog extends StatefulWidget {
  const _SearchDialog();
  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog> {
  String _q = '';
  List<Doc> _orders = [], _customers = [], _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([Db.list(C.orders), Db.list(C.customers), Db.list(C.products)]);
      if (!mounted) return;
      setState(() {
        _orders = r[0];
        _customers = r[1];
        _products = r[2];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase().trim();
    bool m(String s) => s.toLowerCase().contains(q);
    final results = <(IconData, String, String, String)>[];
    if (q.isNotEmpty) {
      for (final o in _orders) {
        if (m('#${o.i('number')}') || m(o.s('customerName')) || m('${o.i('number')}')) {
          results.add((Icons.receipt_long_outlined, 'Order #${o.i('number')}', '${o.s('customerName')} · ${Fmt.label(o.s('status'))}', '/orders/${o.id}'));
        }
      }
      for (final c in _customers) {
        if (m(c.s('name')) || m(c.s('email')) || m(c.s('phone'))) {
          results.add((Icons.person_outline, c.s('name'), c.s('email'), '/customers/${c.id}'));
        }
      }
      for (final p in _products) {
        if (m(p.s('name')) || m(p.s('sku'))) {
          results.add((Icons.inventory_2_outlined, p.s('name'), 'SKU ${p.s('sku', '—')} · ${p.i('quantity')} in stock', '/inventory/products/${p.id}'));
        }
      }
    }
    return Dialog(
      alignment: const Alignment(0, -0.6),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 520),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                hintText: 'Search orders, customers and products',
                prefixIcon: Icon(Icons.search),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
            ),
          ),
          const Divider(),
          Flexible(
            child: _loading
                ? const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())
                : q.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(28),
                        child: Text('Start typing to search across your workspace', style: TextStyle(color: AppColors.muted)),
                      )
                    : results.isEmpty
                        ? const Padding(padding: EdgeInsets.all(28), child: Text('No results', style: TextStyle(color: AppColors.muted)))
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: results.length.clamp(0, 30),
                            itemBuilder: (_, i) {
                              final r = results[i];
                              return ListTile(
                                leading: Icon(r.$1, color: AppColors.primary),
                                title: Text(r.$2, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(r.$3),
                                trailing: const Icon(Icons.north_east, size: 16),
                                onTap: () {
                                  Navigator.pop(context);
                                  context.go(r.$4);
                                },
                              ).animate().fadeIn(delay: (20 * i).ms, duration: 200.ms);
                            },
                          ),
          ),
        ]),
      ),
    ).animate().fadeIn(duration: 180.ms).scaleXY(begin: 0.96, end: 1, curve: Curves.easeOutCubic);
  }
}

// ---------------- Barcode lookup ----------------

Future<void> showBarcodeLookup(BuildContext context) async {
  final c = TextEditingController();
  final router = GoRouter.of(context);
  Future<void> go(BuildContext dctx) async {
    final code = c.text.trim();
    if (code.isEmpty) return;
    final items = await Db.listWhere(C.stockItems, 'identifier', code);
    if (items.isNotEmpty) {
      if (dctx.mounted) Navigator.pop(dctx);
      router.go('/inventory/products/${items.first.s('productId')}');
      return;
    }
    final prods = await Db.listWhere(C.products, 'sku', code);
    if (prods.isNotEmpty) {
      if (dctx.mounted) Navigator.pop(dctx);
      router.go('/inventory/products/${prods.first.id}');
      return;
    }
    final n = int.tryParse(code.replaceAll('#', ''));
    if (n != null) {
      final orders = await Db.listWhere(C.orders, 'number', n);
      if (orders.isNotEmpty) {
        if (dctx.mounted) Navigator.pop(dctx);
        router.go('/orders/${orders.first.id}');
        return;
      }
    }
    if (dctx.mounted) toast(dctx, 'No item, product or order matches "$code"', error: true);
  }

  await showDialog(
    context: context,
    builder: (dctx) => AlertDialog(
      title: const Row(children: [Icon(Icons.qr_code_scanner, color: AppColors.primary), SizedBox(width: 10), Text('Scan a barcode')]),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Scan with a USB/Bluetooth scanner or type a stock identifier, SKU or order number.',
              style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 14),
          TextField(
            controller: c,
            autofocus: true,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.qr_code_2), hintText: 'e.g. CAM-001 or 1024'),
            onSubmitted: (_) => go(dctx),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => go(dctx), child: const Text('Look up')),
      ],
    ),
  );
}
