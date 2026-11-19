import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../core/theme.dart';
import '../../data/session.dart';
import '../../widgets/anim.dart';
import '../../widgets/mobile.dart';
import 'illustrations.dart';

/// Persisted "has seen onboarding" flag.
class OnboardingFlag {
  static const _k = 'onboarding_seen_v1';
  static bool seen = false;
  static Future<void> load() async {
    try {
      seen = (await SharedPreferences.getInstance()).getBool(_k) ?? false;
    } catch (_) {}
  }

  static Future<void> markSeen() async {
    seen = true;
    try {
      await (await SharedPreferences.getInstance()).setBool(_k, true);
    } catch (_) {}
  }
}

/// Deep brand background with drifting light orbs.
class AuroraBackground extends StatelessWidget {
  final Widget child;
  const AuroraBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context);
    Widget orb(double size, Color c, Alignment a, int ms, double dx, double dy) => Align(
          alignment: a,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [c, c.withValues(alpha: 0)])),
          ).animate(onPlay: (ctl) => ctl.repeat(reverse: true)).move(begin: Offset(-dx, -dy), end: Offset(dx, dy), duration: ms.ms, curve: Curves.easeInOut),
        );
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.heroGradient),
      child: Stack(children: [
        orb(s.width * 1.1, AppColors.primary.withValues(alpha: 0.55), const Alignment(1.2, -1.1), 7000, 30, 20),
        orb(s.width * 0.9, AppColors.lavender.withValues(alpha: 0.22), const Alignment(-1.3, 0.2), 9000, 24, 40),
        orb(s.width * 0.7, const Color(0xFF8B5CF6).withValues(alpha: 0.35), const Alignment(0.8, 1.2), 8000, 30, 26),
        child,
      ]),
    );
  }
}

// ===========================================================================
// Splash
// ===========================================================================
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    final s = Session.instance;
    await Future.wait([
      OnboardingFlag.load(),
      Future.delayed(const Duration(milliseconds: 2600)),
      () async {
        while (!s.authResolved || (s.signedIn && s.loading)) {
          await Future.delayed(const Duration(milliseconds: 120));
        }
      }(),
    ]);
    if (!mounted) return;
    if (s.signedIn) {
      context.go(s.hasWorkspace ? '/home' : '/welcome');
    } else {
      context.go(OnboardingFlag.seen ? '/intro' : '/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    const word = 'Booqora';
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: AuroraBackground(
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Stack(alignment: Alignment.center, children: [
                Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 2)),
                ).animate(onPlay: (c) => c.repeat()).scaleXY(begin: 0.6, end: 1.5, duration: 1800.ms, curve: Curves.easeOut).fadeOut(duration: 1800.ms),
                Container(
                  width: 112,
                  height: 112,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.7), blurRadius: 50, spreadRadius: 4)],
                  ),
                  child: Image.asset('assets/brand/logo_mark.png'),
                )
                    .animate()
                    .scaleXY(begin: 0.2, end: 1, duration: 900.ms, curve: Curves.elasticOut)
                    .rotate(begin: -0.08, end: 0, duration: 900.ms, curve: Curves.easeOutBack),
              ]),
              const SizedBox(height: 28),
              Row(mainAxisSize: MainAxisSize.min, children: [
                for (var i = 0; i < word.length; i++)
                  Text(word[i], style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -0.5))
                      .animate(delay: (500 + i * 70).ms)
                      .fadeIn(duration: 350.ms)
                      .slideY(begin: 0.6, end: 0, duration: 450.ms, curve: Curves.easeOutBack),
              ]),
              const SizedBox(height: 10),
              const Text('Rental management, beautifully simple', style: TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 0.2))
                  .animate(delay: 1200.ms)
                  .fadeIn(duration: 600.ms),
              const SizedBox(height: 40),
              SizedBox(
                width: 120,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(minHeight: 4, color: AppColors.lavender, backgroundColor: Colors.white12),
                ),
              ).animate(delay: 1400.ms).fadeIn(),
            ]),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Onboarding — illustration on top, content in an animated bottom panel
// ===========================================================================
class _Slide {
  final Widget art;
  final String eyebrow, title, body;
  final IconData icon;
  const _Slide(this.art, this.eyebrow, this.title, this.body, this.icon);
}

const _slides = [
  _Slide(BookingIllustration(), 'BOOKINGS', 'Every booking,\nperfectly on time',
      'Live availability, smart pricing and a calendar that shows exactly what goes out and comes back.', Icons.event_available_rounded),
  _Slide(InventoryIllustration(), 'INVENTORY', 'Your whole inventory\nin your pocket',
      'Track every item, scan barcodes with your camera and schedule maintenance in seconds.', Icons.qr_code_scanner_rounded),
  _Slide(PaymentsIllustration(), 'PAYMENTS', 'Get paid faster,\nwherever you are',
      'Collect UPI, card and PayPal payments, send payment links and share invoices instantly.', Icons.payments_rounded),
  _Slide(StoreIllustration(), 'ONLINE STORE', 'Grow with your\nown online store',
      'Customers book 24/7 from your branded store while reports show what earns the most.', Icons.storefront_rounded),
];

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pc = PageController();
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _pc.addListener(() => setState(() => _page = _pc.page ?? 0));
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  int get _index => _page.round().clamp(0, _slides.length - 1);

  Future<void> _finish() async {
    HapticFeedback.mediumImpact();
    await OnboardingFlag.markSeen();
    if (mounted) context.go('/intro');
  }

  void _next() {
    HapticFeedback.selectionClick();
    if (_index == _slides.length - 1) {
      _finish();
    } else {
      _pc.nextPage(duration: const Duration(milliseconds: 520), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final artH = size.height * 0.56;
    final slide = _slides[_index];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: AuroraBackground(
          child: Stack(children: [
            // Illustrations with parallax.
            PageView.builder(
              controller: _pc,
              itemCount: _slides.length,
              itemBuilder: (_, i) {
                final delta = (i - _page);
                return Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    height: artH,
                    child: Center(
                      child: Opacity(
                        opacity: (1 - delta.abs() * 0.8).clamp(0, 1),
                        child: Transform.translate(
                          offset: Offset(delta * size.width * 0.35, 24 + delta.abs() * 30),
                          child: Transform.scale(scale: 1 - delta.abs() * 0.18, child: _slides[i].art),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            // Top bar
            Positioned(
              top: pad.top + 8,
              left: 20,
              right: 12,
              child: Row(children: [
                Image.asset('assets/brand/logo_mark.png', height: 30),
                const SizedBox(width: 8),
                const Text('Booqora', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                const Spacer(),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: _index == _slides.length - 1 ? 0 : 1,
                  child: TextButton(
                    onPressed: _finish,
                    child: const Text('Skip', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ),
            // Bottom content panel.
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(26, 26, 26, pad.bottom + 22),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
                  boxShadow: [BoxShadow(color: Color(0x551C0938), blurRadius: 40, offset: Offset(0, -10))],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 420),
                    switchInCurve: Curves.easeOutCubic,
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(a), child: child),
                    ),
                    child: Column(
                      key: ValueKey(_index),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(20)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(slide.icon, size: 14, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(slide.eyebrow, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1)),
                          ]),
                        ),
                        const SizedBox(height: 14),
                        Text(slide.title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(height: 1.15, fontSize: 28)),
                        const SizedBox(height: 10),
                        Text(slide.body, style: const TextStyle(color: AppColors.inkSoft, fontSize: 15, height: 1.5)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  Row(children: [
                    SmoothPageIndicator(
                      controller: _pc,
                      count: _slides.length,
                      effect: const ExpandingDotsEffect(
                        dotHeight: 8,
                        dotWidth: 8,
                        expansionFactor: 3.6,
                        spacing: 6,
                        activeDotColor: AppColors.primary,
                        dotColor: Color(0xFFDCD3F5),
                      ),
                      onDotClicked: (i) => _pc.animateToPage(i, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic),
                    ),
                    const Spacer(),
                    _ProgressNext(progress: (_page + 1) / _slides.length, last: _index == _slides.length - 1, onTap: _next),
                  ]),
                ]),
              ),
            ).animate().slideY(begin: 1, end: 0, duration: 700.ms, curve: Curves.easeOutCubic),
          ]),
        ),
      ),
    );
  }
}

/// Circular "next" button with a progress ring that fills as you advance.
class _ProgressNext extends StatelessWidget {
  final double progress;
  final bool last;
  final VoidCallback onTap;
  const _ProgressNext({required this.progress, required this.last, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        width: last ? 150 : 74,
        height: 74,
        child: Stack(alignment: Alignment.center, children: [
          if (!last)
            SizedBox(
              width: 74,
              height: 74,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: progress),
                duration: const Duration(milliseconds: 400),
                builder: (_, v, __) => CustomPaint(painter: _RingPainter(v)),
              ),
            ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            width: last ? 150 : 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.45), blurRadius: 18, offset: const Offset(0, 8))],
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: last
                    ? const Row(key: ValueKey('go'), mainAxisSize: MainAxisSize.min, children: [
                        Text('Get started', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                      ])
                    : const Icon(Icons.arrow_forward_rounded, key: ValueKey('next'), color: Colors.white),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double v;
  _RingPainter(this.v);
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFFE9E2FB);
    canvas.drawCircle(rect.center, size.width / 2 - 2, bg);
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = AppColors.brandGradient.createShader(rect);
    canvas.drawArc(rect.deflate(2), -math.pi / 2, 2 * math.pi * v, false, fg);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.v != v;
}

// ===========================================================================
// Intro — premium welcome before sign in / sign up
// ===========================================================================
class IntroPage extends StatelessWidget {
  const IntroPage({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final hero = math.min(size.width * 0.86, size.height * 0.42);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: AuroraBackground(
          child: Stack(children: [
            // Sparkles
            for (final (i, a) in const [Alignment(-0.8, -0.75), Alignment(0.75, -0.55), Alignment(-0.6, 0.05), Alignment(0.85, 0.1), Alignment(0.1, -0.9)].indexed)
              Align(
                alignment: a,
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16)
                    .animate(onPlay: (c) => c.repeat(reverse: true), delay: (i * 380).ms)
                    .fadeIn(duration: 900.ms)
                    .scaleXY(begin: 0.4, end: 1.1, duration: 1400.ms, curve: Curves.easeInOut),
              ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(children: [
                  const SizedBox(height: 12),
                  Expanded(child: Center(child: OrbitHero(size: hero).animate().fadeIn(duration: 800.ms).scaleXY(begin: 0.8, end: 1, duration: 900.ms, curve: Curves.easeOutBack))),
                  Text('Welcome to Booqora',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800))
                      .enter(2),
                  const SizedBox(height: 12),
                  const Text(
                    'Run bookings, inventory, customers, payments and your online store — all from your phone.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 15.5, height: 1.5),
                  ).enter(3),
                  const SizedBox(height: 28),
                  GradientButton(label: 'Create free account', icon: Icons.rocket_launch_rounded, onPressed: () => context.push('/signup')).enter(4),
                  const SizedBox(height: 12),
                  PressScale(
                    onTap: () => context.push('/login'),
                    child: Container(
                      height: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                      ),
                      child: const Text('I already have an account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                  ).enter(5),
                  const SizedBox(height: 16),
                  const Text('14-day free trial · No credit card required', style: TextStyle(color: Colors.white54, fontSize: 12.5)).enter(6),
                  SizedBox(height: pad.bottom > 0 ? 8 : 20),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Small helper so auth pages can reuse the timer-free aurora header.
class AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? art;
  const AuthHeader({super.key, required this.title, required this.subtitle, this.art});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (art != null) Center(child: art!),
      Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)).enter(1),
      const SizedBox(height: 6),
      Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 15)).enter(2),
    ]);
  }
}

/// Keeps a widget alive only for the given time (used for one-shot effects).
class TimedVisibility extends StatefulWidget {
  final Duration after;
  final Widget child;
  const TimedVisibility({super.key, required this.after, required this.child});
  @override
  State<TimedVisibility> createState() => _TimedVisibilityState();
}

class _TimedVisibilityState extends State<TimedVisibility> {
  bool _show = false;
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer(widget.after, () => mounted ? setState(() => _show = true) : null);
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _show ? widget.child : const SizedBox.shrink();
}
