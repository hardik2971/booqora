import 'db.dart';

/// Shared rental pricing, totals and availability logic.
class Pricing {
  static const unitHours = {'hour': 1, 'day': 24, 'week': 168, 'month': 720};

  /// Number of charge periods between [start] and [end] for unit [per] (min 1).
  static num periods(DateTime? start, DateTime? end, String per) {
    if (start == null || end == null || !end.isAfter(start)) return 1;
    final hours = end.difference(start).inMinutes / 60.0;
    final u = unitHours[per] ?? 24;
    final p = (hours / u).ceil();
    return p < 1 ? 1 : p;
  }

  /// Price for ONE unit of [product] over the period, honouring pricing method.
  static num unitPrice(Doc product, DateTime? start, DateTime? end, {Doc? structure, Map<String, dynamic>? variation}) {
    if (product.data['chargeEnabled'] == false) return 0;
    final base = (variation?['price'] as num?) ?? product.n('price');
    switch (product.s('pricingMethod', 'flat')) {
      case 'fixed':
        return base;
      case 'none':
        return 0;
      case 'structure':
        if (structure != null) return structurePrice(structure, start, end);
        return base * periods(start, end, product.s('pricePer', 'day'));
      case 'flat':
      default:
        if (product.s('type') == 'sale' || product.s('type') == 'service') return base;
        return base * periods(start, end, product.s('pricePer', 'day'));
    }
  }

  /// Tiered structure: tiers sorted by `upTo` periods; price is the tier price for
  /// the first tier covering the duration, extra periods charged at last tier's per-period rate.
  static num structurePrice(Doc structure, DateTime? start, DateTime? end) {
    final interval = structure.s('interval', 'day');
    var p = periods(start, end, interval);
    final minimum = structure.n('minimum', 0);
    if (p < minimum) p = minimum;
    final tiers = structure.maps('tiers')..sort((a, b) => ((a['upTo'] ?? 0) as num).compareTo((b['upTo'] ?? 0) as num));
    if (tiers.isEmpty) return 0;
    for (final t in tiers) {
      if (p <= ((t['upTo'] ?? 0) as num)) return (t['price'] ?? 0) as num;
    }
    final last = tiers.last;
    final lastUpTo = ((last['upTo'] ?? 1) as num);
    final lastPrice = ((last['price'] ?? 0) as num);
    final num perPeriod = lastUpTo == 0 ? 0 : lastPrice / lastUpTo;
    return lastPrice + (p - lastUpTo) * perPeriod;
  }

  /// Computes order totals from lines.
  /// Each line: {qty, unitPrice, total, taxRate, discountEligible?}
  static Map<String, num> totals({
    required List<Map<String, dynamic>> lines,
    num discountPercent = 0,
    num couponDiscount = 0,
    bool pricesIncludeTax = false,
    num depositPercentOfProducts = 100,
    Map<String, num> productDeposits = const {},
  }) {
    num subtotal = 0, tax = 0, deposit = 0;
    num items = 0;
    for (final l in lines) {
      final qty = (l['qty'] as num?) ?? 1;
      final total = (l['total'] as num?) ?? (((l['unitPrice'] as num?) ?? 0) * qty);
      subtotal += total;
      items += qty;
      final pid = l['productId'] as String?;
      if (pid != null && productDeposits[pid] != null) {
        deposit += productDeposits[pid]! * qty * depositPercentOfProducts / 100;
      }
    }
    final manualDiscount = subtotal * discountPercent / 100;
    num discountTotal = manualDiscount + couponDiscount;
    if (discountTotal > subtotal) discountTotal = subtotal;
    final afterDiscount = subtotal - discountTotal;
    // Tax per line, proportionally discounted.
    final ratio = subtotal == 0 ? 0 : afterDiscount / subtotal;
    for (final l in lines) {
      final rate = (l['taxRate'] as num?) ?? 0;
      if (rate <= 0) continue;
      final qty = (l['qty'] as num?) ?? 1;
      final lt = ((l['total'] as num?) ?? (((l['unitPrice'] as num?) ?? 0) * qty)) * ratio;
      tax += pricesIncludeTax ? lt - lt / (1 + rate / 100) : lt * rate / 100;
    }
    final total = pricesIncludeTax ? afterDiscount : afterDiscount + tax;
    return {
      'subtotal': _r(subtotal),
      'discountTotal': _r(discountTotal),
      'taxTotal': _r(tax),
      'total': _r(total),
      'deposit': _r(deposit),
      'itemCount': items,
    };
  }

  static String paymentStatus(num total, num paid) {
    if (total <= 0 && paid <= 0) return 'paid';
    if (paid <= 0) return 'payment_due';
    if ((paid - total).abs() < 0.005) return 'paid';
    if (paid > total) return 'overpaid';
    return 'partially_paid';
  }

  static num _r(num v) => (v * 100).roundToDouble() / 100;

  /// Statuses that hold stock.
  static const holding = {'reserved', 'started'};

  static bool overlaps(DateTime aStart, DateTime aEnd, DateTime bStart, DateTime bEnd) =>
      aStart.isBefore(bEnd) && bStart.isBefore(aEnd);

  /// Units of [product] available in [start]..[end], given orders and downtimes.
  static int available(Doc product, DateTime start, DateTime end, List<Doc> orders, List<Doc> downtimes,
      {String? excludeOrderId}) {
    final total = product.i('quantity');
    final bufBefore = Duration(minutes: (product.n('bufferBefore') * 60).round());
    final bufAfter = Duration(minutes: (product.n('bufferAfter') * 60).round());
    var used = 0;
    for (final o in orders) {
      if (o.id == excludeOrderId || !holding.contains(o.s('status'))) continue;
      final s = o.d('startsAt'), e = o.d('stopsAt');
      if (s == null || e == null) continue;
      if (!overlaps(start.subtract(bufAfter), end.add(bufBefore), s, e)) continue;
      for (final l in o.maps('lines')) {
        if (l['productId'] == product.id) used += ((l['qty'] as num?) ?? 0).toInt();
      }
    }
    for (final d in downtimes) {
      if (d.s('productId') != product.id) continue;
      if (!{'scheduled', 'started'}.contains(d.s('status'))) continue;
      final s = d.d('startsAt'), e = d.d('endsAt') ?? DateTime(2100);
      if (s == null) continue;
      if (overlaps(start, end, s, e)) used += d.i('quantity', 1);
    }
    return total - used;
  }
}
