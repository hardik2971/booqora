import 'dart:math' as math;

import 'package:flutter/material.dart' hide Thumb;
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/browser.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/pricing.dart';
import '../../data/schema.dart';
import '../../data/session.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/page.dart';
import '../inventory/inv_common.dart';

const _views = ['day', 'week', 'month'];
const _barStatuses = {'draft', 'reserved', 'started'};

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  String _view = 'week';
  DateTime _anchor = DateTime.now();

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  DateTime get _start {
    final a = DateTime(_anchor.year, _anchor.month, _anchor.day);
    switch (_view) {
      case 'day':
        return a;
      case 'month':
        return DateTime(a.year, a.month, 1);
      default:
        final sunday = Session.instance.setting('general', 'weekStart', 'monday') == 'sunday';
        final offset = sunday ? a.weekday % 7 : a.weekday - 1;
        return DateTime(a.year, a.month, a.day - offset);
    }
  }

  DateTime get _end {
    final s = _start;
    switch (_view) {
      case 'day':
        return DateTime(s.year, s.month, s.day + 1);
      case 'month':
        return DateTime(s.year, s.month + 1, 1);
      default:
        return DateTime(s.year, s.month, s.day + 7);
    }
  }

  void _shift(int dir) => setState(() {
        final a = _anchor;
        switch (_view) {
          case 'day':
            _anchor = DateTime(a.year, a.month, a.day + dir);
          case 'month':
            _anchor = DateTime(a.year, a.month + dir, 1);
          default:
            _anchor = DateTime(a.year, a.month, a.day + 7 * dir);
        }
      });

  String get _rangeLabel {
    final s = _start, e = _end.subtract(const Duration(days: 1));
    switch (_view) {
      case 'day':
        return DateFormat('EEEE d MMMM yyyy').format(s);
      case 'month':
        return DateFormat('MMMM yyyy').format(s);
      default:
        if (s.month == e.month) return '${s.day} – ${DateFormat('d MMMM yyyy').format(e)}';
        return '${DateFormat('d MMM').format(s)} – ${DateFormat('d MMM yyyy').format(e)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return LiveData.of(const [C.products, C.orders, C.downtimes], builder: (context, d) {
      final products = d[C.products]!.where((p) => p.s('status', 'active') == 'active' && p.s('type', 'rental') == 'rental').toList()
        ..sort((a, b) => a.s('name').toLowerCase().compareTo(b.s('name').toLowerCase()));
      final orders = d[C.orders]!;
      final downtimes = d[C.downtimes]!;
      final narrow = MediaQuery.sizeOf(context).width < 700;
      final timeline = _Timeline(
        key: ValueKey('$_view-${_start.toIso8601String()}'),
        products: products,
        orders: orders,
        downtimes: downtimes,
        start: _start,
        end: _end,
        view: _view,
        today: _today,
      );
      final agenda = _Agenda(orders: orders, start: _start, end: _end);
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PageHeader(
          title: 'Calendar',
          subtitle: 'Bookings, pickups, returns and downtime across your inventory',
          actions: [
            OutlinedButton.icon(
              onPressed: () => _checkAvailability(context, products, orders, downtimes),
              icon: const Icon(Icons.event_available_outlined, size: 18),
              label: const Text('Check availability'),
            ),
            OutlinedButton.icon(
              onPressed: () => _subscribe(context, orders),
              icon: const Icon(Icons.rss_feed, size: 18),
              label: const Text('Subscribe'),
            ),
            FilledButton.icon(onPressed: () => context.go('/orders/new'), icon: const Icon(Icons.add, size: 18), label: const Text('New order')),
          ],
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(narrow ? 16 : 28, 0, narrow ? 16 : 28, 12),
          child: Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
            OutlinedButton(onPressed: () => setState(() => _anchor = DateTime.now()), child: const Text('Today')),
            Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton.outlined(tooltip: 'Previous', onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
              const SizedBox(width: 6),
              IconButton.outlined(tooltip: 'Next', onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right)),
            ]),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Text(_rangeLabel, key: ValueKey(_rangeLabel), style: Theme.of(context).textTheme.titleMedium),
            ),
            if (!narrow) const SizedBox(width: 12),
            PillTabs(
              tabs: const ['Day', 'Week', 'Month'],
              index: _views.indexOf(_view),
              onChanged: (i) => setState(() => _view = _views[i]),
            ),
          ]),
        ).enter(1),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final side = c.maxWidth >= 1280;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(narrow ? 16 : 28, 4, narrow ? 16 : 28, 40),
              child: side
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: timeline),
                      const SizedBox(width: 20),
                      SizedBox(width: 320, child: agenda),
                    ])
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [timeline, const SizedBox(height: 20), agenda]),
            );
          }),
        ),
      ]);
    });
  }

  // ------------------------------------------------------------------ dialogs
  Future<void> _checkAvailability(BuildContext context, List<Doc> products, List<Doc> orders, List<Doc> downtimes) async {
    if (products.isEmpty) return toast(context, 'Add a rental product first', error: true);
    Doc product = products.first;
    DateTime? from = DateTime.now();
    DateTime? until = DateTime.now().add(const Duration(days: 1));
    await showDialog<void>(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setS) {
        final valid = from != null && until != null && until!.isAfter(from!);
        final avail = valid ? Pricing.available(product, from!, until!, orders, downtimes) : 0;
        final total = product.i('quantity');
        final color = avail <= 0 ? AppColors.danger : (avail < total ? AppColors.warning : AppColors.success);
        return dialogFrame(c,
            title: 'Check availability',
            subtitle: 'See how many units are free for a period, including buffers and downtime.',
            actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Done'))],
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              DropdownX<String>(
                label: 'Product',
                value: product.id,
                items: {for (final p in products) p.id: p.s('name')},
                onChanged: (v) => setS(() => product = products.firstWhere((p) => p.id == v)),
              ),
              const SizedBox(height: 16),
              FieldGrid(children: [
                DateTimeField(label: 'From', value: from, onChanged: (v) => setS(() => from = v)),
                DateTimeField(label: 'Until', value: until, onChanged: (v) => setS(() => until = v)),
              ]),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color.withValues(alpha: 0.12), color.withValues(alpha: 0.04)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: !valid
                    ? const Text('"Until" must be after "From"', textAlign: TextAlign.center, style: TextStyle(color: AppColors.danger))
                    : Column(children: [
                        TweenAnimationBuilder<double>(
                          key: ValueKey('${product.id}-$avail'),
                          tween: Tween(begin: 0, end: avail.toDouble()),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, _) => Text('${v.round()}',
                              style: TextStyle(fontSize: 64, fontWeight: FontWeight.w800, color: color, height: 1, letterSpacing: -2)),
                        ).animate(key: ValueKey('${product.id}-$avail')).scaleXY(begin: 0.8, end: 1, duration: 400.ms, curve: Curves.easeOutBack),
                        const SizedBox(height: 8),
                        Text('of $total unit${total == 1 ? '' : 's'} available', style: const TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('${Fmt.dateTime(from)} → ${Fmt.dateTime(until)}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                      ]),
              ),
            ]));
      }),
    );
  }

  Future<void> _subscribe(BuildContext context, List<Doc> orders) async {
    final link = '${Browser.origin}/calendar';
    await showDialog<void>(
      context: context,
      builder: (c) => dialogFrame(c,
          title: 'Subscribe to calendar',
          subtitle: 'Bring your bookings into Google Calendar, Outlook or Apple Calendar.',
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close')),
            FilledButton.icon(
              onPressed: () {
                final n = _downloadIcs(orders);
                Navigator.pop(c);
                toast(context, n == 0 ? 'No reserved or started orders to export' : 'Exported $n order${n == 1 ? '' : 's'}');
              },
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Download .ics'),
            ),
          ],
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text(
              'Export is via "Download .ics": the file contains every reserved and started order with its pickup and return time. '
              'Import it into your calendar app; download a fresh file whenever you want to refresh it.',
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 16),
            const FieldLabel('Team calendar link'),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
              decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
              child: Row(children: [
                Expanded(child: SelectableText(link, style: const TextStyle(fontFamily: 'monospace', fontSize: 13))),
                IconButton(
                  tooltip: 'Copy link',
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: link));
                    if (c.mounted) toast(c, 'Link copied');
                  },
                ),
              ]),
            ),
            const SizedBox(height: 8),
            const Text('Share this link with team members who have access to your workspace.', style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ])),
    );
  }

  int _downloadIcs(List<Doc> orders) {
    String ts(DateTime d) => '${DateFormat("yyyyMMdd'T'HHmmss").format(d.toUtc())}Z';
    String esc(String s) => s.replaceAll('\\', '\\\\').replaceAll(';', '\\;').replaceAll(',', '\\,').replaceAll('\n', '\\n');
    final list = orders.where((o) => Pricing.holding.contains(o.s('status')) && o.d('startsAt') != null && o.d('stopsAt') != null).toList();
    final b = StringBuffer()
      ..write('BEGIN:VCALENDAR\r\n')
      ..write('VERSION:2.0\r\n')
      ..write('PRODID:-//Booqora//Rental Calendar//EN\r\n')
      ..write('CALSCALE:GREGORIAN\r\n')
      ..write('X-WR-CALNAME:${esc(Session.instance.workspace?.s('name') ?? 'Booqora')} orders\r\n');
    final now = ts(DateTime.now());
    for (final o in list) {
      final items = o.maps('lines').map((l) => '${l['qty'] ?? 1} × ${l['name'] ?? ''}').join('\n');
      b
        ..write('BEGIN:VEVENT\r\n')
        ..write('UID:${o.id}@booqora\r\n')
        ..write('DTSTAMP:$now\r\n')
        ..write('DTSTART:${ts(o.d('startsAt')!)}\r\n')
        ..write('DTEND:${ts(o.d('stopsAt')!)}\r\n')
        ..write('SUMMARY:${esc('Order #${o.i('number')} · ${o.s('customerName', 'No customer')}')}\r\n')
        ..write('DESCRIPTION:${esc('Status: ${Fmt.label(o.s('status'))}\n$items')}\r\n')
        ..write('URL:${Browser.origin}/orders/${o.id}\r\n')
        ..write('END:VEVENT\r\n');
    }
    b.write('END:VCALENDAR\r\n');
    Browser.downloadText(b.toString(), 'booqora-orders.ics', 'text/calendar;charset=utf-8');
    return list.length;
  }
}

// ============================================================================
// Timeline
// ============================================================================

class _Bar {
  final DateTime start, end;
  final Doc doc;
  final bool downtime;
  int lane = 0;
  _Bar(this.start, this.end, this.doc, {this.downtime = false});
}

class _Timeline extends StatelessWidget {
  final List<Doc> products, orders, downtimes;
  final DateTime start, end, today;
  final String view;
  const _Timeline({
    super.key,
    required this.products,
    required this.orders,
    required this.downtimes,
    required this.start,
    required this.end,
    required this.view,
    required this.today,
  });

  static const _headerH = 46.0;
  static const _laneH = 28.0;

  List<DateTime> get _cols {
    if (view == 'day') return [for (var h = 0; h < 24; h++) DateTime(start.year, start.month, start.day, h)];
    final out = <DateTime>[];
    for (var d = start; d.isBefore(end); d = DateTime(d.year, d.month, d.day + 1)) {
      out.add(d);
    }
    return out;
  }

  List<_Bar> _barsFor(Doc p) {
    final now = DateTime.now();
    final bars = <_Bar>[];
    for (final o in orders) {
      if (!_barStatuses.contains(o.s('status')) || !orderHasProduct(o, p.id)) continue;
      final s = o.d('startsAt'), e0 = o.d('stopsAt');
      if (s == null || e0 == null) continue;
      final late = o.s('status') == 'started' && e0.isBefore(now);
      final e = late ? now : e0;
      if (Pricing.overlaps(s, e, start, end)) bars.add(_Bar(s, e, o));
    }
    for (final d in downtimes) {
      if (d.s('productId') != p.id || !{'scheduled', 'started'}.contains(d.s('status'))) continue;
      final s = d.d('startsAt');
      if (s == null) continue;
      final e = d.d('endsAt') ?? end;
      if (Pricing.overlaps(s, e, start, end)) bars.add(_Bar(s, e, d, downtime: true));
    }
    bars.sort((a, b) => a.start.compareTo(b.start));
    final laneEnds = <DateTime>[];
    for (final b in bars) {
      var lane = laneEnds.indexWhere((le) => !le.isAfter(b.start));
      if (lane < 0) {
        laneEnds.add(b.end);
        lane = laneEnds.length - 1;
      } else {
        laneEnds[lane] = b.end;
      }
      b.lane = lane;
    }
    return bars;
  }

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return AppCard(
        child: EmptyState(
          icon: Icons.calendar_month_outlined,
          title: 'Your calendar is empty',
          message: 'Add rental products to see their bookings, pickups, returns and downtime on a timeline.',
          actionLabel: 'Add product',
          onAction: () => context.go('/inventory/products/new'),
        ),
      );
    }
    final cols = _cols;
    final rows = [for (final p in products) (p, _barsFor(p))];
    double rowH(List<_Bar> bars) {
      final lanes = bars.isEmpty ? 1 : bars.map((b) => b.lane).reduce(math.max) + 1;
      return math.max(60, 12 + lanes * _laneH + 4);
    }

    return LayoutBuilder(builder: (context, c) {
      final narrow = c.maxWidth < 700;
      final leftW = narrow ? 132.0 : 220.0;
      final minCol = switch (view) { 'day' => 56.0, 'month' => 42.0, _ => 104.0 };
      final colW = math.max(minCol, (c.maxWidth - leftW - 2) / cols.length);
      final gridW = colW * cols.length;
      final totalMin = end.difference(start).inMinutes.toDouble();
      double x(DateTime t) => (t.difference(start).inMinutes / totalMin * gridW).clamp(0, gridW);
      final now = DateTime.now();
      final showNow = now.isAfter(start) && now.isBefore(end);

      bool isToday(DateTime col) =>
          view == 'day' ? (col.year == now.year && col.month == now.month && col.day == now.day && col.hour == now.hour) : col == today;
      bool isWeekend(DateTime col) => view != 'day' && (col.weekday == DateTime.saturday || col.weekday == DateTime.sunday);

      Widget headerCell(DateTime col) {
        final hl = isToday(col);
        final String top, bottom;
        switch (view) {
          case 'day':
            top = DateFormat('HH:00').format(col);
            bottom = '';
          case 'month':
            top = DateFormat('E').format(col).substring(0, 1);
            bottom = '${col.day}';
          default:
            top = DateFormat('EEE').format(col);
            bottom = DateFormat('d MMM').format(col);
        }
        return Container(
          width: colW,
          height: _headerH,
          decoration: BoxDecoration(
            color: hl ? AppColors.primarySoft : (isWeekend(col) ? const Color(0xFFFBFAFE) : null),
            border: const Border(left: BorderSide(color: Color(0xFFF1EEF7)), bottom: BorderSide(color: AppColors.border)),
          ),
          alignment: Alignment.center,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(top, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: hl ? AppColors.primary : AppColors.muted)),
            if (bottom.isNotEmpty)
              Text(bottom, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: hl ? AppColors.primary : AppColors.ink)),
          ]),
        );
      }

      Widget gridRow(Doc p, List<_Bar> bars, int ri) {
        final h = rowH(bars);
        return SizedBox(
          width: gridW,
          height: h,
          child: Stack(clipBehavior: Clip.hardEdge, children: [
            Row(children: [
              for (final col in cols)
                Container(
                  width: colW,
                  height: h,
                  decoration: BoxDecoration(
                    color: isToday(col) ? AppColors.primarySoft.withValues(alpha: 0.45) : (isWeekend(col) ? const Color(0xFFFBFAFE) : null),
                    border: const Border(left: BorderSide(color: Color(0xFFF1EEF7)), bottom: BorderSide(color: Color(0xFFF1EEF7))),
                  ),
                ),
            ]),
            if (showNow) Positioned(left: x(now) - 1, top: 0, bottom: 0, child: Container(width: 2, color: AppColors.danger.withValues(alpha: 0.6))),
            for (var i = 0; i < bars.length; i++)
              Positioned(
                left: x(bars[i].start) + 1,
                width: math.max(10, x(bars[i].end) - x(bars[i].start) - 2),
                top: 8 + bars[i].lane * _laneH,
                height: _laneH - 4,
                child: _BarView(bar: bars[i], productId: p.id, compact: (x(bars[i].end) - x(bars[i].start)) < 60)
                    .animate(delay: (40 * (ri + i)).clamp(0, 600).ms)
                    .fadeIn(duration: 300.ms)
                    .scaleX(begin: 0.3, end: 1, alignment: Alignment.centerLeft, duration: 450.ms, curve: Curves.easeOutCubic),
              ),
          ]),
        );
      }

      Widget leftCell(Doc p, List<_Bar> bars) {
        final booked = bars.where((b) => !b.downtime).length;
        return InkWell(
          onTap: () => _productDialog(context, p),
          child: Container(
            height: rowH(bars),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1EEF7)))),
            child: Row(children: [
              if (!narrow) ...[Thumb(url: productThumb(p), size: 32), const SizedBox(width: 10)],
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.s('name'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('${p.i('quantity')} in stock${booked > 0 ? ' · $booked booking${booked == 1 ? '' : 's'}' : ''}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                ]),
              ),
            ]),
          ),
        );
      }

      return Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: leftW,
              decoration: const BoxDecoration(border: Border(right: BorderSide(color: AppColors.border))),
              child: Column(children: [
                Container(
                  height: _headerH,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: const BoxDecoration(color: Color(0xFFFAF8FE), border: Border(bottom: BorderSide(color: AppColors.border))),
                  child: Text('PRODUCTS · ${products.length}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.muted)),
                ),
                for (var i = 0; i < rows.length; i++) leftCell(rows[i].$1, rows[i].$2).enterX(i, -0.03),
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: gridW,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(color: const Color(0xFFFAF8FE), child: Row(children: [for (final col in cols) headerCell(col)])),
                    for (var i = 0; i < rows.length; i++) gridRow(rows[i].$1, rows[i].$2, i),
                  ]),
                ),
              ),
            ),
          ]),
          const _Legend(),
        ]),
      ).enter(2);
    });
  }

  void _productDialog(BuildContext context, Doc p) {
    final now = DateTime.now();
    final mine = orders.where((o) => orderHasProduct(o, p.id)).toList();
    final current = mine
        .where((o) => o.s('status') == 'started' || (o.s('status') == 'reserved' && (o.d('startsAt')?.isBefore(now) ?? false)))
        .toList();
    final upcoming = mine.where((o) => {'reserved', 'draft'}.contains(o.s('status')) && (o.d('startsAt')?.isAfter(now) ?? false)).toList()
      ..sort((a, b) => a.d('startsAt')!.compareTo(b.d('startsAt')!));
    var tab = 0;
    showDialog<void>(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setS) {
        final list = tab == 0 ? current : upcoming;
        return dialogFrame(c,
            title: p.s('name'),
            subtitle: priceLabel(p),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close')),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(c);
                  context.go('/inventory/products/${p.id}');
                },
                icon: const Icon(Icons.inventory_2_outlined, size: 18),
                label: const Text('View in inventory'),
              ),
            ],
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Thumb(url: productThumb(p), size: 56),
                const SizedBox(width: 16),
                Expanded(
                  child: Wrap(spacing: 20, runSpacing: 8, children: [
                    _stat('In stock', '${p.i('quantity')}', AppColors.ink),
                    _stat('Available now', '${availableNow(p, orders, downtimes)}', AppColors.success),
                    _stat('Out now', '${unitsOut(p.id, orders)}', AppColors.info),
                  ]),
                ),
              ]),
              const SizedBox(height: 20),
              PillTabs(tabs: const ['Current', 'Upcoming orders'], index: tab, badges: [current.length, upcoming.length], onChanged: (i) => setS(() => tab = i)),
              const SizedBox(height: 12),
              if (list.isEmpty)
                EmptyState(
                  compact: true,
                  icon: Icons.event_busy_outlined,
                  title: tab == 0 ? 'Nothing out right now' : 'No upcoming orders',
                  message: tab == 0 ? 'Orders currently in progress appear here.' : 'Reserved orders starting in the future appear here.',
                )
              else
                for (var i = 0; i < list.length && i < 20; i++)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    leading: StatusPill(list[i].s('status'), dot: false, label: '#${list[i].i('number')}'),
                    title: Text(list[i].s('customerName', 'No customer'), style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${Fmt.dateTime(list[i].d('startsAt'))} → ${Fmt.dateTime(list[i].d('stopsAt'))}', style: const TextStyle(fontSize: 12)),
                    trailing: Text('× ${orderQtyFor(list[i], p.id)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    onTap: () {
                      Navigator.pop(c);
                      context.go('/orders/${list[i].id}');
                    },
                  ).enterX(i),
            ]));
      }),
    );
  }

  Widget _stat(String label, String value, Color color) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      ]);
}

class _BarView extends StatelessWidget {
  final _Bar bar;
  final String productId;
  final bool compact;
  const _BarView({required this.bar, required this.productId, required this.compact});

  @override
  Widget build(BuildContext context) {
    final d = bar.doc;
    if (bar.downtime) {
      final label = '${downtimeReasons[d.s('reason')] ?? 'Downtime'} · ${d.i('quantity', 1)}';
      return Tooltip(
        message: '$label\n${Fmt.dateTime(d.d('startsAt'))} → ${d.d('endsAt') == null ? 'open-ended' : Fmt.dateTime(d.d('endsAt'))}'
            '${d.s('note').isEmpty ? '' : '\n${d.s('note')}'}',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => context.go('/inventory/products/$productId?tab=downtime'),
            child: CustomPaint(
              painter: _StripePainter(),
              child: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.danger.withValues(alpha: 0.6))),
                child: compact
                    ? null
                    : Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.danger)),
              ),
            ),
          ),
        ),
      );
    }
    final status = d.s('status');
    final late = status == 'started' && (d.d('stopsAt')?.isBefore(DateTime.now()) ?? false);
    final Color bg = switch (status) {
      'reserved' => AppColors.primary,
      'started' => late ? AppColors.warning : AppColors.info,
      _ => const Color(0xFFF0EEF5),
    };
    final draft = status == 'draft';
    final fg = draft ? AppColors.inkSoft : Colors.white;
    final qty = orderQtyFor(d, productId);
    final label = '#${d.i('number')} ${d.s('customerName', 'No customer')}${qty > 1 ? ' · ×$qty' : ''}';
    Widget box = Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: draft
          ? null
          : BoxDecoration(
              gradient: LinearGradient(colors: [bg, Color.lerp(bg, Colors.black, 0.12)!]),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [BoxShadow(color: bg.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))],
            ),
      child: compact ? null : Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
    if (draft) box = CustomPaint(painter: _DashedPainter(), child: box);
    return Tooltip(
      message: '$label\n${late ? 'Late · ' : ''}${Fmt.label(status)}\n${Fmt.dateTime(d.d('startsAt'))} → ${Fmt.dateTime(d.d('stopsAt'))}',
      child: HoverLift(lift: 1.5, radius: BorderRadius.circular(6), onTap: () => context.go('/orders/${d.id}'), child: box),
    );
  }
}

class _StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(6));
    canvas.save();
    canvas.clipRRect(r);
    canvas.drawRRect(r, Paint()..color = AppColors.dangerSoft);
    final p = Paint()
      ..color = AppColors.danger.withValues(alpha: 0.18)
      ..strokeWidth = 4;
    for (double x = -size.height; x < size.width; x += 10) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashedPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(6));
    canvas.drawRRect(r, Paint()..color = const Color(0xFFF4F2F8));
    final paint = Paint()
      ..color = const Color(0xFF9C94AE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()..addRRect(r.deflate(0.6));
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 8) {
        canvas.drawPath(m.extractPath(d, math.min(d + 4, m.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Widget swatch, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 18, height: 10, child: swatch),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
        ]);
    Widget solid(Color c) => DecoratedBox(decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(color: Color(0xFFFAF8FE), border: Border(top: BorderSide(color: AppColors.border))),
      child: Wrap(spacing: 18, runSpacing: 8, children: [
        item(solid(AppColors.primary), 'Reserved'),
        item(solid(AppColors.info), 'Started'),
        item(solid(AppColors.warning), 'Late'),
        item(CustomPaint(painter: _DashedPainter()), 'Draft'),
        item(CustomPaint(painter: _StripePainter()), 'Downtime'),
      ]),
    );
  }
}

// ============================================================================
// Agenda
// ============================================================================

class _Agenda extends StatelessWidget {
  final List<Doc> orders;
  final DateTime start, end;
  const _Agenda({required this.orders, required this.start, required this.end});

  bool _in(DateTime? d) => d != null && !d.isBefore(start) && d.isBefore(end);

  @override
  Widget build(BuildContext context) {
    final events = <(DateTime, bool, Doc)>[];
    for (final o in orders) {
      if (!Pricing.holding.contains(o.s('status'))) continue;
      final s = o.d('startsAt'), e = o.d('stopsAt');
      if (o.s('status') == 'reserved' && _in(s)) events.add((s!, true, o));
      if (_in(e)) events.add((e!, false, o));
    }
    events.sort((a, b) => a.$1.compareTo(b.$1));
    final byDay = <DateTime, List<(DateTime, bool, Doc)>>{};
    for (final ev in events) {
      byDay.putIfAbsent(DateTime(ev.$1.year, ev.$1.month, ev.$1.day), () => []).add(ev);
    }
    final pickups = events.where((e) => e.$2).length;
    final returns = events.length - pickups;
    var idx = 0;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.view_agenda_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text('Agenda', style: Theme.of(context).textTheme.titleSmall)),
          smallChip('$pickups pickups', color: AppColors.success, bg: AppColors.successSoft),
          const SizedBox(width: 6),
          smallChip('$returns returns', color: AppColors.info, bg: AppColors.infoSoft),
        ]),
        const SizedBox(height: 12),
        if (events.isEmpty)
          const EmptyState(compact: true, icon: Icons.event_note_outlined, title: 'No pickups or returns', message: 'Nothing scheduled for this period.')
        else
          for (final day in byDay.entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 6),
              child: Text(DateFormat('EEEE d MMMM').format(day.key).toUpperCase(),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.muted)),
            ),
            for (final ev in day.value) _AgendaTile(at: ev.$1, pickup: ev.$2, order: ev.$3).enterX(idx++),
          ],
      ]),
    ).enter(3);
  }
}

class _AgendaTile extends StatelessWidget {
  final DateTime at;
  final bool pickup;
  final Doc order;
  const _AgendaTile({required this.at, required this.pickup, required this.order});

  @override
  Widget build(BuildContext context) {
    final color = pickup ? AppColors.success : AppColors.info;
    final late = !pickup && order.s('status') == 'started' && at.isBefore(DateTime.now());
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: HoverLift(
        lift: 1.5,
        radius: BorderRadius.circular(10),
        onTap: () => context.go('/orders/${order.id}'),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
          child: Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(pickup ? Icons.north_east : Icons.south_west, size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('#${order.i('number')} · ${order.s('customerName', 'No customer')}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text('${pickup ? 'Pickup' : 'Return'} · ${order.i('itemCount', order.maps('lines').length)} items',
                    style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              ]),
            ),
            if (late) ...[const StatusPill('late', dot: false), const SizedBox(width: 6)],
            Text(Fmt.time(at), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}
