import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue, Timestamp;
import 'package:flutter/material.dart' hide Thumb;
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
import '../../widgets/page.dart';
import '../../widgets/side_panel.dart';
import 'online_payment_dialog.dart';
import 'order_dialogs.dart';
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

  // Product search
  final _searchCtl = TextEditingController();
  final _searchFocus = FocusNode();

  String? _savedId;
  String? get _id => widget.id ?? _savedId;
  bool get _isNew => _id == null;

  late final Stream<List<Doc>>? _paymentsStream = widget.id == null ? null : Db.watchWhere(C.payments, 'orderId', widget.id);
  late final Stream<List<Doc>>? _documentsStream = widget.id == null ? null : Db.watchWhere(C.documents, 'orderId', widget.id);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final (ph, pm) = _hm(Session.instance.setting('rentalPeriod', 'pickupTime', '09:00'), 9);
    final (rh, rm) = _hm(Session.instance.setting('rentalPeriod', 'returnTime', '17:00'), 17);
    _start = DateTime(now.year, now.month, now.day, ph, pm);
    _end = DateTime(now.year, now.month, now.day + 1, rh, rm);
    _fulfillment = (Session.instance.setting('fulfillment', 'defaultMethod', 'pickup') as String?) == 'delivery' ? 'delivery' : 'pickup';

    void sub<T>(Stream<T> s, void Function(T) on) => _subs.add(s.listen((v) {
          if (mounted) setState(() => on(v));
        }, onError: (_) {}));

    sub<List<Doc>>(Db.watch(C.products), (v) {
      _products = {for (final p in v) p.id: p};
      _productsLoaded = true;
    });
    sub<List<Doc>>(Db.watch(C.bundles), (v) => _bundles = v);
    sub<List<Doc>>(Db.watch(C.customers), (v) {
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
    sub<List<Doc>>(Db.watch(C.orders), (v) => _orders = v);
    sub<List<Doc>>(Db.watch(C.downtimes), (v) => _downtimes = v);
    sub<List<Doc>>(Db.watch(C.pricingStructures), (v) {
      _structures = {for (final s in v) s.id: s};
      if (_dirty) _recalc();
    });
    sub<List<Doc>>(Db.watch(C.taxProfiles), (v) {
      _taxProfiles = {for (final s in v) s.id: s};
      if (_dirty) _recalc();
    });
    sub<List<Doc>>(Db.watch(C.locations), (v) {
      _locations = v;
      if (_isNew && _locationId == null && v.isNotEmpty) {
        _locationId = (v.where((l) => l.b('isDefault')).firstOrNull ?? v.last).id;
      }
    });
    if (widget.id != null) {
      sub<Doc?>(Db.watchDoc(C.orders, widget.id!), _onOrder);
    }
  }

  static (int, int) _hm(dynamic v, int defH) {
    final p = '${v ?? ''}'.split(':');
    final h = int.tryParse(p.first) ?? defH;
    final m = p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0;
    return (h.clamp(0, 23), m.clamp(0, 59));
  }

  void _onOrder(Doc? o) {
    if (o == null) {
      _notFound = true;
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
    _discountCtl.text = dp > 0 ? _fmtNum(dp) : '';
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
    _searchCtl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  static String _fmtNum(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

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
      final ok = e == 'products'
          ? c.l<String>('productIds').contains(p.id)
          : p.l<String>('collectionIds').any(c.l<String>('collectionIds').contains);
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

  int _qtyInOrder(String pid) =>
      _lines.where((l) => l['productId'] == pid).fold<int>(0, (a, l) => a + ((l['qty'] as num?) ?? 0).toInt());

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
      _discountCtl.text = _fmtNum(dp);
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
    _searchCtl.clear();
  }

  void _setQty(Map<String, dynamic> l, num q) => _touch(() {
        l['qty'] = q < 1 ? 1 : q.toInt();
        _recalc();
      });

  void _setPeriod({DateTime? start, DateTime? end}) => _touch(() {
        if (start != null) {
          final dur = _end.difference(_start);
          _start = start;
          if (!_end.isAfter(_start)) _end = _start.add(dur.inMinutes > 0 ? dur : const Duration(days: 1));
        }
        if (end != null) _end = end;
        _recalc();
      });

  Future<void> _editPrice(Map<String, dynamic> l) async {
    final c = TextEditingController(text: _fmtNum((l['unitPrice'] as num?) ?? 0));
    final r = await showDialog<num>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Override price'),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Field.money(label: 'Price per unit for this period', controller: c),
            const SizedBox(height: 8),
            Text('Automatic price: ${Fmt.money(_autoPrice(l))}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ]),
        ),
        actions: [
          if (l['override'] == true && l['kind'] != 'custom')
            TextButton(onPressed: () => Navigator.pop(ctx, -1), child: const Text('Use automatic price')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, parseNum(c.text)), child: const Text('Apply')),
        ],
      ),
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

  Future<void> _addCustomLine() async {
    final name = TextEditingController(), qty = TextEditingController(text: '1'), price = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add custom line'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Field(label: 'Name', controller: name, autofocus: true, hint: 'e.g. Delivery fee, Cleaning'),
            const SizedBox(height: 14),
            FieldGrid(children: [
              Field.number(label: 'Quantity', controller: qty, decimal: false),
              Field.money(label: 'Price', controller: price),
            ]),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add line')),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
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
    final applied = await showDialog<Doc>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Add a coupon'),
          content: SizedBox(
            width: 380,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Field(label: 'Coupon code', controller: c, autofocus: true, hint: 'SUMMER10'),
              if (err != null) ...[const SizedBox(height: 10), InfoBanner(err!, tone: Tone.danger)],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      setD(() => busy = true);
                      final (doc, e) = await _validateCoupon(c.text.trim());
                      if (!ctx.mounted) return;
                      if (doc != null) {
                        Navigator.pop(ctx, doc);
                      } else {
                        setD(() {
                          err = e;
                          busy = false;
                        });
                      }
                    },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    c.dispose();
    if (applied != null) {
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
  Future<(String, Map<String, dynamic>)?> _persist({String? status, String? successMessage, bool navigate = true}) async {
    if (!_end.isAfter(_start)) {
      toast(context, 'The return date must be after the pickup date', error: true);
      return null;
    }
    final st = status ?? _status;
    if (st != 'draft' && st != 'canceled' && _lines.isEmpty) {
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
      });
      toast(context, successMessage ?? 'Order saved');
      if (created && navigate) context.go('/orders/$id');
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
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 36),
            title: const Text('Not enough stock to reserve'),
            content: SizedBox(
              width: 420,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('These products are unavailable between ${Fmt.dateTime(_start)} and ${Fmt.dateTime(_end)}:',
                    style: const TextStyle(color: AppColors.inkSoft, height: 1.4)),
                const SizedBox(height: 12),
                for (final e in blocking)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Thumb(url: _products[e.key]?.l<String>('imageUrls').firstOrNull, size: 32),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_products[e.key]?.s('name') ?? 'Product', style: const TextStyle(fontWeight: FontWeight.w600))),
                      StatusPill('shortage', label: 'Short ${e.value}', dot: false),
                    ]),
                  ),
                const SizedBox(height: 12),
                const Text('Reduce quantities, change the period, or allow shortages on the product to continue.',
                    style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4)),
              ]),
            ),
            actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Review order'))],
          ),
        );
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
      toast(context, 'Order duplicated as #$n');
      context.go('/orders/$id');
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
      toast(context, 'Order deleted');
      context.go('/orders');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  Future<void> _createCustomerFromOrder() async {
    final c = await showNewCustomerDialog(context, name: _customerName, email: _customerEmail, phone: _customerPhone);
    if (c == null || !mounted) return;
    setState(() => _applyCustomer(c));
    await _persist(successMessage: 'Customer linked to order');
  }

  Future<void> _pickCustomer() async {
    final c = await showCustomerPicker(context, _customers);
    if (c != null && mounted) setState(() => _applyCustomer(c));
  }

  /// Ensures the order is saved (saving pending changes), returning its id/data.
  Future<(String, Map<String, dynamic>)?> _ensureSaved() async {
    if (!_isNew && !_dirty) return (_id!, {..._payload(_status), 'number': _number});
    return _persist(navigate: false);
  }

  Future<void> _createDocument(String type) async {
    final saved = await _ensureSaved();
    if (saved == null || !mounted) return;
    try {
      final id = await DocType.createFromOrder(type, saved.$1, saved.$2);
      if (!mounted) return;
      toast(context, '${DocType.title[type]} created');
      context.go('/documents/$id');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  Future<void> _collectOnline() async {
    final wasNew = widget.id == null;
    final saved = await _ensureSaved();
    if (saved == null || !mounted) return;
    await showOnlinePaymentDialog(
      context,
      orderId: saved.$1,
      orderLabel: _number > 0 ? '#$_number' : 'order',
      due: OrderX.dueOf(_totals['total']!, _paid),
      customerName: _customerName,
      customerEmail: _customerEmail,
      companyName: companyName,
    );
    if (wasNew && mounted) context.go('/orders/${saved.$1}');
  }

  Future<void> _addPayment() async {
    final wasNew = widget.id == null;
    final saved = await _ensureSaved();
    if (saved == null || !mounted) return;
    final due = OrderX.dueOf(_totals['total']!, _paid);
    final p = await showPaymentDialog(context, suggested: due);
    if (p == null) return;
    try {
      await OrderX.recordPayment(
          orderId: saved.$1, orderNumber: _number, amount: p.amount, method: p.method, kind: p.kind, note: p.note);
      if (mounted) toast(context, p.kind == 'refund' ? 'Refund recorded' : 'Payment recorded');
      if (wasNew && mounted) context.go('/orders/${saved.$1}');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  Future<void> _sendConfirmation() async {
    final wasNew = widget.id == null;
    final saved = await _ensureSaved();
    if (saved == null || !mounted) return;
    await showEmailDialog(
      context,
      emailContext: 'orders',
      to: _customerEmail,
      entityId: saved.$1,
      title: 'Send order confirmation',
      vars: {
        'order.number': '$_number',
        'customer.name': _customerName,
        'company.name': companyName,
      },
      defaultSubject: 'Your order #{{order.number}} is confirmed',
      defaultBody:
          'Hi {{customer.name}},\n\nThank you for your order #{{order.number}}.\nPickup: ${Fmt.dateTime(_start)}\nReturn: ${Fmt.dateTime(_end)}\nTotal: ${Fmt.money(_totals['total'])}\n\nKind regards,\n{{company.name}}',
    );
    if (wasNew && mounted) context.go('/orders/${saved.$1}');
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_notFound) {
      return EmptyState(
        icon: Icons.search_off,
        title: 'Order not found',
        message: 'It may have been deleted or you may not have access to it.',
        actionLabel: 'Back to orders',
        onAction: () => context.go('/orders'),
      );
    }
    if (!_productsLoaded || (!_isNew && !_orderLoaded)) return const LoadingView();
    if (_isNew && _products.isEmpty) return _noProducts();

    final title = _isNew ? 'New order' : (_number > 0 ? 'Order #$_number' : 'Web order');
    return Column(children: [
      PageHeader(
        title: title,
        breadcrumbs: const [('Orders', '/orders')],
        titleTrailing: Row(mainAxisSize: MainAxisSize.min, children: [
          StatusPill(_status),
          if (_dirty) ...[const SizedBox(width: 6), const StatusPill('draft', label: 'Unsaved', dot: false)],
        ]),
        subtitle: _source == 'online' ? 'Web order · placed ${Fmt.dateTime(_createdAt)}' : null,
        actions: _actions(),
      ),
      Expanded(
        child: PageBody(children: [
          DetailLayout(main: _main(), side: _side()),
        ]),
      ),
    ]);
  }

  Widget _noProducts() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: AppCard(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.inventory_2_outlined, color: Colors.white, size: 34),
              ).pop(),
              const SizedBox(height: 20),
              Text('Add some products first', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text(
                'Orders are built from your inventory. Create a product with its price and stock, then come back to book it.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, height: 1.5),
              ),
              const SizedBox(height: 24),
              Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
                OutlinedButton(onPressed: () => context.go('/'), child: const Text('Back to dashboard')),
                FilledButton.icon(
                  onPressed: () => context.go('/inventory/products/new'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Create product'),
                ),
              ]),
            ]),
          ).enter(),
        ),
      ),
    );
  }

  List<Widget> _actions() {
    final busy = _saving;
    Widget primary(String label, IconData icon, String to) =>
        FilledButton.icon(onPressed: busy ? null : () => _transition(to), icon: Icon(icon, size: 18), label: Text(label));
    Widget save(String label) => OutlinedButton(
          onPressed: busy ? null : () => _persist(),
          child: busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(label),
        );
    final list = <Widget>[];
    switch (_status) {
      case 'draft':
        list.addAll([save('Save as draft'), primary('Reserve', Icons.event_available, 'reserved')]);
      case 'reserved':
        list.addAll([save('Save'), primary('Pick up', Icons.outbox_outlined, 'started')]);
      case 'started':
        list.addAll([save('Save'), primary('Return', Icons.assignment_return_outlined, 'returned')]);
      case 'returned':
        list.addAll([save('Save'), primary('Archive', Icons.archive_outlined, 'archived')]);
      default:
        list.add(save('Save'));
    }
    final menu = <(String, String, IconData, bool)>[
      if (_status == 'reserved') ('draft', 'Revert to draft', Icons.undo, false),
      if (_status == 'started') ('reserved', 'Undo pick up', Icons.undo, false),
      if (_status == 'returned') ('started', 'Undo return', Icons.undo, false),
      if (_status == 'canceled' || _status == 'archived') ('draft', 'Restore to draft', Icons.restore, false),
      if (_status == 'draft' || _status == 'reserved') ('canceled', 'Cancel order', Icons.block, true),
      if (!_isNew) ('duplicate', 'Duplicate', Icons.copy_outlined, false),
      if (!_isNew) ('delete', 'Delete', Icons.delete_outline, true),
    ];
    if (menu.isNotEmpty) {
      list.add(PopupMenuButton<String>(
        tooltip: 'More actions',
        icon: const Icon(Icons.more_horiz),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: (v) {
          if (v == 'duplicate') {
            _duplicate();
          } else if (v == 'delete') {
            _delete();
          } else {
            _transition(v);
          }
        },
        itemBuilder: (_) => [
          for (final m in menu)
            PopupMenuItem(
              value: m.$1,
              child: Row(children: [
                Icon(m.$3, size: 18, color: m.$4 ? AppColors.danger : AppColors.inkSoft),
                const SizedBox(width: 10),
                Text(m.$2, style: TextStyle(color: m.$4 ? AppColors.danger : AppColors.ink)),
              ]),
            ),
        ],
      ));
    }
    return list;
  }

  Widget _cardTitle(String t, IconData icon, {Widget? trailing}) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(t, style: Theme.of(context).textTheme.titleMedium)),
          if (trailing != null) trailing,
        ]),
      );

  Widget _main() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_source == 'online' && _customerId == null && _customerName.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: InfoBanner(
            'This web order was placed by $_customerName and is not linked to a customer profile yet.',
            tone: Tone.brand,
            icon: Icons.language,
            actionLabel: 'Create customer from order',
            onAction: _createCustomerFromOrder,
          ),
        ).enter(0),
      LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth > 760;
        final customer = _customerCard();
        final period = _periodCard();
        if (!wide) return Column(children: [customer, const SizedBox(height: 16), period]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 3, child: customer),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: period),
        ]);
      }),
      const SizedBox(height: 16),
      _linesCard().enter(3),
      const SizedBox(height: 16),
      _totalsCard().enter(4),
    ]);
  }

  // ---- Customer ----
  Widget _customerCard() {
    final hasCustomer = _customerId != null || _customerName.isNotEmpty;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _cardTitle('Customer', Icons.person_outline,
            trailing: hasCustomer
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    TextButton(onPressed: _pickCustomer, child: const Text('Change')),
                    IconButton(
                      tooltip: 'Remove customer',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => _touch(() {
                        _customerId = null;
                        _customer = null;
                        _customerName = _customerEmail = _customerPhone = '';
                      }),
                    ),
                  ])
                : null),
        if (!hasCustomer)
          Wrap(spacing: 10, runSpacing: 10, children: [
            OutlinedButton.icon(onPressed: _pickCustomer, icon: const Icon(Icons.search, size: 18), label: const Text('Select customer')),
            TextButton.icon(
              onPressed: () async {
                final c = await showNewCustomerDialog(context);
                if (c != null && mounted) setState(() => _applyCustomer(c));
              },
              icon: const Icon(Icons.person_add_alt, size: 18),
              label: const Text('New customer'),
            ),
          ])
        else
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Container(
              key: ValueKey(_customerId ?? _customerName),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Avatar(_customerName, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    InkWell(
                      onTap: _customerId == null ? null : () => context.go('/customers/$_customerId'),
                      child: Text(_customerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                    if (_customerEmail.isNotEmpty) _iconText(Icons.mail_outline, _customerEmail),
                    if (_customerPhone.isNotEmpty) _iconText(Icons.phone_outlined, _customerPhone),
                  ]),
                ),
                if ((_customer?.n('discountPercent') ?? 0) > 0)
                  StatusPill('active', label: '${_fmtNum(_customer!.n('discountPercent'))}% discount', dot: false),
              ]),
            ),
          ),
        const SizedBox(height: 16),
        Wrap(spacing: 12, runSpacing: 12, children: [
          _addressTile('Billing address', _billing, (a) => _touch(() => _billing = a)),
          _addressTile('Delivery address', _delivery, (a) => _touch(() => _delivery = a)),
        ]),
        const SizedBox(height: 16),
        const FieldLabel('Fulfillment'),
        LayoutBuilder(builder: (context, c) {
          final seg = SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'pickup', label: Text('Pickup'), icon: Icon(Icons.storefront_outlined, size: 18)),
              ButtonSegment(value: 'delivery', label: Text('Delivery'), icon: Icon(Icons.local_shipping_outlined, size: 18)),
            ],
            selected: {_fulfillment},
            showSelectedIcon: false,
            onSelectionChanged: (s) => _touch(() => _fulfillment = s.first),
          );
          final loc = _locations.isEmpty
              ? const SizedBox.shrink()
              : DropdownX<String>(
                  key: ValueKey('loc$_locationId${_locations.length}'),
                  label: '',
                  value: _locationId,
                  hint: 'Location',
                  items: {for (final l in _locations) l.id: l.s('name')},
                  onChanged: (v) => _touch(() => _locationId = v),
                );
          if (c.maxWidth < 460) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [seg, const SizedBox(height: 10), loc]);
          return Row(children: [seg, const SizedBox(width: 12), Expanded(child: loc)]);
        }),
      ]),
    ).enter(1);
  }

  Widget _iconText(IconData i, String t) => Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(children: [
          Icon(i, size: 14, color: AppColors.muted),
          const SizedBox(width: 6),
          Flexible(child: Text(t, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.inkSoft))),
        ]),
      );

  Widget _addressTile(String label, Map<String, dynamic> a, ValueChanged<Map<String, dynamic>> onSave) {
    final text = addressText(a);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 320),
      child: HoverLift(
        lift: 2,
        radius: BorderRadius.circular(12),
        onTap: () async {
          final r = await showAddressDialog(context, label, a);
          if (r != null) onSave(r);
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
            color: Colors.white,
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(text.isEmpty ? Icons.add_location_alt_outlined : Icons.location_on_outlined, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 2),
                Text(text.isEmpty ? 'Add address' : text,
                    style: TextStyle(fontSize: 12, height: 1.4, color: text.isEmpty ? AppColors.primary : AppColors.inkSoft)),
              ]),
            ),
            if (text.isNotEmpty) const Icon(Icons.edit_outlined, size: 14, color: AppColors.muted),
          ]),
        ),
      ),
    );
  }

  // ---- Period ----
  Widget _periodCard() {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _cardTitle('Rental period', Icons.event_outlined),
        DateTimeField(label: 'Pickup (From)', value: _start, onChanged: (d) {
          if (d != null) _setPeriod(start: d);
        }),
        const SizedBox(height: 14),
        DateTimeField(label: 'Return (Until)', value: _end, firstDate: _start, onChanged: (d) {
          if (d != null) _setPeriod(end: d);
        }),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _end.isAfter(_start) ? AppColors.primarySoft : AppColors.dangerSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Icon(Icons.timelapse, size: 18, color: _end.isAfter(_start) ? AppColors.primary : AppColors.danger),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _end.isAfter(_start) ? 'Duration: ${durationText(_start, _end)}' : 'Return must be after pickup',
                style: TextStyle(fontWeight: FontWeight.w600, color: _end.isAfter(_start) ? AppColors.primaryDeep : AppColors.danger),
              ),
            ),
          ]),
        ),
      ]),
    ).enter(2);
  }

  // ---- Lines ----
  Widget _linesCard() {
    final shortages = _shortages;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _cardTitle('Products', Icons.inventory_2_outlined,
            trailing: TextButton.icon(onPressed: _addCustomLine, icon: const Icon(Icons.add, size: 18), label: const Text('Add custom line'))),
        _productSearch(),
        const SizedBox(height: 12),
        if (_lines.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
              color: AppColors.bg,
            ),
            child: const Column(children: [
              Icon(Icons.add_shopping_cart, color: AppColors.lavender, size: 32),
              SizedBox(height: 8),
              Text('No products yet', style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 4),
              Text('Search above to add products or bundles. Prices update with the rental period.',
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 13)),
            ]),
          )
        else
          for (var i = 0; i < _lines.length; i++)
            KeyedSubtree(key: ValueKey(_lines[i]['id']), child: _lineRow(_lines[i], shortages).enter(i, 0.03)),
      ]),
    );
  }

  Widget _productSearch() {
    final picks = [
      for (final p in _products.values.where((p) => p.s('status', 'active') == 'active')) _Pick(p, false),
      for (final b in _bundles) _Pick(b, true),
    ];
    return LayoutBuilder(builder: (context, c) {
      return RawAutocomplete<_Pick>(
        textEditingController: _searchCtl,
        focusNode: _searchFocus,
        displayStringForOption: (p) => p.doc.s('name'),
        optionsBuilder: (v) {
          final q = v.text.trim().toLowerCase();
          final list = picks.where((p) => q.isEmpty || '${p.doc.s('name')} ${p.doc.s('sku')}'.toLowerCase().contains(q)).toList()
            ..sort((a, b) => a.doc.s('name').toLowerCase().compareTo(b.doc.s('name').toLowerCase()));
          return list.take(30);
        },
        onSelected: _addPick,
        fieldViewBuilder: (context, ctl, focus, onSubmit) => TextField(
          controller: ctl,
          focusNode: focus,
          onSubmitted: (_) => onSubmit(),
          decoration: const InputDecoration(
            hintText: 'Search to add products',
            prefixIcon: Icon(Icons.search, size: 20),
          ),
        ),
        optionsViewBuilder: (context, onSelect, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            shadowColor: const Color(0x331C0938),
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 340, maxWidth: c.maxWidth),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                children: [
                  for (final o in options)
                    InkWell(
                      onTap: () => onSelect(o),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(children: [
                          Thumb(
                            url: o.bundle ? o.doc.s('imageUrl') : o.doc.l<String>('imageUrls').firstOrNull,
                            size: 36,
                            icon: o.bundle ? Icons.widgets_outlined : Icons.inventory_2_outlined,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(o.doc.s('name'), overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(
                                o.bundle
                                    ? 'Bundle · ${o.doc.maps('items').length} items'
                                    : '${Fmt.money(_productPrice(o.doc))} for this period',
                                style: const TextStyle(fontSize: 12, color: AppColors.muted),
                              ),
                            ]),
                          ),
                          if (!o.bundle) _availBadge(o.doc, _available(o.doc) - _qtyInOrder(o.doc.id)),
                        ]),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _availBadge(Doc p, int remaining) {
    if (p.s('type') == 'service') return const SizedBox.shrink();
    if (remaining < 0) return StatusPill('shortage', label: 'Shortage ${-remaining}', dot: false);
    return StatusPill(remaining == 0 ? 'late' : 'available', label: '$remaining available', dot: false);
  }

  Widget _lineRow(Map<String, dynamic> l, Map<String, int> shortages) {
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
          : StatusPill('available', label: '${_available(p) - _qtyInOrder(p.id)} more available', dot: false);
    } else if (kind == 'bundle') {
      badge = const StatusPill('scheduled', label: 'Bundle', dot: false);
    } else if (kind == 'custom') {
      badge = const StatusPill('custom', label: 'Custom', dot: false);
    }

    final info = Row(children: [
      Thumb(
        url: (l['imageUrl'] as String?) ?? '',
        size: 44,
        icon: kind == 'bundle' ? Icons.widgets_outlined : (kind == 'custom' ? Icons.receipt_outlined : Icons.inventory_2_outlined),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            onTap: kind == 'product' && p != null ? () => context.go('/inventory/products/${p.id}') : null,
            child: Text('${l['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            badge,
            if (kind == 'product' && p != null && p.s('pricingMethod', 'flat') == 'flat' && p.s('type', 'rental') == 'rental')
              Text('$periods $per${periods == 1 ? '' : 's'}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            if (l['override'] == true && kind != 'custom') const Text('Price overridden', style: TextStyle(fontSize: 12, color: AppColors.warning)),
          ]),
        ]),
      ),
    ]);

    final stepper = Container(
      decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        InkWell(
          onTap: qty > 1 ? () => _setQty(l, qty - 1) : null,
          child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.remove, size: 16)),
        ),
        SizedBox(width: 34, child: Text('$qty', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
        InkWell(
          onTap: () => _setQty(l, qty + 1),
          child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.add, size: 16)),
        ),
      ]),
    );

    final price = InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _editPrice(l),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(Fmt.money(l['total'] as num?), style: const TextStyle(fontWeight: FontWeight.w700)),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text('${Fmt.money(unit)} each', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(width: 4),
            const Icon(Icons.edit_outlined, size: 12, color: AppColors.muted),
          ]),
        ]),
      ),
    );

    final remove = IconButton(
      tooltip: 'Remove line',
      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.muted),
      onPressed: () => _touch(() => _lines.remove(l)),
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF1EEF7)))),
      child: LayoutBuilder(builder: (context, c) {
        if (c.maxWidth < 560) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            info,
            const SizedBox(height: 10),
            Row(children: [stepper, const Spacer(), price, remove]),
          ]);
        }
        return Row(children: [Expanded(child: info), const SizedBox(width: 12), stepper, const SizedBox(width: 12), SizedBox(width: 150, child: Align(alignment: Alignment.centerRight, child: price)), remove]);
      }),
    );
  }

  // ---- Totals ----
  Widget _totalsCard() {
    final t = _totals;
    final inclTax = Session.instance.setting('taxes', 'pricesIncludeTax', false) == true;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _cardTitle('Summary', Icons.calculate_outlined),
        KV('Subtotal', Fmt.money(t['subtotal'])),
        const SizedBox(height: 4),
        if (_discountPercent == null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _touch(() {
                _discountPercent = _customer?.n('discountPercent') ?? 0;
                _discountCtl.text = _fmtNum(_discountPercent!);
              }),
              icon: const Icon(Icons.percent, size: 16),
              label: const Text('Add a discount'),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              const Expanded(child: Text('Discount', style: TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w500))),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _discountCtl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(suffixText: '%', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                  onChanged: (v) => _touch(() => _discountPercent = parseNum(v).clamp(0, 100)),
                ),
              ),
              IconButton(
                tooltip: 'Remove discount',
                icon: const Icon(Icons.close, size: 16),
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
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(onPressed: _addCoupon, icon: const Icon(Icons.local_offer_outlined, size: 16), label: const Text('Add a coupon')),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              const Expanded(child: Text('Coupon', style: TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w500))),
              Chip(
                avatar: const Icon(Icons.local_offer, size: 14, color: AppColors.primary),
                label: Text('$_couponCode · -${Fmt.money(_couponDiscount)}'),
                visualDensity: VisualDensity.compact,
                onDeleted: () => _touch(() {
                  _couponCode = '';
                  _coupon = null;
                  _storedCouponDiscount = 0;
                }),
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
    );
  }

  // ---- Side panel ----
  List<Widget> _side() {
    final id = widget.id;
    final t = _totals;
    final due = OrderX.dueOf(t['total']!, _paid);
    final payStatus = Pricing.paymentStatus(t['total']!, _paid);
    return [
      PanelCard(
        title: 'Payments',
        icon: Icons.payments_outlined,
        trailing: (t['total']! <= 0 && _paid <= 0) ? null : StatusPill(payStatus),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: _stat('Paid', Fmt.money(_paid), AppColors.success)),
            const SizedBox(width: 10),
            Expanded(child: _stat('Due', Fmt.money(due), due > 0 ? AppColors.danger : AppColors.muted)),
          ]),
          if (id != null)
            StreamBuilder<List<Doc>>(
              stream: _paymentsStream,
              builder: (context, s) {
                final pays = s.data ?? [];
                if (pays.isEmpty) return const SizedBox(height: 4);
                final held = pays.where((p) => p.s('kind') == 'deposit').fold<num>(0, (a, p) => a + p.n('amount'));
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const SizedBox(height: 10),
                  for (final p in pays.take(6))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        Icon(
                          p.s('kind') == 'refund' ? Icons.call_made : (p.s('kind') == 'deposit' ? Icons.shield_outlined : Icons.call_received),
                          size: 16,
                          color: p.s('kind') == 'refund' ? AppColors.danger : AppColors.success,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('${Fmt.label(p.s('kind'))} · ${Fmt.label(p.s('method'))}\n${Fmt.date(p.d('paidAt') ?? p.created)}',
                              style: const TextStyle(fontSize: 12, height: 1.35, color: AppColors.inkSoft)),
                        ),
                        Text('${p.s('kind') == 'refund' ? '-' : ''}${Fmt.money(p.n('amount'))}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  if (held > 0) KV('Deposit held', Fmt.money(held)),
                ]);
              },
            ),
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: _saving ? null : _addPayment, icon: const Icon(Icons.add, size: 18), label: const Text('Add payment')),
          if (due > 0) ...[
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _saving ? null : _collectOnline,
              icon: const Icon(Icons.bolt_rounded, size: 18),
              label: const Text('Collect online payment'),
            ),
          ],
        ]),
      ).enter(1),
      PanelCard(
        title: 'Documents',
        icon: Icons.description_outlined,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (id != null)
            StreamBuilder<List<Doc>>(
              stream: _documentsStream,
              builder: (context, s) {
                final docs = s.data ?? [];
                if (docs.isEmpty) return const SizedBox.shrink();
                return Column(children: [
                  for (final d in docs)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => context.go('/documents/${d.id}'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        child: Row(children: [
                          const Icon(Icons.insert_drive_file_outlined, size: 18, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('${DocType.title[d.s('type')] ?? 'Document'} ${DocType.number(d)}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ),
                          if (d.b('finalized')) const StatusPill('finalized', dot: false) else if (d.b('sent')) const StatusPill('sent', dot: false),
                        ]),
                      ),
                    ),
                  const Divider(height: 16),
                ]);
              },
            ),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in const [
              ('quote', 'New quote', Icons.request_quote_outlined),
              ('contract', 'New contract', Icons.handshake_outlined),
              ('packing', 'Packing slip', Icons.checklist_rtl),
              ('invoice', 'Create invoice', Icons.receipt_long_outlined),
            ])
              ActionChip(
                avatar: Icon(e.$3, size: 16, color: AppColors.primary),
                label: Text(e.$2),
                onPressed: _saving ? null : () => _createDocument(e.$1),
              ),
          ]),
        ]),
      ).enter(2),
      PanelCard(
        title: 'Email',
        icon: Icons.mail_outline,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(
            _customerEmail.isEmpty ? 'Add a customer with an email address to send confirmations.' : 'Send to $_customerEmail',
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _saving ? null : _sendConfirmation,
            icon: const Icon(Icons.send_outlined, size: 18),
            label: const Text('Send confirmation'),
          ),
        ]),
      ).enter(3),
      if (id != null) ...[
        TagsCard(collection: C.orders, id: id, tags: _tags).enter(4),
        NotesCard(entity: 'orders', entityId: id).enter(5),
        ActivityCard(entityId: id).enter(6),
      ] else
        const InfoBanner('Tags, notes and the activity log become available once the order is saved.', tone: Tone.brand).enter(4),
    ];
  }

  Widget _stat(String label, String value, Color color) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 2),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 15))),
        ]),
      );
}
