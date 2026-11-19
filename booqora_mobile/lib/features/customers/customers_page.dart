import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/browser.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/mobile.dart';
import '../../widgets/side_panel.dart';
import 'customer_kit.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

const _sorts = {
  'newest': 'Newest first',
  'name': 'Name A–Z',
  'revenue': 'Highest revenue',
  'balance': 'Highest balance due',
  'recent': 'Most recent order',
};

class _CustomersPageState extends State<CustomersPage> {
  late Stream<List<Doc>> _stream = Db.watch(C.customers);
  late Stream<List<Doc>> _ordersStream = Db.watch(C.orders);
  String _q = '';
  String _chip = 'all';
  String _sort = 'newest';

  List<Doc> _filter(List<Doc> all) {
    final q = _q.trim().toLowerCase();
    final rows = all.where((c) {
      if (q.isNotEmpty &&
          !c.s('name').toLowerCase().contains(q) &&
          !c.s('email').toLowerCase().contains(q) &&
          !c.s('phone').toLowerCase().contains(q) &&
          !c.l<String>('tags').any((t) => t.toLowerCase().contains(q))) {
        return false;
      }
      switch (_chip) {
        case 'individual':
        case 'company':
          if (c.s('type', 'individual') != _chip) return false;
        case 'balance':
          if (c.n('balanceDue') <= 0) return false;
      }
      return true;
    }).toList();
    switch (_sort) {
      case 'name':
        rows.sort((a, b) => a.s('name').toLowerCase().compareTo(b.s('name').toLowerCase()));
      case 'revenue':
        rows.sort((a, b) => b.n('revenue').compareTo(a.n('revenue')));
      case 'balance':
        rows.sort((a, b) => b.n('balanceDue').compareTo(a.n('balanceDue')));
      case 'recent':
        rows.sort((a, b) => (b.d('latestOrderAt') ?? DateTime(1970)).compareTo(a.d('latestOrderAt') ?? DateTime(1970)));
    }
    return rows;
  }

  Future<void> _export(List<Doc> rows) async {
    HapticFeedback.lightImpact();
    if (rows.isEmpty) {
      toast(context, 'There are no customers to export', error: true);
      return;
    }
    try {
      await exportCsv(
        'customers',
        ['Number', 'Name', 'Email', 'Phone', 'Type', 'Marketing', 'Created at', 'Latest order', 'Orders', 'Revenue', 'Balance due', 'Tags'],
        [
          for (final c in rows)
            [
              c.i('number'),
              c.s('name'),
              c.s('email'),
              c.s('phone'),
              c.s('type', 'individual'),
              c.b('marketing') ? 'Yes' : 'No',
              Fmt.date(c.created),
              Fmt.date(c.d('latestOrderAt')),
              c.i('orderCount'),
              c.n('revenue'),
              c.n('balanceDue'),
              c.l<String>('tags').join('; '),
            ],
        ],
      );
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  void _pickSort() {
    HapticFeedback.selectionClick();
    showAppSheet<void>(
      context,
      title: 'Sort customers',
      builder: (c) => Column(mainAxisSize: MainAxisSize.min, children: [
        for (final e in _sorts.entries)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text(e.value, style: TextStyle(fontWeight: e.key == _sort ? FontWeight.w700 : FontWeight.w500)),
            trailing: e.key == _sort ? const Icon(Icons.check_circle_rounded, color: AppColors.primary) : null,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _sort = e.key);
              Navigator.pop(c);
            },
          ),
      ]),
    );
  }

  Future<void> _refresh() async {
    HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() {
        _stream = Db.watch(C.customers);
        _ordersStream = Db.watch(C.orders);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Doc>>(
      stream: _ordersStream,
      builder: (context, ordersSnap) => StreamBuilder<List<Doc>>(
        stream: _stream,
        builder: (context, snap) {
          final all = customersWithStats(snap.data ?? const <Doc>[], ordersSnap.data);
          final rows = _filter(all);
          final counts = {
            'all': all.length,
            'individual': all.where((c) => c.s('type', 'individual') == 'individual').length,
            'company': all.where((c) => c.s('type') == 'company').length,
            'balance': all.where((c) => c.n('balanceDue') > 0).length,
          };
          final revenue = all.fold<num>(0, (a, c) => a + c.n('revenue'));
          final balance = all.fold<num>(0, (a, c) => a + c.n('balanceDue'));
          final monthStart = DateTime(DateTime.now().year, DateTime.now().month);
          final newThisMonth = all.where((c) => !c.created.isBefore(monthStart)).length;
          final loading = !snap.hasData;

          return MPage(
            title: 'Customers',
            onRefresh: _refresh,
            actions: [
              IconButton(tooltip: 'Export CSV', icon: const Icon(Icons.ios_share_rounded), onPressed: () => _export(rows)),
            ],
            fab: _AddFab(onTap: () => context.push('/customers/new')),
            headerHeight: 116,
            header: Column(children: [
              MSearch(
                hint: 'Search name, email or phone',
                onChanged: (v) => setState(() => _q = v),
                trailing: SquareIconButton(icon: Icons.swap_vert_rounded, tooltip: 'Sort', badge: _sort == 'newest' ? 0 : 1, onTap: _pickSort),
              ),
              const SizedBox(height: 10),
              ChoiceChipsBar<String>(
                value: _chip,
                counts: counts,
                options: const [('all', 'All'), ('individual', 'Individual'), ('company', 'Company'), ('balance', 'Has balance')],
                onChanged: (v) => setState(() => _chip = v),
              ),
            ]),
            slivers: [
              if (snap.hasError)
                SliverToBoxAdapter(child: ErrorView(snap.error!))
              else if (loading)
                const SliverToBoxAdapter(child: LoadingView())
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 14),
                    child: MetricScroller(items: [
                      MiniMetric(label: 'Customers', value: all.length, format: Fmt.integer, icon: Icons.people_alt_outlined),
                      MiniMetric(label: 'New this month', value: newThisMonth, format: Fmt.integer, icon: Icons.person_add_alt_1_outlined, color: AppColors.info),
                      MiniMetric(label: 'Revenue', value: revenue, format: Fmt.compactMoney, icon: Icons.payments_outlined, color: AppColors.success),
                      MiniMetric(
                          label: 'Balance due', value: balance, format: Fmt.compactMoney, icon: Icons.account_balance_wallet_outlined, color: AppColors.danger),
                    ]),
                  ),
                ),
                if (rows.isEmpty)
                  SliverToBoxAdapter(
                    child: all.isEmpty
                        ? EmptyState(
                            icon: Icons.people_alt_outlined,
                            title: 'No customers yet',
                            message: 'Save contact details, addresses and discounts so orders fill in faster.',
                            actionLabel: 'Add customer',
                            onAction: () => context.push('/customers/new'),
                          )
                        : const EmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'No matching customers',
                            message: 'Try a different search or filter.',
                            compact: true,
                          ),
                  )
                else ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Text('${rows.length} customer${rows.length == 1 ? '' : 's'} · swipe right to call, left to email',
                          style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                    ),
                  ),
                  SList(count: rows.length, builder: (_, i) => _SwipeCustomer(c: rows[i])),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _AddFab extends StatelessWidget {
  final VoidCallback onTap;
  const _AddFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text('Add customer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
        ]),
      ),
    ).pop(2);
  }
}

class _SwipeCustomer extends StatelessWidget {
  final Doc c;
  const _SwipeCustomer({required this.c});

  Widget _bg(Color color, IconData icon, String label, Alignment align) => Container(
        alignment: align,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final phone = c.s('phone').trim(), email = c.s('email').trim();
    return Dismissible(
      key: ValueKey('cust-${c.id}'),
      direction: DismissDirection.horizontal,
      dismissThresholds: const {DismissDirection.startToEnd: 0.3, DismissDirection.endToStart: 0.3},
      background: _bg(AppColors.success, Icons.call_rounded, 'Call', Alignment.centerLeft),
      secondaryBackground: _bg(AppColors.info, Icons.mail_rounded, 'Email', Alignment.centerRight),
      confirmDismiss: (dir) async {
        HapticFeedback.mediumImpact();
        if (dir == DismissDirection.startToEnd) {
          if (phone.isEmpty) {
            toast(context, '${c.s('name')} has no phone number', error: true);
          } else {
            await Browser.openUrl('tel:${phoneDigits(phone)}');
          }
        } else {
          if (email.isEmpty) {
            toast(context, '${c.s('name')} has no email address', error: true);
          } else {
            await Browser.openUrl('mailto:$email');
          }
        }
        return false;
      },
      child: _CustomerCard(c: c),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  final Doc c;
  const _CustomerCard({required this.c});

  @override
  Widget build(BuildContext context) {
    final balance = c.n('balanceDue');
    final company = c.s('type') == 'company';
    final contact = [c.s('email'), c.s('phone')].where((e) => e.trim().isNotEmpty).join(' · ');
    final orders = c.i('orderCount');
    return MTile(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/customers/${c.id}');
      },
      leading: Stack(clipBehavior: Clip.none, children: [
        Avatar(c.s('name', '?'), size: 46),
        if (company)
          Positioned(
            right: -3,
            bottom: -3,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: AppColors.border)),
              child: const Icon(Icons.business_rounded, size: 12, color: AppColors.primaryDeep),
            ),
          ),
      ]),
      title: c.s('name', 'Unnamed customer'),
      subtitle: contact.isEmpty ? 'No contact details' : contact,
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
      footer: Row(children: [
        _Pill(icon: Icons.receipt_long_outlined, text: '$orders order${orders == 1 ? '' : 's'}'),
        const SizedBox(width: 6),
        Flexible(child: _Pill(icon: Icons.payments_outlined, text: Fmt.compactMoney(c.n('revenue')))),
        const Spacer(),
        balance > 0
            ? StatusPill('payment_due', label: '${Fmt.compactMoney(balance)} due')
            : (orders > 0 ? const StatusPill('paid', label: 'Settled') : const SizedBox.shrink()),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Pill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: AppColors.muted),
          const SizedBox(width: 4),
          Flexible(
            child: Text(text,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.inkSoft, fontWeight: FontWeight.w600)),
          ),
        ]),
      );
}
