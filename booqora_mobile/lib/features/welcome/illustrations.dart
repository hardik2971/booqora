import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme.dart';

// Original animated illustrations for onboarding, built from Flutter widgets
// and painters (no external assets), in the Booqora brand palette.

const _violet = AppColors.primary;
const _indigo = AppColors.primaryDeep;
const _lav = AppColors.lavender;

/// Soft glowing stage behind every illustration: rotating dotted ring + floating orbs.
class IlloStage extends StatelessWidget {
  final Widget child;
  final double size;
  const IlloStage({super.key, required this.child, this.size = 300});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        Container(
          width: size * 0.92,
          height: size * 0.92,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [Colors.white.withValues(alpha: 0.16), Colors.white.withValues(alpha: 0.0)]),
          ),
        ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 0.94, end: 1.04, duration: 3.seconds, curve: Curves.easeInOut),
        CustomPaint(size: Size.square(size * 0.86), painter: _DottedRing())
            .animate(onPlay: (c) => c.repeat())
            .rotate(duration: 26.seconds),
        _orb(const Alignment(-0.85, -0.7), 18, _lav, 0),
        _orb(const Alignment(0.9, -0.45), 12, Colors.white, 400),
        _orb(const Alignment(0.8, 0.85), 22, const Color(0xFF9F7AEA), 800),
        _orb(const Alignment(-0.9, 0.6), 10, Colors.white70, 1200),
        child,
      ]),
    );
  }

  Widget _orb(Alignment a, double s, Color c, int delayMs) => Align(
        alignment: a,
        child: Container(
          width: s,
          height: s,
          decoration: BoxDecoration(shape: BoxShape.circle, color: c.withValues(alpha: 0.85), boxShadow: [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: s)]),
        )
            .animate(onPlay: (ctl) => ctl.repeat(reverse: true), delay: delayMs.ms)
            .moveY(begin: -8, end: 8, duration: 2600.ms, curve: Curves.easeInOut)
            .fadeIn(duration: 600.ms),
      );
}

class _DottedRing extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.35);
    final r = size.width / 2;
    final c = size.center(Offset.zero);
    for (var i = 0; i < 48; i++) {
      final a = i / 48 * 2 * math.pi;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * r, i % 4 == 0 ? 2.6 : 1.4, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

BoxDecoration _card([double r = 18]) => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(r),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 30, offset: const Offset(0, 16))],
    );

Widget _chip(String text, IconData icon, {Color color = _violet}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 7),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.ink)),
      ]),
    );

// ---------------------------------------------------------------------------
// 1 · Bookings & live availability
// ---------------------------------------------------------------------------
class BookingIllustration extends StatelessWidget {
  const BookingIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return IlloStage(
      child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
        Container(
          width: 196,
          height: 186,
          decoration: _card(22),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            Container(
              height: 44,
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [_violet, _indigo])),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: const Row(children: [
                Icon(Icons.calendar_month_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('November', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                Spacer(),
                Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 18),
              ]),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: GridView.count(
                  crossAxisCount: 7,
                  mainAxisSpacing: 5,
                  crossAxisSpacing: 5,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (var i = 0; i < 28; i++)
                      _DayCell(i: i),
                  ],
                ),
              ),
            ),
          ]),
        ).animate().scaleXY(begin: 0.85, end: 1, duration: 600.ms, curve: Curves.easeOutBack).fadeIn(),
        // Booking bar sweeping across a week.
        Positioned(
          top: 104,
          left: -4,
          child: Container(
            width: 128,
            height: 22,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 10),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), _violet]), borderRadius: BorderRadius.circular(11),
                boxShadow: [BoxShadow(color: _violet.withValues(alpha: 0.5), blurRadius: 12, offset: const Offset(0, 6))]),
            child: const Text('#1042 · Aarav', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700)),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleX(begin: 0.25, end: 1, alignment: Alignment.centerLeft, duration: 1800.ms, curve: Curves.easeInOutCubic),
        ),
        Positioned(
          top: -6,
          right: -30,
          child: _chip('Reserved', Icons.check_rounded, color: AppColors.success)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(begin: -4, end: 6, duration: 2.seconds, curve: Curves.easeInOut),
        ),
        Positioned(
          bottom: -14,
          left: -26,
          child: _chip('3 available', Icons.inventory_2_rounded)
              .animate(onPlay: (c) => c.repeat(reverse: true), delay: 500.ms)
              .moveY(begin: 6, end: -4, duration: 2200.ms, curve: Curves.easeInOut),
        ),
      ]),
    );
  }
}

class _DayCell extends StatelessWidget {
  final int i;
  const _DayCell({required this.i});

  @override
  Widget build(BuildContext context) {
    final hot = const {9, 10, 11, 17, 23}.contains(i);
    final cell = Container(
      decoration: BoxDecoration(
        color: hot ? _violet.withValues(alpha: 0.85) : const Color(0xFFF1ECFD),
        borderRadius: BorderRadius.circular(5),
      ),
      alignment: Alignment.center,
      child: Text('${i + 1}', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: hot ? Colors.white : AppColors.inkSoft)),
    );
    if (!hot) return cell;
    return cell.animate(onPlay: (c) => c.repeat(reverse: true), delay: (i * 70).ms).scaleXY(begin: 0.85, end: 1.06, duration: 900.ms);
  }
}

// ---------------------------------------------------------------------------
// 2 · Inventory in your pocket (barcode scanning)
// ---------------------------------------------------------------------------
class InventoryIllustration extends StatelessWidget {
  const InventoryIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    Widget product(IconData icon, String name, String meta, Color c) => Container(
          width: 150,
          padding: const EdgeInsets.all(10),
          decoration: _card(16),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(gradient: LinearGradient(colors: [c, c.withValues(alpha: 0.7)]), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.ink)),
                Text(meta, style: const TextStyle(fontSize: 9.5, color: AppColors.muted)),
              ]),
            ),
          ]),
        );
    return IlloStage(
      child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
        Transform.translate(
          offset: const Offset(-34, -62),
          child: Transform.rotate(angle: -0.12, child: product(Icons.photo_camera_rounded, 'Canon R100', '4 in stock', const Color(0xFF8B5CF6))),
        ).animate().slideX(begin: -0.6, end: 0, duration: 700.ms, curve: Curves.easeOutCubic).fadeIn(),
        Transform.translate(
          offset: const Offset(40, -6),
          child: Transform.rotate(angle: 0.08, child: product(Icons.light_mode_rounded, 'Godox SL60', '6 in stock', const Color(0xFFF59E0B))),
        ).animate(delay: 150.ms).slideX(begin: 0.6, end: 0, duration: 700.ms, curve: Curves.easeOutCubic).fadeIn(),
        Transform.translate(
          offset: const Offset(-22, 52),
          child: Transform.rotate(angle: -0.04, child: product(Icons.mic_rounded, 'Rode GO II', '5 in stock', const Color(0xFF10B981))),
        ).animate(delay: 300.ms).slideY(begin: 0.6, end: 0, duration: 700.ms, curve: Curves.easeOutCubic).fadeIn(),
        // Scanner frame with sweeping laser.
        Positioned(
          right: 18,
          bottom: 30,
          child: Container(
            width: 92,
            height: 74,
            padding: const EdgeInsets.all(10),
            decoration: _card(16),
            child: Stack(children: [
              CustomPaint(size: const Size(72, 54), painter: _BarcodePainter()),
              const _Laser(),
            ]),
          ).animate(delay: 450.ms).scaleXY(begin: 0.5, end: 1, duration: 600.ms, curve: Curves.easeOutBack).fadeIn(),
        ),
        Positioned(
          top: 18,
          right: 6,
          child: _chip('Scanned', Icons.qr_code_scanner_rounded, color: AppColors.success)
              .animate(onPlay: (c) => c.repeat(reverse: true), delay: 600.ms)
              .moveY(begin: -5, end: 5, duration: 2.seconds, curve: Curves.easeInOut),
        ),
      ]),
    );
  }
}

class _Laser extends StatelessWidget {
  const _Laser();
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        height: 3,
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(2),
          boxShadow: [BoxShadow(color: const Color(0xFFEF4444).withValues(alpha: 0.7), blurRadius: 8)],
        ),
      ).animate(onPlay: (c) => c.repeat(reverse: true)).moveY(begin: 0, end: 50, duration: 1300.ms, curve: Curves.easeInOut),
    );
  }
}

class _BarcodePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = AppColors.ink;
    const widths = [2.0, 1.0, 3.0, 1.0, 1.0, 2.0, 3.0, 1.0, 2.0, 1.0, 1.0, 3.0, 2.0, 1.0, 2.0, 1.0, 3.0, 1.0, 2.0, 1.0];
    var x = 0.0;
    var i = 0;
    while (x < size.width) {
      final w = widths[i % widths.length];
      if (i.isEven) canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), p);
      x += w + 1.4;
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// 3 · Get paid faster
// ---------------------------------------------------------------------------
class PaymentsIllustration extends StatelessWidget {
  const PaymentsIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return IlloStage(
      child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
        // Phone
        Container(
          width: 132,
          height: 224,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(26),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 18))]),
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 18),
              Container(
                width: 54,
                height: 54,
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF34D399), AppColors.success])),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 32)
                    .animate(onPlay: (c) => c.repeat(), delay: 400.ms)
                    .scaleXY(begin: 0, end: 1, duration: 500.ms, curve: Curves.elasticOut)
                    .then(delay: 2200.ms)
                    .fadeOut(duration: 300.ms),
              ),
              const SizedBox(height: 12),
              const Text('Payment received', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
              const SizedBox(height: 4),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 12480),
                duration: const Duration(milliseconds: 1600),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => Text('₹${v.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _violet, letterSpacing: -0.5)),
              ),
              const Spacer(),
              Container(
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [_violet, _indigo]), borderRadius: BorderRadius.circular(9)),
                child: const Text('Receipt sent', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ).animate().slideY(begin: 0.25, end: 0, duration: 700.ms, curve: Curves.easeOutCubic).fadeIn(),
        // Credit card swiping in.
        Positioned(
          left: -10,
          bottom: 46,
          child: Transform.rotate(
            angle: -0.28,
            child: Container(
              width: 120,
              height: 74,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFEC4899)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 18, offset: const Offset(0, 10))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 18, height: 13, decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(3))),
                const Spacer(),
                const Text('•••• 4242', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 1)),
              ]),
            ),
          ),
        ).animate(onPlay: (c) => c.repeat(reverse: true)).moveX(begin: -10, end: 8, duration: 2400.ms, curve: Curves.easeInOut),
        // Coins
        for (var i = 0; i < 3; i++)
          Positioned(
            right: 8.0 + i * 18,
            top: 40.0 + i * 26,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [Color(0xFFFDE68A), Color(0xFFF59E0B)]),
                border: Border.all(color: const Color(0xFFFFF7D6), width: 2),
              ),
              alignment: Alignment.center,
              child: const Text('₹', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF92400E))),
            )
                .animate(onPlay: (c) => c.repeat(), delay: (i * 450).ms)
                .moveY(begin: 30, end: -30, duration: 2200.ms, curve: Curves.easeOut)
                .fadeIn(duration: 300.ms)
                .then(delay: 1400.ms)
                .fadeOut(duration: 400.ms),
          ),
        Positioned(
          top: 6,
          left: 0,
          child: _chip('UPI · Cards · PayPal', Icons.bolt_rounded)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(begin: -5, end: 5, duration: 2200.ms, curve: Curves.easeInOut),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// 4 · Grow with your online store
// ---------------------------------------------------------------------------
class StoreIllustration extends StatelessWidget {
  const StoreIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return IlloStage(
      child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
        Container(
          width: 196,
          height: 176,
          decoration: _card(20),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            SizedBox(height: 34, child: CustomPaint(size: const Size(196, 34), painter: _AwningPainter())),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: GridView.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: 7,
                  crossAxisSpacing: 7,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (final (i, ic) in [
                      Icons.photo_camera_rounded,
                      Icons.pedal_bike_rounded,
                      Icons.speaker_rounded,
                      Icons.celebration_rounded,
                      Icons.kayaking_rounded,
                      Icons.handyman_rounded,
                    ].indexed)
                      Container(
                        decoration: BoxDecoration(color: const Color(0xFFF3EEFE), borderRadius: BorderRadius.circular(10)),
                        child: Icon(ic, color: _violet, size: 22),
                      ).animate(delay: (200 + i * 90).ms).scaleXY(begin: 0, end: 1, duration: 450.ms, curve: Curves.easeOutBack),
                  ],
                ),
              ),
            ),
          ]),
        ).animate().scaleXY(begin: 0.85, end: 1, duration: 600.ms, curve: Curves.easeOutBack).fadeIn(),
        // Cart with bouncing badge.
        Positioned(
          top: 10,
          right: -2,
          child: Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [_violet, _indigo]), borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: _violet.withValues(alpha: 0.5), blurRadius: 16, offset: const Offset(0, 8))]),
              child: const Icon(Icons.shopping_bag_rounded, color: Colors.white),
            ),
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                child: const Text('3', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
              ).animate(onPlay: (c) => c.repeat()).scaleXY(begin: 1, end: 1.3, duration: 400.ms, curve: Curves.easeOut).then().scaleXY(begin: 1.3, end: 1, duration: 400.ms).then(delay: 1200.ms),
            ),
          ]),
        ),
        // Growth chart.
        Positioned(
          left: -8,
          bottom: 4,
          child: Container(
            width: 92,
            height: 74,
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            decoration: _card(14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              for (final (i, h) in [0.35, 0.55, 0.45, 0.75, 1.0].indexed)
                Container(
                  width: 11,
                  height: 52 * h,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_lav, _violet], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ).animate(onPlay: (c) => c.repeat(reverse: true), delay: (i * 120).ms).scaleY(begin: 0.2, end: 1, alignment: Alignment.bottomCenter, duration: 1100.ms, curve: Curves.easeOutCubic),
            ]),
          ),
        ),
        Positioned(
          bottom: -10,
          right: 4,
          child: _chip('New booking', Icons.notifications_active_rounded, color: AppColors.warning)
              .animate(onPlay: (c) => c.repeat(reverse: true), delay: 300.ms)
              .moveY(begin: 5, end: -5, duration: 2.seconds, curve: Curves.easeInOut),
        ),
      ]),
    );
  }
}

class _AwningPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const stripes = 7;
    final w = size.width / stripes;
    for (var i = 0; i < stripes; i++) {
      final paint = Paint()..color = i.isEven ? _violet : Colors.white;
      final path = Path()
        ..moveTo(i * w, 0)
        ..lineTo((i + 1) * w, 0)
        ..lineTo((i + 1) * w, size.height - 8)
        ..arcToPoint(Offset(i * w, size.height - 8), radius: Radius.circular(w / 2))
        ..close();
      canvas.drawPath(path, paint);
    }
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 4), Paint()..color = _indigo);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Orbiting module icons around the logo (intro screen hero).
class OrbitHero extends StatelessWidget {
  final double size;
  const OrbitHero({super.key, this.size = 300});

  static const _icons = [
    Icons.receipt_long_rounded,
    Icons.calendar_month_rounded,
    Icons.inventory_2_rounded,
    Icons.people_alt_rounded,
    Icons.storefront_rounded,
    Icons.insights_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final r1 = size * 0.36;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        for (final f in [1.0, 0.72])
          Container(
            width: size * f,
            height: size * f,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.14), width: 1.2)),
          ),
        // Orbiting icons (counter-rotated so they stay upright).
        _Orbit(radius: r1, icons: _icons, duration: 22.seconds),
        Container(
          width: size * 0.36,
          height: size * 0.36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [BoxShadow(color: _violet.withValues(alpha: 0.6), blurRadius: 50, spreadRadius: 6)],
          ),
          padding: EdgeInsets.all(size * 0.06),
          child: Image.asset('assets/brand/logo_mark.png'),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scaleXY(begin: 0.96, end: 1.04, duration: 2200.ms, curve: Curves.easeInOut),
      ]),
    );
  }
}

class _Orbit extends StatefulWidget {
  final double radius;
  final List<IconData> icons;
  final Duration duration;
  const _Orbit({required this.radius, required this.icons, required this.duration});

  @override
  State<_Orbit> createState() => _OrbitState();
}

class _OrbitState extends State<_Orbit> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration)..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final n = widget.icons.length;
        return Stack(alignment: Alignment.center, children: [
          for (var i = 0; i < n; i++)
            Transform.translate(
              offset: Offset(math.cos(_c.value * 2 * math.pi + i * 2 * math.pi / n), math.sin(_c.value * 2 * math.pi + i * 2 * math.pi / n)) * widget.radius,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                ),
                child: Icon(widget.icons[i], color: Colors.white, size: 22),
              ),
            ),
        ]);
      },
    );
  }
}
