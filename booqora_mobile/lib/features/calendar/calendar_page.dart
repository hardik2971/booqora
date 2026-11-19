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
import '../../widgets/mobile.dart';
import '../inventory/inv_common.dart';

const _barStatuses = {'draft', 'reserved', 'started'};

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// A pickup (reserved order starting) or return (holding order ending).
class _Event {
  final DateTime at;
  final bool pickup;
  final Doc order;
  const _Event(this.at, this.pickup, this.order);
}

List<_Event> _events(List<Doc> orders, DateTime start, DateTime end) {
  bool inRange(DateTime? d) => d != null && !d.isBefore(start) && d.isBefore(end);
  final out = <_Event>[];
  for (final o in orders) {
    if (!Pricing.holding.contains(o.s('status'))) continue;
    final s = o.d('startsAt'), e = o.d('stopsAt');
    if (o.s('status') == 'reserved' && inRange(s)) out.add(_Event(s!, true, o));
    if (inRange(e)) out.add(_Event(e!, false, o));
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out;
}

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _selected = _day(DateTime.now());
  String _view = 'agenda';
  int _span = 7;
  int _dir = 1;

  DateTime get _today => _day(DateTime.now());

  DateTime get _weekStart {
    final a = _selected;
    final sunday = Session.instance.setting('general', 'weekStart', 'monday') == 'sunday';
    final offset = sunday ? a.weekday % 7 : a.weekday - 1;
    return DateTime(a.year, a.month, a.day - offset);
  }

  void _shiftWeek(int dir) {
    HapticFeedback.selectionClick();
    setState(() {
      _dir = dir;
      _selected = DateTime(_selected.year, _selected.month, _selected.day + 7 * dir);
    });
  }

  void _goToday() {
    HapticFeedback.lightImpact();
    setState(() {
      _dir = _selected.isAfter(_today) ? -1 : 1;
      _selected = _today;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LiveData.of(
      const [C.products, C.orders, C.downtimes],
      loading: MPage(title: 'Calendar', slivers: const [SliverToBoxAdapter(child: LoadingView())]),
      builder: (context, d) {
        final products = d[C.products]!.where((p) => p.s('status', 'active') == 'active' && p.s('type', 'rental') == 'rental').toList()
          ..sort((a, b) => a.s('name').toLowerCase().compareTo(b.s('name').toLowerCase()));
        final orders = d[C.orders]!;
        final downtimes = d[C.downtimes]!;
        final ws = _weekStart;
        final weekEvents = _events(orders, ws, DateTime(ws.year, ws.month, ws.day + 7));
        return MPage(
          title: 'Calendar',
          actions: [
            IconButton(
              tooltip: 'Check availability',
              icon: const Icon(Icons.event_available_outlined),
              onPressed: () => _checkAvailability(context, products, orders, downtimes),
            ),
            IconButton(tooltip: 'Share calendar (.ics)', icon: const Icon(Icons.ios_share_rounded), onPressed: () => _shareIcs(context, orders)),
          ],
          header: _ViewSwitch(value: _view, onChanged: (v) => setState(() => _view = v)),
          headerHeight: 62,
          slivers: [
            SPad(_monthHeader(context), padding: const EdgeInsets.fromLTRB(20, 0, 12, 6)),
            SliverToBoxAdapter(child: _weekStrip(ws, weekEvents)),
            const SliverToBoxAdapter(child: SizedBox(height: 4)),
            ...(_view == 'agenda' ? _agenda(context, orders) : _timeline(context, products, orders, downtimes)),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------------ header
  Widget _monthHeader(BuildContext context) {
    final label = DateFormat('MMMM yyyy').format(_selected);
    final isToday = _sameDay(_selected, _today);
    return Row(children: [
      Expanded(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (c, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(position: Tween(begin: Offset(0, 0.3 * _dir), end: Offset.zero).animate(a), child: c),
          ),
          layoutBuilder: (cur, prev) => Stack(alignment: Alignment.centerLeft, children: [...prev, ?cur]),
          child: Text(label, key: ValueKey(label), style: Theme.of(context).textTheme.titleLarge),
        ),
      ),
      AnimatedOpacity(
        opacity: isToday ? 0.4 : 1,
        duration: const Duration(milliseconds: 200),
        child: TextButton(onPressed: isToday ? null : _goToday, child: const Text('Today')),
      ),
      _RoundBtn(icon: Icons.chevron_left_rounded, onTap: () => _shiftWeek(-1)),
      const SizedBox(width: 6),
      _RoundBtn(icon: Icons.chevron_right_rounded, onTap: () => _shiftWeek(1)),
    ]);
  }

  Widget _weekStrip(DateTime ws, List<_Event> events) {
    final days = [for (var i = 0; i < 7; i++) DateTime(ws.year, ws.month, ws.day + i)];
    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v.abs() < 200) return;
        _shiftWeek(v < 0 ? 1 : -1);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (c, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(position: Tween(begin: Offset(0.15 * _dir, 0), end: Offset.zero).animate(a), child: c),
          ),
          layoutBuilder: (cur, prev) => Stack(children: [...prev, ?cur]),
          child: Row(
            key: ValueKey(ws),
            children: [
              for (final day in days)
                Expanded(
                  child: _DayCell(
                    day: day,
                    selected: _sameDay(day, _selected),
                    today: _sameDay(day, _today),
                    pickups: events.where((e) => e.pickup && _sameDay(e.at, day)).length,
                    returns: events.where((e) => !e.pickup && _sameDay(e.at, day)).length,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selected = day);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ agenda
  List<Widget> _agenda(BuildContext context, List<Doc> orders) {
    final start = _selected;
    final end = DateTime(start.year, start.month, start.day + 7);
    final events = _events(orders, start, end);
    final byDay = <DateTime, List<_Event>>{};
    for (final ev in events) {
      byDay.putIfAbsent(_day(ev.at), () => []).add(ev);
    }
    final pickups = events.where((e) => e.pickup).length;
    final returns = events.length - pickups;
    final children = <Widget>[];
    var idx = 0;
    for (final day in byDay.entries) {
      final rel = _sameDay(day.key, _today)
          ? 'Today'
          : _sameDay(day.key, _today.add(const Duration(days: 1)))
              ? 'Tomorrow'
              : DateFormat('EEEE').format(day.key);
      children.add(SectionLabel('$rel · ${DateFormat('d MMMM').format(day.key)}',
          trailing: Text('${day.value.length}', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700, fontSize: 12))));
      for (final ev in day.value) {
        children.add(Padding(padding: const EdgeInsets.only(bottom: 10), child: _AgendaTile(event: ev).enter(idx++)));
      }
    }
    return [
      SPad(
        Row(children: [
          Expanded(
            child: Text('Next 7 days from ${Fmt.shortDate(start)}', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          smallChip('$pickups pickups', color: AppColors.success, bg: AppColors.successSoft, icon: Icons.north_east_rounded),
          const SizedBox(width: 6),
          smallChip('$returns returns', color: AppColors.info, bg: AppColors.infoSoft, icon: Icons.south_west_rounded),
        ]),
        padding: const EdgeInsets.fromLTRB(20, 4, 16, 0),
      ),
      if (events.isEmpty)
        SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.event_note_outlined,
            title: 'No pickups or returns',
            message: 'Nothing is scheduled for the 7 days from ${Fmt.shortDate(start)}. Select another day or week.',
            actionLabel: 'New order',
            onAction: () => context.push('/orders/new'),
          ),
        )
      else
        SPad(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children), padding: const EdgeInsets.fromLTRB(16, 0, 16, 0)),
    ];
  }

  // ------------------------------------------------------------------ timeline
  List<Widget> _timeline(BuildContext context, List<Doc> products, List<Doc> orders, List<Doc> downtimes) {
    final ws = _weekStart;
    final end = DateTime(ws.year, ws.month, ws.day + _span);
    return [
      SPad(
        Row(children: [
          Expanded(
            child: Text('${Fmt.shortDate(ws)} – ${Fmt.shortDate(end.subtract(const Duration(days: 1)))}',
                style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          SegmentedButton<int>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [ButtonSegment(value: 7, label: Text('7 days')), ButtonSegment(value: 14, label: Text('14 days'))],
            selected: {_span},
            onSelectionChanged: (v) {
              HapticFeedback.selectionClick();
              setState(() => _span = v.first);
            },
          ),
        ]),
        padding: const EdgeInsets.fromLTRB(20, 4, 16, 8),
      ),
      SPad(
        _Timeline(
          key: ValueKey('$ws-$_span'),
          products: products,
          orders: orders,
          downtimes: downtimes,
          start: ws,
          end: end,
          days: _span,
          today: _today,
          selected: _selected,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    ];
  }

  // ------------------------------------------------------------------ availability
  Future<void> _checkAvailability(BuildContext context, List<Doc> products, List<Doc> orders, List<Doc> downtimes) async {
    if (products.isEmpty) return toast(context, 'Add a rental product first', error: true);
    HapticFeedback.selectionClick();
    Doc product = products.first;
    DateTime? from = DateTime(_selected.year, _selected.month, _selected.day, 9);
    DateTime? until = from.add(const Duration(days: 1));
    await showAppSheet<void>(
      context,
      title: 'Check availability',
      builder: (c) => StatefulBuilder(builder: (c, setS) {
        final valid = from != null && until != null && until!.isAfter(from!);
        final avail = valid ? Pricing.available(product, from!, until!, orders, downtimes) : 0;
        final total = product.i('quantity');
        final color = availColor(avail, total);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('See how many units are free for a period, including buffers and downtime.', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          const FieldLabel('Product'),
          PressScale(
            onTap: () async {
              final p = await pickProductSheet(c, products, title: 'Select product');
              if (p != null) setS(() => product = p);
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              child: Row(children: [
                Thumb(url: productThumb(product), size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(product.s('name'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('$total in stock', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ]),
                ),
                const Icon(Icons.unfold_more_rounded, color: AppColors.muted),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          DateTimeField(label: 'From', value: from, onChanged: (v) => setS(() => from = v)),
          const SizedBox(height: 16),
          DateTimeField(label: 'Until', value: until, onChanged: (v) => setS(() => until = v)),
          const SizedBox(height: 20),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0.04)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: !valid
                ? const Text('"Until" must be after "From"', textAlign: TextAlign.center, style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600))
                : Column(children: [
                    TweenAnimationBuilder<double>(
                      key: ValueKey('${product.id}-$avail-$from-$until'),
                      tween: Tween(begin: 0, end: math.max(avail, 0).toDouble()),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, _) => Text(avail < 0 ? '$avail' : '${v.round()}',
                          style: TextStyle(fontSize: 72, fontWeight: FontWeight.w800, color: color, height: 1, letterSpacing: -2)),
                    ).animate(key: ValueKey('${product.id}-$avail')).scaleXY(begin: 0.8, end: 1, duration: 420.ms, curve: Curves.easeOutBack),
                    const SizedBox(height: 8),
                    Text('of $total unit${total == 1 ? '' : 's'} available', style: const TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('${Fmt.dateTime(from)} → ${Fmt.dateTime(until)}', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  ]),
          ),
          SheetActions(label: 'Done', onPressed: () => Navigator.pop(c)),
        ]);
      }),
    );
  }

  // ------------------------------------------------------------------ ics
  Future<void> _shareIcs(BuildContext context, List<Doc> orders) async {
    HapticFeedback.selectionClick();
    String ts(DateTime d) => '${DateFormat("yyyyMMdd'T'HHmmss").format(d.toUtc())}Z';
    String esc(String s) => s.replaceAll('\\', '\\\\').replaceAll(';', '\\;').replaceAll(',', '\\,').replaceAll('\n', '\\n');
    final list = orders.where((o) => Pricing.holding.contains(o.s('status')) && o.d('startsAt') != null && o.d('stopsAt') != null).toList();
    if (list.isEmpty) return toast(context, 'No reserved or started orders to export', error: true);
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
    try {
      await Browser.downloadText(b.toString(), 'booqora-orders.ics', 'text/calendar');
    } catch (e) {
      if (context.mounted) toast(context, friendlyError(e), error: true);
    }
  }
}

// ============================================================================
// Header widgets
// ============================================================================

class _ViewSwitch extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _ViewSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const opts = [('agenda', 'Agenda', Icons.view_agenda_outlined), ('timeline', 'Timeline', Icons.view_timeline_outlined)];
    final idx = opts.indexWhere((o) => o.$1 == value);
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFEDE9F6), borderRadius: BorderRadius.circular(14)),
      child: Stack(children: [
        AnimatedAlign(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: idx == 0 ? Alignment.centerLeft : Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: 0.5,
            heightFactor: 1,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(11),
                boxShadow: const [BoxShadow(color: Color(0x1A1C0938), blurRadius: 8, offset: Offset(0, 2))],
              ),
            ),
          ),
        ),
        Row(children: [
          for (final o in opts)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (o.$1 == value) return;
                  HapticFeedback.selectionClick();
                  onChanged(o.$1);
                },
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(o.$3, size: 18, color: o.$1 == value ? AppColors.primary : AppColors.muted),
                  const SizedBox(width: 6),
                  Text(o.$2, style: TextStyle(fontWeight: FontWeight.w700, color: o.$1 == value ? AppColors.ink : AppColors.muted)),
                ]),
              ),
            ),
        ]),
      ]),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => PressScale(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: AppColors.border)),
          child: Icon(icon, color: AppColors.primary),
        ),
      );
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final bool selected;
  final bool today;
  final int pickups;
  final int returns;
  final VoidCallback onTap;
  const _DayCell({required this.day, required this.selected, required this.today, required this.pickups, required this.returns, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : (today ? AppColors.primary : AppColors.ink);
    Widget dot(Color c) => Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(color: selected ? Colors.white : c, shape: BoxShape.circle),
        );
    return PressScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.brandGradient : null,
          color: selected ? null : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? Colors.transparent : (today ? AppColors.primary : AppColors.border), width: today && !selected ? 1.5 : 1),
          boxShadow: selected ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.32), blurRadius: 14, offset: const Offset(0, 6))] : null,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(DateFormat('E').format(day).substring(0, 2).toUpperCase(),
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: selected ? Colors.white70 : AppColors.muted)),
          const SizedBox(height: 4),
          Text('${day.day}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: fg)),
          const SizedBox(height: 5),
          SizedBox(
            height: 6,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (pickups > 0) dot(AppColors.success),
              if (returns > 0) dot(AppColors.info),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ============================================================================
// Agenda tile
// ============================================================================

class _AgendaTile extends StatelessWidget {
  final _Event event;
  const _AgendaTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final order = event.order;
    final pickup = event.pickup;
    final color = pickup ? AppColors.success : AppColors.info;
    final late = !pickup && order.s('status') == 'started' && event.at.isBefore(DateTime.now());
    final lines = order.maps('lines');
    final itemsLabel = lines.take(2).map((l) => '${l['qty'] ?? 1}× ${l['name'] ?? ''}').join(', ') + (lines.length > 2 ? ' +${lines.length - 2}' : '');
    return MTile(
      onTap: () => context.push('/orders/${order.id}'),
      leading: Container(
        width: 52,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Icon(pickup ? Icons.north_east_rounded : Icons.south_west_rounded, size: 18, color: color),
          const SizedBox(height: 2),
          Text(Fmt.time(event.at), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: color)),
        ]),
      ),
      title: '#${order.i('number')} · ${order.s('customerName', 'No customer')}',
      subtitle: '${pickup ? 'Pickup' : 'Return'} · ${itemsLabel.isEmpty ? '${order.i('itemCount')} items' : itemsLabel}',
      trailing: late ? const StatusPill('late') : StatusPill(order.s('status')),
    );
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
  final DateTime start, end, today, selected;
  final int days;
  const _Timeline({
    super.key,
    required this.products,
    required this.orders,
    required this.downtimes,
    required this.start,
    required this.end,
    required this.days,
    required this.today,
    required this.selected,
  });

  static const _headerH = 50.0;
  static const _laneH = 30.0;
  static const _leftW = 118.0;
  static const _colW = 58.0;

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
      return EmptyState(
        icon: Icons.calendar_month_outlined,
        title: 'Your calendar is empty',
        message: 'Add rental products to see their bookings, pickups, returns and downtime on a timeline.',
        actionLabel: 'Add product',
        onAction: () => context.push('/inventory/products/new'),
      );
    }
    final cols = [for (var i = 0; i < days; i++) DateTime(start.year, start.month, start.day + i)];
    final rows = [for (final p in products) (p, _barsFor(p))];
    double rowH(List<_Bar> bars) {
      final lanes = bars.isEmpty ? 1 : bars.map((b) => b.lane).reduce(math.max) + 1;
      return math.max(62, 14 + lanes * _laneH + 4);
    }

    return LayoutBuilder(builder: (context, c) {
      final colW = math.max(_colW, (c.maxWidth - _leftW - 2) / cols.length);
      final gridW = colW * cols.length;
      final totalMin = end.difference(start).inMinutes.toDouble();
      double x(DateTime t) => (t.difference(start).inMinutes / totalMin * gridW).clamp(0, gridW);
      final now = DateTime.now();
      final showNow = now.isAfter(start) && now.isBefore(end);
      bool isWeekend(DateTime d) => d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;

      Widget headerCell(DateTime col) {
        final hl = col == today;
        final sel = col == selected;
        return Container(
          width: colW,
          height: _headerH,
          decoration: BoxDecoration(
            color: hl ? AppColors.primarySoft : (isWeekend(col) ? const Color(0xFFFBFAFE) : null),
            border: const Border(left: BorderSide(color: Color(0xFFF1EEF7)), bottom: BorderSide(color: AppColors.border)),
          ),
          alignment: Alignment.center,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(DateFormat('EEE').format(col), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: hl ? AppColors.primary : AppColors.muted)),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: sel ? BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(8)) : null,
              child: Text('${col.day}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: sel ? Colors.white : (hl ? AppColors.primary : AppColors.ink))),
            ),
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
                    color: col == today ? AppColors.primarySoft.withValues(alpha: 0.45) : (isWeekend(col) ? const Color(0xFFFBFAFE) : null),
                    border: const Border(left: BorderSide(color: Color(0xFFF1EEF7)), bottom: BorderSide(color: Color(0xFFF1EEF7))),
                  ),
                ),
            ]),
            if (showNow) Positioned(left: x(now) - 1, top: 0, bottom: 0, child: Container(width: 2, color: AppColors.danger.withValues(alpha: 0.6))),
            for (var i = 0; i < bars.length; i++)
              Positioned(
                left: x(bars[i].start) + 1,
                width: math.max(12, x(bars[i].end) - x(bars[i].start) - 2),
                top: 9 + bars[i].lane * _laneH,
                height: _laneH - 5,
                child: _BarView(bar: bars[i], productId: p.id, compact: (x(bars[i].end) - x(bars[i].start)) < 54)
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
          onTap: () => context.push('/inventory/products/${p.id}'),
          child: Container(
            height: rowH(bars),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1EEF7)))),
            child: Row(children: [
              Thumb(url: productThumb(p), size: 26),
              const SizedBox(width: 8),
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.s('name'), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, height: 1.2)),
                  const SizedBox(height: 2),
                  Text('${p.i('quantity')} units${booked > 0 ? ' · $booked' : ''}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
                ]),
              ),
            ]),
          ),
        );
      }

      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: const [BoxShadow(color: Color(0x0A1C0938), blurRadius: 14, offset: Offset(0, 6))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: _leftW,
              decoration: const BoxDecoration(border: Border(right: BorderSide(color: AppColors.border))),
              child: Column(children: [
                Container(
                  height: _headerH,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: const BoxDecoration(color: Color(0xFFFAF8FE), border: Border(bottom: BorderSide(color: AppColors.border))),
                  child: Text('PRODUCTS · ${products.length}',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.muted)),
                ),
                for (var i = 0; i < rows.length; i++) leftCell(rows[i].$1, rows[i].$2).enterX(i, -0.03),
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
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
      ).enter(1);
    });
  }
}

class _BarView extends StatelessWidget {
  final _Bar bar;
  final String productId;
  final bool compact;
  const _BarView({required this.bar, required this.productId, required this.compact});

  void _details(BuildContext context) {
    HapticFeedback.mediumImpact();
    final d = bar.doc;
    if (bar.downtime) {
      showAppSheet<void>(context, title: '${downtimeReasons[d.s('reason')] ?? 'Downtime'} · ${d.s('productName')}', builder: (c) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          KV('Quantity', '${d.i('quantity', 1)}'),
          KV('Status', Fmt.label(d.s('status'))),
          KV('From', Fmt.dateTime(d.d('startsAt'))),
          KV('Until', d.d('endsAt') == null ? 'Open-ended' : Fmt.dateTime(d.d('endsAt'))),
          if (d.s('note').isNotEmpty) ...[const SizedBox(height: 8), Text(d.s('note'), style: const TextStyle(color: AppColors.inkSoft))],
          SheetActions(
            label: 'View product',
            icon: Icons.inventory_2_outlined,
            onPressed: () {
              Navigator.pop(c);
              context.push('/inventory/products/$productId?tab=downtime');
            },
          ),
        ]);
      });
      return;
    }
    final late = d.s('status') == 'started' && (d.d('stopsAt')?.isBefore(DateTime.now()) ?? false);
    showAppSheet<void>(context, title: 'Order #${d.i('number')}', builder: (c) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(d.s('customerName', 'No customer'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
          if (late) const StatusPill('late') else StatusPill(d.s('status')),
        ]),
        const SizedBox(height: 10),
        KV('Pickup', Fmt.dateTime(d.d('startsAt'))),
        KV('Return', Fmt.dateTime(d.d('stopsAt'))),
        KV('Quantity of this product', '${orderQtyFor(d, productId)}'),
        if (d.n('total') > 0) KV('Total', Fmt.money(d.n('total')), bold: true),
        SheetActions(
          label: 'Open order',
          icon: Icons.receipt_long_outlined,
          onPressed: () {
            Navigator.pop(c);
            context.push('/orders/${d.id}');
          },
        ),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = bar.doc;
    if (bar.downtime) {
      final label = '${downtimeReasons[d.s('reason')] ?? 'Downtime'} · ${d.i('quantity', 1)}';
      return GestureDetector(
        onTap: () => context.push('/inventory/products/$productId?tab=downtime'),
        onLongPress: () => _details(context),
        child: CustomPaint(
          painter: _StripePainter(),
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(7), border: Border.all(color: AppColors.danger.withValues(alpha: 0.6))),
            child: compact
                ? null
                : Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.danger)),
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
              borderRadius: BorderRadius.circular(7),
              boxShadow: [BoxShadow(color: bg.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))],
            ),
      child: compact ? null : Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
    if (draft) box = CustomPaint(painter: _DashedPainter(), child: box);
    return PressScale(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/orders/${d.id}');
      },
      onLongPress: () => _details(context),
      child: box,
    );
  }
}

class _StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(7));
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
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(7));
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
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
        ]);
    Widget solid(Color c) => DecoratedBox(decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(color: Color(0xFFFAF8FE), border: Border(top: BorderSide(color: AppColors.border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 14, runSpacing: 8, children: [
          item(solid(AppColors.primary), 'Reserved'),
          item(solid(AppColors.info), 'Started'),
          item(solid(AppColors.warning), 'Late'),
          item(CustomPaint(painter: _DashedPainter()), 'Draft'),
          item(CustomPaint(painter: _StripePainter()), 'Downtime'),
        ]),
        const SizedBox(height: 6),
        const Text('Tap a bar to open it · long-press for details', style: TextStyle(fontSize: 11, color: AppColors.muted)),
      ]),
    );
  }
}
