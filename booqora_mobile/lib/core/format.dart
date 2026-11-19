import 'package:intl/intl.dart';

import '../data/session.dart';

/// Formatting helpers driven by workspace settings.
class Fmt {
  static String get symbol => (Session.instance.setting('pricing', 'symbol', '₹') as String?) ?? '₹';
  static bool get _after => Session.instance.setting('pricing', 'position', 'before') == 'after';
  static String get _datePattern => (Session.instance.setting('general', 'dateFormat', 'dd-MM-yyyy') as String?) ?? 'dd-MM-yyyy';
  static bool get _h12 => Session.instance.setting('general', 'use12h', false) == true;

  static final _num = NumberFormat('#,##0.00');
  static final _int = NumberFormat('#,##0');

  static String money(num? v, {String? sym, bool after = false}) {
    final s = sym ?? symbol;
    final a = sym != null ? after : _after;
    final n = _num.format(v ?? 0);
    return a ? '$n $s' : '$s$n';
  }

  static String compactMoney(num? v) {
    final x = (v ?? 0).toDouble();
    if (x.abs() >= 10000000) return '$symbol${(x / 10000000).toStringAsFixed(1)}Cr';
    if (x.abs() >= 100000) return '$symbol${(x / 100000).toStringAsFixed(1)}L';
    if (x.abs() >= 1000) return '$symbol${(x / 1000).toStringAsFixed(1)}K';
    return money(x);
  }

  static String integer(num? v) => _int.format(v ?? 0);

  static String date(DateTime? d) => d == null ? '—' : DateFormat(_datePattern).format(d);
  static String time(DateTime? d) => d == null ? '' : DateFormat(_h12 ? 'h:mm a' : 'HH:mm').format(d);
  static String dateTime(DateTime? d) => d == null ? '—' : '${date(d)} ${time(d)}';
  static String shortDate(DateTime? d) => d == null ? '—' : DateFormat('d MMM').format(d);
  static String dayLabel(DateTime d) => DateFormat('EEE d').format(d);

  static String relative(DateTime? d) {
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return date(d);
  }

  static String label(String v) {
    if (v.isEmpty) return v;
    final s = v.replaceAll('_', ' ');
    return s[0].toUpperCase() + s.substring(1);
  }

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}
