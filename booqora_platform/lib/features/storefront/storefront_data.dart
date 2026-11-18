import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../core/format.dart';
import '../../data/db.dart';
import '../../data/pricing.dart';

/// One line in the visitor's cart.
class CartLine {
  final String productId;
  int qty;
  CartLine(this.productId, this.qty);
}

Color? storeHex(String? hex) {
  if (hex == null) return null;
  var h = hex.trim().replaceAll('#', '');
  if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
  if (h.length != 6) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}

/// Public storefront state for one store slug. Kept in memory across route
/// changes (home <-> product) and mirrored to localStorage.
class StoreData extends ChangeNotifier {
  static final _cache = <String, StoreData>{};
  static StoreData of(String slug) => _cache.putIfAbsent(slug, () => StoreData._(slug));

  StoreData._(this.slug) {
    final now = DateTime.now();
    start = DateTime(now.year, now.month, now.day + 1, 9);
    end = DateTime(now.year, now.month, now.day + 2, 9);
    _restore();
    load();
  }

  final String slug;
  final _fs = FirebaseFirestore.instance;

  bool loading = true;
  String? error;
  Map<String, dynamic>? store;
  List<Doc> products = [];
  List<Doc> collections = [];
  late DateTime start;
  late DateTime end;
  final List<CartLine> cart = [];
  String query = '';
  String? collectionId;
  Map<String, dynamic>? lastOrder;
  DateTime? _loadedAt;

  // ---------------- Store props ----------------
  bool get missing => store == null;
  bool get offline => store == null || store!['enabled'] == false;
  String get workspaceId => (store?['workspaceId'] ?? '').toString();
  String get name => (store?['name'] ?? 'Online store').toString();
  String str(String k, [String def = '']) => (store?[k] ?? def).toString();
  bool flag(String k, [bool def = false]) => store?[k] is bool ? store![k] as bool : def;
  Color get brand => storeHex(store?['brandColor'] as String?) ?? const Color(0xFF6431DD);
  String get symbol => str('symbol', '₹');
  bool get symbolAfter => str('position', 'before') == 'after';
  bool get showPrices => flag('showPrices', true);
  Map<String, dynamic> get crossSell => store?['crossSell'] is Map ? Map<String, dynamic>.from(store!['crossSell'] as Map) : {};

  String money(num v) => Fmt.money(v, sym: symbol, after: symbolAfter);

  // ---------------- Loading ----------------
  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final snap = await _fs.collection('publicStores').doc(slug).get();
      store = snap.exists ? snap.data() : null;
      if (store != null && !offline && workspaceId.isNotEmpty) {
        final ws = _fs.collection('workspaces').doc(workspaceId);
        final ps = await ws.collection('products').where('showInStore', isEqualTo: true).get();
        products = ps.docs.map(Doc.of).where((p) => p.s('status', 'active') != 'archived').toList()
          ..sort((a, b) => a.s('name').toLowerCase().compareTo(b.s('name').toLowerCase()));
        try {
          final cs = await ws.collection('collections').where('showInStore', isEqualTo: true).get();
          collections = cs.docs.map(Doc.of).where((c) => !c.b('isSystem')).toList()
            ..sort((a, b) => a.s('name').compareTo(b.s('name')));
        } catch (_) {
          collections = [];
        }
        cart.removeWhere((l) => product(l.productId) == null);
      }
      _loadedAt = DateTime.now();
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  void refreshIfStale() {
    if (_loadedAt != null && DateTime.now().difference(_loadedAt!) > const Duration(minutes: 3)) load();
  }

  Doc? product(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  List<Doc> get visibleProducts {
    final q = query.trim().toLowerCase();
    return products.where((p) {
      if (collectionId != null && !p.l<String>('collectionIds').contains(collectionId)) return false;
      if (q.isEmpty) return true;
      return p.s('name').toLowerCase().contains(q) || p.s('excerpt').toLowerCase().contains(q) || p.s('description').toLowerCase().contains(q);
    }).toList();
  }

  void setQuery(String q) {
    query = q;
    notifyListeners();
  }

  void setCollection(String? id) {
    collectionId = id;
    notifyListeners();
  }

  // ---------------- Pricing ----------------
  bool _isRental(Doc p) => !{'sale', 'service'}.contains(p.s('type', 'rental'));

  num unitPrice(Doc p) => Pricing.unitPrice(p, start, end);

  num periodsFor(Doc p) {
    if (!_isRental(p) || p.s('pricingMethod', 'flat') == 'fixed') return 1;
    return Pricing.periods(start, end, p.s('pricePer', 'day'));
  }

  String perLabel(Doc p) {
    if (!_isRental(p) || p.s('pricingMethod', 'flat') == 'fixed') return '';
    return ' / ${p.s('pricePer', 'day')}';
  }

  /// Display price e.g. "₹500.00 / day".
  String priceLabel(Doc p) {
    if (p.data['chargeEnabled'] == false || p.s('pricingMethod') == 'none') return 'Free';
    final prefix = p.s('pricingMethod') == 'structure' ? 'From ' : '';
    return '$prefix${money(p.n('price'))}${perLabel(p)}';
  }

  // ---------------- Period ----------------
  void setPeriod({DateTime? from, DateTime? until}) {
    if (from != null) {
      final dur = end.difference(start);
      start = from;
      if (!end.isAfter(start)) end = start.add(dur.inMinutes > 0 ? dur : const Duration(days: 1));
    }
    if (until != null) end = until;
    _persist();
    notifyListeners();
  }

  bool get periodValid => end.isAfter(start);

  String get periodLabel => '${Fmt.dateTime(start)}  →  ${Fmt.dateTime(end)}';

  // ---------------- Cart ----------------
  int get cartCount => cart.fold(0, (s, l) => s + l.qty);

  void add(Doc p, [int qty = 1]) {
    final existing = cart.where((l) => l.productId == p.id).firstOrNull;
    if (existing != null) {
      existing.qty += qty;
    } else {
      cart.add(CartLine(p.id, qty));
    }
    _persist();
    notifyListeners();
  }

  void setQty(String productId, int qty) {
    final l = cart.where((e) => e.productId == productId).firstOrNull;
    if (l == null) return;
    if (qty <= 0) {
      cart.remove(l);
    } else {
      l.qty = qty;
    }
    _persist();
    notifyListeners();
  }

  num lineTotal(CartLine l) {
    final p = product(l.productId);
    return p == null ? 0 : unitPrice(p) * l.qty;
  }

  num get subtotal => _r(cart.fold<num>(0, (s, l) => s + lineTotal(l)));

  num get depositTotal => _r(cart.fold<num>(0, (s, l) => s + (product(l.productId)?.n('deposit') ?? 0) * l.qty));

  static num _r(num v) => (v * 100).roundToDouble() / 100;

  void clearSuccess() {
    lastOrder = null;
    notifyListeners();
  }

  // ---------------- Checkout ----------------
  Future<void> submit({
    required String name,
    required String email,
    required String phone,
    required String fulfillment,
    required Map<String, dynamic> address,
    required String note,
  }) async {
    if (cart.isEmpty) throw Exception('Your cart is empty');
    if (!periodValid) throw Exception('The return date must be after the pickup date');
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) await auth.signInAnonymously();

    final lines = <Map<String, dynamic>>[];
    var i = 0;
    for (final l in cart) {
      final p = product(l.productId);
      if (p == null) continue;
      final unit = _r(unitPrice(p));
      final images = p.l<String>('imageUrls');
      lines.add({
        'id': 'l${DateTime.now().microsecondsSinceEpoch}${i++}',
        'kind': 'product',
        'productId': p.id,
        'name': p.s('name'),
        'qty': l.qty,
        'unitPrice': unit,
        'periods': periodsFor(p),
        'total': _r(unit * l.qty),
        'taxRate': 0,
        'imageUrl': images.isEmpty ? '' : images.first,
      });
    }
    final sub = _r(lines.fold<num>(0, (s, l) => s + (l['total'] as num)));
    final dep = depositTotal;
    final items = lines.fold<int>(0, (s, l) => s + (l['qty'] as int));
    final data = <String, dynamic>{
      'source': 'online',
      'status': 'draft',
      'paymentStatus': 'payment_due',
      'number': null,
      'customerName': name,
      'customerEmail': email,
      'customerPhone': phone,
      'deliveryAddress': address,
      'fulfillment': fulfillment,
      'startsAt': Timestamp.fromDate(start),
      'stopsAt': Timestamp.fromDate(end),
      'lines': lines,
      'subtotal': sub,
      'discountTotal': 0,
      'taxTotal': 0,
      'total': sub,
      'deposit': dep,
      'paid': 0,
      'due': sub,
      'itemCount': items,
      'note': note,
      'tags': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final ref = await _fs.collection('workspaces').doc(workspaceId).collection('orders').add(data);
    lastOrder = {
      'orderId': ref.id,
      'workspaceId': workspaceId,
      'name': name,
      'email': email,
      'lines': lines,
      'total': sub,
      'deposit': dep,
      'start': start,
      'end': end,
      'fulfillment': fulfillment,
    };
    cart.clear();
    _persist();
    notifyListeners();
  }

  // ---------------- Persistence ----------------
  String get _key => 'booqora_cart_$slug';

  void _persist() {
    try {
      web.window.localStorage.setItem(
        _key,
        jsonEncode({
          'start': start.toIso8601String(),
          'end': end.toIso8601String(),
          'lines': [for (final l in cart) {'p': l.productId, 'q': l.qty}],
        }),
      );
    } catch (_) {}
  }

  void _restore() {
    try {
      final raw = web.window.localStorage.getItem(_key);
      if (raw == null) return;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final s = DateTime.tryParse((m['start'] ?? '').toString());
      final e = DateTime.tryParse((m['end'] ?? '').toString());
      if (s != null && e != null && s.isAfter(DateTime.now()) && e.isAfter(s)) {
        start = s;
        end = e;
      }
      for (final l in (m['lines'] as List? ?? const [])) {
        if (l is Map && l['p'] is String && l['q'] is num) cart.add(CartLine(l['p'] as String, (l['q'] as num).toInt()));
      }
    } catch (_) {}
  }
}
