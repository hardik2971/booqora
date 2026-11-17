import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'schema.dart';
import 'session.dart';

/// Lightweight document wrapper with typed accessors.
class Doc {
  final String id;
  final Map<String, dynamic> data;
  const Doc(this.id, this.data);

  factory Doc.of(DocumentSnapshot<Map<String, dynamic>> s) => Doc(s.id, s.data() ?? {});

  dynamic operator [](String k) => data[k];
  String s(String k, [String def = '']) {
    final v = data[k];
    if (v == null) return def;
    return v.toString();
  }

  num n(String k, [num def = 0]) {
    final v = data[k];
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? def;
    return def;
  }

  int i(String k, [int def = 0]) => n(k, def).toInt();
  bool b(String k, [bool def = false]) => data[k] is bool ? data[k] as bool : def;
  DateTime? d(String k) => toDate(data[k]);
  List<T> l<T>(String k) => (data[k] is List) ? List<T>.from((data[k] as List).whereType<T>()) : <T>[];
  List<Map<String, dynamic>> maps(String k) => (data[k] is List)
      ? (data[k] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];
  Map<String, dynamic> m(String k) => data[k] is Map ? Map<String, dynamic>.from(data[k] as Map) : {};
  DateTime get created => d('createdAt') ?? DateTime.now();

  static DateTime? toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }
}

/// Firestore / Storage repository scoped to the active workspace.
class Db {
  static final fs = FirebaseFirestore.instance;
  static final storage = FirebaseStorage.instance;

  static String get wid {
    final w = Session.instance.workspaceId;
    if (w == null) throw StateError('No active workspace');
    return w;
  }

  static DocumentReference<Map<String, dynamic>> get workspaceRef => fs.collection(C.workspaces).doc(wid);
  static CollectionReference<Map<String, dynamic>> col(String c) => workspaceRef.collection(c);

  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  static String get _actor => Session.instance.displayName;

  /// Live list of a collection, newest first by default.
  static Stream<List<Doc>> watch(String c, {String orderBy = 'createdAt', bool desc = true, int? limit}) {
    Query<Map<String, dynamic>> q = col(c).orderBy(orderBy, descending: desc);
    if (limit != null) q = q.limit(limit);
    return q.snapshots().map((s) => s.docs.map(Doc.of).toList());
  }

  /// Live list filtered by a single equality.
  static Stream<List<Doc>> watchWhere(String c, String field, Object? value) => col(c)
      .where(field, isEqualTo: value)
      .snapshots()
      .map((s) => s.docs.map(Doc.of).toList()..sort((a, b) => b.created.compareTo(a.created)));

  static Stream<Doc?> watchDoc(String c, String id) =>
      col(c).doc(id).snapshots().map((s) => s.exists ? Doc.of(s) : null);

  static Future<Doc?> get(String c, String id) async {
    final s = await col(c).doc(id).get();
    return s.exists ? Doc.of(s) : null;
  }

  static Future<List<Doc>> list(String c) async {
    final s = await col(c).get();
    return s.docs.map(Doc.of).toList()..sort((a, b) => b.created.compareTo(a.created));
  }

  static Future<List<Doc>> listWhere(String c, String field, Object? value) async {
    final s = await col(c).where(field, isEqualTo: value).get();
    return s.docs.map(Doc.of).toList()..sort((a, b) => b.created.compareTo(a.created));
  }

  /// Atomically increments `counters.<key>` on the workspace and returns the new value.
  static Future<int> nextNumber(String key) => fs.runTransaction((tx) async {
        final snap = await tx.get(workspaceRef);
        final counters = Map<String, dynamic>.from((snap.data()?['counters'] as Map?) ?? {});
        final next = ((counters[key] as num?) ?? 0).toInt() + 1;
        tx.update(workspaceRef, {'counters.$key': next});
        return next;
      });

  /// Creates a document. If [numberKey] is given, assigns a sequential `number`.
  static Future<String> create(String c, Map<String, dynamic> data,
      {String? numberKey, String? label, String? id}) async {
    final payload = <String, dynamic>{
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdBy': _uid,
    };
    if (numberKey != null) payload['number'] = await nextNumber(numberKey);
    final ref = id == null ? col(c).doc() : col(c).doc(id);
    await ref.set(payload);
    log(c, ref.id, 'created', label ?? (data['name'] ?? data['code'] ?? data['title'] ?? '').toString());
    return ref.id;
  }

  static Future<void> update(String c, String id, Map<String, dynamic> data, {String? label, bool silent = false}) async {
    await col(c).doc(id).update({...data, 'updatedAt': FieldValue.serverTimestamp()});
    if (!silent) log(c, id, 'updated', label ?? (data['name'] ?? '').toString());
  }

  static Future<void> set(String c, String id, Map<String, dynamic> data, {bool merge = true}) =>
      col(c).doc(id).set({...data, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: merge));

  static Future<void> remove(String c, String id, {String? label}) async {
    await col(c).doc(id).delete();
    log(c, id, 'deleted', label ?? '');
  }

  /// Fire-and-forget activity log entry.
  static Future<void> log(String entity, String entityId, String action, String label) async {
    if (entity == C.activity || entity == C.notes) return;
    try {
      await col(C.activity).add({
        'entity': entity,
        'entityId': entityId,
        'action': action,
        'label': label,
        'actorName': _actor,
        'actorId': _uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  static Future<void> addNote(String entity, String entityId, String text) => col(C.notes).add({
        'entity': entity,
        'entityId': entityId,
        'text': text,
        'authorName': _actor,
        'authorId': _uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

  /// Uploads bytes to `workspaces/{wid}/{folder}/{ts}_{name}` and returns the download URL.
  static Future<String> upload(String folder, String fileName, Uint8List bytes, {String? contentType}) async {
    final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final ref = storage.ref('workspaces/$wid/$folder/${DateTime.now().millisecondsSinceEpoch}_$safe');
    await ref.putData(bytes, SettableMetadata(contentType: contentType ?? _guessType(safe), customMetadata: {'uploadedBy': _uid}));
    return ref.getDownloadURL();
  }

  static String _guessType(String n) {
    final l = n.toLowerCase();
    if (l.endsWith('.png')) return 'image/png';
    if (l.endsWith('.jpg') || l.endsWith('.jpeg')) return 'image/jpeg';
    if (l.endsWith('.webp')) return 'image/webp';
    if (l.endsWith('.gif')) return 'image/gif';
    if (l.endsWith('.svg')) return 'image/svg+xml';
    if (l.endsWith('.pdf')) return 'application/pdf';
    return 'application/octet-stream';
  }

  static String newId() => fs.collection('_').doc().id;
}
