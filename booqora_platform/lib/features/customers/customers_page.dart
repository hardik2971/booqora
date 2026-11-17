import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../widgets/common.dart';
import '../../widgets/page.dart';
import '../../widgets/side_panel.dart';
import '../../widgets/table.dart';

/// Default shape of a new customer document.
Map<String, dynamic> newCustomerData({
  required String name,
  String email = '',
  String phone = '',
  String type = 'individual',
  bool marketing = false,
}) => {
  'name': name,
  'email': email,
  'phone': phone,
  'type': type,
  'marketing': marketing,
  'discountPercent': 0,
  'taxProfileId': null,
  'depositMode': 'default',
  'depositValue': 0,
  'addresses': <Map<String, dynamic>>[],
  'customFields': <String, dynamic>{},
  'balanceDue': 0,
  'orderCount': 0,
  'revenue': 0,
  'latestOrderAt': null,
  'tags': <String>[],
};

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  late final Stream<List<Doc>> _stream = Db.watch(C.customers);
  late final Stream<List<Doc>> _ordersStream = Db.watch(C.orders);
  String _q = '';

  /// Customer stats computed live from orders so they are always accurate
  /// (online bookings, bulk status changes and payments included).
  List<Doc> _withStats(List<Doc> customers, List<Doc>? orders) {
    if (orders == null) return customers;
    final by = <String, List<Doc>>{};
    for (final o in orders) {
      final cid = o.s('customerId');
      if (cid.isNotEmpty) (by[cid] ??= []).add(o);
    }
    return [
      for (final c in customers)
        () {
          final os = by[c.id] ?? const <Doc>[];
          final counted = os.where((o) => o.s('status') != 'canceled');
          final billable = counted.where((o) => o.s('status') != 'draft');
          DateTime? latest;
          for (final o in counted) {
            final d = o.d('startsAt') ?? o.created;
            if (latest == null || d.isAfter(latest)) latest = d;
          }
          return Doc(c.id, {
            ...c.data,
            'orderCount': counted.length,
            'revenue': billable.fold<num>(0, (a, o) => a + o.n('total')),
            'balanceDue': billable.fold<num>(0, (a, o) => a + (o.n('due') < 0 ? 0 : o.n('due'))),
            'latestOrderAt': latest,
          });
        }(),
    ];
  }

  Set<String> _types = {};
  Set<String> _marketing = {};
  Set<String> _tags = {};
  DateTimeRange? _created;
  DateTimeRange? _latest;
  bool _importing = false;

  bool _in(DateTime? d, DateTimeRange? r) {
    if (r == null) return true;
    if (d == null) return false;
    return !d.isBefore(r.start) && d.isBefore(r.end);
  }

  List<Doc> _filter(List<Doc> all) {
    final q = _q.trim().toLowerCase();
    return all.where((c) {
      if (q.isNotEmpty &&
          !c.s('name').toLowerCase().contains(q) &&
          !c.s('email').toLowerCase().contains(q) &&
          !c.s('phone').toLowerCase().contains(q)) {
        return false;
      }
      if (_types.isNotEmpty && !_types.contains(c.s('type', 'individual'))) return false;
      if (_marketing.isNotEmpty && !_marketing.contains(c.b('marketing') ? 'subscribed' : 'not_subscribed')) return false;
      if (_tags.isNotEmpty && !c.l<String>('tags').any(_tags.contains)) return false;
      if (!_in(c.created, _created)) return false;
      if (!_in(c.d('latestOrderAt'), _latest)) return false;
      return true;
    }).toList();
  }

  Future<void> _import() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
      final f = files.firstOrNull;
      if (f == null) return;
      setState(() => _importing = true);
      final text = utf8.decode(await f.readAsBytes(), allowMalformed: true);
      final rows = parseCsv(text);
      if (rows.length < 2) throw Exception('The file has no customer rows');
      final head = rows.first.map((h) => h.trim().toLowerCase()).toList();
      final iName = head.indexOf('name');
      if (iName < 0) throw Exception('Missing a "name" column. Expected columns: name, email, phone, type');
      final iEmail = head.indexOf('email'), iPhone = head.indexOf('phone'), iType = head.indexOf('type');
      String cell(List<String> r, int i) => (i >= 0 && i < r.length) ? r[i].trim() : '';
      var created = 0;
      for (final r in rows.skip(1)) {
        final name = cell(r, iName);
        if (name.isEmpty) continue;
        final type = cell(r, iType).toLowerCase() == 'company' ? 'company' : 'individual';
        await Db.create(
          C.customers,
          newCustomerData(name: name, email: cell(r, iEmail), phone: cell(r, iPhone), type: type),
          numberKey: 'customer',
        );
        created++;
      }
      if (mounted) toast(context, 'Imported $created customer${created == 1 ? '' : 's'}');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _export(List<Doc> rows) async {
    await exportCsv(
      'customers',
      ['Number', 'Name', 'Email', 'Phone', 'Type', 'Marketing', 'Created at', 'Latest order', 'Orders', 'Revenue', 'Balance due', 'Tags'],
      [
        for (final c in rows)
          [
            c.i('number'),
            c.s('name'),
            c.s('email'),
            c.s('phone'),
            c.s('type', 'individual'),
            c.b('marketing') ? 'Yes' : 'No',
            Fmt.date(c.created),
            Fmt.date(c.d('latestOrderAt')),
            c.i('orderCount'),
            c.n('revenue'),
            c.n('balanceDue'),
            c.l<String>('tags').join('; '),
          ],
      ],
    );
  }

  Future<void> _bulk(List<Doc> rows, Map<String, dynamic> data, String msg) async {
    try {
      for (final c in rows) {
        await Db.update(C.customers, c.id, data, label: c.s('name'));
      }
      if (mounted) toast(context, msg);
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Doc>>(
      stream: _ordersStream,
      builder: (context, ordersSnap) => StreamBuilder<List<Doc>>(
        stream: _stream,
        builder: (context, snap) {
          final all = _withStats(snap.data ?? const <Doc>[], ordersSnap.data);
          final rows = _filter(all);
          final typeCounts = <String, int>{};
          final mkCounts = <String, int>{};
          final tagCounts = <String, int>{};
          for (final c in all) {
            final t = c.s('type', 'individual');
            typeCounts[t] = (typeCounts[t] ?? 0) + 1;
            final m = c.b('marketing') ? 'subscribed' : 'not_subscribed';
            mkCounts[m] = (mkCounts[m] ?? 0) + 1;
            for (final tag in c.l<String>('tags')) {
              tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
            }
          }
          final tags = tagCounts.keys.toList()..sort();
          final now = DateTime.now();
          final monthStart = DateTime(now.year, now.month);

          return ListLayout(
            header: PageHeader(
              title: 'Customers',
              subtitle: 'Everyone who rents from you, with their orders and balances.',
              actions: [
                SearchField(hint: 'Search name, email or phone', onChanged: (v) => setState(() => _q = v)),
                FilledButton.icon(
                  onPressed: () => context.go('/customers/new'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add customer'),
                ),
              ],
            ),
            filters: [
              FilterSection(
                title: 'Customer type',
                child: CheckFacet(
                  options: const ['individual', 'company'],
                  counts: typeCounts,
                  selected: _types,
                  onChanged: (s) => setState(() => _types = s),
                ),
              ),
              FilterSection(
                title: 'Marketing emails',
                child: CheckFacet(
                  options: const ['subscribed', 'not_subscribed'],
                  counts: mkCounts,
                  selected: _marketing,
                  labeler: (v) => v == 'subscribed' ? 'Subscribed' : 'Not subscribed',
                  onChanged: (s) => setState(() => _marketing = s),
                ),
              ),
              FilterSection(
                title: 'Customer created',
                initiallyExpanded: false,
                child: DateRangeFacet(value: _created, onChanged: (v) => setState(() => _created = v)),
              ),
              FilterSection(
                title: 'Latest order',
                initiallyExpanded: false,
                child: DateRangeFacet(value: _latest, onChanged: (v) => setState(() => _latest = v)),
              ),
              if (tags.isNotEmpty)
                FilterSection(
                  title: 'Tags',
                  child: CheckFacet(
                    options: tags,
                    counts: tagCounts,
                    selected: _tags,
                    labeler: (v) => v,
                    onChanged: (s) => setState(() => _tags = s),
                  ),
                ),
            ],
            footerFilters: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _importing ? null : _import,
                    icon: _importing
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.upload_file_rounded, size: 16),
                    label: const Text('Import'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: rows.isEmpty ? null : () => _export(rows),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Export'),
                  ),
                ),
              ],
            ),
            body: snap.hasError
                ? ErrorView(snap.error!)
                : !snap.hasData
                ? const Padding(padding: EdgeInsets.symmetric(horizontal: 28), child: LoadingView())
                : PageBody(
                    children: [
                      MetricRow(
                        children: [
                          MetricCard(label: 'Customers', value: all.length, icon: Icons.people_alt_outlined, index: 0),
                          MetricCard(
                            label: 'New this month',
                            value: all.where((c) => !c.created.isBefore(monthStart)).length,
                            icon: Icons.person_add_alt_1_outlined,
                            color: AppColors.primaryDeep,
                            index: 1,
                          ),
                          MetricCard(
                            label: 'Total revenue',
                            value: all.fold<num>(0, (a, c) => a + c.n('revenue')),
                            icon: Icons.payments_outlined,
                            format: Fmt.money,
                            color: AppColors.success,
                            index: 2,
                          ),
                          MetricCard(
                            label: 'Balance due',
                            value: all.fold<num>(0, (a, c) => a + c.n('balanceDue')),
                            icon: Icons.account_balance_wallet_outlined,
                            format: Fmt.money,
                            color: AppColors.danger,
                            index: 3,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _table(rows, all.isEmpty),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _table(List<Doc> rows, bool none) {
    return DataTableX<Doc>(
      rows: rows,
      idOf: (c) => c.id,
      noun: 'customers',
      minWidth: 1000,
      onTap: (c) => context.go('/customers/${c.id}'),
      empty: AppCard(
        padding: EdgeInsets.zero,
        child: none
            ? EmptyState(
                icon: Icons.people_alt_outlined,
                title: 'Add your first customer',
                message:
                    'Keep contact details, addresses, discounts and order history in one place — or import a CSV with name, email, phone and type.',
                actionLabel: 'Add customer',
                onAction: () => context.go('/customers/new'),
              )
            : const EmptyState(
                icon: Icons.search_off_rounded,
                title: 'No customers match',
                message: 'Try a different search or clear some filters.',
                compact: true,
              ),
      ),
      bulkActions: [
        BulkAction(
          'Subscribe',
          Icons.mark_email_read_outlined,
          (r) => _bulk(r, {'marketing': true}, '${r.length} subscribed to marketing emails'),
        ),
        BulkAction(
          'Unsubscribe',
          Icons.unsubscribe_outlined,
          (r) => _bulk(r, {'marketing': false}, '${r.length} unsubscribed from marketing emails'),
        ),
        BulkAction('Delete', Icons.delete_outline, (r) async {
          final ok = await confirmDialog(
            context,
            title: 'Delete ${r.length} customer${r.length == 1 ? '' : 's'}?',
            message: 'Their contact details will be removed. Existing orders and documents keep the customer name.',
            confirmLabel: 'Delete',
            danger: true,
          );
          if (!ok) return;
          try {
            for (final c in r) {
              await Db.remove(C.customers, c.id, label: c.s('name'));
            }
            if (mounted) toast(context, 'Deleted ${r.length} customer${r.length == 1 ? '' : 's'}');
          } catch (e) {
            if (mounted) toast(context, friendlyError(e), error: true);
          }
        }, danger: true),
      ],
      columns: [
        ColumnX(
          '#',
          (c) => Text('${c.i('number')}', style: const TextStyle(color: AppColors.muted)),
          sort: (c) => c.i('number'),
          width: 64,
        ),
        ColumnX(
          'Name',
          (c) => CellText(
            c.s('name'),
            subtitle: c.s('type') == 'company' ? 'Company' : (c.s('phone').isEmpty ? null : c.s('phone')),
            leading: Avatar(c.s('name'), size: 32),
          ),
          sort: (c) => c.s('name').toLowerCase(),
          flex: 3,
        ),
        ColumnX('Email', (c) => Text(c.s('email', '—'), overflow: TextOverflow.ellipsis), sort: (c) => c.s('email').toLowerCase(), flex: 3),
        ColumnX('Created at', (c) => Text(Fmt.date(c.created)), sort: (c) => c.created, flex: 2),
        ColumnX('Latest order', (c) => Text(Fmt.date(c.d('latestOrderAt'))), sort: (c) => c.d('latestOrderAt') ?? DateTime(1970), flex: 2),
        ColumnX('Orders', (c) => Text(Fmt.integer(c.i('orderCount'))), sort: (c) => c.i('orderCount'), numeric: true),
        ColumnX(
          'Balance due',
          (c) {
            final b = c.n('balanceDue');
            return Text(
              Fmt.money(b),
              style: TextStyle(color: b > 0 ? AppColors.danger : AppColors.ink, fontWeight: b > 0 ? FontWeight.w600 : null),
            );
          },
          sort: (c) => c.n('balanceDue'),
          numeric: true,
          flex: 2,
        ),
        ColumnX('Tags', (c) {
          final t = c.l<String>('tags');
          if (t.isEmpty) return const SizedBox.shrink();
          return Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [for (final x in t.take(2)) _Tag(x), if (t.length > 2) _Tag('+${t.length - 2}')],
          );
        }, flex: 2),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(6)),
    child: Text(
      text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryDeep),
    ),
  );
}

/// Minimal RFC 4180 CSV parser (quoted fields, escaped quotes, CRLF).
List<List<String>> parseCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false;
  final s = text.startsWith('﻿') ? text.substring(1) : text;
  for (var i = 0; i < s.length; i++) {
    final ch = s[i];
    if (quoted) {
      if (ch == '"') {
        if (i + 1 < s.length && s[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        field.write(ch);
      }
    } else if (ch == '"') {
      quoted = true;
    } else if (ch == ',') {
      row.add(field.toString());
      field.clear();
    } else if (ch == '\n' || ch == '\r') {
      if (ch == '\r' && i + 1 < s.length && s[i + 1] == '\n') i++;
      row.add(field.toString());
      field.clear();
      if (row.any((c) => c.trim().isNotEmpty)) rows.add(row);
      row = <String>[];
    } else {
      field.write(ch);
    }
  }
  row.add(field.toString());
  if (row.any((c) => c.trim().isNotEmpty)) rows.add(row);
  return rows;
}
