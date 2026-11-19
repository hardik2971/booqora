import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/anim.dart';
import '../../widgets/inputs.dart';
import 'settings_kit.dart';

const _days = [
  ('mon', 'Monday'),
  ('tue', 'Tuesday'),
  ('wed', 'Wednesday'),
  ('thu', 'Thursday'),
  ('fri', 'Friday'),
  ('sat', 'Saturday'),
  ('sun', 'Sunday'),
];

const _units = {'hour': 'hour', 'day': 'day', 'week': 'week', 'month': 'month'};

class RentalPeriodSettings extends StatefulWidget {
  const RentalPeriodSettings({super.key});

  @override
  State<RentalPeriodSettings> createState() => _RentalPeriodSettingsState();
}

class _RentalPeriodSettingsState extends SettingsState<RentalPeriodSettings> {
  @override
  String get section => 'rentalPeriod';

  final _durCount = TextEditingController(text: '1');
  String _durUnit = 'day';

  @override
  void dispose() {
    _durCount.dispose();
    super.dispose();
  }

  Map<String, dynamic> _hours(String day) {
    final h = sub('hours');
    if (h[day] is! Map) {
      h[day] = <String, dynamic>{'open': !(day == 'sun'), 'from': '09:00', 'to': '18:00'};
    } else if (h[day] is! Map<String, dynamic>) {
      h[day] = Map<String, dynamic>.from(h[day] as Map);
    }
    return h[day] as Map<String, dynamic>;
  }

  List<Map<String, dynamic>> get _away {
    if (v['awayRanges'] is! List) v['awayRanges'] = <dynamic>[];
    return (v['awayRanges'] as List).whereType<Map<String, dynamic>>().toList();
  }

  void _addDuration() {
    final n = int.tryParse(_durCount.text.trim()) ?? 0;
    if (n <= 0) return;
    final label = '$n ${_units[_durUnit]}${n == 1 ? '' : 's'}';
    final list = strings('durations');
    if (list.contains(label)) return;
    HapticFeedback.selectionClick();
    put('durations', [...list, label]);
    _durCount.text = '1';
  }

  Future<void> _addAway() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(context: context, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 3));
    if (r == null) return;
    touch(() => (v['awayRanges'] as List).add({
          'from': r.start.toIso8601String().substring(0, 10),
          'to': r.end.toIso8601String().substring(0, 10),
        }));
  }

  String _fmtTime(String hhmm) {
    final p = hhmm.split(':');
    return Fmt.time(DateTime(2026, 1, 1, int.parse(p[0]), int.parse(p[1])));
  }

  Widget _timeDrop(String label, String key, String def) => DropdownX<String>(
        key: ValueKey('$key-${v[key]}-$gen'),
        label: label,
        value: val<String>(key, def),
        items: {for (final t in timeOptions(30)) t: _fmtTime(t)},
        onChanged: (x) => put(key, x),
      );

  /// Compact tappable time chip that opens a picker sheet.
  Widget _timeChip(Map<String, dynamic> h, String k, String def) {
    final times = timeOptions(30);
    final cur = times.contains(h[k]) ? h[k] as String : def;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final now = cur.split(':');
        final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.parse(now[0]), minute: int.parse(now[1])));
        if (t == null) return;
        final m = (t.minute ~/ 30) * 30;
        touch(() => h[k] = '${t.hour.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
        child: Text(_fmtTime(cur), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryDeep)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mode = val<String>('mode', 'datetime');
    final durations = strings('durations');
    final away = _away;

    final durationsEditor = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (durations.isEmpty)
        const Text('No durations yet. Add the rental lengths customers can pick from.', style: TextStyle(color: AppColors.muted, fontSize: 13)),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final d in durations)
          Chip(
            label: Text(d),
            onDeleted: () => put('durations', durations.where((x) => x != d).toList()),
            deleteIconColor: AppColors.primaryDeep,
          ).pop(),
      ]),
      const SizedBox(height: 10),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        SizedBox(width: 76, child: Field.number(label: 'Length', controller: _durCount, decimal: false)),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownX<String>(
            label: 'Unit',
            value: _durUnit,
            items: const {'hour': 'Hours', 'day': 'Days', 'week': 'Weeks', 'month': 'Months'},
            onChanged: (x) => setState(() => _durUnit = x ?? 'day'),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(onPressed: _addDuration, icon: const Icon(Icons.add)),
      ]),
    ]);

    return view(
      title: 'Rental period',
      subtitle: 'How customers and staff choose rental dates and times.',
      children: [
        SGroup(
          title: 'Rental period',
          description: 'How the rental period is selected on orders and in your online store.',
          children: [
            RadioCards<String>(
              value: mode,
              options: const [
                ('datetime', 'Dates and times', 'Customers choose a start and end date.'),
                ('fixed', 'Fixed durations', 'Customers choose a start date and one of your predefined durations.'),
                ('single', 'Single day rental', 'Rentals start and end on the same day.'),
              ],
              onChanged: (x) => put('mode', x),
              expanded: {
                'datetime': CheckTile(
                  value: val<bool>('timeSelection', true),
                  title: 'Enable time selection',
                  subtitle: 'Let customers pick pickup and return times, not just dates.',
                  onChanged: (x) => put('timeSelection', x),
                ),
                'fixed': durationsEditor,
              },
            ),
          ],
        ),
        SGroup(
          title: 'Default order times',
          description: 'Used when an order is created without explicit pickup and return times.',
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _timeDrop('Pickup time', 'pickupTime', '09:00')),
              const SizedBox(width: 12),
              Expanded(child: _timeDrop('Return time', 'returnTime', '17:00')),
            ]),
            SwitchTile(
              value: val<bool>('prefill', true),
              title: 'Pre-fill the times',
              subtitle: 'Automatically fill these times when selecting dates on a new order.',
              onChanged: (x) => put('prefill', x),
            ),
          ],
        ),
        SGroup(
          title: 'Operating hours',
          description: 'Restrict pickups and returns to the hours your business is open.',
          children: [
            SwitchTile(value: val<bool>('hoursEnabled', false), title: 'Enable operating hours', onChanged: (x) => put('hoursEnabled', x)),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: !val<bool>('hoursEnabled', false)
                  ? const SizedBox(width: double.infinity)
                  : Column(children: [
                      for (final (key, label) in _days)
                        Builder(builder: (context) {
                          final h = _hours(key);
                          final open = h['open'] == true;
                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1EEF7)))),
                            child: Row(children: [
                              Switch(value: open, onChanged: (x) => touch(() => h['open'] = x)),
                              const SizedBox(width: 6),
                              Expanded(child: Text(label.substring(0, 3), style: const TextStyle(fontWeight: FontWeight.w600))),
                              if (!open)
                                const Text('Closed', style: TextStyle(color: AppColors.muted))
                              else ...[
                                _timeChip(h, 'from', '09:00'),
                                const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('–', style: TextStyle(color: AppColors.muted))),
                                _timeChip(h, 'to', '18:00'),
                              ],
                            ]),
                          );
                        }),
                    ]),
            ),
          ],
        ),
        SGroup(
          title: 'Time interval',
          description: 'Granularity of the time pickers for orders and the online store.',
          children: [
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 15, label: Text('15 min')),
                ButtonSegment(value: 30, label: Text('30 min')),
                ButtonSegment(value: 60, label: Text('1 hour')),
              ],
              selected: {numVal('interval', 60).toInt()},
              onSelectionChanged: (s) {
                HapticFeedback.selectionClick();
                put('interval', s.first);
              },
            ),
          ],
        ),
        SGroup(
          title: 'Away mode',
          description: 'Block bookings while you are closed, for example during holidays.',
          children: [
            SwitchTile(
              value: val<bool>('awayEnabled', false),
              title: 'Enable away mode',
              subtitle: 'No pickups or returns can be scheduled in these date ranges.',
              onChanged: (x) => put('awayEnabled', x),
            ),
            if (val<bool>('awayEnabled', false)) ...[
              for (var i = 0; i < away.length; i++)
                ListRow(
                  leading: const IconBubble(Icons.beach_access_outlined, size: 36),
                  title: '${Fmt.date(DateTime.tryParse(away[i]['from']?.toString() ?? ''))} – '
                      '${Fmt.date(DateTime.tryParse(away[i]['to']?.toString() ?? ''))}',
                  trailing: IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => touch(() => (v['awayRanges'] as List).remove(away[i])),
                  ),
                ).enterX(i),
              AddRowButton(label: 'Add date range', icon: Icons.date_range, onTap: _addAway),
            ],
          ],
        ),
        SGroup(
          title: 'Manual orders',
          children: [
            SwitchTile(
              value: val<bool>('restrictManual', false),
              title: 'Apply rental restrictions to manual orders',
              subtitle: 'Operating hours, away mode and fixed durations also apply to orders created in the back office.',
              onChanged: (x) => put('restrictManual', x),
            ),
          ],
        ),
      ],
    );
  }
}
