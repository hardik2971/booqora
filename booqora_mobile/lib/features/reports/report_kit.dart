import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../widgets/common.dart';

/// Order statuses that count towards revenue.
bool isRevenueOrder(Doc o) => !const {'draft', 'canceled'}.contains(o.s('status'));

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

bool inRange(DateTime? d, DateTimeRange? r) {
  if (r == null) return true;
  if (d == null) return false;
  return !d.isBefore(r.start) && d.isBefore(r.end);
}

/// Units on an order (uses `itemCount` when present).
num orderItems(Doc o) {
  final ic = o.data['itemCount'];
  if (ic is num) return ic;
  return o.maps('lines').fold<num>(0, (a, l) => a + ((l['qty'] as num?) ?? 0));
}

/// Subscribes to several streams and rebuilds with their latest values.
class MultiStream extends StatefulWidget {
  final Map<String, Stream<List<Doc>>> streams;
  final Widget Function(BuildContext context, Map<String, List<Doc>> data) builder;
  final Widget? loading;
  const MultiStream({super.key, required this.streams, required this.builder, this.loading});

  @override
  State<MultiStream> createState() => _MultiStreamState();
}

class _MultiStreamState extends State<MultiStream> {
  final Map<String, List<Doc>> _data = {};
  final List<StreamSubscription> _subs = [];
  Object? _error;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(covariant MultiStream old) {
    super.didUpdateWidget(old);
    if (!identical(old.streams, widget.streams)) {
      _cancel();
      _listen();
    }
  }

  void _listen() {
    for (final e in widget.streams.entries) {
      _subs.add(e.value.listen(
        (v) {
          if (mounted) setState(() => _data[e.key] = v);
        },
        onError: (Object err) {
          if (mounted) setState(() => _error = err);
        },
      ));
    }
  }

  void _cancel() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return ErrorView(_error!);
    if (_data.length < widget.streams.length) return widget.loading ?? const LoadingView();
    return widget.builder(context, _data);
  }
}

/// Builds day (or month, for long ranges) buckets and sums [value] for each doc by [dateOf].
(List<String>, List<num>) bucketize(List<Doc> docs, DateTimeRange range, DateTime? Function(Doc) dateOf, num Function(Doc) value) {
  final days = range.end.difference(range.start).inDays;
  if (days <= 62) {
    final n = math.max(days, 1);
    final labels = <String>[];
    final vals = List<num>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      labels.add(Fmt.shortDate(range.start.add(Duration(days: i))));
    }
    final s = dayOf(range.start);
    for (final d in docs) {
      final dt = dateOf(d);
      if (dt == null) continue;
      final idx = dayOf(dt).difference(s).inDays;
      if (idx >= 0 && idx < n) vals[idx] += value(d);
    }
    return (labels, vals);
  }
  final months = <DateTime>[];
  var m = DateTime(range.start.year, range.start.month);
  while (m.isBefore(range.end) && months.length < 60) {
    months.add(m);
    m = DateTime(m.year, m.month + 1);
  }
  const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final labels = [for (final x in months) "${names[x.month - 1]} '${(x.year % 100).toString().padLeft(2, '0')}"];
  final vals = List<num>.filled(months.length, 0);
  for (final d in docs) {
    final dt = dateOf(d);
    if (dt == null) continue;
    final idx = months.indexWhere((x) => x.year == dt.year && x.month == dt.month);
    if (idx >= 0) vals[idx] += value(d);
  }
  return (labels, vals);
}

/// Colour cycle for categorical charts.
const chartPalette = [
  AppColors.primary,
  AppColors.primaryDeep,
  AppColors.lavender,
  AppColors.info,
  AppColors.success,
  AppColors.warning,
  AppColors.danger,
  Color(0xFF0E7490),
];

/// Plays a 0 → 1 entrance value once, used to grow charts in.
class GrowIn extends StatelessWidget {
  final Widget Function(double t) builder;
  final Duration duration;
  const GrowIn({super.key, required this.builder, this.duration = const Duration(milliseconds: 1000)});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (_, t, _) => builder(t),
      );
}

/// White rounded card with a title row, for charts on phones.
class ChartCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final IconData? icon;
  const ChartCard({super.key, required this.title, this.subtitle, required this.child, this.trailing, this.icon});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: Color(0x0D1C0938), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          if (icon != null) ...[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.16), AppColors.lavender.withValues(alpha: 0.12)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: t.titleMedium),
              if (subtitle != null) Text(subtitle!, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
            ]),
          ),
          ?trailing,
        ]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }
}

/// Animated gradient bar chart over labelled buckets.
class BucketBarChart extends StatelessWidget {
  final List<String> labels;
  final List<num> values;
  final String Function(num) format;
  final double height;
  final String Function(num)? axisFormat;
  const BucketBarChart({super.key, required this.labels, required this.values, required this.format, this.height = 220, this.axisFormat});

  @override
  Widget build(BuildContext context) {
    final maxV = values.fold<num>(0, (a, b) => math.max(a, b)).toDouble();
    final top = maxV <= 0 ? 10.0 : maxV * 1.18;
    final step = labels.length <= 7 ? 1 : (labels.length / 5).ceil();
    final axis = axisFormat ?? Fmt.compactMoney;
    return SizedBox(
      height: height,
      child: LayoutBuilder(builder: (context, c) {
        final barW = ((c.maxWidth - 50) / math.max(labels.length, 1) * 0.62).clamp(3.0, 22.0);
        return GrowIn(
          builder: (t) => BarChart(
            BarChartData(
              maxY: top,
              minY: 0,
              alignment: BarChartAlignment.spaceAround,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: top / 4,
                getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 1, dashArray: [4, 4]),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    interval: top / 4,
                    getTitlesWidget: (v, meta) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(axis(v), style: const TextStyle(fontSize: 9.5, color: AppColors.muted), textAlign: TextAlign.right),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (v, meta) {
                      final i = v.toInt();
                      if (i < 0 || i >= labels.length || i % step != 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(labels[i], style: const TextStyle(fontSize: 9.5, color: AppColors.muted)),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => AppColors.ink,
                  tooltipBorderRadius: BorderRadius.circular(10),
                  getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                    '${labels[group.x]}\n${format(values[group.x])}',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < values.length; i++)
                  BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                      toY: values[i].toDouble() * t,
                      width: barW,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryDeep, AppColors.primary, AppColors.lavender],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      backDrawRodData: BackgroundBarChartRodData(show: true, toY: top, color: const Color(0xFFF6F3FD)),
                    ),
                  ]),
              ],
            ),
            duration: Duration.zero,
          ),
        );
      }),
    );
  }
}

/// Animated smooth line with gradient fill and axes (for counts over time).
class TrendLineChart extends StatelessWidget {
  final List<String> labels;
  final List<num> values;
  final String Function(num) format;
  final Color color;
  final double height;
  const TrendLineChart({super.key, required this.labels, required this.values, required this.format, this.color = AppColors.primary, this.height = 180});

  @override
  Widget build(BuildContext context) {
    final maxV = values.fold<num>(0, (a, b) => math.max(a, b)).toDouble();
    final top = maxV <= 0 ? 4.0 : (maxV * 1.25).ceilToDouble();
    final step = labels.length <= 7 ? 1 : (labels.length / 5).ceil();
    return SizedBox(
      height: height,
      child: GrowIn(
        builder: (t) => LineChart(
          LineChartData(
            minY: 0,
            maxY: top,
            minX: 0,
            maxX: math.max(values.length - 1, 1).toDouble(),
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: top / 4,
              getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 1, dashArray: [4, 4]),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: top / 4,
                  getTitlesWidget: (v, meta) => Text(Fmt.integer(v), style: const TextStyle(fontSize: 9.5, color: AppColors.muted)),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  interval: 1,
                  getTitlesWidget: (v, meta) {
                    final i = v.toInt();
                    if (v != i.toDouble() || i < 0 || i >= labels.length || i % step != 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(labels[i], style: const TextStyle(fontSize: 9.5, color: AppColors.muted)),
                    );
                  },
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => AppColors.ink,
                getTooltipItems: (spots) => [
                  for (final s in spots)
                    LineTooltipItem('${labels[s.x.toInt()]}\n${format(values[s.x.toInt()])}',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                ],
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i].toDouble() * t)],
                isCurved: true,
                curveSmoothness: 0.28,
                preventCurveOverShooting: true,
                color: color,
                barWidth: 3,
                dotData: FlDotData(show: values.length <= 14),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
          duration: Duration.zero,
        ),
      ),
    );
  }
}

/// Minimal animated sparkline (no axes).
class Sparkline extends StatelessWidget {
  final List<num> values;
  final Color color;
  final double height;
  const Sparkline({super.key, required this.values, this.color = AppColors.lavender, this.height = 64});

  @override
  Widget build(BuildContext context) {
    final maxV = values.fold<num>(0, (a, b) => math.max(a, b)).toDouble();
    return SizedBox(
      height: height,
      child: GrowIn(
        duration: const Duration(milliseconds: 1400),
        builder: (t) => LineChart(
          LineChartData(
            minY: 0,
            maxY: maxV <= 0 ? 1 : maxV * 1.12,
            titlesData: const FlTitlesData(show: false),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            lineTouchData: const LineTouchData(enabled: false),
            lineBarsData: [
              LineChartBarData(
                spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i].toDouble() * t)],
                isCurved: true,
                curveSmoothness: 0.3,
                preventCurveOverShooting: true,
                color: color,
                barWidth: 2.6,
                dotData: FlDotData(
                  show: true,
                  checkToShowDot: (s, d) => s.x == values.length - 1,
                  getDotPainter: (s, p, b, i) => FlDotCirclePainter(radius: 4, color: Colors.white, strokeWidth: 2.5, strokeColor: color),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.38), color.withValues(alpha: 0)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
          duration: Duration.zero,
        ),
      ),
    );
  }
}

/// Animated donut with a centre total and a legend. Entries are (label, value, color).
class DonutChart extends StatefulWidget {
  final List<(String, num, Color)> entries;
  final String centerCaption;
  final String Function(num) format;
  final String emptyText;
  const DonutChart({super.key, required this.entries, this.centerCaption = 'total', this.format = Fmt.integer, this.emptyText = 'Nothing to show for this period'});

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries.where((e) => e.$2 > 0).toList();
    final total = entries.fold<num>(0, (a, e) => a + e.$2);
    if (total <= 0) {
      return SizedBox(
        height: 140,
        child: Center(child: Text(widget.emptyText, style: const TextStyle(color: AppColors.muted))),
      );
    }
    final focus = _touched >= 0 && _touched < entries.length ? entries[_touched] : null;
    return Column(children: [
      SizedBox(
        height: 200,
        child: GrowIn(
          duration: const Duration(milliseconds: 1100),
          builder: (t) => Stack(alignment: Alignment.center, children: [
            Transform.rotate(
              angle: (1 - t) * -math.pi / 2,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2.5,
                  centerSpaceRadius: 62,
                  startDegreeOffset: -90,
                  pieTouchData: PieTouchData(touchCallback: (event, resp) {
                    final i = (event.isInterestedForInteractions && resp?.touchedSection != null) ? resp!.touchedSection!.touchedSectionIndex : -1;
                    if (i != _touched) setState(() => _touched = i);
                  }),
                  sections: [
                    for (var i = 0; i < entries.length; i++)
                      PieChartSectionData(
                        value: entries[i].$2.toDouble(),
                        color: entries[i].$3,
                        radius: (_touched == i ? 30 : 22) * t,
                        showTitle: false,
                      ),
                  ],
                ),
                duration: const Duration(milliseconds: 250),
              ),
            ),
            Opacity(
              opacity: t,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  widget.format(focus?.$2 ?? total),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, fontSize: 20),
                ),
                SizedBox(
                  width: 100,
                  child: Text(focus?.$1 ?? widget.centerCaption,
                      textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                ),
              ]),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 14),
      Wrap(spacing: 14, runSpacing: 8, alignment: WrapAlignment.center, children: [
        for (final e in entries)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: e.$3, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 6),
            Text('${e.$1} · ${widget.format(e.$2)}', style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
          ]),
      ]),
    ]);
  }
}

/// Colour of an order status in charts.
Color statusChartColor(String s) {
  final (fg, _) = statusColors(s);
  return s == 'reserved' ? AppColors.primary : (s == 'archived' ? AppColors.lavender : fg);
}

/// Donut of order counts by status.
DonutChart statusDonut(Map<String, int> counts) => DonutChart(
      centerCaption: 'orders',
      emptyText: 'No orders in this period',
      entries: [
        for (final s in OrderStatus.all)
          if ((counts[s] ?? 0) > 0) (Fmt.label(s), counts[s]!, statusChartColor(s)),
      ],
    );

/// Ranked list with animated horizontal bars.
class RankBars extends StatelessWidget {
  final List<(String, num, Widget?)> items; // label, value, leading
  final String Function(num) format;
  const RankBars({super.key, required this.items, required this.format});

  @override
  Widget build(BuildContext context) {
    final max = items.isEmpty ? 1 : items.map((e) => e.$2).reduce(math.max);
    return Column(children: [
      for (var i = 0; i < items.length; i++)
        Padding(
          padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 14),
          child: Row(children: [
            if (items[i].$3 != null) ...[items[i].$3!, const SizedBox(width: 12)],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: Text(items[i].$1, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  Text(format(items[i].$2), style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: max <= 0 ? 0 : items[i].$2 / max),
                    duration: Duration(milliseconds: 700 + i * 120),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 7,
                      backgroundColor: AppColors.primarySoft,
                      color: chartPalette[i % 3],
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
    ]);
  }
}
