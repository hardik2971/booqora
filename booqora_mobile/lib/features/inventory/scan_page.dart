import 'dart:async';

import 'package:flutter/material.dart' hide Thumb;
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/mobile.dart';

/// Full-screen barcode / QR scanner that opens the matching stock item,
/// product (by SKU) or order (by number).
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> with SingleTickerProviderStateMixin {
  final _controller = MobileScannerController(detectionSpeed: DetectionSpeed.normal);
  late final AnimationController _laser = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
  final _manual = TextEditingController();
  bool _busy = false;
  bool _found = false;
  String? _lastCode;
  DateTime _lastAt = DateTime(2000);

  @override
  void dispose() {
    _laser.dispose();
    _manual.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final code = capture.barcodes.map((b) => b.rawValue ?? b.displayValue).whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty).firstOrNull;
    if (code == null || _busy) return;
    final now = DateTime.now();
    if (code == _lastCode && now.difference(_lastAt) < const Duration(seconds: 3)) return;
    _lastCode = code;
    _lastAt = now;
    _lookup(code);
  }

  /// Resolves [raw] to a route, or null when nothing matches.
  Future<String?> _resolve(String raw) async {
    final code = raw.trim();
    // Booqora links (e.g. a QR with a product or order URL).
    final link = RegExp(r'/(?:inventory/products|p)/([A-Za-z0-9_-]{8,})').firstMatch(code);
    if (link != null && await Db.get(C.products, link.group(1)!) != null) return '/inventory/products/${link.group(1)}';
    final orderLink = RegExp(r'/orders/([A-Za-z0-9_-]{8,})').firstMatch(code);
    if (orderLink != null && await Db.get(C.orders, orderLink.group(1)!) != null) return '/orders/${orderLink.group(1)}';

    for (final v in {code, code.toUpperCase()}) {
      final items = await Db.listWhere(C.stockItems, 'identifier', v);
      if (items.isNotEmpty) return '/inventory/products/${items.first.s('productId')}?tab=inventory';
    }
    for (final v in {code, code.toUpperCase()}) {
      final products = await Db.listWhere(C.products, 'sku', v);
      if (products.isNotEmpty) return '/inventory/products/${products.first.id}';
    }
    final n = int.tryParse(code.replaceAll(RegExp(r'^#|^(ORD|ORDER)[-\s]?', caseSensitive: false), ''));
    if (n != null) {
      final orders = await Db.listWhere(C.orders, 'number', n);
      if (orders.isNotEmpty) return '/orders/${orders.first.id}';
    }
    return null;
  }

  Future<void> _lookup(String code) async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    try {
      await _controller.stop();
    } catch (_) {}
    try {
      final route = await _resolve(code);
      if (!mounted) return;
      if (route != null) {
        setState(() => _found = true);
        HapticFeedback.heavyImpact();
        await Future<void>.delayed(const Duration(milliseconds: 350));
        if (mounted) context.pushReplacement(route);
        return;
      }
      HapticFeedback.vibrate();
      await _notFound(code);
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    try {
      await _controller.start();
    } catch (_) {}
  }

  Future<void> _notFound(String code) => showAppSheet<void>(context, title: 'No match found', builder: (c) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: AppColors.warningSoft, borderRadius: BorderRadius.circular(22)),
              child: const Icon(Icons.search_off_rounded, size: 36, color: AppColors.warning),
            ).pop(),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: Text(code, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 12),
          const Text(
            'This code doesn\'t match a stock item identifier, product SKU or order number in your workspace.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, height: 1.45),
          ),
          const SizedBox(height: 20),
          GradientButton(label: 'Scan again', icon: Icons.qr_code_scanner_rounded, onPressed: () => Navigator.pop(c)),
        ]);
      });

  void _submitManual() {
    final v = _manual.text.trim();
    if (v.isEmpty) return;
    FocusScope.of(context).unfocus();
    _lookup(v);
  }

  Rect _window(Size s) {
    final side = (s.width * 0.72).clamp(200.0, 320.0);
    return Rect.fromCenter(center: Offset(s.width / 2, s.height * 0.42), width: side, height: side);
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: LayoutBuilder(builder: (context, c) {
          final size = c.biggest;
          final win = _window(size);
          return Stack(children: [
            Positioned.fill(
              child: MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                scanWindow: win,
                errorBuilder: (context, error) => _PermissionView(error: error),
                placeholderBuilder: (_) => const ColoredBox(color: Colors.black, child: Center(child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2))),
              ),
            ),
            // Dimmed overlay with a cut-out window.
            Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _OverlayPainter(win)))),
            // Animated corner frame + laser.
            Positioned.fromRect(
              rect: win,
              child: IgnorePointer(
                child: AnimatedScale(
                  scale: _found ? 1.06 : 1,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                  child: Stack(children: [
                    Positioned.fill(
                      child: CustomPaint(painter: _CornerPainter(_found ? AppColors.success : Colors.white))
                          .animate(onPlay: (a) => a.repeat(reverse: true))
                          .scaleXY(begin: 1, end: 1.025, duration: 1400.ms, curve: Curves.easeInOut),
                    ),
                    if (!_busy)
                      AnimatedBuilder(
                        animation: _laser,
                        builder: (_, _) => Positioned(
                          left: 14,
                          right: 14,
                          top: 14 + (win.height - 28) * Curves.easeInOut.transform(_laser.value),
                          child: Container(
                            height: 2.5,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0x00C2A3F9), AppColors.lavender, Color(0x00C2A3F9)]),
                              boxShadow: [BoxShadow(color: AppColors.lavender.withValues(alpha: 0.8), blurRadius: 14, spreadRadius: 1)],
                            ),
                          ),
                        ),
                      ),
                    if (_busy)
                      Center(
                        child: _found
                            ? const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 64).animate().scaleXY(begin: 0.4, end: 1, curve: Curves.easeOutBack)
                            : const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.6)),
                      ),
                  ]),
                ).animate().fadeIn(duration: 400.ms).scaleXY(begin: 0.92, end: 1, curve: Curves.easeOutCubic),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: win.bottom + 18,
              child: Text(
                _busy ? (_found ? 'Found it' : 'Looking up…') : 'Point at a barcode or QR code',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
            // Top bar.
            Positioned(
              left: 8,
              right: 8,
              top: pad.top + 6,
              child: Row(children: [
                _GlassBtn(icon: Icons.close_rounded, tooltip: 'Close', onTap: () => Navigator.of(context).maybePop()),
                const Expanded(
                  child: Text('Scan', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                ValueListenableBuilder<MobileScannerState>(
                  valueListenable: _controller,
                  builder: (_, st, _) {
                    final on = st.torchState == TorchState.on;
                    final enabled = st.isRunning && st.torchState != TorchState.unavailable;
                    return _GlassBtn(
                      icon: on ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                      tooltip: 'Torch',
                      active: on,
                      onTap: enabled
                          ? () {
                              HapticFeedback.selectionClick();
                              _controller.toggleTorch();
                            }
                          : null,
                    );
                  },
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<MobileScannerState>(
                  valueListenable: _controller,
                  builder: (_, st, _) => _GlassBtn(
                    icon: Icons.cameraswitch_rounded,
                    tooltip: 'Switch camera',
                    onTap: st.isRunning && (st.availableCameras ?? 2) > 1
                        ? () {
                            HapticFeedback.selectionClick();
                            _controller.switchCamera();
                          }
                        : null,
                  ),
                ),
              ]),
            ),
            // Manual entry.
            AnimatedPositioned(
              duration: const Duration(milliseconds: 180),
              left: 16,
              right: 16,
              bottom: MediaQuery.viewInsetsOf(context).bottom + pad.bottom + 16,
              child: _ManualEntry(controller: _manual, onSubmit: _busy ? null : _submitManual).enter(2),
            ),
          ]);
        }),
      ),
    );
  }
}

class _ManualEntry extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onSubmit;
  const _ManualEntry({required this.controller, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 24, offset: Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        const Text('Enter a code manually', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        const Text('Stock identifier, product SKU or order number', style: TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onSubmit?.call(),
              decoration: const InputDecoration(hintText: 'e.g. CAME-001 or 1024', prefixIcon: Icon(Icons.keyboard_alt_outlined, size: 20)),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(width: 92, child: GradientButton(label: 'Find', height: 48, onPressed: onSubmit)),
        ]),
      ]),
    );
  }
}

class _PermissionView extends StatelessWidget {
  final MobileScannerException error;
  const _PermissionView({required this.error});

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    final unsupported = error.errorCode == MobileScannerErrorCode.unsupported;
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.heroGradient),
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 220),
      alignment: Alignment.center,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(26)),
          child: Icon(denied ? Icons.no_photography_outlined : Icons.videocam_off_outlined, color: Colors.white, size: 40),
        ).pop(),
        const SizedBox(height: 20),
        Text(
          denied ? 'Camera access is off' : (unsupported ? 'Scanning isn\'t supported here' : 'Camera unavailable'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          denied
              ? 'Allow camera access for Booqora in your device settings to scan barcodes. You can still enter a code below.'
              : 'The camera couldn\'t be started. You can still enter a code below.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, height: 1.5),
        ),
      ]),
    );
  }
}

class _GlassBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool active;
  const _GlassBtn({required this.icon, required this.tooltip, this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: PressScale(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.white.withValues(alpha: onTap == null ? 0.08 : 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(icon, color: active ? AppColors.ink : (onTap == null ? Colors.white38 : Colors.white), size: 22),
          ),
        ),
      );
}

class _OverlayPainter extends CustomPainter {
  final Rect window;
  _OverlayPainter(this.window);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(window, const Radius.circular(28)));
    canvas.drawPath(path, Paint()..color = const Color(0xA6120626));
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter old) => old.window != window;
}

class _CornerPainter extends CustomPainter {
  final Color color;
  _CornerPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const r = 28.0, len = 34.0;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    final w = size.width, h = size.height;
    // top-left
    canvas.drawPath(
        Path()
          ..moveTo(0, r + len)
          ..lineTo(0, r)
          ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
          ..lineTo(r + len, 0),
        p);
    // top-right
    canvas.drawPath(
        Path()
          ..moveTo(w - r - len, 0)
          ..lineTo(w - r, 0)
          ..arcToPoint(Offset(w, r), radius: const Radius.circular(r))
          ..lineTo(w, r + len),
        p);
    // bottom-right
    canvas.drawPath(
        Path()
          ..moveTo(w, h - r - len)
          ..lineTo(w, h - r)
          ..arcToPoint(Offset(w - r, h), radius: const Radius.circular(r))
          ..lineTo(w - r - len, h),
        p);
    // bottom-left
    canvas.drawPath(
        Path()
          ..moveTo(r + len, h)
          ..lineTo(r, h)
          ..arcToPoint(Offset(0, h - r), radius: const Radius.circular(r))
          ..lineTo(0, h - r - len),
        p);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter old) => old.color != color;
}
