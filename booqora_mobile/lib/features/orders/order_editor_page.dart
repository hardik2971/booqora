import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue, Timestamp;
import 'package:flutter/material.dart' hide Thumb;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

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
import '../../widgets/side_panel.dart';
import 'order_sheets.dart';
import 'order_shared.dart';

class OrderEditorPage extends StatefulWidget {
  final String? id;
  final String? customerId;
  const OrderEditorPage({super.key, this.id, this.customerId});

  @override
  State<OrderEditorPage> createState() => _OrderEditorPageState();
}

/// An item that can be added from the product search.
class _Pick {
  final Doc doc;
  final bool bundle;
  const _Pick(this.doc, this.bundle);
}

class _OrderEditorPageState extends State<OrderEditorPage> {
  final _subs = <StreamSubscription>[];

  // Reference data
  Map<String, Doc> _products = {};
  List<Doc> _bundles = [];
  List<Doc> _customers = [];
  List<Doc> _orders = [];
  List<Doc> _downtimes = [];
  Map<String, Doc> _structures = {};
  Map<String, Doc> _taxProfiles = {};
  List<Doc> _locations = [];
  bool _productsLoaded = false;
  bool _orderLoaded = false;
  bool _notFound = false;
  bool _preselected = false;

  // Order state
  String _status = 'draft';
  int _number = 0;
  String _source = 'manual';
  DateTime? _createdAt;
  String? _customerId;
  String _customerName = '', _customerEmail = '', _customerPhone = '';
  Doc? _customer;
  Map<String, dynamic> _billing = {}, _delivery = {};
  String _fulfillment = 'pickup';
  String? _locationId;
  late DateTime _start, _end;
  List<Map<String, dynamic>> _lines = [];
  num? _discountPercent;
  final _discountCtl = TextEditingController();
  String _couponCode = '';
  String _originalCoupon = '';
  Doc? _coupon;
  num _storedCouponDiscount = 0;
  num _paid = 0;
  List<String> _tags = [];
  Map<String, dynamic> _customFields = {};
  String? _originalCustomerId;

  bool _dirty = false;
  bool _saving = false;

  String? _savedId;
  String? get _id => widget.id ?? _savedId;
  bool get _isNew => _id == null;

  Stream<List<Doc>>? _paymentsStream;
  Stream<List<Doc>>? _documentsStream;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final (ph, pm) = _hm(Session.instance.setting('rentalPeriod', 'pickupTime', '09:00'), 9);
    final (rh, rm) = _hm(Session.instance.setting('rentalPeriod', 'returnTime', '17:00'), 17);
    _start = DateTime(now.year, now.month, now.day, ph, pm);
    _end = DateTime(now.year, now.month, now.day + 1, rh, rm);
    _fulfillment = (Session.instance.setting('fulfillment', 'defaultMethod', 'pickup') as String?) == 'delivery' ? 'delivery' : 'pickup';

    _sub<List<Doc>>(Db.watch(C.products), (v) {
      _products = {for (final p in v) p.id: p};
      _productsLoaded = true;
    });
    _sub<List<Doc>>(Db.watch(C.bundles), (v) => _bundles = v);
    _sub<List<Doc>>(Db.watch(C.customers), (v) {
      _customers = v;
      if (_customerId != null) _customer = v.where((c) => c.id == _customerId).firstOrNull ?? _customer;
      if (!_preselected && widget.customerId != null && _customerId == null) {
        final c = v.where((c) => c.id == widget.customerId).firstOrNull;
        if (c != null) {
          _preselected = true;
          _applyCustomer(c);
        }
      }
    });
    _sub<List<Doc>>(Db.watch(C.orders), (v) => _orders = v);
    _sub<List<Doc>>(Db.watch(C.downtimes), (v) => _downtimes = v);
    _sub<List<Doc>>(Db.watch(C.pricingStructures), (v) {
      _structures = {for (final s in v) s.id: s};
      if (_dirty) _recalc();
    });
    _sub<List<Doc>>(Db.watch(C.taxProfiles), (v) {
      _taxProfiles = {for (final s in v) s.id: s};
      if (_dirty) _recalc();
    });
    _sub<List<Doc>>(Db.watch(C.locations), (v) {
      _locations = v;
      if (_isNew && _locationId == null && v.isNotEmpty) {
        _locationId = (v.where((l) => l.b('isDefault')).firstOrNull ?? v.last).id;
      }
    });
    if (widget.id != null) _attach(widget.id!, loadState: true);
  }

  void _sub<T>(Stream<T> s, void Function(T) on) => _subs.add(s.listen((v) {
        if (mounted) setState(() => on(v));
      }, onError: (_) {}));

  /// Binds live order / payments / documents streams to [id].
  void _attach(String id, {bool loadState = false}) {
    if (!loadState) _orderLoaded = true;
    _paymentsStream = Db.watchWhere(C.payments, 'orderId', id);
    _documentsStream = Db.watchWhere(C.documents, 'orderId', id);
    _sub<Doc?>(Db.watchDoc(C.orders, id), _onOrder);
  }

  static (int, int) _hm(dynamic v, int defH) {
    final p = '${v ?? ''}'.split(':');
    final h = int.tryParse(p.first) ?? defH;
    final m = p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0;
    return (h.clamp(0, 23), m.clamp(0, 59));
  }

  void _onOrder(Doc? o) {
    if (o == null) {
      if (_savedId == null) _notFound = true;
      return;
    }
    _paid = o.n('paid');
    _tags = o.l<String>('tags');
    _number = o.i('number');
    if (_orderLoaded) return;
    _orderLoaded = true;
    _status = o.s('status', 'draft');
    _source = o.s('source', 'manual');
    _createdAt = o.d('createdAt');
    _customerId = o.s('customerId').isEmpty ? null : o.s('customerId');
    _originalCustomerId = _customerId;
    _customerName = o.s('customerName');
    _customerEmail = o.s('customerEmail');
    _customerPhone = o.s('customerPhone');
    _customer = _customers.where((c) => c.id == _customerId).firstOrNull;
    _billing = o.m('billingAddress');
    _delivery = o.m('deliveryAddress');
    _fulfillment = o.s('fulfillment', 'pickup');
    _locationId = o.s('locationId').isEmpty ? null : o.s('locationId');
    _start = o.d('startsAt') ?? _start;
    _end = o.d('stopsAt') ?? _end;
    _lines = o.maps('lines');
    final dp = o.n('discountPercent');
    _discountPercent = dp > 0 ? dp : null;
    _discountCtl.text = dp > 0 ? fmtNum(dp) : '';
    _couponCode = o.s('couponCode');
    _originalCoupon = _couponCode;
    _storedCouponDiscount = o.n('couponDiscount');
    _customFields = o.m('customFields');
    if (_couponCode.isNotEmpty) _loadCoupon(_couponCode);
  }

  Future<void> _loadCoupon(String code) async {
    try {
      final c = (await Db.listWhere(C.coupons, 'code', code.toUpperCase())).firstOrNull;
      if (mounted && c != null) setState(() => _coupon = c);
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _discountCtl.dispose();
    super.dispose();
  }

  void _touch(VoidCallback f) => setState(() {
        f();
        _dirty = true;
      });

  // ---------------------------------------------------------------------------
  // Pricing
  // ---------------------------------------------------------------------------

  num _productPrice(Doc p) => Pricing.unitPrice(p, _start, _end, structure: _structures[p.s('pricingStructureId')]);

  num _bundlePrice(Doc b) {
    final fixed = b.data['price'];
    if (fixed is num && fixed > 0) return fixed;
    num sum = 0;
    for (final it in b.maps('items')) {
      final p = _products[it['productId']];
      if (p == null) continue;
      final qty = (it['qty'] as num?) ?? 1;
      final disc = (it['discount'] as num?) ?? 0;
      sum += _productPrice(p) * qty * (1 - disc / 100);
    }
    return sum;
  }

  num _taxRate(Doc? p) {
    if (p == null || p.data['taxable'] == false) return 0;
    return _taxProfiles[p.s('taxProfileId')]?.n('rate') ?? 0;
  }

  /// Recomputes prices of non-overridden lines for the current period.
  void _recalc() {
    for (final l in _lines) {
      final qty = (l['qty'] as num?) ?? 1;
      if (l['kind'] == 'product') {
        final p = _products[l['productId']];
        if (p != null) {
          if (l['override'] != true) l['unitPrice'] = _productPrice(p);
          l['periods'] = Pricing.periods(_start, _end, p.s('pricePer', 'day'));
          l['taxRate'] = _taxRate(p);
        }
      } else if (l['kind'] == 'bundle' && l['override'] != true) {
        final b = _bundles.where((e) => e.id == l['bundleId']).firstOrNull;
        if (b != null) l['unitPrice'] = _bundlePrice(b);
      }
      l['total'] = _r(((l['unitPrice'] as num?) ?? 0) * qty);
    }
  }

  static num _r(num v) => (v * 100).roundToDouble() / 100;

  num get _subtotal => _lines.fold<num>(0, (a, l) => a + ((l['total'] as num?) ?? 0));

  num _eligibleSubtotal(Doc c) {
    final e = c.s('eligible', 'all');
    if (e == 'all') return _subtotal;
    num s = 0;
    for (final l in _lines) {
      final p = _products[l['productId']];
      if (p == null) continue;
      final ok = e == 'products' ? c.l<String>('productIds').contains(p.id) : p.l<String>('collectionIds').any(c.l<String>('collectionIds').contains);
      if (ok) s += (l['total'] as num?) ?? 0;
    }
    return s;
  }

  num get _couponDiscount {
    if (_couponCode.isEmpty) return 0;
    final c = _coupon;
    if (c == null) return _storedCouponDiscount;
    final base = _eligibleSubtotal(c);
    final v = c.n('value');
    final d = c.s('discountType', 'percentage') == 'fixed' ? (v > base ? base : v) : base * v / 100;
    return _r(d);
  }

  bool get _couponBlocksDiscount => _coupon != null && _coupon!.data['stackWithCustomerDiscount'] == false;

  Map<String, num> get _totals {
    final ws = Session.instance.settings('pricing');
    var mode = _customer?.s('depositMode', 'default') ?? 'default';
    num value = _customer?.n('depositValue') ?? 0;
    if (mode == 'default' || mode.isEmpty) {
      mode = (ws['depositMode'] as String?) ?? 'product';
      value = (ws['depositValue'] as num?) ?? 100;
    }
    final productPct = mode == 'product' ? ((ws['depositValue'] as num?) ?? 100) : 100;
    final t = Pricing.totals(
      lines: _lines,
      discountPercent: _couponBlocksDiscount ? 0 : (_discountPercent ?? 0),
      couponDiscount: _couponDiscount,
      pricesIncludeTax: Session.instance.setting('taxes', 'pricesIncludeTax', false) == true,
      depositPercentOfProducts: productPct,
      productDeposits: {for (final p in _products.values) if (p.n('deposit') > 0) p.id: p.n('deposit')},
    );
    final out = Map<String, num>.from(t);
    switch (mode) {
      case 'none':
        out['deposit'] = 0;
      case 'percentage':
        out['deposit'] = _r(t['total']! * value / 100);
      case 'fixed':
        out['deposit'] = value;
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Availability
  // ---------------------------------------------------------------------------

  int _qtyInOrder(String pid) => _lines.where((l) => l['productId'] == pid).fold<int>(0, (a, l) => a + ((l['qty'] as num?) ?? 0).toInt());

  int _available(Doc p) => Pricing.available(p, _start, _end, _orders, _downtimes, excludeOrderId: _id);

  /// productId -> shortage units for the current lines.
  Map<String, int> get _shortages {
    final out = <String, int>{};
    for (final pid in _lines.map((l) => l['productId']).whereType<String>().toSet()) {
      final p = _products[pid];
      if (p == null || p.s('type') == 'service') continue;
      final short = _qtyInOrder(pid) - _available(p);
      if (short > 0) out[pid] = short;
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  void _applyCustomer(Doc c) {
    _customerId = c.id;
    _customer = c;
    _customerName = c.s('name');
    _customerEmail = c.s('email');
    _customerPhone = c.s('phone');
    final dp = c.n('discountPercent');
    if (dp > 0) {
      _discountPercent = dp;
      _discountCtl.text = fmtNum(dp);
    }
    final addrs = c.maps('addresses');
    if (_billing.isEmpty && addrs.isNotEmpty) {
      _billing = Map<String, dynamic>.from(addrs.firstWhere((a) => a['isMain'] == true, orElse: () => addrs.first))
        ..remove('isMain')
        ..remove('label');
    }
    _dirty = true;
  }

  void _addPick(_Pick pick) {
    HapticFeedback.lightImpact();
    _touch(() {
      if (!pick.bundle) {
        final p = pick.doc;
        final existing = _lines.where((l) => l['productId'] == p.id && l['override'] != true).firstOrNull;
        if (existing != null) {
          existing['qty'] = ((existing['qty'] as num?) ?? 0) + 1;
        } else {
          final imgs = p.l<String>('imageUrls');
          _lines.add({
            'id': Db.newId(),
            'kind': 'product',
            'productId': p.id,
            'name': p.s('name'),
            'qty': 1,
            'unitPrice': 0,
            'periods': 1,
            'total': 0,
            'taxRate': 0,
            'imageUrl': imgs.isEmpty ? '' : imgs.first,
          });
        }
      } else {
        final b = pick.doc;
        _lines.add({
          'id': Db.newId(),
          'kind': 'bundle',
          'bundleId': b.id,
          'name': b.s('name'),
          'qty': 1,
          'unitPrice': 0,
          'periods': 1,
          'total': 0,
          'taxRate': 0,
          'imageUrl': b.s('imageUrl'),
          'items': b.maps('items'),
        });
      }
      _recalc();
    });
  }

  void _setQty(Map<String, dynamic> l, num q) {
    HapticFeedback.selectionClick();
    _touch(() {
      l['qty'] = q < 1 ? 1 : q.toInt();
      _recalc();
    });
  }

  void _setPeriod({DateTime? start, DateTime? end}) => _touch(() {
        if (start != null) {
          final dur = _end.difference(_start);
          _start = start;
          if (!_end.isAfter(_start)) _end = _start.add(dur.inMinutes > 0 ? dur : const Duration(days: 1));
        }
        if (end != null) _end = end;
        _recalc();
      });

  num _autoPrice(Map<String, dynamic> l) {
    if (l['kind'] == 'product') {
      final p = _products[l['productId']];
      return p == null ? 0 : _productPrice(p);
    }
    if (l['kind'] == 'bundle') {
      final b = _bundles.where((e) => e.id == l['bundleId']).firstOrNull;
      return b == null ? 0 : _bundlePrice(b);
    }
    return (l['unitPrice'] as num?) ?? 0;
  }

  Future<void> _editPrice(Map<String, dynamic> l) async {
    final c = TextEditingController(text: fmtNum((l['unitPrice'] as num?) ?? 0));
    final r = await showAppSheet<num>(
      context,
      title: l['kind'] == 'custom' ? 'Edit price' : 'Override price',
      builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${l['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
        const SizedBox(height: 14),
        Field.money(label: 'Price per unit for this period', controller: c),
        if (l['kind'] != 'custom') ...[
          const SizedBox(height: 8),
          Text('Automatic price: ${Fmt.money(_autoPrice(l))}', style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
        ],
        const SizedBox(height: 22),
        GradientButton(label: 'Apply price', icon: Icons.check_rounded, onPressed: () => Navigator.pop(ctx, parseNum(c.text))),
        if (l['override'] == true && l['kind'] != 'custom') ...[
          const SizedBox(height: 8),
          TextButton.icon(onPressed: () => Navigator.pop(ctx, -1), icon: const Icon(Icons.auto_mode_rounded, size: 18), label: const Text('Use automatic price')),
        ],
      ]),
    );
    c.dispose();
    if (r == null) return;
    _touch(() {
      if (r < 0) {
        l['override'] = false;
      } else {
        l['override'] = l['kind'] != 'custom' ? true : l['override'];
        l['unitPrice'] = r;
      }
      _recalc();
    });
  }

  Future<void> _addCustomLine() async {
    final name = TextEditingController(), qty = TextEditingController(text: '1'), price = TextEditingController();
    final ok = await showAppSheet<bool>(
      context,
      title: 'Add custom line',
      builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Field(label: 'Name', controller: name, autofocus: true, hint: 'e.g. Delivery fee, Cleaning'),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: Field.number(label: 'Quantity', controller: qty, decimal: false)),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: Field.money(label: 'Price', controller: price)),
        ]),
        const SizedBox(height: 22),
        GradientButton(label: 'Add line', icon: Icons.add_rounded, onPressed: () => Navigator.pop(ctx, true)),
      ]),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      HapticFeedback.lightImpact();
      _touch(() {
        _lines.add({
          'id': Db.newId(),
          'kind': 'custom',
          'productId': null,
          'name': name.text.trim(),
          'qty': parseNum(qty.text, 1).toInt().clamp(1, 100000),
          'unitPrice': parseNum(price.text),
          'periods': 1,
          'total': 0,
          'taxRate': 0,
          'imageUrl': '',
          'override': true,
        });
        _recalc();
      });
    } else if (ok == true && mounted) {
      toast(context, 'Enter a name for the line', error: true);
    }
    name.dispose();
    qty.dispose();
    price.dispose();
  }

  Future<void> _addCoupon() async {
    final c = TextEditingController();
    String? err;
    var busy = false;
    final applied = await showAppSheet<Doc>(
      context,
      title: 'Add a coupon',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Field(
            label: 'Coupon code',
            controller: c,
            autofocus: true,
            hint: 'SUMMER10',
            prefix: const Icon(Icons.local_offer_outlined, size: 18),
            inputFormatters: [TextInputFormatter.withFunction((o, n) => n.copyWith(text: n.text.toUpperCase()))],
          ),
          if (err != null) ...[const SizedBox(height: 12), InfoBanner(err!, tone: Tone.danger, icon: Icons.error_outline)],
          const SizedBox(height: 22),
          GradientButton(
            label: 'Apply coupon',
            busy: busy,
            onPressed: () async {
              setD(() => busy = true);
              final (doc, e) = await _validateCoupon(c.text.trim());
              if (!ctx.mounted) return;
              if (doc != null) {
                Navigator.pop(ctx, doc);
              } else {
                HapticFeedback.heavyImpact();
                setD(() {
                  err = e;
                  busy = false;
                });
              }
            },
          ),
        ]),
      ),
    );
    c.dispose();
    if (applied != null) {
      HapticFeedback.mediumImpact();
      _touch(() {
        _coupon = applied;
        _couponCode = applied.s('code').toUpperCase();
      });
      if (mounted) toast(context, 'Coupon $_couponCode applied');
    }
  }

  Future<(Doc?, String?)> _validateCoupon(String raw) async {
    final code = raw.toUpperCase();
    if (code.isEmpty) return (null, 'Enter a coupon code');
    try {
      final c = (await Db.listWhere(C.coupons, 'code', code)).firstOrNull;
      if (c == null) return (null, 'No coupon found with code $code');
      if (!c.b('active')) return (null, 'This coupon is not active');
      final now = DateTime.now();
      final s = c.d('startsAt'), e = c.d('endsAt');
      if (s != null && s.isAfter(now)) return (null, 'This coupon is valid from ${Fmt.date(s)}');
      if (e != null && e.isBefore(now)) return (null, 'This coupon expired on ${Fmt.date(e)}');
      final max = c.i('maxUses');
      if (max > 0 && c.i('uses') >= max && code != _originalCoupon) return (null, 'This coupon has reached its usage limit');
      final min = c.n('minimumSpend');
      if (min > 0 && _subtotal < min) return (null, 'A minimum spend of ${Fmt.money(min)} is required');
      if (_eligibleSubtotal(c) <= 0) return (null, 'No products in this order are eligible for this coupon');
      return (c, null);
    } catch (e) {
      return (null, friendlyError(e));
    }
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _payload(String status) {
    final t = _totals;
    final total = t['total']!;
    return {
      'status': status,
      'customerId': _customerId ?? '',
      'customerName': _customerName,
      'customerEmail': _customerEmail,
      'customerPhone': _customerPhone,
      'billingAddress': _billing,
      'deliveryAddress': _delivery,
      'fulfillment': _fulfillment,
      'locationId': _locationId ?? '',
      'startsAt': Timestamp.fromDate(_start),
      'stopsAt': Timestamp.fromDate(_end),
      'lines': _lines,
      'discountPercent': _couponBlocksDiscount ? 0 : (_discountPercent ?? 0),
      'couponCode': _couponCode,
      'couponDiscount': _couponDiscount,
      'subtotal': t['subtotal'],
      'discountTotal': t['discountTotal'],
      'taxTotal': t['taxTotal'],
      'total': total,
      'deposit': t['deposit'],
      'paid': _paid,
      'due': OrderX.dueOf(total, _paid),
      'paymentStatus': Pricing.paymentStatus(total, _paid),
      'itemCount': t['itemCount']!.toInt(),
      'customFields': _customFields,
      'tags': _tags,
    };
  }

  /// Saves the order. Returns (id, data) or null on failure.
  Future<(String, Map<String, dynamic>)?> _persist({String? status, String? successMessage}) async {
    if (!_end.isAfter(_start)) {
      HapticFeedback.heavyImpact();
      toast(context, 'The return date must be after the pickup date', error: true);
      return null;
    }
    final st = status ?? _status;
    if (st != 'draft' && st != 'canceled' && _lines.isEmpty) {
      HapticFeedback.heavyImpact();
      toast(context, 'Add at least one product before changing the status', error: true);
      return null;
    }
    setState(() => _saving = true);
    try {
      final data = _payload(st);
      String id;
      final created = _isNew;
      if (created) {
        final n = await Db.nextNumber('order');
        data['number'] = n;
        data['source'] = 'manual';
        id = await Db.create(C.orders, data, label: 'Order #$n');
        _number = n;
        _savedId = id;
        Session.instance.markOnboarding('order').catchError((_) {});
      } else {
        id = _id!;
        await Db.update(C.orders, id, data, label: 'Order ${_number > 0 ? '#$_number' : 'web order'}');
        data['number'] = _number;
      }
      if (_couponCode.isNotEmpty && _couponCode != _originalCoupon && _coupon != null) {
        Db.update(C.coupons, _coupon!.id, {'uses': FieldValue.increment(1)}, silent: true).catchError((_) {});
        _originalCoupon = _couponCode;
      }
      await OrderX.syncCustomer(_customerId);
      if (_originalCustomerId != null && _originalCustomerId != _customerId) await OrderX.syncCustomer(_originalCustomerId);
      _originalCustomerId = _customerId;
      if (!mounted) return (id, data);
      setState(() {
        _status = st;
        _dirty = false;
        _saving = false;
        if (created) _attach(id);
      });
      HapticFeedback.mediumImpact();
      toast(context, successMessage ?? (created ? 'Order #$_number created' : 'Order saved'));
      return (id, data);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        toast(context, friendlyError(e), error: true);
      }
      return null;
    }
  }

  Future<void> _transition(String to) async {
    if (to == 'reserved') {
      final short = _shortages;
      final blocking = short.entries.where((e) => _products[e.key]?.b('allowShortage') != true).toList();
      if (blocking.isNotEmpty) {
        HapticFeedback.heavyImpact();
        await _shortageSheet(blocking);
        return;
      }
    }
    if (to == 'canceled') {
      final ok = await confirmDialog(context,
          title: 'Cancel this order?', message: 'The reserved items will be released for other orders.', confirmLabel: 'Cancel order', danger: true);
      if (!ok) return;
    }
    const msg = {
      'reserved': 'Order reserved',
      'started': 'Items picked up',
      'returned': 'Items returned',
      'archived': 'Order archived',
      'canceled': 'Order canceled',
      'draft': 'Order moved back to draft',
    };
    await _persist(status: to, successMessage: msg[to]);
  }

  Future<void> _shortageSheet(List<MapEntry<String, int>> blocking) => showAppSheet<void>(
        context,
        title: 'Not enough stock to reserve',
        builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('These products are unavailable between ${Fmt.dateTime(_start)} and ${Fmt.dateTime(_end)}:',
              style: const TextStyle(color: AppColors.inkSoft, height: 1.45)),
          const SizedBox(height: 14),
          for (var i = 0; i < blocking.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.warningSoft, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Thumb(url: _products[blocking[i].key]?.l<String>('imageUrls').firstOrNull, size: 38),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(_products[blocking[i].key]?.s('name') ?? 'Product',
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                StatusPill('shortage', label: 'Short ${blocking[i].value}', dot: false),
              ]),
            ).enter(i),
          const SizedBox(height: 8),
          const Text('Reduce quantities, change the period, or allow shortages on the product to continue.',
              style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.45)),
          const SizedBox(height: 20),
          GradientButton(label: 'Review order', onPressed: () => Navigator.pop(ctx)),
        ]),
      );

  Future<void> _duplicate() async {
    try {
      final data = _payload('draft');
      final n = await Db.nextNumber('order');
      data['number'] = n;
      data['source'] = 'manual';
      data['paid'] = 0;
      data['due'] = data['total'];
      data['paymentStatus'] = Pricing.paymentStatus(data['total'] as num, 0);
      data['couponCode'] = '';
      data['couponDiscount'] = 0;
      final id = await Db.create(C.orders, data, label: 'Order #$n');
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      toast(context, 'Order duplicated as #$n');
      context.push('/orders/$id');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context,
        title: 'Delete order?', message: 'This permanently deletes the order. This cannot be undone.', confirmLabel: 'Delete', danger: true);
    if (!ok) return;
    try {
      await Db.remove(C.orders, _id!, label: 'Order #$_number');
      await OrderX.syncCustomer(_customerId);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      toast(context, 'Order deleted');
      setState(() => _dirty = false);
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  Future<void> _createCustomerFromOrder() async {
    final c = await showNewCustomerSheet(context, name: _customerName, email: _customerEmail, phone: _customerPhone);
    if (c == null || !mounted) return;
    setState(() => _applyCustomer(c));
    await _persist(successMessage: 'Customer linked to order');
  }

  Future<void> _pickCustomer() async {
    final c = await showCustomerPickerSheet(context, _customers);
    if (c != null && mounted) setState(() => _applyCustomer(c));
  }

  /// Ensures the order is saved (saving pending changes), returning its id/data.
  Future<(String, Map<String, dynamic>)?> _ensureSaved() async {
    if (!_isNew && !_dirty) return (_id!, {..._payload(_status), 'number': _number});
    return _persist();
  }

  Future<void> _createDocument(String type) async {
    HapticFeedback.lightImpact();
    final saved = await _ensureSaved();
    if (saved == null || !mounted) return;
    try {
      final id = await DocType.createFromOrder(type, saved.$1, saved.$2);
      if (!mounted) return;
      toast(context, '${DocType.title[type]} created');
      context.push('/documents/$id');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  Future<void> _collectOnline() async {
    final saved = await _ensureSaved();
    if (saved == null || !mounted) return;
    await showOnlinePaymentSheet(
      context,
      orderId: saved.$1,
      orderLabel: _number > 0 ? '#$_number' : 'order',
      due: OrderX.dueOf(_totals['total']!, _paid),
      customerName: _customerName,
      customerEmail: _customerEmail,
    );
  }

  Future<void> _addPayment() async {
    final saved = await _ensureSaved();
    if (saved == null || !mounted) return;
    final due = OrderX.dueOf(_totals['total']!, _paid);
    final p = await showPaymentSheet(context, suggested: due);
    if (p == null) return;
    try {
      await OrderX.recordPayment(orderId: saved.$1, orderNumber: _number, amount: p.amount, method: p.method, kind: p.kind, note: p.note);
      if (mounted) toast(context, p.kind == 'refund' ? 'Refund recorded' : 'Payment recorded');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  Future<void> _sendConfirmation() async {
    final saved = await _ensureSaved();
    if (saved == null || !mounted) return;
    await showEmailSheet(
      context,
      emailContext: 'orders',
      to: _customerEmail,
      entityId: saved.$1,
      title: 'Send order confirmation',
      vars: {'order.number': '$_number', 'customer.name': _customerName, 'company.name': companyName},
      defaultSubject: 'Your order #{{order.number}} is confirmed',
      defaultBody:
          'Hi {{customer.name}},\n\nThank you for your order #{{order.number}}.\nPickup: ${Fmt.dateTime(_start)}\nReturn: ${Fmt.dateTime(_end)}\nTotal: ${Fmt.money(_totals['total'])}\n\nKind regards,\n{{company.name}}',
    );
  }

  Future<DateTime?> _pickDateTime(DateTime initial, {DateTime? first}) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: first != null && initial.isBefore(first) ? first : initial,
      firstDate: first ?? DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (d == null || !mounted) return null;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    return DateTime(d.year, d.month, d.day, t?.hour ?? initial.hour, t?.minute ?? initial.minute);
  }

  Future<void> _pickLocation() async {
    final id = await showAppSheet<String>(
      context,
      title: 'Location',
      builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final l in _locations)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: const IconBadge(Icons.storefront_outlined, size: 38),
            title: Text(l.s('name'), style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: l.s('address').isEmpty ? null : Text(l.s('address'), maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: l.id == _locationId ? const Icon(Icons.check_circle_rounded, color: AppColors.primary) : null,
            onTap: () => Navigator.pop(ctx, l.id),
          ),
      ]),
    );
    if (id != null) _touch(() => _locationId = id);
  }

  // ---------------------------------------------------------------------------
  // Product picker sheet
  // ---------------------------------------------------------------------------

  Future<void> _openProductPicker() async {
    HapticFeedback.selectionClick();
    var q = '';
    var kind = 'all';
    await showAppSheet<void>(
      context,
      title: 'Add products',
      scroll: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
        final ql = q.toLowerCase();
        final picks = <_Pick>[
          if (kind != 'bundles')
            for (final p in _products.values.where((p) => p.s('status', 'active') == 'active')) _Pick(p, false),
          if (kind != 'products')
            for (final b in _bundles) _Pick(b, true),
        ].where((p) => ql.isEmpty || '${p.doc.s('name')} ${p.doc.s('sku')}'.toLowerCase().contains(ql)).toList()
          ..sort((a, b) => a.doc.s('name').toLowerCase().compareTo(b.doc.s('name').toLowerCase()));
        final inOrder = _lines.fold<int>(0, (a, l) => a + ((l['qty'] as num?) ?? 0).toInt());
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          MSearch(hint: 'Search name or SKU', onChanged: (v) => setD(() => q = v.trim())),
          const SizedBox(height: 10),
          ChoiceChipsBar<String>(
            options: const [('all', 'All'), ('products', 'Products'), ('bundles', 'Bundles')],
            value: kind,
            onChanged: (v) => setD(() => kind = v),
          ),
          const SizedBox(height: 6),
          Text('Prices and availability for ${Fmt.shortDate(_start)} → ${Fmt.shortDate(_end)}',
              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 6),
          Flexible(
            child: picks.isEmpty
                ? const EmptyState(icon: Icons.search_off_rounded, title: 'Nothing found', message: 'Try another name or SKU.', compact: true)
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: picks.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1EEF7)),
                    itemBuilder: (_, i) {
                      final o = picks[i];
                      final qty = o.bundle ? 0 : _qtyInOrder(o.doc.id);
                      return InkWell(
                        onTap: () {
                          _addPick(o);
                          setD(() {});
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(children: [
                            Thumb(
                              url: o.bundle ? o.doc.s('imageUrl') : o.doc.l<String>('imageUrls').firstOrNull,
                              size: 46,
                              icon: o.bundle ? Icons.widgets_outlined : Icons.inventory_2_outlined,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(o.doc.s('name'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(
                                  o.bundle ? 'Bundle · ${o.doc.maps('items').length} items · ${Fmt.money(_bundlePrice(o.doc))}' : Fmt.money(_productPrice(o.doc)),
                                  style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                                ),
                                if (!o.bundle) ...[const SizedBox(height: 4), _availBadge(o.doc, _available(o.doc) - qty)],
                              ]),
                            ),
                            const SizedBox(width: 8),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                              child: qty > 0
                                  ? Container(
                                      key: ValueKey('q$qty'),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(20)),
                                      child: Text('$qty', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                                    )
                                  : Container(
                                      key: const ValueKey('add'),
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(11)),
                                      child: const Icon(Icons.add_rounded, color: AppColors.primary, size: 20),
                                    ),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          GradientButton(label: inOrder == 0 ? 'Done' : 'Done · $inOrder item${inOrder == 1 ? '' : 's'}', onPressed: () => Navigator.pop(ctx)),
        ]);
      }),
    );
  }

  Widget _availBadge(Doc p, int remaining) {
    if (p.s('type') == 'service') return const StatusPill('scheduled', label: 'Service', dot: false);
    if (remaining < 0) return StatusPill('shortage', label: 'Shortage ${-remaining}', dot: false);
    return StatusPill(remaining == 0 ? 'late' : 'available', label: '$remaining available', dot: false);
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_notFound) {
      return _scaffold(
        'Order',
        const EmptyState(icon: Icons.search_off, title: 'Order not found', message: 'It may have been deleted or you may not have access to it.'),
      );
    }
    if (!_productsLoaded || (!_isNew && !_orderLoaded)) return _scaffold(_isNew ? 'New order' : 'Order', const LoadingView());
    if (_isNew && _products.isEmpty) return _scaffold('New order', _noProducts());

    final title = _isNew ? 'New order' : (_number > 0 ? 'Order #$_number' : 'Web order');
    final sections = <Widget>[
      if (_source == 'online' && _customerId == null && _customerName.isNotEmpty)
        InfoBanner(
          'This web order was placed by $_customerName and is not linked to a customer profile yet.',
          tone: Tone.brand,
          icon: Icons.language,
          actionLabel: 'Link',
          onAction: _createCustomerFromOrder,
        ),
      _customerSection(),
      _periodSection(),
      _productsSection(),
      _totalsSection(),
      _paymentsSection(),
      _documentsSection(),
      _emailSection(),
      if (_id != null) ...[
        TagsCard(collection: C.orders, id: _id!, tags: _tags),
        NotesCard(entity: 'orders', entityId: _id!),
        ActivityCard(entityId: _id),
      ] else
        const InfoBanner('Tags, notes and the activity log become available once the order is saved.', tone: Tone.brand),
    ];

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirmDialog(context,
            title: 'Discard changes?', message: 'You have unsaved changes on this order.', confirmLabel: 'Discard', danger: true);
        if (leave && mounted) {
          setState(() => _dirty = false);
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => Navigator.of(context).maybePop()),
          title: Text(title),
          actions: [
            if (_dirty)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Center(child: StatusPill('partially_paid', label: 'Unsaved', dot: false)),
              ),
            IconButton(tooltip: 'More actions', icon: const Icon(Icons.more_horiz_rounded), onPressed: _moreMenu),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: _headerCard()),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                for (var i = 0; i < sections.length; i++) Padding(padding: const EdgeInsets.only(bottom: 4), child: sections[i].enter(i, 0.04)),
              ],
            ),
          ),
        ]),
        bottomNavigationBar: _actionBar(),
      ),
    );
  }

  Widget _scaffold(String title, Widget body) => Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => Navigator.of(context).maybePop()),
          title: Text(title),
        ),
        body: body,
      );

  Widget _noProducts() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 12))],
            ),
            child: const Icon(Icons.inventory_2_outlined, color: Colors.white, size: 40),
          ).pop(),
          const SizedBox(height: 24),
          Text('Add products first', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center).enter(1),
          const SizedBox(height: 8),
          const Text(
            'Orders are built from your inventory. Create a product with its price and stock, then come back to book it.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, height: 1.5),
          ).enter(2),
          const SizedBox(height: 28),
          GradientButton(label: 'Create product', icon: Icons.add_rounded, onPressed: () => context.push('/inventory/products/new')).enter(3),
        ]),
      ),
    );
  }

  Widget _headerCard() {
    final t = _totals;
    final due = OrderX.dueOf(t['total']!, _paid);
    final shortages = _shortages;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: AppColors.primaryDeep.withValues(alpha: 0.28), blurRadius: 22, offset: const Offset(0, 10))],
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(
                  _isNew ? 'New order' : (_number > 0 ? '#$_number' : 'Web order'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                ),
              ),
              const SizedBox(width: 8),
              _HeaderPill(Fmt.label(_status)),
            ]),
            const SizedBox(height: 6),
            Text(
              shortages.isNotEmpty
                  ? 'Shortage on ${shortages.length} product${shortages.length == 1 ? '' : 's'}'
                  : (_source == 'online' ? 'Web order · ${Fmt.dateTime(_createdAt)}' : durationText(_start, _end)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: shortages.isNotEmpty ? const Color(0xFFFFD58A) : Colors.white.withValues(alpha: 0.8), fontSize: 12.5),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              Fmt.money(t['total']),
              key: ValueKey(t['total']),
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            due > 0 ? 'Due ${Fmt.money(due)}' : (t['total']! > 0 ? 'Fully paid' : '${t['itemCount']!.toInt()} items'),
            style: TextStyle(color: due > 0 ? const Color(0xFFFFC9C9) : const Color(0xFFB8F5CC), fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ]),
      ]),
    ).enter();
  }

  Widget _sectionTitle(String t, IconData icon, {Widget? trailing}) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(children: [
          IconBadge(icon, size: 32),
          const SizedBox(width: 10),
          Expanded(child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
          ?trailing,
        ]),
      );

  Widget _section(String label, List<Widget> children) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionLabel(label),
        Group(children: children),
      ]);

  // ---- Customer ----
  Widget _customerSection() {
    final hasCustomer = _customerId != null || _customerName.isNotEmpty;
    return _section('Customer', [
      if (!hasCustomer)
        Row(children: [
          Expanded(
            child: _ActionTile(icon: Icons.person_search_outlined, label: 'Select customer', onTap: _pickCustomer, primary: true),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ActionTile(
              icon: Icons.person_add_alt_1_outlined,
              label: 'New customer',
              onTap: () async {
                final c = await showNewCustomerSheet(context);
                if (c != null && mounted) setState(() => _applyCustomer(c));
              },
            ),
          ),
        ])
      else
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: PressScale(
            key: ValueKey(_customerId ?? _customerName),
            onTap: _pickCustomer,
            child: Row(children: [
              Avatar(_customerName, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_customerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  if (_customerEmail.isNotEmpty) _iconText(Icons.mail_outline, _customerEmail),
                  if (_customerPhone.isNotEmpty) _iconText(Icons.phone_outlined, _customerPhone),
                  if ((_customer?.n('discountPercent') ?? 0) > 0) ...[
                    const SizedBox(height: 6),
                    StatusPill('active', label: '${fmtNum(_customer!.n('discountPercent'))}% customer discount', dot: false),
                  ],
                ]),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: AppColors.muted),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                onSelected: (v) {
                  switch (v) {
                    case 'change':
                      _pickCustomer();
                    case 'open':
                      context.push('/customers/$_customerId');
                    case 'remove':
                      _touch(() {
                        _customerId = null;
                        _customer = null;
                        _customerName = _customerEmail = _customerPhone = '';
                      });
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'change', child: Text('Change customer')),
                  if (_customerId != null) const PopupMenuItem(value: 'open', child: Text('Open profile')),
                  const PopupMenuItem(value: 'remove', child: Text('Remove from order', style: TextStyle(color: AppColors.danger))),
                ],
              ),
            ]),
          ),
        ),
      const Divider(height: 1, color: Color(0xFFF1EEF7)),
      _addressRow('Billing address', _billing, (a) => _touch(() => _billing = a)),
      _addressRow('Delivery address', _delivery, (a) => _touch(() => _delivery = a)),
      const Divider(height: 1, color: Color(0xFFF1EEF7)),
      Row(children: [
        Expanded(
          child: OptionChip(
            label: 'Pickup',
            icon: Icons.storefront_outlined,
            selected: _fulfillment == 'pickup',
            onTap: () => _touch(() => _fulfillment = 'pickup'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OptionChip(
            label: 'Delivery',
            icon: Icons.local_shipping_outlined,
            selected: _fulfillment == 'delivery',
            onTap: () => _touch(() => _fulfillment = 'delivery'),
          ),
        ),
      ]),
      if (_locations.isNotEmpty)
        NavRow(
          icon: Icons.place_outlined,
          title: _locations.where((l) => l.id == _locationId).firstOrNull?.s('name') ?? 'Select location',
          subtitle: 'Location',
          onTap: _pickLocation,
        ),
    ]);
  }

  Widget _iconText(IconData i, String t) => Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(children: [
          Icon(i, size: 14, color: AppColors.muted),
          const SizedBox(width: 6),
          Flexible(child: Text(t, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.inkSoft))),
        ]),
      );

  Widget _addressRow(String label, Map<String, dynamic> a, ValueChanged<Map<String, dynamic>> onSave) {
    final text = addressText(a);
    return NavRow(
      icon: text.isEmpty ? Icons.add_location_alt_outlined : Icons.location_on_outlined,
      title: label,
      subtitle: text.isEmpty ? 'Add address' : text.replaceAll('\n', ', '),
      color: text.isEmpty ? AppColors.muted : AppColors.primary,
      onTap: () async {
        final r = await showAddressSheet(context, label, a);
        if (r != null) onSave(r);
      },
    );
  }

  // ---- Period ----
  Widget _periodSection() {
    final valid = _end.isAfter(_start);
    Widget tile(String label, DateTime v, IconData icon, VoidCallback onTap) => Expanded(
          child: PressScale(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(icon, size: 15, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(label.toUpperCase(), style: const TextStyle(fontSize: 11, letterSpacing: 0.6, fontWeight: FontWeight.w700, color: AppColors.muted)),
                ]),
                const SizedBox(height: 8),
                Text(Fmt.shortDate(v), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
                Text('${Fmt.dayLabel(v).split(' ').first} · ${Fmt.time(v)}', style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
              ]),
            ),
          ),
        );
    return _section('Rental period', [
      Row(children: [
        tile('Pickup', _start, Icons.outbox_outlined, () async {
          final d = await _pickDateTime(_start);
          if (d != null) _setPeriod(start: d);
        }),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.muted)),
        tile('Return', _end, Icons.assignment_return_outlined, () async {
          final d = await _pickDateTime(_end, first: DateTime(_start.year, _start.month, _start.day));
          if (d != null) _setPeriod(end: d);
        }),
      ]),
      AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: valid ? AppColors.primarySoft : AppColors.dangerSoft, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(Icons.timelapse_rounded, size: 18, color: valid ? AppColors.primary : AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              valid ? durationText(_start, _end) : 'Return must be after pickup',
              style: TextStyle(fontWeight: FontWeight.w700, color: valid ? AppColors.primaryDeep : AppColors.danger),
            ),
          ),
        ]),
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final q in const [('1 day', Duration(days: 1)), ('2 days', Duration(days: 2)), ('3 days', Duration(days: 3)), ('1 week', Duration(days: 7)), ('1 month', Duration(days: 30))])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                label: Text(q.$1),
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: AppColors.inkSoft),
                side: const BorderSide(color: AppColors.border),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  _setPeriod(end: _start.add(q.$2));
                },
              ),
            ),
        ]),
      ),
    ]);
  }

  // ---- Products ----
  Widget _productsSection() {
    final shortages = _shortages;
    return _section('Products', [
      _sectionTitle(
        '${_lines.length} line${_lines.length == 1 ? '' : 's'}',
        Icons.inventory_2_outlined,
        trailing: TextButton.icon(onPressed: _addCustomLine, icon: const Icon(Icons.add, size: 18), label: const Text('Custom')),
      ),
      if (_lines.isEmpty)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: AppColors.bg, border: Border.all(color: AppColors.border)),
          child: const Column(children: [
            Icon(Icons.add_shopping_cart_rounded, color: AppColors.lavender, size: 34),
            SizedBox(height: 8),
            Text('No products yet', style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            Text('Add products or bundles. Prices update with the rental period.',
                textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 13)),
          ]),
        )
      else
        Column(children: [
          for (var i = 0; i < _lines.length; i++) KeyedSubtree(key: ValueKey(_lines[i]['id']), child: _lineCard(_lines[i], shortages)),
        ]),
      GradientButton(label: 'Add products', icon: Icons.add_shopping_cart_rounded, height: 50, onPressed: _openProductPicker),
    ]);
  }

  Widget _lineCard(Map<String, dynamic> l, Map<String, int> shortages) {
    final kind = l['kind'] as String? ?? 'product';
    final p = _products[l['productId']];
    final qty = ((l['qty'] as num?) ?? 1).toInt();
    final unit = (l['unitPrice'] as num?) ?? 0;
    final periods = (l['periods'] as num?) ?? 1;
    final per = p?.s('pricePer', 'day') ?? 'day';
    Widget badge = const SizedBox.shrink();
    if (kind == 'product' && p != null && p.s('type') != 'service') {
      final short = shortages[p.id];
      badge = short != null
          ? StatusPill('shortage', label: 'Shortage $short', dot: false)
          : StatusPill('available', label: '${_available(p) - _qtyInOrder(p.id)} more free', dot: false);
    } else if (kind == 'bundle') {
      badge = const StatusPill('scheduled', label: 'Bundle', dot: false);
    } else if (kind == 'custom') {
      badge = const StatusPill('custom', label: 'Custom', dot: false);
    }

    return Dismissible(
      key: ValueKey('line-${l['id']}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        _touch(() => _lines.remove(l));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: shortages.containsKey(p?.id) ? AppColors.warning.withValues(alpha: 0.5) : AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Thumb(
              url: (l['imageUrl'] as String?) ?? '',
              size: 48,
              icon: kind == 'bundle' ? Icons.widgets_outlined : (kind == 'custom' ? Icons.receipt_outlined : Icons.inventory_2_outlined),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${l['name'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  badge,
                  if (kind == 'product' && p != null && p.s('pricingMethod', 'flat') == 'flat' && p.s('type', 'rental') == 'rental')
                    Text('$periods $per${periods == 1 ? '' : 's'}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  if (l['override'] == true && kind != 'custom')
                    const Text('Price overridden', style: TextStyle(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w600)),
                ]),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _Stepper(
              qty: qty,
              onMinus: qty > 1 ? () => _setQty(l, qty - 1) : null,
              onPlus: () => _setQty(l, qty + 1),
            ),
            const Spacer(),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _editPrice(l),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(Fmt.money(l['total'] as num?), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('${Fmt.money(unit)} each', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    const SizedBox(width: 4),
                    const Icon(Icons.edit_outlined, size: 12, color: AppColors.primary),
                  ]),
                ]),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  // ---- Totals ----
  Widget _totalsSection() {
    final t = _totals;
    final inclTax = Session.instance.setting('taxes', 'pricesIncludeTax', false) == true;
    return _section('Summary', [
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        KV('Subtotal', Fmt.money(t['subtotal'])),
        if (_discountPercent == null)
          _LinkRow(
            icon: Icons.percent_rounded,
            label: 'Add a discount',
            onTap: () => _touch(() {
              _discountPercent = _customer?.n('discountPercent') ?? 0;
              _discountCtl.text = fmtNum(_discountPercent!);
            }),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              const Expanded(child: Text('Discount', style: TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w500))),
              SizedBox(
                width: 96,
                child: TextField(
                  controller: _discountCtl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(suffixText: '%', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                  onChanged: (v) => _touch(() => _discountPercent = parseNum(v).clamp(0, 100)),
                ),
              ),
              IconButton(
                tooltip: 'Remove discount',
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () => _touch(() {
                  _discountPercent = null;
                  _discountCtl.clear();
                }),
              ),
            ]),
          ),
        if (_couponBlocksDiscount && (_discountPercent ?? 0) > 0)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text('This coupon cannot be combined with the manual discount.', style: TextStyle(fontSize: 12, color: AppColors.warning)),
          ),
        if (_couponCode.isEmpty)
          _LinkRow(icon: Icons.local_offer_outlined, label: 'Add a coupon', onTap: _addCoupon)
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              const Expanded(child: Text('Coupon', style: TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w500))),
              Flexible(
                child: InputChip(
                  avatar: const Icon(Icons.local_offer, size: 14, color: AppColors.primary),
                  label: Text('$_couponCode · -${Fmt.money(_couponDiscount)}', overflow: TextOverflow.ellipsis),
                  visualDensity: VisualDensity.compact,
                  onDeleted: () => _touch(() {
                    _couponCode = '';
                    _coupon = null;
                    _storedCouponDiscount = 0;
                  }),
                ).pop(),
              ),
            ]),
          ),
        const Divider(height: 20),
        KV('Total discount', t['discountTotal']! > 0 ? '-${Fmt.money(t['discountTotal'])}' : Fmt.money(0)),
        KV(inclTax ? 'Tax (included)' : 'Tax', Fmt.money(t['taxTotal'])),
        const Divider(height: 20),
        KV('Total incl. taxes', Fmt.money(t['total']), bold: true),
        KV('Security deposit', Fmt.money(t['deposit']), color: AppColors.inkSoft),
      ]),
    ]);
  }

  // ---- Payments ----
  Widget _paymentsSection() {
    final t = _totals;
    final due = OrderX.dueOf(t['total']!, _paid);
    final payStatus = Pricing.paymentStatus(t['total']!, _paid);
    return _section('Payments', [
      Row(children: [
        Expanded(child: _stat('Paid', _paid, AppColors.success, Icons.check_circle_outline_rounded)),
        const SizedBox(width: 10),
        Expanded(child: _stat('Due', due, due > 0 ? AppColors.danger : AppColors.muted, Icons.schedule_rounded)),
      ]),
      if (!(t['total']! <= 0 && _paid <= 0)) Align(alignment: Alignment.centerLeft, child: StatusPill(payStatus)),
      if (_paymentsStream != null)
        StreamBuilder<List<Doc>>(
          stream: _paymentsStream,
          builder: (context, s) {
            final pays = s.data ?? [];
            if (pays.isEmpty) return const Text('No payments recorded yet.', style: TextStyle(fontSize: 13, color: AppColors.muted));
            final held = pays.where((p) => p.s('kind') == 'deposit').fold<num>(0, (a, p) => a + p.n('amount'));
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final p in pays.take(8))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    IconBadge(
                      p.s('kind') == 'refund'
                          ? Icons.call_made_rounded
                          : (p.s('kind') == 'deposit' ? Icons.shield_outlined : Icons.call_received_rounded),
                      color: p.s('kind') == 'refund' ? AppColors.danger : (p.s('kind') == 'deposit' ? AppColors.info : AppColors.success),
                      size: 34,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${Fmt.label(p.s('kind'))} · ${Fmt.label(p.s('method'))}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                        Text(
                          [Fmt.dateTime(p.d('paidAt') ?? p.created), if (p.s('note').isNotEmpty) p.s('note')].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                      ]),
                    ),
                    Text('${p.s('kind') == 'refund' ? '-' : ''}${Fmt.money(p.n('amount'))}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                ),
              if (held > 0) KV('Deposit held', Fmt.money(held)),
            ]);
          },
        ),
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: _saving ? null : _addPayment,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add payment'),
          ),
        ),
        if (due > 0) ...[
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: _saving ? null : _collectOnline,
              icon: const Icon(Icons.bolt_rounded, size: 18),
              label: const Text('Collect online'),
            ),
          ),
        ],
      ]),
    ]);
  }

  Widget _stat(String label, num value, Color color, IconData icon) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: CountUp(value: value, format: Fmt.money, style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 17)),
          ),
        ]),
      );

  // ---- Documents ----
  Widget _documentsSection() {
    return _section('Documents', [
      if (_documentsStream != null)
        StreamBuilder<List<Doc>>(
          stream: _documentsStream,
          builder: (context, s) {
            final docs = s.data ?? [];
            if (docs.isEmpty) return const Text('No documents yet. Create one below.', style: TextStyle(fontSize: 13, color: AppColors.muted));
            return Column(children: [
              for (final d in docs)
                NavRow(
                  icon: _docIcon(d.s('type')),
                  title: '${DocType.title[d.s('type')] ?? 'Document'} ${DocType.number(d)}',
                  subtitle: '${Fmt.date(d.d('date') ?? d.created)}${d.s('type') == 'packing' ? '' : ' · ${Fmt.money(d.n('total'))}'}',
                  trailing: d.b('finalized')
                      ? const StatusPill('finalized', dot: false)
                      : (d.b('sent') ? const StatusPill('sent', dot: false) : const Icon(Icons.chevron_right_rounded, color: AppColors.muted)),
                  onTap: () => context.push('/documents/${d.id}'),
                ),
            ]);
          },
        ),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.9,
        children: [
          for (final e in const [
            ('quote', 'Quote'),
            ('contract', 'Contract'),
            ('packing', 'Packing slip'),
            ('invoice', 'Invoice'),
          ])
            _ActionTile(icon: _docIcon(e.$1), label: e.$2, compact: true, onTap: _saving ? null : () => _createDocument(e.$1)),
        ],
      ),
    ]);
  }

  static IconData _docIcon(String type) => switch (type) {
        'quote' => Icons.request_quote_outlined,
        'contract' => Icons.handshake_outlined,
        'packing' => Icons.checklist_rtl_rounded,
        _ => Icons.receipt_long_outlined,
      };

  // ---- Email ----
  Widget _emailSection() {
    return _section('Email', [
      NavRow(
        icon: Icons.send_outlined,
        title: 'Send confirmation',
        subtitle: _customerEmail.isEmpty ? 'Add a customer with an email address' : 'To $_customerEmail',
        onTap: _saving ? () {} : _sendConfirmation,
      ),
    ]);
  }

  // ---- Bottom bar / menu ----
  (String, IconData, String)? get _primaryAction => switch (_status) {
        'draft' => ('Reserve', Icons.event_available_rounded, 'reserved'),
        'reserved' => ('Pick up', Icons.outbox_rounded, 'started'),
        'started' => ('Return', Icons.assignment_return_rounded, 'returned'),
        'returned' => ('Archive', Icons.archive_outlined, 'archived'),
        _ => null,
      };

  Widget _actionBar() {
    final primary = _primaryAction;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [BoxShadow(color: Color(0x141C0938), blurRadius: 18, offset: Offset(0, -6))],
      ),
      child: Row(children: [
        if (primary != null) ...[
          SizedBox(
            height: 54,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _saving ? null : () => _persist(),
              child: Text(_status == 'draft' ? 'Save draft' : 'Save', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GradientButton(label: primary.$1, icon: primary.$2, busy: _saving, onPressed: () => _transition(primary.$3)),
          ),
        ] else
          Expanded(child: GradientButton(label: 'Save', icon: Icons.check_rounded, busy: _saving, onPressed: () => _persist())),
      ]),
    );
  }

  Future<void> _moreMenu() async {
    HapticFeedback.selectionClick();
    final items = <(String, String, IconData, bool)>[
      if (_status == 'reserved') ('draft', 'Revert to draft', Icons.undo_rounded, false),
      if (_status == 'started') ('reserved', 'Undo pick up', Icons.undo_rounded, false),
      if (_status == 'returned') ('started', 'Undo return', Icons.undo_rounded, false),
      if (_status == 'canceled' || _status == 'archived') ('draft', 'Restore to draft', Icons.restore_rounded, false),
      if (_status == 'started' || _status == 'reserved' || _status == 'draft') ('archived', 'Archive', Icons.archive_outlined, false),
      if (_status == 'draft' || _status == 'reserved') ('canceled', 'Cancel order', Icons.block_rounded, true),
      if (!_isNew) ('duplicate', 'Duplicate', Icons.copy_rounded, false),
      if (!_isNew) ('delete', 'Delete', Icons.delete_outline_rounded, true),
    ];
    if (items.isEmpty) {
      toast(context, 'Save the order to see more actions');
      return;
    }
    final v = await showAppSheet<String>(
      context,
      title: _isNew ? 'New order' : 'Order ${_number > 0 ? '#$_number' : ''}',
      builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < items.length; i++)
          NavRow(
            icon: items[i].$3,
            title: items[i].$2,
            color: items[i].$4 ? AppColors.danger : AppColors.primary,
            trailing: const SizedBox.shrink(),
            onTap: () => Navigator.pop(ctx, items[i].$1),
          ).enterX(i),
      ]),
    );
    if (v == null || !mounted) return;
    switch (v) {
      case 'duplicate':
        await _duplicate();
      case 'delete':
        await _delete();
      default:
        await _transition(v);
    }
  }
}

class _HeaderPill extends StatelessWidget {
  final String text;
  const _HeaderPill(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
      );
}

class _Stepper extends StatelessWidget {
  final int qty;
  final VoidCallback? onMinus;
  final VoidCallback onPlus;
  const _Stepper({required this.qty, required this.onMinus, required this.onPlus});

  Widget _btn(IconData icon, VoidCallback? onTap) => PressScale(
        onTap: onTap,
        scale: 0.88,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: onTap == null ? AppColors.bg : AppColors.primarySoft, borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, size: 18, color: onTap == null ? AppColors.muted : AppColors.primary),
        ),
      );

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        _btn(Icons.remove_rounded, onMinus),
        SizedBox(
          width: 40,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: Text('$qty', key: ValueKey(qty), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
        ),
        _btn(Icons.add_rounded, onPlus),
      ]);
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool compact;
  const _ActionTile({required this.icon, required this.label, required this.onTap, this.primary = false, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 8 : 14),
        decoration: BoxDecoration(
          color: primary ? AppColors.primarySoft : AppColors.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: primary ? AppColors.lavender : AppColors.border),
        ),
        child: Row(mainAxisAlignment: compact ? MainAxisAlignment.start : MainAxisAlignment.center, children: [
          Icon(icon, size: 19, color: AppColors.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: primary ? AppColors.primaryDeep : AppColors.ink)),
          ),
        ]),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _LinkRow({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
          onPressed: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          icon: Icon(icon, size: 16),
          label: Text(label),
        ),
      );
}
