import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
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

  Widget _timeDrop(String label, String key, String def) => DropdownX<String>(
        key: ValueKey('$key-${v[key]}'),
        label: label,
        value: val<String>(key, def),
        items: {for (final t in timeOptions(30)) t: _fmtTime(t)},
        onChanged: (x) => put(key, x),
      );

  String _fmtTime(String hhmm) {
    final p = hhmm.split(':');
    return Fmt.time(DateTime(2026, 1, 1, int.parse(p[0]), int.parse(p[1])));
  }

  @override
  Widget build(BuildContext context) {
    final mode = val<String>('mode', 'datetime');
    final durations = strings('durations');
    final times = timeOptions(30);
    _away; // ensure list exists

    final durationsEditor = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (durations.isEmpty)
        const Text('No durations yet. Add the rental lengths customers can pick from.', style: TextStyle(color: AppColors.muted, fontSize: 13)),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final d in durations)
          Chip(
            label: Text(d),
            onDeleted: () => put('durations', durations.where((x) => x != d).toList()),
            deleteIconColor: AppColors.primaryDeep,
          ),
      ]),
      const SizedBox(height: 10),
      Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.end, children: [
        SizedBox(width: 90, child: Field.number(label: 'Length', controller: _durCount, decimal: false)),
        SizedBox(
          width: 140,
          child: DropdownX<String>(label: 'Unit', value: _durUnit, items: const {'hour': 'Hours', 'day': 'Days', 'week': 'Weeks', 'month': 'Months'}, onChanged: (x) => setState(() => _durUnit = x ?? 'day')),
        ),
        OutlinedButton.icon(onPressed: _addDuration, icon: const Icon(Icons.add, size: 18), label: const Text('Add duration')),
      ]),
    ]);

    return view(
      title: 'Rental period',
      subtitle: 'How customers and staff choose rental dates and times.',
      children: [
        FormSection(
          index: 0,
          title: 'Rental period',
          description: 'Choose how the rental period is selected on orders and in your online store.',
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
        FormSection(
          index: 1,
          title: 'Default order times',
          description: 'Times used when an order is created without explicit pickup and return times.',
          children: [
            FieldGrid(children: [
              _timeDrop('Pickup time', 'pickupTime', '09:00'),
              _timeDrop('Return time', 'returnTime', '17:00'),
            ]),
            CheckTile(
              value: val<bool>('prefill', true),
              title: 'Pre-fill the times',
              subtitle: 'Automatically fill these times when selecting dates on a new order.',
              onChanged: (x) => put('prefill', x),
            ),
          ],
        ),
        FormSection(
          index: 2,
          title: 'Operating hours',
          description: 'Restrict pickups and returns to the hours your business is open.',
          children: [
            SwitchTile(
              value: val<bool>('hoursEnabled', false),
              title: 'Enable operating hours',
              onChanged: (x) => put('hoursEnabled', x),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
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
                            child: Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                              SizedBox(
                                width: 150,
                                child: Row(children: [
                                  Switch(value: open, onChanged: (x) => touch(() => h['open'] = x)),
                                  const SizedBox(width: 6),
                                  Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                                ]),
                              ),
                              if (!open)
                                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Closed', style: TextStyle(color: AppColors.muted)))
                              else ...[
                                _smallTime(times, h, 'from', '09:00'),
                                const Text('to', style: TextStyle(color: AppColors.muted)),
                                _smallTime(times, h, 'to', '18:00'),
                              ],
                            ]),
                          );
                        }),
                    ]),
            ),
          ],
        ),
        FormSection(
          index: 3,
          title: 'Time interval',
          description: 'Granularity of the time pickers for orders and the online store.',
          children: [
            DropdownX<int>(
              label: 'Time interval',
              value: numVal('interval', 60).toInt(),
              items: const {15: '15 minutes', 30: '30 minutes', 60: '1 hour'},
              onChanged: (x) => put('interval', x ?? 60),
            ),
          ],
        ),
        FormSection(
          index: 4,
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
              for (var i = 0; i < _away.length; i++)
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                  child: Row(children: [
                    const Icon(Icons.beach_access_outlined, size: 18, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${Fmt.date(DateTime.tryParse(_away[i]['from']?.toString() ?? ''))} – ${Fmt.date(DateTime.tryParse(_away[i]['to']?.toString() ?? ''))}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => touch(() => (v['awayRanges'] as List).removeAt(i)),
                    ),
                  ]),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(onPressed: _addAway, icon: const Icon(Icons.date_range, size: 18), label: const Text('Add date range')),
              ),
            ],
          ],
        ),
        FormSection(
          index: 5,
          title: 'Manual orders',
          description: 'Whether staff-created orders follow the same restrictions as online bookings.',
          children: [
            CheckTile(
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

  Widget _smallTime(List<String> times, Map<String, dynamic> h, String k, String def) {
    final cur = times.contains(h[k]) ? h[k] as String : def;
    return SizedBox(
      width: 130,
      child: DropdownButtonFormField<String>(
        key: ValueKey('${h.hashCode}-$k-$cur'),
        initialValue: cur,
        isDense: true,
        decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
        items: [for (final t in times) DropdownMenuItem(value: t, child: Text(_fmtTime(t)))],
        onChanged: (x) => touch(() => h[k] = x ?? def),
      ),
    );
  }
}
