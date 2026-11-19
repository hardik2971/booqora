import '../../data/db.dart';

/// Default shape of a new customer document (same as web).
Map<String, dynamic> newCustomerData({
  required String name,
  String email = '',
  String phone = '',
  String type = 'individual',
  bool marketing = false,
}) =>
    {
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

/// Live customer stats computed from orders (never trusts stored counters):
/// orderCount = non-canceled orders; revenue / balanceDue = non-draft, non-canceled.
List<Doc> customersWithStats(List<Doc> customers, List<Doc>? orders) {
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

/// Digits-only phone for tel: / WhatsApp links.
String phoneDigits(String phone) => phone.replaceAll(RegExp(r'[^0-9+]'), '');
