import '../../core/format.dart';
import '../../data/db.dart';
import '../../data/schema.dart';

/// A navigation shortcut attached to a reply.
class BoraAction {
  final String label;
  final String route;
  const BoraAction(this.label, this.route);

  Map<String, dynamic> toMap() => {'label': label, 'route': route};

  static List<BoraAction> fromList(dynamic v) => v is List
      ? v.whereType<Map>().map((m) => BoraAction((m['label'] ?? '').toString(), (m['route'] ?? '/').toString())).toList()
      : const [];
}

class BoraReply {
  final String text;
  final List<BoraAction> actions;
  const BoraReply(this.text, [this.actions = const []]);
}

class _Range {
  final DateTime start, end;
  final String label;
  const _Range(this.start, this.end, this.label);
  bool has(DateTime? d) => d != null && !d.isBefore(start) && d.isBefore(end);
}

/// Rule-based intent engine. Answers with live workspace data.
class BoraEngine {
  List<Doc> _orders = [], _products = [], _customers = [], _coupons = [];
  DateTime? _loadedAt;

  static const suggestions = [
    'How many orders this month?',
    "What's going out today?",
    'Which products earn the most?',
    'Who owes me money?',
    'Help me add my first product',
    'Set up taxes',
  ];

  Future<void> _load() async {
    if (_loadedAt != null && DateTime.now().difference(_loadedAt!) < const Duration(seconds: 45)) return;
    final r = await Future.wait([
      Db.list(C.orders),
      Db.list(C.products),
      Db.list(C.customers).catchError((_) => <Doc>[]),
      Db.list(C.coupons).catchError((_) => <Doc>[]),
    ]);
    _orders = r[0];
    _products = r[1];
    _customers = r[2];
    _coupons = r[3];
    _loadedAt = DateTime.now();
  }

  Future<BoraReply> reply(String input) async {
    final q = ' ${input.toLowerCase().replaceAll(RegExp(r"[^a-z0-9#' ]"), ' ').replaceAll(RegExp(r'\s+'), ' ').trim()} ';
    bool has(List<String> words) => words.any((w) => q.contains(w));

    if (q.trim().isEmpty) return _help();
    if (RegExp(r'^ (hi|hello|hey|yo|good (morning|afternoon|evening))\b').hasMatch(q) && q.trim().split(' ').length <= 4) {
      return const BoraReply('Hello! Ask me about orders, revenue, stock or customers — or tell me what you want to set up.');
    }
    if (has([' thank', ' thanks', ' cheers'])) return const BoraReply("You're welcome! Anything else I can help with?");
    if (q.trim() == 'help' || has([' what can you do', ' commands', ' what do you know', ' what can i ask'])) return _help();

    // Setup / how-to questions first.
    final counting = has([' how many', ' how much']);
    final howTo = !counting && has([' how ', ' help me', ' set up', ' setup', ' configure', ' where do i', ' where can i', ' how do i', ' guide', ' first ']) ||
        RegExp(r'^ (add|create|enable|connect|invite|change|edit|make) ').hasMatch(q);
    if (howTo) {
      final r = _howTo(q);
      if (r != null) return r;
    }

    try {
      await _load();
    } catch (e) {
      return BoraReply("I couldn't read your data right now (${e.toString().split(']').last.trim()}). Please try again in a moment.");
    }

    final tomorrow = has([' tomorrow']);
    if (counting && has([' order', ' booking'])) return _orderCount(q);
    if (has([' late', ' overdue'])) return _late();
    if (has([' going out', ' out today', ' out tomorrow', ' pick up', ' pickup', ' pickups', ' leaving', ' dispatch', ' collect'])) {
      return _goingOut(tomorrow);
    }
    if (has([' coming back', ' come back', ' return', ' due back', ' back today', ' back tomorrow'])) return _comingBack(tomorrow);
    if (has([' owe', ' owes', ' owing', ' balance', ' unpaid', ' outstanding', ' debt', ' due money', ' payment due', ' not paid'])) {
      return _owed();
    }
    if (has([' top ', ' best', ' most ', ' popular', ' earn the most', ' bestsell'])) {
      return _top(units: has([' unit', ' rented', ' most rented', ' quantity', ' often']));
    }
    if (has([' revenue', ' earn', ' sales', ' income', ' turnover', ' made ', ' money did', ' how much'])) return _revenue(_range(q));
    if (has([' stock', ' inventory level', ' running out', ' sold out', ' low '])) return _lowStock();
    if (has([' coupon', ' discount code', ' promo'])) return _activeCoupons();
    if (has([' customer'])) return _customersCount();
    if (has([' product', ' inventory', ' catalog', ' items do i'])) return _inventory();
    if (has([' order', ' booking', ' reservation'])) return _orderCount(q);

    final r = _howTo(q);
    if (r != null) return r;
    return _help(fallback: true);
  }

  // ---------------- Helpers ----------------

  static String _money(num v) => Fmt.money(v);

  bool _counted(Doc o) => !{'canceled', 'draft'}.contains(o.s('status'));

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  _Range _range(String q) {
    final now = DateTime.now();
    final today = _day(now);
    if (q.contains('last month') || q.contains('previous month')) {
      return _Range(DateTime(now.year, now.month - 1), DateTime(now.year, now.month), 'last month');
    }
    if (q.contains('yesterday')) return _Range(today.subtract(const Duration(days: 1)), today, 'yesterday');
    if (q.contains('today')) return _Range(today, today.add(const Duration(days: 1)), 'today');
    if (q.contains('last week')) {
      final s = today.subtract(Duration(days: today.weekday - 1 + 7));
      return _Range(s, s.add(const Duration(days: 7)), 'last week');
    }
    if (q.contains('week')) {
      final s = today.subtract(Duration(days: today.weekday - 1));
      return _Range(s, s.add(const Duration(days: 7)), 'this week');
    }
    if (q.contains('last year')) return _Range(DateTime(now.year - 1), DateTime(now.year), 'last year');
    if (q.contains('year')) return _Range(DateTime(now.year), DateTime(now.year + 1), 'this year');
    if (q.contains('all time') || q.contains('ever') || q.contains('total')) return _Range(DateTime(2000), DateTime(2100), 'all time');
    return _Range(DateTime(now.year, now.month), DateTime(now.year, now.month + 1), 'this month');
  }

  String _orderLine(Doc o, {bool showDate = true, String field = 'startsAt'}) {
    final n = o.data['number'] == null ? 'Request' : '#${o.i('number')}';
    final who = o.s('customerName', 'No customer');
    final when = showDate ? ' · ${Fmt.dateTime(o.d(field))}' : ' · ${Fmt.time(o.d(field))}';
    return '• **$n** $who — ${o.i('itemCount')} item${o.i('itemCount') == 1 ? '' : 's'}$when';
  }

  BoraAction _openOrder(Doc o) => BoraAction(o.data['number'] == null ? 'Open request' : 'Open order #${o.i('number')}', '/orders/${o.id}');

  // ---------------- Intents ----------------

  BoraReply _help({bool fallback = false}) => BoraReply(
        '${fallback ? "I'm not sure I understood that, but here's what I can do:" : "Here's what I can help with:"}\n'
        '• **Revenue** — "What was revenue last month?"\n'
        '• **Orders** — "How many orders this week?", "How many reserved orders?"\n'
        '• **Today** — "What\'s going out today?", "What\'s coming back tomorrow?", "Any late orders?"\n'
        '• **Products** — "Which products earn the most?", "What\'s low on stock?"\n'
        '• **Customers** — "Who owes me money?"\n'
        '• **Coupons** — "Which coupons are active?"\n'
        '• **Setup** — "How do I set up taxes?", "Help me add my first product", "How do I invite my team?"',
        const [BoraAction('Orders', '/orders'), BoraAction('Inventory', '/inventory'), BoraAction('Setup guide', '/setup')],
      );

  BoraReply _revenue(_Range r) {
    final os = _orders.where((o) => _counted(o) && r.has(o.created)).toList();
    final total = os.fold<num>(0, (s, o) => s + o.n('total'));
    final paid = os.fold<num>(0, (s, o) => s + o.n('paid'));
    final due = os.fold<num>(0, (s, o) => s + o.n('due'));
    if (os.isEmpty) {
      return BoraReply('No confirmed orders were created ${r.label}, so revenue is **${_money(0)}**.',
          const [BoraAction('New order', '/orders/new'), BoraAction('View reports', '/reports')]);
    }
    final avg = total / os.length;
    var text = 'Revenue ${r.label}: **${_money(total)}** from ${os.length} order${os.length == 1 ? '' : 's'}.\n'
        '• Collected: ${_money(paid)}\n'
        '• Still due: ${_money(due)}\n'
        '• Average order: ${_money(avg)}';
    if (r.label == 'this month') {
      final now = DateTime.now();
      final last = _Range(DateTime(now.year, now.month - 1), DateTime(now.year, now.month), 'last month');
      final prev = _orders.where((o) => _counted(o) && last.has(o.created)).fold<num>(0, (s, o) => s + o.n('total'));
      if (prev > 0) {
        final pct = ((total - prev) / prev * 100).round();
        text += '\n\nThat\'s ${pct >= 0 ? 'up' : 'down'} ${pct.abs()}% vs last month (${_money(prev)}).';
      }
    }
    return BoraReply(text, const [BoraAction('Revenue report', '/reports'), BoraAction('View orders', '/orders')]);
  }

  BoraReply _orderCount(String q) {
    final r = _range(q);
    String? status;
    for (final s in OrderStatus.all) {
      if (q.contains(' $s')) status = s;
    }
    if (q.contains(' cancelled')) status = 'canceled';
    if (q.contains(' active')) status = 'started';
    if (q.contains(' online') || q.contains(' request')) {
      final online = _orders.where((o) => o.s('source') == 'online').toList();
      final pending = online.where((o) => o.s('status') == 'draft').toList();
      return BoraReply(
        'You have **${online.length}** online booking${online.length == 1 ? '' : 's'} in total, **${pending.length}** waiting for review.'
        '${pending.isEmpty ? '' : '\n${pending.take(5).map((o) => _orderLine(o)).join('\n')}'}',
        [for (final o in pending.take(2)) _openOrder(o), const BoraAction('View orders', '/orders')],
      );
    }
    if (status != null) {
      final os = _orders.where((o) => o.s('status') == status).toList();
      return BoraReply(
        'You have **${os.length}** ${Fmt.label(status).toLowerCase()} order${os.length == 1 ? '' : 's'}.'
        '${os.isEmpty ? '' : '\n${os.take(5).map((o) => _orderLine(o)).join('\n')}'}',
        [for (final o in os.take(2)) _openOrder(o), const BoraAction('View orders', '/orders')],
      );
    }
    final os = _orders.where((o) => r.has(o.created)).toList();
    if (os.isEmpty) {
      return BoraReply('No orders were created ${r.label} yet.', const [BoraAction('Create order', '/orders/new'), BoraAction('Share your store', '/online-store')]);
    }
    final by = <String, int>{};
    for (final o in os) {
      by[o.s('status', 'draft')] = (by[o.s('status', 'draft')] ?? 0) + 1;
    }
    final online = os.where((o) => o.s('source') == 'online').length;
    final parts = OrderStatus.all.where(by.containsKey).map((s) => '• ${Fmt.label(s)}: ${by[s]}').join('\n');
    return BoraReply(
      'You have **${os.length}** order${os.length == 1 ? '' : 's'} ${r.label}${online > 0 ? ' ($online from your online store)' : ''}.\n$parts',
      const [BoraAction('View orders', '/orders'), BoraAction('New order', '/orders/new')],
    );
  }

  BoraReply _goingOut(bool tomorrow) {
    final day = _day(DateTime.now()).add(Duration(days: tomorrow ? 1 : 0));
    final r = _Range(day, day.add(const Duration(days: 1)), tomorrow ? 'tomorrow' : 'today');
    final os = _orders.where((o) => o.s('status') == 'reserved' && r.has(o.d('startsAt'))).toList()
      ..sort((a, b) => (a.d('startsAt') ?? day).compareTo(b.d('startsAt') ?? day));
    if (os.isEmpty) {
      return BoraReply('Nothing is scheduled to go out ${r.label}. 🎉', const [BoraAction('Open calendar', '/calendar'), BoraAction('View orders', '/orders')]);
    }
    final items = os.fold<int>(0, (s, o) => s + o.i('itemCount'));
    return BoraReply(
      '**${os.length}** order${os.length == 1 ? '' : 's'} ($items items) going out ${r.label}:\n${os.take(8).map((o) => _orderLine(o, showDate: false)).join('\n')}',
      [for (final o in os.take(3)) _openOrder(o), const BoraAction('Open calendar', '/calendar')],
    );
  }

  BoraReply _comingBack(bool tomorrow) {
    final day = _day(DateTime.now()).add(Duration(days: tomorrow ? 1 : 0));
    final r = _Range(day, day.add(const Duration(days: 1)), tomorrow ? 'tomorrow' : 'today');
    final os = _orders.where((o) => o.s('status') == 'started' && r.has(o.d('stopsAt'))).toList()
      ..sort((a, b) => (a.d('stopsAt') ?? day).compareTo(b.d('stopsAt') ?? day));
    if (os.isEmpty) {
      return BoraReply('Nothing is due back ${r.label}.', const [BoraAction('Open calendar', '/calendar')]);
    }
    return BoraReply(
      '**${os.length}** order${os.length == 1 ? '' : 's'} coming back ${r.label}:\n${os.take(8).map((o) => _orderLine(o, showDate: false, field: 'stopsAt')).join('\n')}',
      [for (final o in os.take(3)) _openOrder(o), const BoraAction('Open calendar', '/calendar')],
    );
  }

  BoraReply _late() {
    final now = DateTime.now();
    final returns = _orders.where((o) => o.s('status') == 'started' && (o.d('stopsAt')?.isBefore(now) ?? false)).toList();
    final pickups = _orders.where((o) => o.s('status') == 'reserved' && (o.d('startsAt')?.isBefore(now) ?? false)).toList();
    if (returns.isEmpty && pickups.isEmpty) {
      return const BoraReply('Good news — no late orders right now. ✅', [BoraAction('View orders', '/orders')]);
    }
    final b = StringBuffer();
    if (returns.isNotEmpty) {
      b.writeln('**${returns.length}** late return${returns.length == 1 ? '' : 's'}:');
      for (final o in returns.take(6)) {
        b.writeln(_orderLine(o, field: 'stopsAt'));
      }
    }
    if (pickups.isNotEmpty) {
      if (returns.isNotEmpty) b.writeln();
      b.writeln('**${pickups.length}** late pickup${pickups.length == 1 ? '' : 's'} (still reserved):');
      for (final o in pickups.take(6)) {
        b.writeln(_orderLine(o));
      }
    }
    return BoraReply(b.toString().trim(), [for (final o in [...returns, ...pickups].take(2)) _openOrder(o), const BoraAction('View late orders', '/orders')]);
  }

  BoraReply _top({required bool units}) {
    final rev = <String, num>{}, qty = <String, num>{}, names = <String, String>{};
    for (final o in _orders.where(_counted)) {
      for (final l in o.maps('lines')) {
        final id = (l['productId'] ?? '').toString();
        if (id.isEmpty) continue;
        names[id] = (l['name'] ?? names[id] ?? 'Product').toString();
        rev[id] = (rev[id] ?? 0) + ((l['total'] as num?) ?? 0);
        qty[id] = (qty[id] ?? 0) + ((l['qty'] as num?) ?? 0);
      }
    }
    if (rev.isEmpty) {
      return const BoraReply("There's no order data yet to rank products. Once you have confirmed orders I'll show your best performers.",
          [BoraAction('Create order', '/orders/new'), BoraAction('Inventory', '/inventory')]);
    }
    final metric = units ? qty : rev;
    final ids = metric.keys.toList()..sort((a, b) => metric[b]!.compareTo(metric[a]!));
    final top = ids.take(5).toList();
    final lines = [
      for (var i = 0; i < top.length; i++)
        '${i + 1}. **${names[top[i]]}** — ${_money(rev[top[i]]!)} · ${Fmt.integer(qty[top[i]]!)} unit${qty[top[i]] == 1 ? '' : 's'} rented',
    ];
    return BoraReply(
      'Your top products by ${units ? 'units rented' : 'revenue'}:\n${lines.join('\n')}',
      [
        for (final id in top.take(2))
          if (_products.any((p) => p.id == id)) BoraAction('Open ${names[id]}', '/inventory/products/$id'),
        const BoraAction('Reports', '/reports'),
      ],
    );
  }

  BoraReply _owed() {
    final due = _orders.where((o) => _counted(o) && o.n('due') > 0.005).toList();
    if (due.isEmpty) {
      final cust = _customers.where((c) => c.n('balanceDue') > 0.005).toList();
      if (cust.isEmpty) return const BoraReply('Nobody owes you money right now — every order is settled. 🙌', [BoraAction('View orders', '/orders')]);
    }
    final byCustomer = <String, (String, num, int, String?)>{};
    for (final o in due) {
      final key = o.s('customerId').isNotEmpty ? o.s('customerId') : o.s('customerName', 'Unknown');
      final cur = byCustomer[key];
      byCustomer[key] = (
        o.s('customerName', 'No customer'),
        (cur?.$2 ?? 0) + o.n('due'),
        (cur?.$3 ?? 0) + 1,
        o.s('customerId').isNotEmpty ? o.s('customerId') : null,
      );
    }
    final list = byCustomer.values.toList()..sort((a, b) => b.$2.compareTo(a.$2));
    final total = list.fold<num>(0, (s, e) => s + e.$2);
    final lines = list.take(6).map((e) => '• **${e.$1}** — ${_money(e.$2)} across ${e.$3} order${e.$3 == 1 ? '' : 's'}').join('\n');
    due.sort((a, b) => b.n('due').compareTo(a.n('due')));
    return BoraReply(
      '**${list.length}** customer${list.length == 1 ? '' : 's'} owe you a total of **${_money(total)}**:\n$lines',
      [
        for (final e in list.take(2))
          if (e.$4 != null) BoraAction('Open ${e.$1}', '/customers/${e.$4}'),
        if (due.isNotEmpty) _openOrder(due.first),
        const BoraAction('View orders', '/orders'),
      ],
    );
  }

  BoraReply _lowStock() {
    final active = _products.where((p) => p.s('status', 'active') != 'archived' && p.s('type', 'rental') == 'rental').toList();
    final none = active.where((p) => p.i('quantity') <= 0).toList();
    final low = active.where((p) => p.i('quantity') > 0 && p.i('quantity') <= 2).toList();
    if (active.isEmpty) {
      return const BoraReply("You don't have any rental products yet.", [BoraAction('Add product', '/inventory/products/new')]);
    }
    if (none.isEmpty && low.isEmpty) {
      return BoraReply('Stock looks healthy — all ${active.length} rental products have 3 or more units.', const [BoraAction('Inventory', '/inventory')]);
    }
    final b = StringBuffer();
    if (none.isNotEmpty) {
      b.writeln('**${none.length}** product${none.length == 1 ? ' has' : 's have'} no stock:');
      for (final p in none.take(6)) {
        b.writeln('• ${p.s('name')}');
      }
    }
    if (low.isNotEmpty) {
      if (none.isNotEmpty) b.writeln();
      b.writeln('**${low.length}** running low:');
      for (final p in low.take(6)) {
        b.writeln('• ${p.s('name')} — ${p.i('quantity')} left');
      }
    }
    return BoraReply(b.toString().trim(), [
      for (final p in [...none, ...low].take(2)) BoraAction('Open ${p.s('name')}', '/inventory/products/${p.id}'),
      const BoraAction('Inventory', '/inventory'),
    ]);
  }

  BoraReply _activeCoupons() {
    final now = DateTime.now();
    final active = _coupons.where((c) {
      if (!c.b('active', true)) return false;
      final s = c.d('startsAt'), e = c.d('endsAt');
      if (s != null && s.isAfter(now)) return false;
      if (e != null && e.isBefore(now)) return false;
      final max = c.data['maxUses'];
      if (max is num && max > 0 && c.i('uses') >= max) return false;
      return true;
    }).toList();
    if (active.isEmpty) {
      return BoraReply(_coupons.isEmpty ? "You haven't created any coupons yet." : 'None of your ${_coupons.length} coupons are active right now.',
          const [BoraAction('Create coupon', '/coupons/new'), BoraAction('Coupons', '/coupons')]);
    }
    final lines = active.take(8).map((c) {
      final v = c.s('discountType') == 'fixed' ? _money(c.n('value')) : '${Fmt.integer(c.n('value'))}%';
      final ends = c.d('endsAt');
      return '• **${c.s('code')}** — $v off · used ${c.i('uses')}×${ends == null ? '' : ' · ends ${Fmt.date(ends)}'}';
    }).join('\n');
    return BoraReply('**${active.length}** active coupon${active.length == 1 ? '' : 's'}:\n$lines',
        [for (final c in active.take(2)) BoraAction('Open ${c.s('code')}', '/coupons/${c.id}'), const BoraAction('Coupons', '/coupons')]);
  }

  BoraReply _inventory() {
    final active = _products.where((p) => p.s('status', 'active') != 'archived').toList();
    if (active.isEmpty) return _howTo(' product ')!;
    final byType = <String, int>{};
    for (final p in active) {
      byType[p.s('type', 'rental')] = (byType[p.s('type', 'rental')] ?? 0) + 1;
    }
    final units = active.fold<int>(0, (s, p) => s + p.i('quantity'));
    final inStore = active.where((p) => p.b('showInStore')).length;
    return BoraReply(
      'You have **${active.length}** active product${active.length == 1 ? '' : 's'} with ${Fmt.integer(units)} units in stock.\n'
      '${byType.entries.map((e) => '• ${Fmt.label(e.key)}: ${e.value}').join('\n')}\n'
      '• Visible in online store: $inStore',
      const [BoraAction('Inventory', '/inventory'), BoraAction('Add product', '/inventory/products/new')],
    );
  }

  BoraReply _customersCount() {
    final r = DateTime.now();
    final month = _Range(DateTime(r.year, r.month), DateTime(r.year, r.month + 1), 'this month');
    final fresh = _customers.where((c) => month.has(c.created)).length;
    final top = [..._customers]..sort((a, b) => b.n('revenue').compareTo(a.n('revenue')));
    final best = top.where((c) => c.n('revenue') > 0).take(3).map((c) => '• **${c.s('name')}** — ${_money(c.n('revenue'))}').join('\n');
    return BoraReply(
      'You have **${_customers.length}** customer${_customers.length == 1 ? '' : 's'}, $fresh new this month.${best.isEmpty ? '' : '\n\nTop customers by revenue:\n$best'}',
      const [BoraAction('Customers', '/customers'), BoraAction('Add customer', '/customers/new')],
    );
  }

  // ---------------- How-to ----------------

  BoraReply? _howTo(String q) {
    bool has(List<String> w) => w.any(q.contains);
    if (has(['tax', 'gst', 'vat'])) {
      return const BoraReply(
        'Setting up taxes takes a minute:\n'
        '1. Go to **Settings → Taxes** and choose whether your prices include tax.\n'
        '2. Add a tax profile (e.g. "GST 18%") — it becomes the default for products.\n'
        '3. Optionally add customer tax profiles for exempt or reduced-rate customers.\n'
        '4. On each product, set Taxable and pick a profile if it differs from the default.',
        [BoraAction('Open tax settings', '/settings/taxes')],
      );
    }
    if (has(['coupon', 'discount code', 'promo'])) {
      return const BoraReply(
        'To create a coupon:\n'
        '1. Open **Coupons → New coupon** and enter a code (e.g. WELCOME10).\n'
        '2. Choose a percentage or fixed discount and what it applies to.\n'
        '3. Optionally set dates, a minimum spend and usage limits.\n'
        'Customers can enter it at checkout when coupons are enabled in Online store → Preferences.',
        [BoraAction('Create coupon', '/coupons/new'), BoraAction('Store preferences', '/online-store/preferences')],
      );
    }
    if (has(['invoice', 'quote', 'contract', 'document', 'packing'])) {
      return const BoraReply(
        'Documents are generated from orders:\n'
        '1. Open an order and choose **Create invoice / quote / contract**.\n'
        '2. Finalize it to lock the number, then send or print it.\n'
        '3. Customize numbering, due days and footer in **Settings → Documents**.',
        [BoraAction('Documents', '/documents'), BoraAction('Document settings', '/settings/documents')],
      );
    }
    if (has(['online store', 'store', 'website', 'booking page', 'shop', 'embed'])) {
      return const BoraReply(
        'Your online store is ready to share:\n'
        '1. Mark products **Show in store** under Inventory.\n'
        '2. Customize your hero text and brand colour in **Online store**.\n'
        '3. Share your booking page link, or embed it on your website.\n'
        'Online requests arrive as draft orders for you to confirm.',
        [BoraAction('Online store', '/online-store'), BoraAction('Booking page', '/online-store/booking-page'), BoraAction('Embed on website', '/online-store/integration')],
      );
    }
    if (has(['team', 'member', 'invite', 'staff', 'employee', 'user'])) {
      return const BoraReply(
        'To invite your team:\n'
        '1. Go to **Settings → Team**.\n'
        '2. Enter their email and choose a role (Admin or Member).\n'
        '3. They\'ll join your workspace when they sign up with that email.',
        [BoraAction('Team settings', '/settings/team')],
      );
    }
    if (has(['payment', 'stripe', 'razorpay', 'card', 'upi', 'pay '])) {
      return const BoraReply(
        'Payments:\n'
        '• Record cash, card, bank or UPI payments on any order with **Add payment**.\n'
        '• To take card payments online, connect a provider in **Settings → Payment providers**.\n'
        '• Choose what customers pay at checkout in **Online store → Checkout**.',
        [BoraAction('Payment settings', '/settings/payments'), BoraAction('Checkout settings', '/online-store/checkout')],
      );
    }
    if (has(['pricing', 'price', 'rate', 'charge'])) {
      return const BoraReply(
        'Pricing options per product:\n'
        '• **Flat** — a price per hour, day, week or month.\n'
        '• **Fixed** — one price regardless of duration.\n'
        '• **Pricing structure** — tiered prices (e.g. 1 day, weekend, week).\n'
        'Set currency and deposits in **Settings → Pricing**.',
        [BoraAction('Pricing settings', '/settings/pricing'), BoraAction('Inventory', '/inventory')],
      );
    }
    if (has(['rental period', 'opening hours', 'pickup time', 'return time'])) {
      return const BoraReply(
        'Rental periods control how customers choose dates and times. Set default pickup/return times and intervals in **Settings → Rental period**.',
        [BoraAction('Rental period', '/settings/rental-period')],
      );
    }
    if (has(['customer'])) {
      return const BoraReply(
        'Add customers from **Customers → New customer**, or let them be created automatically from orders. You can set discounts, tax profiles and deposit rules per customer.',
        [BoraAction('Add customer', '/customers/new'), BoraAction('Customers', '/customers')],
      );
    }
    if (has(['order', 'booking', 'reservation'])) {
      return const BoraReply(
        'To create an order:\n'
        '1. Click **New order**, pick a customer and the rental period.\n'
        '2. Add products — availability is checked automatically.\n'
        '3. Reserve it to hold stock, then mark it picked up and returned.',
        [BoraAction('New order', '/orders/new'), BoraAction('Orders', '/orders')],
      );
    }
    if (has(['product', 'item', 'inventory', 'stock', 'gear', 'equipment'])) {
      return const BoraReply(
        "Let's add your first product:\n"
        '1. Go to **Inventory → Add product**.\n'
        '2. Give it a name, a photo and choose rental, sale or service.\n'
        '3. Set the price (e.g. ₹500 per day) and a security deposit if needed.\n'
        '4. Add stock quantity, then turn on **Show in store** to list it online.',
        [BoraAction('Add product', '/inventory/products/new'), BoraAction('Inventory', '/inventory')],
      );
    }
    return null;
  }
}
