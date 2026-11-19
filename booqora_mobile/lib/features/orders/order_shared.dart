import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

import '../../core/format.dart';
import '../../data/db.dart';
import '../../data/pricing.dart';
import '../../data/schema.dart';
import '../../data/session.dart';

/// Shared order helpers (ported 1:1 from the web platform so data stays consistent).
class OrderX {
  /// "#12" for numbered orders, "Web order" for online orders without a number.
  static String label(Doc o) {
    final n = o.i('number');
    if (n > 0) return '#$n';
    return o.s('source') == 'online' ? 'Web order' : 'New order';
  }

  static bool isLate(Doc o, [DateTime? now]) {
    final t = now ?? DateTime.now();
    final s = o.d('startsAt'), e = o.d('stopsAt');
    final st = o.s('status');
    if (st == 'started' && e != null && e.isBefore(t)) return true;
    if (st == 'reserved' && s != null && s.isBefore(t)) return true;
    return false;
  }

  static bool isUpcoming(Doc o, [DateTime? now]) {
    final s = o.d('startsAt');
    return o.s('status') == 'reserved' && s != null && s.isAfter(now ?? DateTime.now());
  }

  /// Product lines of [o] that exceed availability in the order period.
  /// Returns productName -> shortage units.
  static Map<String, int> shortages(Doc o, Map<String, Doc> products, List<Doc> orders, List<Doc> downtimes) {
    final out = <String, int>{};
    final st = o.s('status');
    if (!{'draft', 'reserved', 'started'}.contains(st)) return out;
    final s = o.d('startsAt'), e = o.d('stopsAt');
    if (s == null || e == null) return out;
    final qtyByProduct = <String, int>{};
    for (final l in o.maps('lines')) {
      final pid = l['productId'];
      if (pid is! String || pid.isEmpty) continue;
      qtyByProduct[pid] = (qtyByProduct[pid] ?? 0) + ((l['qty'] as num?) ?? 0).toInt();
    }
    qtyByProduct.forEach((pid, qty) {
      final p = products[pid];
      if (p == null || p.s('type') == 'service') return;
      final avail = Pricing.available(p, s, e, orders, downtimes, excludeOrderId: o.id) - qty;
      if (avail < 0) out[p.s('name')] = -avail;
    });
    return out;
  }

  /// Recomputes the denormalised stats on a customer document.
  static Future<void> syncCustomer(String? customerId) async {
    if (customerId == null || customerId.isEmpty) return;
    try {
      final orders = await Db.listWhere(C.orders, 'customerId', customerId);
      num revenue = 0, due = 0;
      DateTime? latest;
      var count = 0;
      for (final o in orders) {
        if (o.s('status') == 'canceled') continue;
        count++;
        if (o.s('status') != 'draft') {
          revenue += o.n('total');
          due += o.n('due');
        }
        final c = o.d('startsAt') ?? o.created;
        if (latest == null || c.isAfter(latest)) latest = c;
      }
      await Db.update(
          C.customers,
          customerId,
          {
            'orderCount': count,
            'revenue': revenue,
            'balanceDue': due,
            'latestOrderAt': latest == null ? null : Timestamp.fromDate(latest),
          },
          silent: true);
    } catch (_) {}
  }

  /// Creates a payment doc and updates the order's paid / due / paymentStatus.
  /// When [invoiceId] is given the invoice totals are updated as well.
  static Future<void> recordPayment({
    required String orderId,
    required int orderNumber,
    required num amount,
    required String method,
    required String kind,
    String note = '',
    String? invoiceId,
  }) async {
    await Db.create(
        C.payments,
        {
          'orderId': orderId,
          'orderNumber': orderNumber,
          'amount': amount,
          'method': method,
          'kind': kind,
          'note': note,
          'paidAt': Timestamp.now(),
        },
        label: '${kind == 'refund' ? 'Refund' : 'Payment'} for order #$orderNumber');
    final delta = kind == 'charge' ? amount : (kind == 'refund' ? -amount : 0);
    final order = await Db.get(C.orders, orderId);
    if (order != null && delta != 0) {
      final paid = order.n('paid') + delta;
      final total = order.n('total');
      await Db.update(
          C.orders,
          orderId,
          {
            'paid': paid,
            'due': dueOf(total, paid),
            'paymentStatus': Pricing.paymentStatus(total, paid),
          },
          silent: true);
      await syncCustomer(order.s('customerId'));
    }
    if (invoiceId != null && delta != 0) {
      final inv = await Db.get(C.documents, invoiceId);
      if (inv != null) {
        final paid = inv.n('paid') + delta;
        final total = inv.n('total');
        await Db.update(
            C.documents,
            invoiceId,
            {
              'paid': paid,
              'due': dueOf(total, paid),
              'paymentStatus': Pricing.paymentStatus(total, paid),
            },
            silent: true);
      }
    }
  }

  static num dueOf(num total, num paid) {
    final d = total - paid;
    return d < 0 ? 0 : (d * 100).roundToDouble() / 100;
  }
}

/// Document type metadata.
class DocType {
  static const all = ['invoice', 'quote', 'contract', 'packing'];
  static const prefix = {'invoice': 'INV', 'quote': 'QUO', 'contract': 'CON', 'packing': 'PS'};
  static const title = {'invoice': 'Invoice', 'quote': 'Quote', 'contract': 'Contract', 'packing': 'Packing slip'};
  static const plural = {'invoice': 'Invoices', 'quote': 'Quotes', 'contract': 'Contracts', 'packing': 'Packing slips'};
  static const emailContext = {'invoice': 'invoices', 'quote': 'quotes', 'contract': 'contracts', 'packing': 'orders'};

  static String number(Doc d) => '${prefix[d.s('type')] ?? 'DOC'}-${d.i('number').toString().padLeft(4, '0')}';

  /// Creates a document from an order snapshot and returns its id.
  static Future<String> createFromOrder(String type, String orderId, Map<String, dynamic> order) async {
    final now = DateTime.now();
    final dueDays = (Session.instance.setting('documents', 'dueDays', 14) as num?) ?? 14;
    final total = (order['total'] as num?) ?? 0;
    final paid = (order['paid'] as num?) ?? 0;
    return Db.create(
      C.documents,
      {
        'type': type,
        'orderId': orderId,
        'orderNumber': order['number'] ?? 0,
        'customerId': order['customerId'] ?? '',
        'customerName': order['customerName'] ?? '',
        'customerEmail': order['customerEmail'] ?? '',
        'date': Timestamp.fromDate(now),
        if (type == 'invoice') 'dueDate': Timestamp.fromDate(now.add(Duration(days: dueDays.toInt()))),
        'reference': '',
        'lines': order['lines'] ?? [],
        'subtotal': order['subtotal'] ?? 0,
        'discountTotal': order['discountTotal'] ?? 0,
        'taxTotal': order['taxTotal'] ?? 0,
        'total': total,
        'deposit': order['deposit'] ?? 0,
        'paid': paid,
        'due': OrderX.dueOf(total, paid),
        'paymentStatus': Pricing.paymentStatus(total, paid),
        'finalized': false,
        'sent': false,
        'text': '',
        'footer': '',
        'tags': <String>[],
      },
      numberKey: type,
      label: '${title[type]} for order #${order['number'] ?? ''}',
    );
  }
}

String fillTemplate(String s, Map<String, String> vars) {
  var out = s;
  vars.forEach((k, v) => out = out.replaceAll('{{$k}}', v));
  return out;
}

String get companyName {
  final n = Session.instance.setting('general', 'companyName', '') as String? ?? '';
  return n.isNotEmpty ? n : Session.instance.workspace?.s('name') ?? '';
}

String addressText(Map<String, dynamic> a) {
  if (a.isEmpty) return '';
  final name = '${a['firstName'] ?? ''} ${a['lastName'] ?? ''}'.trim();
  final cityLine = [a['zip'], a['city'], a['state']].where((e) => e != null && '$e'.isNotEmpty).join(' ');
  return [name, a['line1'], a['line2'], cityLine, a['country']].where((e) => e != null && '$e'.trim().isNotEmpty).join('\n');
}

/// "dd-MM-yyyy 09:00 → dd-MM-yyyy 17:00".
String periodText(DateTime? s, DateTime? e) => '${Fmt.dateTime(s)} → ${Fmt.dateTime(e)}';

/// Human readable duration such as "2 days 4 hours".
String durationText(DateTime? s, DateTime? e) {
  if (s == null || e == null || !e.isAfter(s)) return '—';
  final d = e.difference(s);
  final days = d.inDays, hours = d.inHours % 24, mins = d.inMinutes % 60;
  final parts = <String>[
    if (days > 0) '$days day${days == 1 ? '' : 's'}',
    if (hours > 0) '$hours hour${hours == 1 ? '' : 's'}',
    if (mins > 0 && days == 0) '$mins min',
  ];
  return parts.isEmpty ? '0 min' : parts.join(' ');
}

String fmtNum(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
