import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Premium entrance animation helpers.
extension EnterAnim on Widget {
  /// Fade + rise, staggered by [index].
  Widget enter([int index = 0, double dy = 0.06]) => animate(delay: (40 * index.clamp(0, 14)).ms)
      .fadeIn(duration: 380.ms, curve: Curves.easeOutCubic)
      .slideY(begin: dy, end: 0, duration: 420.ms, curve: Curves.easeOutCubic);

  /// Fade + slide from the side.
  Widget enterX([int index = 0, double dx = 0.04]) => animate(delay: (40 * index.clamp(0, 14)).ms)
      .fadeIn(duration: 360.ms, curve: Curves.easeOutCubic)
      .slideX(begin: dx, end: 0, duration: 420.ms, curve: Curves.easeOutCubic);

  /// Soft scale-in pop.
  Widget pop([int index = 0]) => animate(delay: (50 * index.clamp(0, 12)).ms)
      .fadeIn(duration: 300.ms)
      .scaleXY(begin: 0.94, end: 1, duration: 420.ms, curve: Curves.easeOutBack);
}

/// Lifts and glows a child on hover; scales slightly on press.
class HoverLift extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double lift;
  final BorderRadius radius;
  const HoverLift({super.key, required this.child, this.onTap, this.lift = 3, this.radius = const BorderRadius.all(Radius.circular(14))});

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.985 : 1,
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(0, _hover ? -widget.lift : 0, 0),
            decoration: BoxDecoration(
              borderRadius: widget.radius,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6431DD).withValues(alpha: _hover ? 0.14 : 0.0),
                  blurRadius: _hover ? 28 : 0,
                  offset: Offset(0, _hover ? 12 : 0),
                ),
              ],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Animated number counter.
class CountUp extends StatelessWidget {
  final num value;
  final String Function(num) format;
  final TextStyle? style;
  const CountUp({super.key, required this.value, required this.format, this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text(format(v), style: style),
    );
  }
}

/// Animated shimmer placeholder.
class Skeleton extends StatelessWidget {
  final double height;
  final double? width;
  final double radius;
  const Skeleton({super.key, this.height = 14, this.width, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(color: const Color(0xFFEDE9F6), borderRadius: BorderRadius.circular(radius)),
    ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.7));
  }
}

/// Touch feedback: gently scales the child down while pressed (mobile).
class PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  const PressScale({super.key, required this.child, this.onTap, this.onLongPress, this.scale = 0.965});

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: active ? (_) => setState(() => _down = true) : null,
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
