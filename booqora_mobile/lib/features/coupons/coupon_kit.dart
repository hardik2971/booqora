import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../widgets/common.dart';

/// Effective status of a coupon: active | inactive | scheduled | expired | used_up.
String couponState(Doc c, [DateTime? now]) {
  final t = now ?? DateTime.now();
  if (!c.b('active')) return 'inactive';
  final ends = c.d('endsAt');
  if (ends != null && ends.isBefore(t)) return 'expired';
  final max = c.data['maxUses'];
  if (max is num && max > 0 && c.i('uses') >= max) return 'used_up';
  final starts = c.d('startsAt');
  if (starts != null && starts.isAfter(t)) return 'scheduled';
  return 'active';
}

Widget couponStatePill(String state) => switch (state) {
      'expired' => const StatusPill('overdue', label: 'Expired'),
      'used_up' => const StatusPill('late', label: 'Limit reached'),
      'scheduled' => const StatusPill('scheduled'),
      'inactive' => const StatusPill('inactive'),
      _ => const StatusPill('active'),
    };

String numText(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

String couponDiscountLabel(String type, num value) => type == 'fixed' ? Fmt.money(value) : '${numText(value)}%';

String couponValidityText(DateTime? s, DateTime? e) {
  if (s == null && e == null) return 'No expiry date';
  if (s != null && e != null) return '${Fmt.date(s)} – ${Fmt.date(e)}';
  if (s != null) return 'From ${Fmt.date(s)}';
  return 'Until ${Fmt.date(e)}';
}

String couponEligibleText(Doc c) => switch (c.s('eligible', 'all')) {
      'products' => '${c.l<String>('productIds').length} product${c.l<String>('productIds').length == 1 ? '' : 's'}',
      'collections' => '${c.l<String>('collectionIds').length} collection${c.l<String>('collectionIds').length == 1 ? '' : 's'}',
      _ => 'All products',
    };

Future<void> copyCode(BuildContext context, String code) async {
  HapticFeedback.lightImpact();
  await Clipboard.setData(ClipboardData(text: code));
  if (context.mounted) toast(context, 'Copied $code');
}

/// Ticket-shaped coupon card: value stub, perforation with notches, code & details.
class CouponTicket extends StatelessWidget {
  final String code;
  final String discount;
  final bool live; // colourful when live, muted otherwise
  final List<(IconData, String)> lines;
  final Widget? trailing;
  final Widget? badge;
  final double stubWidth;
  final bool large;
  const CouponTicket({
    super.key,
    required this.code,
    required this.discount,
    required this.live,
    required this.lines,
    this.trailing,
    this.badge,
    this.stubWidth = 104,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    const notch = 11.0;
    return PhysicalShape(
      clipper: _TicketClipper(stubWidth, notch),
      color: Colors.white,
      elevation: large ? 8 : 3,
      shadowColor: AppColors.primary.withValues(alpha: large ? 0.35 : 0.18),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: stubWidth,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            decoration: BoxDecoration(
              gradient: live ? AppColors.brandGradient : const LinearGradient(colors: [Color(0xFFB9B2C9), Color(0xFF8E86A3)]),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(discount,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: large ? 32 : 26, letterSpacing: -0.8)),
              ),
              const Text('OFF', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 2.5)),
            ]),
          ),
          SizedBox(width: 1, child: CustomPaint(painter: _DashPainter())),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(14, large ? 16 : 12, 10, large ? 16 : 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      code,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w800,
                        fontSize: large ? 20 : 17,
                        letterSpacing: 1.4,
                        color: live ? AppColors.primaryDeep : AppColors.inkSoft,
                      ),
                    ),
                  ),
                  ?trailing,
                ]),
                if (badge != null) ...[const SizedBox(height: 6), badge!],
                const SizedBox(height: 6),
                for (final l in lines)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(children: [
                      Icon(l.$1, size: 13, color: AppColors.muted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(l.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
                      ),
                    ]),
                  ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _TicketClipper extends CustomClipper<Path> {
  final double x;
  final double r;
  _TicketClipper(this.x, this.r);

  @override
  Path getClip(Size size) {
    const radius = Radius.circular(18);
    final body = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, radius));
    final holes = Path()
      ..addOval(Rect.fromCircle(center: Offset(x, 0), radius: r))
      ..addOval(Rect.fromCircle(center: Offset(x, size.height), radius: r));
    return Path.combine(PathOperation.difference, body, holes);
  }

  @override
  bool shouldReclip(covariant _TicketClipper old) => old.x != x || old.r != r;
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1.4;
    var y = 14.0;
    while (y < size.height - 14) {
      canvas.drawLine(Offset(0.5, y), Offset(0.5, y + 5), p);
      y += 9;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
