import 'package:flutter/material.dart';
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
import 'coupon_kit.dart';

class CouponsPage extends StatefulWidget {
  const CouponsPage({super.key});

  @override
  State<CouponsPage> createState() => _CouponsPageState();
}

class _CouponsPageState extends State<CouponsPage> {
  late Stream<List<Doc>> _stream = Db.watch(C.coupons);
  String _q = '';
  String _chip = 'all';

  Future<void> _toggle(Doc c, bool v) async {
    HapticFeedback.selectionClick();
    try {
      await Db.update(C.coupons, c.id, {'active': v}, label: c.s('code'));
      if (mounted) toast(context, '${c.s('code')} ${v ? 'activated' : 'deactivated'}');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  Future<bool> _delete(Doc c) async {
    HapticFeedback.mediumImpact();
    final ok = await confirmDialog(
      context,
      title: 'Delete coupon ${c.s('code')}?',
      message: 'Customers will no longer be able to redeem this code. Past orders are not affected.',
      confirmLabel: 'Delete coupon',
      danger: true,
    );
    if (!ok) return false;
    try {
      await Db.remove(C.coupons, c.id, label: c.s('code'));
      if (mounted) toast(context, 'Coupon deleted');
      return true;
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
      return false;
    }
  }

  Future<void> _export(List<Doc> rows) async {
    HapticFeedback.lightImpact();
    if (rows.isEmpty) {
      toast(context, 'There are no coupons to export', error: true);
      return;
    }
    await exportCsv('coupons', [
      'Code',
      'Status',
      'Discount',
      'Valid from',
      'Valid until',
      'Eligible',
      'Minimum spend',
      'Max uses',
      'Uses'
    ], [
      for (final c in rows)
        [
          c.s('code'),
          Fmt.label(couponState(c)),
          couponDiscountLabel(c.s('discountType', 'percentage'), c.n('value')),
          Fmt.date(c.d('startsAt')),
          Fmt.date(c.d('endsAt')),
          couponEligibleText(c),
          c.data['minimumSpend'] ?? '',
          c.data['maxUses'] ?? '',
          c.i('uses'),
        ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Doc>>(
      stream: _stream,
      builder: (context, snap) {
        final all = snap.data ?? const <Doc>[];
        final states = {for (final c in all) c.id: couponState(c)};
        final q = _q.trim().toLowerCase();
        final rows = all.where((c) {
          if (q.isNotEmpty && !c.s('code').toLowerCase().contains(q)) return false;
          final st = states[c.id]!;
          if (_chip == 'expired') return st == 'expired' || st == 'used_up';
          if (_chip != 'all' && st != _chip) return false;
          return true;
        }).toList();
        int count(bool Function(String) f) => states.values.where(f).length;
        final counts = {
          'all': all.length,
          'active': count((s) => s == 'active'),
          'scheduled': count((s) => s == 'scheduled'),
          'expired': count((s) => s == 'expired' || s == 'used_up'),
          'inactive': count((s) => s == 'inactive'),
        };
        final redemptions = all.fold<int>(0, (a, c) => a + c.i('uses'));

        return MPage(
          title: 'Coupons',
          onRefresh: () async {
            HapticFeedback.mediumImpact();
            await Future<void>.delayed(const Duration(milliseconds: 600));
            if (mounted) setState(() => _stream = Db.watch(C.coupons));
          },
          actions: [IconButton(tooltip: 'Export CSV', icon: const Icon(Icons.ios_share_rounded), onPressed: () => _export(rows))],
          fab: FloatingActionButton.extended(
            heroTag: 'coupon-add',
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            onPressed: () {
              HapticFeedback.lightImpact();
              context.push('/coupons/new');
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('New coupon', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          headerHeight: 116,
          header: Column(children: [
            MSearch(hint: 'Search code', onChanged: (v) => setState(() => _q = v)),
            const SizedBox(height: 10),
            ChoiceChipsBar<String>(
              value: _chip,
              counts: counts,
              options: const [('all', 'All'), ('active', 'Active'), ('scheduled', 'Scheduled'), ('expired', 'Expired'), ('inactive', 'Inactive')],
              onChanged: (v) => setState(() => _chip = v),
            ),
          ]),
          slivers: [
            if (snap.hasError)
              SliverToBoxAdapter(child: ErrorView(snap.error!))
            else if (!snap.hasData)
              const SliverToBoxAdapter(child: LoadingView())
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 14),
                  child: MetricScroller(items: [
                    MiniMetric(label: 'Live coupons', value: counts['active']!, format: Fmt.integer, icon: Icons.confirmation_number_outlined),
                    MiniMetric(label: 'Redemptions', value: redemptions, format: Fmt.integer, icon: Icons.redeem_rounded, color: AppColors.success),
                    MiniMetric(label: 'Scheduled', value: counts['scheduled']!, format: Fmt.integer, icon: Icons.schedule_rounded, color: AppColors.info),
                  ]),
                ),
              ),
              if (rows.isEmpty)
                SliverToBoxAdapter(
                  child: all.isEmpty
                      ? EmptyState(
                          icon: Icons.confirmation_number_outlined,
                          title: 'No coupons yet',
                          message: 'Create discount codes for online checkout and manual orders.',
                          actionLabel: 'Create coupon',
                          onAction: () => context.push('/coupons/new'),
                        )
                      : const EmptyState(icon: Icons.search_off_rounded, title: 'No matching coupons', message: 'Try a different search or filter.', compact: true),
                )
              else
                SList(
                  count: rows.length,
                  builder: (_, i) {
                    final c = rows[i];
                    final st = states[c.id]!;
                    final max = c.data['maxUses'];
                    return Dismissible(
                      key: ValueKey('coupon-${c.id}'),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) => _delete(c),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(18)),
                        child: const Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.delete_outline_rounded, color: Colors.white),
                          SizedBox(height: 4),
                          Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                        ]),
                      ),
                      child: PressScale(
                        scale: 0.98,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          context.push('/coupons/${c.id}');
                        },
                        onLongPress: () => copyCode(context, c.s('code')),
                        child: CouponTicket(
                          code: c.s('code'),
                          discount: couponDiscountLabel(c.s('discountType', 'percentage'), c.n('value')),
                          live: st == 'active' || st == 'scheduled',
                          badge: couponStatePill(st),
                          trailing: SizedBox(
                            height: 30,
                            child: FittedBox(child: Switch(value: c.b('active'), onChanged: (v) => _toggle(c, v))),
                          ),
                          lines: [
                            (Icons.event_outlined, couponValidityText(c.d('startsAt'), c.d('endsAt'))),
                            (
                              Icons.redeem_rounded,
                              '${Fmt.integer(c.i('uses'))}${max is num && max > 0 ? ' / ${Fmt.integer(max)}' : ''} uses · ${couponEligibleText(c)}'
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ],
        );
      },
    );
  }
}
