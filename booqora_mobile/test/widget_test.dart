import 'package:flutter_test/flutter_test.dart';

import 'package:booqora_mobile/data/db.dart';
import 'package:booqora_mobile/data/pricing.dart';

void main() {
  test('rental periods round up to whole charge units', () {
    final start = DateTime(2026, 11, 1, 9);
    expect(Pricing.periods(start, start.add(const Duration(hours: 30)), 'day'), 2);
    expect(Pricing.periods(start, start.add(const Duration(hours: 3)), 'hour'), 3);
    expect(Pricing.periods(start, start, 'day'), 1);
  });

  test('order totals apply discount and tax', () {
    final t = Pricing.totals(lines: [
      {'qty': 2, 'unitPrice': 500, 'total': 1000, 'taxRate': 18},
    ], discountPercent: 10);
    expect(t['subtotal'], 1000);
    expect(t['discountTotal'], 100);
    expect(t['taxTotal'], 162);
    expect(t['total'], 1062);
  });

  test('payment status reflects paid vs total', () {
    expect(Pricing.paymentStatus(1000, 0), 'payment_due');
    expect(Pricing.paymentStatus(1000, 400), 'partially_paid');
    expect(Pricing.paymentStatus(1000, 1000), 'paid');
    expect(Pricing.paymentStatus(1000, 1200), 'overpaid');
  });

  test('late rentals keep holding stock until returned', () {
    final now = DateTime.now();
    final product = Doc('p1', {'quantity': 4});
    final late = Doc('o1', {
      'status': 'started',
      'startsAt': now.subtract(const Duration(days: 3)),
      'stopsAt': now.subtract(const Duration(hours: 5)), // overdue
      'lines': [{'productId': 'p1', 'qty': 1}],
    });
    final returned = Doc('o2', {
      'status': 'returned',
      'startsAt': now.subtract(const Duration(days: 3)),
      'stopsAt': now.add(const Duration(days: 1)),
      'lines': [{'productId': 'p1', 'qty': 2}],
    });
    expect(Pricing.available(product, now, now.add(const Duration(hours: 1)), [late, returned], const []), 3);
  });
}
