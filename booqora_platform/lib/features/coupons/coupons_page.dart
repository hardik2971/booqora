import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../widgets/common.dart';
import '../../widgets/page.dart';
import '../../widgets/table.dart';

/// Effective status of a coupon: active | inactive | scheduled | expired | used_up.
String couponState(Doc c, [DateTime? now]) {
  final t = now ?? DateTime.now();
  if (!c.b('active')) return 'inactive';
  final ends = c.d('endsAt');
  if (ends != null && ends.isBefore(t)) return 'expired';
  final max = c.data['maxUses'];
  if (max is num && max > 0 && c.i('uses') >= max) return 'used_up';
  final starts = c.d('startsAt');
  if (starts != null && starts.isAfter(t)) return 'scheduled';
  return 'active';
}

Widget couponStatePill(String state) => switch (state) {
  'expired' => const StatusPill('overdue', label: 'Expired'),
  'used_up' => const StatusPill('late', label: 'Limit reached'),
  'scheduled' => const StatusPill('scheduled'),
  'inactive' => const StatusPill('inactive'),
  _ => const StatusPill('active'),
};

String couponDiscountLabel(String type, num value) => type == 'fixed' ? Fmt.money(value) : '${_n(value)}%';

String _n(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

class CodeChip extends StatelessWidget {
  final String code;
  const CodeChip(this.code, {super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: AppColors.lavender.withValues(alpha: 0.7)),
    ),
    child: Text(
      code,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, color: AppColors.primaryDeep, letterSpacing: 1, fontSize: 12.5),
    ),
  );
}

class CouponsPage extends StatefulWidget {
  const CouponsPage({super.key});

  @override
  State<CouponsPage> createState() => _CouponsPageState();
}

class _CouponsPageState extends State<CouponsPage> {
  late final Stream<List<Doc>> _stream = Db.watch(C.coupons);
  String _q = '';
  Set<String> _status = {};
  DateTimeRange? _validity;

  bool _validIn(Doc c, DateTimeRange r) {
    final s = c.d('startsAt') ?? DateTime(1970);
    final e = c.d('endsAt') ?? DateTime(2200);
    return s.isBefore(r.end) && r.start.isBefore(e);
  }

  Future<void> _setActive(List<Doc> rows, bool active) async {
    try {
      for (final c in rows) {
        await Db.update(C.coupons, c.id, {'active': active}, label: c.s('code'));
      }
      if (mounted) toast(context, '${rows.length} coupon${rows.length == 1 ? '' : 's'} ${active ? 'activated' : 'deactivated'}');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  String _validityText(Doc c) {
    final s = c.d('startsAt'), e = c.d('endsAt');
    if (s == null && e == null) return 'Always valid';
    if (s != null && e != null) return '${Fmt.date(s)} – ${Fmt.date(e)}';
    if (s != null) return 'From ${Fmt.date(s)}';
    return 'Until ${Fmt.date(e)}';
  }

  String _eligibleText(Doc c) => switch (c.s('eligible', 'all')) {
    'products' => '${c.l<String>('productIds').length} product${c.l<String>('productIds').length == 1 ? '' : 's'}',
    'collections' => '${c.l<String>('collectionIds').length} collection${c.l<String>('collectionIds').length == 1 ? '' : 's'}',
    _ => 'All products',
  };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Doc>>(
      stream: _stream,
      builder: (context, snap) {
        final all = snap.data ?? const <Doc>[];
        final q = _q.trim().toLowerCase();
        final rows = all.where((c) {
          if (q.isNotEmpty && !c.s('code').toLowerCase().contains(q)) return false;
          if (_status.isNotEmpty && !_status.contains(c.b('active') ? 'active' : 'inactive')) return false;
          if (_validity != null && !_validIn(c, _validity!)) return false;
          return true;
        }).toList();
        final counts = {'active': all.where((c) => c.b('active')).length, 'inactive': all.where((c) => !c.b('active')).length};
        return ListLayout(
          header: PageHeader(
            title: 'Coupons',
            subtitle: 'Discount codes for online checkout and manual orders.',
            actions: [
              SearchField(hint: 'Search code', width: 220, onChanged: (v) => setState(() => _q = v)),
              FilledButton.icon(onPressed: () => context.go('/coupons/new'), icon: const Icon(Icons.add, size: 18), label: const Text('Add coupon')),
            ],
          ),
          filters: [
            FilterSection(
              title: 'Status',
              child: CheckFacet(
                options: const ['active', 'inactive'],
                counts: counts,
                selected: _status,
                onChanged: (s) => setState(() => _status = s),
              ),
            ),
            FilterSection(
              title: 'Validity',
              child: DateRangeFacet(value: _validity, onChanged: (v) => setState(() => _validity = v)),
            ),
          ],
          body: snap.hasError
              ? ErrorView(snap.error!)
              : !snap.hasData
              ? const Padding(padding: EdgeInsets.symmetric(horizontal: 28), child: LoadingView())
              : PageBody(
                  children: [
                    if (all.isNotEmpty) ...[
                      MetricRow(
                        children: [
                          MetricCard(label: 'Coupons', value: all.length, icon: Icons.confirmation_number_outlined, index: 0),
                          MetricCard(
                            label: 'Active now',
                            value: all.where((c) => couponState(c) == 'active').length,
                            icon: Icons.bolt_rounded,
                            color: AppColors.success,
                            index: 1,
                          ),
                          MetricCard(
                            label: 'Total redemptions',
                            value: all.fold<num>(0, (a, c) => a + c.i('uses')),
                            icon: Icons.redeem_rounded,
                            color: AppColors.primaryDeep,
                            index: 2,
                          ),
                          MetricCard(
                            label: 'Expired',
                            value: all.where((c) => couponState(c) == 'expired').length,
                            icon: Icons.event_busy_outlined,
                            color: AppColors.warning,
                            index: 3,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                    DataTableX<Doc>(
                      rows: rows,
                      idOf: (c) => c.id,
                      noun: 'coupons',
                      minWidth: 900,
                      onTap: (c) => context.go('/coupons/${c.id}'),
                      empty: AppCard(
                        padding: EdgeInsets.zero,
                        child: all.isEmpty
                            ? EmptyState(
                                icon: Icons.confirmation_number_outlined,
                                title: 'Add your first coupon',
                                message: 'Add your first coupon — redeem at online checkout and on manual orders.',
                                actionLabel: 'Add coupon',
                                onAction: () => context.go('/coupons/new'),
                              )
                            : const EmptyState(
                                icon: Icons.search_off_rounded,
                                title: 'No coupons match',
                                message: 'Try a different code or clear the filters.',
                                compact: true,
                              ),
                      ),
                      bulkActions: [
                        BulkAction('Activate', Icons.toggle_on_outlined, (r) => _setActive(r, true)),
                        BulkAction('Deactivate', Icons.toggle_off_outlined, (r) => _setActive(r, false)),
                        BulkAction('Delete', Icons.delete_outline, (r) async {
                          final ok = await confirmDialog(
                            context,
                            title: 'Delete ${r.length} coupon${r.length == 1 ? '' : 's'}?',
                            message: 'Customers will no longer be able to redeem these codes. Past orders are not affected.',
                            confirmLabel: 'Delete',
                            danger: true,
                          );
                          if (!ok) return;
                          try {
                            for (final c in r) {
                              await Db.remove(C.coupons, c.id, label: c.s('code'));
                            }
                            if (context.mounted) toast(context, 'Coupons deleted');
                          } catch (e) {
                            if (context.mounted) toast(context, friendlyError(e), error: true);
                          }
                        }, danger: true),
                      ],
                      columns: [
                        ColumnX('Code', (c) => CodeChip(c.s('code')), sort: (c) => c.s('code'), flex: 2),
                        ColumnX(
                          'Discount',
                          (c) => Text(
                            couponDiscountLabel(c.s('discountType', 'percentage'), c.n('value')),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          sort: (c) => c.n('value'),
                        ),
                        ColumnX('Eligible', (c) => Text(_eligibleText(c)), flex: 2),
                        ColumnX(
                          'Validity',
                          (c) => Text(_validityText(c), style: const TextStyle(fontSize: 13)),
                          sort: (c) => c.d('endsAt') ?? DateTime(2200),
                          flex: 2,
                        ),
                        ColumnX(
                          'Uses',
                          (c) {
                            final max = c.data['maxUses'];
                            return Text(max is num && max > 0 ? '${c.i('uses')} / ${max.toInt()}' : '${c.i('uses')} / ∞');
                          },
                          sort: (c) => c.i('uses'),
                          numeric: true,
                        ),
                        ColumnX('Status', (c) => couponStatePill(couponState(c)), sort: (c) => couponState(c), width: 130),
                        ColumnX('Active', (c) => Switch(value: c.b('active'), onChanged: (v) => _setActive([c], v)), width: 76),
                      ],
                    ),
                  ],
                ),
        );
      },
    );
  }
}
