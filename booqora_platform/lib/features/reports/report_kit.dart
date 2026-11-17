import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../widgets/common.dart';

/// Order statuses that count towards revenue.
bool isRevenueOrder(Doc o) => !const {'draft', 'canceled'}.contains(o.s('status'));

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

bool inRange(DateTime? d, DateTimeRange? r) {
  if (r == null) return true;
  if (d == null) return false;
  return !d.isBefore(r.start) && d.isBefore(r.end);
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
    for (final e in widget.streams.entries) {
      _subs.add(
        e.value.listen(
          (v) {
            if (mounted) setState(() => _data[e.key] = v);
          },
          onError: (Object err) {
            if (mounted) setState(() => _error = err);
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return ErrorView(_error!);
    if (_data.length < widget.streams.length) return widget.loading ?? const Padding(padding: EdgeInsets.all(28), child: LoadingView());
    return widget.builder(context, _data);
  }
}

/// Bar chart of values over labelled buckets.
class BucketBarChart extends StatelessWidget {
  final List<String> labels;
  final List<num> values;
  final String Function(num) format;
  final double height;
  const BucketBarChart({super.key, required this.labels, required this.values, required this.format, this.height = 240});

  @override
  Widget build(BuildContext context) {
    final maxV = values.fold<num>(0, (a, b) => math.max(a, b)).toDouble();
    final top = maxV <= 0 ? 10.0 : maxV * 1.15;
    final step = labels.length <= 8 ? 1 : (labels.length / 6).ceil();
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, c) {
          final barW = ((c.maxWidth - 60) / math.max(labels.length, 1) * 0.6).clamp(3.0, 28.0);
          return BarChart(
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
                    reservedSize: 52,
                    interval: top / 4,
                    getTitlesWidget: (v, meta) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        Fmt.compactMoney(v),
                        style: const TextStyle(fontSize: 10, color: AppColors.muted),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    getTitlesWidget: (v, meta) {
                      final i = v.toInt();
                      if (i < 0 || i >= labels.length || i % step != 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(labels[i], style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => AppColors.ink,
                  getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                    '${labels[group.x]}\n${format(values[group.x])}',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < values.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: values[i].toDouble(),
                        width: barW,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        gradient: const LinearGradient(
                          colors: [AppColors.primaryDeep, AppColors.primary, AppColors.lavender],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        backDrawRodData: BackgroundBarChartRodData(show: true, toY: top, color: const Color(0xFFF6F3FD)),
                      ),
                    ],
                  ),
              ],
            ),
            duration: const Duration(milliseconds: 500),
          );
        },
      ),
    );
  }
}

/// Minimal line sparkline (no axes).
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
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxV <= 0 ? 1 : maxV * 1.1,
          titlesData: const FlTitlesData(show: false),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i].toDouble())],
              isCurved: true,
              curveSmoothness: 0.3,
              preventCurveOverShooting: true,
              color: color,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

/// Small titled chart card.
class ChartCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  const ChartCard({super.key, required this.title, this.subtitle, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.titleMedium),
                    if (subtitle != null) Text(subtitle!, style: t.bodySmall?.copyWith(color: AppColors.muted)),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
