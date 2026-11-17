import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../widgets/anim.dart';
import '../../widgets/page.dart';

class _ReportDef {
  final String type;
  final String title;
  final String description;
  final IconData icon;
  const _ReportDef(this.type, this.title, this.description, this.icon);
}

const _sections = <(String, String, List<_ReportDef>)>[
  (
    'Business reports',
    'How your rental business is performing over time.',
    [
      _ReportDef(
        'performance',
        'Company performance',
        'Revenue, orders, average order value, items rented and deposits held — by day and status.',
        Icons.trending_up_rounded,
      ),
    ],
  ),
  (
    'Inventory reports',
    'Understand which products earn their keep and where stock runs short.',
    [
      _ReportDef(
        'products',
        'Product performance',
        'Times rented, units, rent duration, revenue and ROI for every product, sale item and service.',
        Icons.inventory_2_outlined,
      ),
      _ReportDef(
        'availability',
        'Availability',
        'Stock on hand versus units reserved in a period, with shortages flagged.',
        Icons.event_available_outlined,
      ),
      _ReportDef(
        'fulfillment',
        'Product fulfillment',
        'Every line going out in a period — a pick list for your warehouse team.',
        Icons.local_shipping_outlined,
      ),
    ],
  ),
  (
    'Customer reports',
    'Who your best customers are and who still owes you.',
    [_ReportDef('customers', 'Customers', 'New customers, revenue share, average order value and outstanding balances.', Icons.people_alt_outlined)],
  ),
  (
    'Coupon reports',
    'Measure the impact of your discount codes.',
    [
      _ReportDef(
        'coupons',
        'Coupons',
        'Redemptions, total discount given and revenue generated per coupon code.',
        Icons.confirmation_number_outlined,
      ),
    ],
  ),
  (
    'Activity',
    'A complete audit trail of changes made in your workspace.',
    [
      _ReportDef(
        'activity',
        'Activity logs',
        'Who created, updated or deleted what — searchable and filterable by record type.',
        Icons.history_rounded,
      ),
    ],
  ),
];

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    var idx = 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(title: 'Reports', subtitle: 'Insights across revenue, inventory, customers and coupons.'),
        Expanded(
          child: PageBody(
            children: [
              for (final s in _sections) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.$1, style: t.titleMedium),
                      const SizedBox(height: 2),
                      Text(s.$2, style: t.bodySmall?.copyWith(color: AppColors.muted)),
                    ],
                  ),
                ).enter(idx++),
                LayoutBuilder(
                  builder: (context, c) {
                    final cols = c.maxWidth > 1000 ? 3 : (c.maxWidth > 620 ? 2 : 1);
                    final w = (c.maxWidth - (cols - 1) * 16) / cols;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [for (final r in s.$3) SizedBox(width: w, child: _ReportCard(r).enter(idx++))],
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  final _ReportDef r;
  const _ReportCard(this.r);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return HoverLift(
      onTap: () => context.go('/reports/${r.type}'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.16), AppColors.lavender.withValues(alpha: 0.12)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(r.icon, color: AppColors.primary),
            ),
            const SizedBox(height: 14),
            Text(r.title, style: t.titleMedium),
            const SizedBox(height: 6),
            SizedBox(
              height: 58,
              child: Text(
                r.description,
                style: t.bodySmall?.copyWith(color: AppColors.muted, height: 1.5),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'Run report',
                  style: t.labelLarge?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Exposed for other modules / report page titles.
String reportTitle(String type) {
  for (final s in _sections) {
    for (final r in s.$3) {
      if (r.type == type) return r.title;
    }
  }
  return 'Report';
}
