import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'db.dart';
import 'schema.dart';

/// Global auth + workspace state. Listenable so the router can refresh.
class Session extends ChangeNotifier {
  Session._();
  static final Session instance = Session._();

  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  User? user;
  Doc? profile;
  Doc? workspace;
  Doc? member;
  Doc? pendingInvite;
  bool authResolved = false;
  bool loading = true;

  StreamSubscription? _authSub, _profileSub, _wsSub, _memberSub;
  String? _activeWid;

  String? get workspaceId => profile?.s('workspaceId').isNotEmpty == true ? profile!.s('workspaceId') : null;
  bool get signedIn => user != null && !(user!.isAnonymous);
  bool get hasWorkspace => workspace != null && member != null;
  String get displayName {
    final n = profile?.s('name') ?? '';
    if (n.isNotEmpty) return n;
    return user?.displayName ?? user?.email?.split('@').first ?? 'User';
  }

  String get role => member?.s('role', 'member') ?? 'member';
  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'owner' || role == 'admin';

  Map<String, dynamic> settings(String section) {
    final s = workspace?.m('settings') ?? {};
    return s[section] is Map ? Map<String, dynamic>.from(s[section] as Map) : <String, dynamic>{};
  }

  dynamic setting(String section, String key, [dynamic def]) => settings(section)[key] ?? def;

  Future<void> saveSettings(String section, Map<String, dynamic> values) async {
    await Db.workspaceRef.update({'settings.$section': {...settings(section), ...values}});
    Db.log('settings', section, 'updated', section);
  }

  Future<void> markOnboarding(String step) async {
    if (workspace?.m('onboarding')[step] == true) return;
    await Db.workspaceRef.update({'onboarding.$step': true});
  }

  void init() {
    _authSub = _auth.authStateChanges().listen(_onAuth);
  }

  Future<void> _onAuth(User? u) async {
    user = u;
    authResolved = true;
    await _profileSub?.cancel();
    await _wsSub?.cancel();
    await _memberSub?.cancel();
    profile = null;
    workspace = null;
    member = null;
    pendingInvite = null;
    _activeWid = null;
    _wsSub = null;
    _memberSub = null;
    if (u == null || u.isAnonymous) {
      loading = false;
      notifyListeners();
      return;
    }
    loading = true;
    notifyListeners();
    _profileSub = _fs.collection(C.users).doc(u.uid).snapshots().listen((s) async {
      profile = s.exists ? Doc.of(s) : null;
      final wid = workspaceId;
      if (wid != null && wid == _activeWid) {
        notifyListeners(); // profile changed but same workspace
        return;
      }
      _activeWid = wid;
      if (wid != null) {
        loading = true;
        notifyListeners();
      }
      await _wsSub?.cancel();
      await _memberSub?.cancel();
      _wsSub = null;
      _memberSub = null;
      if (wid == null) {
        workspace = null;
        member = null;
        await _checkInvite();
        loading = false;
        notifyListeners();
        return;
      }
      var wsLoaded = false, memberLoaded = false;
      void settle() {
        if (wsLoaded && memberLoaded) loading = false;
        notifyListeners();
      }

      // Membership first: workspace reads are only permitted for members.
      _memberSub = _fs.collection(C.workspaces).doc(wid).collection(C.members).doc(u.uid).snapshots().listen((m) {
        member = m.exists ? Doc.of(m) : null;
        memberLoaded = true;
        if (member == null) {
          wsLoaded = true;
          workspace = null;
        }
        settle();
        if (member != null && _wsSub == null) {
          _wsSub = _fs.collection(C.workspaces).doc(wid).snapshots().listen((w) {
            workspace = w.exists ? Doc.of(w) : null;
            wsLoaded = true;
            settle();
          }, onError: (_) {
            workspace = null;
            wsLoaded = true;
            settle();
          });
        }
      }, onError: (_) {
        member = null;
        memberLoaded = true;
        wsLoaded = true;
        settle();
      });
    }, onError: (_) {
      loading = false;
      notifyListeners();
    });
  }

  Future<void> _checkInvite() async {
    final email = user?.email?.toLowerCase();
    if (email == null) return;
    try {
      final s = await _fs.collection(C.invites).doc(email).get();
      pendingInvite = s.exists ? Doc.of(s) : null;
    } catch (_) {
      pendingInvite = null;
    }
  }

  // ---------------- Auth ----------------
  Future<void> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<void> signUp(String name, String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    await cred.user?.updateDisplayName(name);
    await _fs.collection(C.users).doc(cred.user!.uid).set({
      'name': name,
      'email': email.trim().toLowerCase(),
      'locale': 'en',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> resetPassword(String email) => _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> signOut() => _auth.signOut();

  Future<void> updateProfile(Map<String, dynamic> data) async {
    await _fs.collection(C.users).doc(user!.uid).set(data, SetOptions(merge: true));
    if (data['name'] != null) await user!.updateDisplayName(data['name'] as String);
    if (workspaceId != null && data['name'] != null) {
      await _fs.collection(C.workspaces).doc(workspaceId).collection(C.members).doc(user!.uid).update({'name': data['name']});
    }
  }

  // ---------------- Workspace ----------------
  static String slugify(String s) {
    final v = s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
    return v.isEmpty ? 'store' : v;
  }

  Future<String> _uniqueSlug(String base) async {
    var slug = slugify(base);
    for (var i = 0; i < 20; i++) {
      final candidate = i == 0 ? slug : '$slug-$i';
      final s = await _fs.collection(C.publicStores).doc(candidate).get();
      if (!s.exists) return candidate;
    }
    return '$slug-${DateTime.now().millisecondsSinceEpoch % 100000}';
  }

  /// Creates a new workspace with sensible defaults and makes the user its owner.
  Future<void> createWorkspace({
    required String companyName,
    required String industry,
    String currency = 'INR',
    String currencySymbol = '₹',
    String country = 'India',
    String timezone = 'Asia/Kolkata',
  }) async {
    final u = user!;
    final ws = _fs.collection(C.workspaces).doc();
    final slug = await _uniqueSlug(companyName);
    final now = FieldValue.serverTimestamp();
    final batch = _fs.batch();
    batch.set(ws, {
      'name': companyName,
      'slug': slug,
      'industry': industry,
      'ownerId': u.uid,
      'plan': 'trial',
      'trialEndsAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 14))),
      'counters': {'order': 0, 'customer': 0, 'invoice': 0, 'quote': 0, 'contract': 0, 'packing': 0},
      'onboarding': <String, bool>{},
      'createdAt': now,
      'settings': {
        'general': {
          'companyName': companyName,
          'email': u.email ?? '',
          'country': country,
          'timezone': timezone,
          'dateFormat': 'dd-MM-yyyy',
          'weekStart': 'monday',
          'use12h': false,
          'unitSystem': 'metric',
          'weightUnit': 'kg',
        },
        'pricing': {
          'enabled': true,
          'currency': currency,
          'symbol': currencySymbol,
          'position': 'before',
          'depositMode': 'product',
          'depositValue': 100,
        },
        'taxes': {'pricesIncludeTax': false},
        'rentalPeriod': {
          'mode': 'datetime',
          'pickupTime': '09:00',
          'returnTime': '17:00',
          'interval': 60,
          'prefill': true,
        },
        'documents': {'showTime': false, 'pageSize': 'A4', 'numbering': 'global', 'dueDays': 14},
        'store': {
          'enabled': true,
          'brandColor': '#6431DD',
          'showPrices': true,
          'availability': true,
          'couponsEnabled': true,
          'addToCart': 'cart',
        },
        'checkout': {'paymentMode': 'none', 'termsRequired': false, 'termsLabel': 'I accept the Terms and conditions'},
        'fulfillment': {'defaultMethod': 'pickup'},
        'seo': {'title': companyName, 'description': ''},
        'security': {'emailConfirmNewDevices': true},
      },
    });
    batch.set(ws.collection(C.members).doc(u.uid), {
      'uid': u.uid,
      'name': displayName,
      'email': u.email ?? '',
      'role': 'owner',
      'active': true,
      'joinedAt': now,
      'createdAt': now,
    });
    batch.set(ws.collection(C.collections).doc('all-products'), {
      'name': 'All products',
      'isSystem': true,
      'showInStore': true,
      'slug': 'all',
      'createdAt': now,
    });
    batch.set(ws.collection(C.locations).doc('main'), {
      'name': 'Main location',
      'address': country,
      'pickup': true,
      'delivery': false,
      'showInStore': true,
      'isDefault': true,
      'createdAt': now,
    });
    final templates = [
      ['Order confirmation', 'orders', 'Your order #{{order.number}} is confirmed'],
      ['Order cancellation', 'orders', 'Your order #{{order.number}} has been cancelled'],
      ['Send quote', 'quotes', 'Quote #{{document.number}} from {{company.name}}'],
      ['Send contract', 'contracts', 'Contract #{{document.number}} from {{company.name}}'],
      ['Send invoice', 'invoices', 'Invoice #{{document.number}} from {{company.name}}'],
      ['Invoice approaching due date', 'invoices', 'Reminder: invoice #{{document.number}} is due soon'],
      ['Invoice overdue', 'invoices', 'Invoice #{{document.number}} is overdue'],
    ];
    for (final t in templates) {
      batch.set(ws.collection(C.emailTemplates).doc(), {
        'name': t[0],
        'kind': 'manual',
        'context': t[1],
        'subject': t[2],
        'body': 'Hi {{customer.name}},\n\nPlease find the details below.\n\nKind regards,\n{{company.name}}',
        'enabled': true,
        'createdAt': now,
      });
    }
    batch.set(_fs.collection(C.publicStores).doc(slug), {
      'workspaceId': ws.id,
      'name': companyName,
      'enabled': true,
      'brandColor': '#6431DD',
      'currency': currency,
      'symbol': currencySymbol,
      'position': 'before',
      'showPrices': true,
      'seoTitle': companyName,
      'seoDescription': '',
      'email': u.email ?? '',
      'createdAt': now,
    });
    batch.set(_fs.collection(C.users).doc(u.uid), {'workspaceId': ws.id, 'name': displayName, 'email': u.email}, SetOptions(merge: true));
    await batch.commit();
  }

  /// Accepts the pending invite for the signed-in user.
  Future<void> acceptInvite() async {
    final inv = pendingInvite;
    final u = user;
    if (inv == null || u == null) return;
    final wid = inv.s('workspaceId');
    final batch = _fs.batch();
    batch.set(_fs.collection(C.workspaces).doc(wid).collection(C.members).doc(u.uid), {
      'uid': u.uid,
      'name': displayName,
      'email': u.email ?? '',
      'role': inv.s('role', 'member'),
      'active': true,
      'joinedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(_fs.collection(C.users).doc(u.uid), {'workspaceId': wid}, SetOptions(merge: true));
    await batch.commit();
    await _fs.collection(C.invites).doc(u.email!.toLowerCase()).delete();
    pendingInvite = null;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    _wsSub?.cancel();
    _memberSub?.cancel();
    super.dispose();
  }
}
