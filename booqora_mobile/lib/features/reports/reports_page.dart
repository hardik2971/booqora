import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../widgets/anim.dart';
import '../../widgets/mobile.dart';

class ReportDef {
  final String type;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  const ReportDef(this.type, this.title, this.description, this.icon, this.color);
}

const reportSections = <(String, String, List<ReportDef>)>[
  (
    'Business',
    'How your rental business is performing over time.',
    [
      ReportDef('performance', 'Company performance', 'Revenue, orders, average order value, items rented and deposits held.',
          Icons.trending_up_rounded, AppColors.primary),
    ],
  ),
  (
    'Inventory',
    'Which products earn their keep and where stock runs short.',
    [
      ReportDef('products', 'Product performance', 'Times rented, units, rent duration, revenue and ROI per product.', Icons.inventory_2_outlined,
          AppColors.primaryDeep),
      ReportDef('availability', 'Availability', 'Stock on hand versus units reserved, with shortages flagged.', Icons.event_available_outlined,
          AppColors.info),
      ReportDef('fulfillment', 'Product fulfillment', 'Every line going out in a period — a pick list for your team.', Icons.local_shipping_outlined,
          AppColors.success),
    ],
  ),
  (
    'Customers',
    'Who your best customers are and who still owes you.',
    [
      ReportDef('customers', 'Customers', 'New customers, revenue share, average order value and balances.', Icons.people_alt_outlined,
          AppColors.warning),
    ],
  ),
  (
    'Marketing',
    'Measure the impact of your discount codes.',
    [
      ReportDef('coupons', 'Coupons', 'Redemptions, discount given and revenue generated per code.', Icons.confirmation_number_outlined,
          Color(0xFFDB2777)),
    ],
  ),
  (
    'Audit',
    'A complete trail of changes made in your workspace.',
    [
      ReportDef('activity', 'Activity log', 'Who created, updated or deleted what — filterable by record type.', Icons.history_rounded,
          Color(0xFF0E7490)),
    ],
  ),
];

ReportDef? reportDef(String type) {
  for (final s in reportSections) {
    for (final r in s.$3) {
      if (r.type == type) return r;
    }
  }
  return null;
}

String reportTitle(String type) => reportDef(type)?.title ?? 'Report';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    var idx = 1;
    return MPage(
      title: 'Reports',
      subtitle: 'Insights across revenue, inventory and customers',
      slivers: [
        SPad(
          PressScale(
            scale: 0.98,
            onTap: () {
              HapticFeedback.selectionClick();
              context.push('/reports/performance');
            },
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: AppColors.primaryDeep.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 12))],
              ),
              child: Row(children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.insights_rounded, color: AppColors.lavender, size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Company performance', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                    SizedBox(height: 3),
                    Text('Your revenue, orders and deposits at a glance.', style: TextStyle(color: Color(0xFFD9CCF8), fontSize: 13, height: 1.35)),
                  ]),
                ),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              ]),
            ),
          ).enter(0),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        ),
        for (final s in reportSections) ...[
          SPad(SectionLabel(s.$1).enter(idx++), padding: const EdgeInsets.fromLTRB(16, 8, 16, 0)),
          SPad(
            Column(children: [
              for (final r in s.$3)
                Padding(padding: const EdgeInsets.only(bottom: 10), child: _ReportCard(r).enter(idx++)),
            ]),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ],
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  final ReportDef r;
  const _ReportCard(this.r);

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/reports/${r.type}');
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: const [BoxShadow(color: Color(0x0A1C0938), blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [r.color.withValues(alpha: 0.2), r.color.withValues(alpha: 0.06)]),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(r.icon, color: r.color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 2),
              Text(r.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.35)),
            ]),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ]),
      ),
    );
  }
}
