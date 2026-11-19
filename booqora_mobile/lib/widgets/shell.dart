import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import 'anim.dart';

/// Bottom-tab shell: keeps every tab alive and cross-fades between them.
class AppShell extends StatelessWidget {
  final StatefulNavigationShell shell;
  final List<Widget> children;
  const AppShell({super.key, required this.shell, required this.children});

  static const _tabs = [
    (Icons.space_dashboard_outlined, Icons.space_dashboard_rounded, 'Home'),
    (Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Orders'),
    (Icons.inventory_2_outlined, Icons.inventory_2_rounded, 'Inventory'),
    (Icons.grid_view_outlined, Icons.grid_view_rounded, 'More'),
  ];

  void _go(int i) {
    HapticFeedback.selectionClick();
    shell.goBranch(i, initialLocation: i == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    // Tab pages are light: force dark status-bar icons (the welcome flow uses light ones).
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: _scaffold(context, bottom),
    );
  }

  Widget _scaffold(BuildContext context, double bottom) {
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        for (var i = 0; i < children.length; i++)
          IgnorePointer(
            ignoring: i != shell.currentIndex,
            child: TickerMode(
              enabled: i == shell.currentIndex,
              child: AnimatedOpacity(
                opacity: i == shell.currentIndex ? 1 : 0,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOut,
                child: AnimatedScale(
                  scale: i == shell.currentIndex ? 1 : 0.985,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: children[i],
                ),
              ),
            ),
          ),
      ]),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(14, 0, 14, bottom > 0 ? bottom : 12),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.border),
            boxShadow: [BoxShadow(color: AppColors.ink.withValues(alpha: 0.12), blurRadius: 30, offset: const Offset(0, 12))],
          ),
          child: Row(children: [
            _item(0),
            _item(1),
            Expanded(child: Center(child: _CreateButton(onTap: () => showQuickActions(context)))),
            _item(2),
            _item(3),
          ]),
        ),
      ).animate().slideY(begin: 1, end: 0, duration: 600.ms, curve: Curves.easeOutCubic),
    );
  }

  Widget _item(int i) {
    final sel = shell.currentIndex == i;
    final t = _tabs[i];
    return Expanded(
      child: PressScale(
        onTap: () => _go(i),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(horizontal: sel ? 16 : 10, vertical: 5),
            decoration: BoxDecoration(color: sel ? AppColors.primarySoft : Colors.transparent, borderRadius: BorderRadius.circular(14)),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: Icon(sel ? t.$2 : t.$1, key: ValueKey(sel), color: sel ? AppColors.primary : AppColors.muted, size: 24),
            ),
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            style: TextStyle(fontSize: 11, fontWeight: sel ? FontWeight.w700 : FontWeight.w500, color: sel ? AppColors.primary : AppColors.muted),
            child: Text(t.$3),
          ),
        ]),
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CreateButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      scale: 0.9,
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.45), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
      ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(delay: 2.seconds, duration: 1600.ms, color: Colors.white24),
    );
  }
}

/// Animated quick-create sheet opened from the center "+" button.
Future<void> showQuickActions(BuildContext context) {
  const actions = [
    (Icons.receipt_long_rounded, 'New order', '/orders/new', Color(0xFF6431DD)),
    (Icons.inventory_2_rounded, 'Add product', '/inventory/products/new', Color(0xFF2563EB)),
    (Icons.person_add_alt_1_rounded, 'Add customer', '/customers/new', Color(0xFF059669)),
    (Icons.qr_code_scanner_rounded, 'Scan barcode', '/scan', Color(0xFFD97706)),
    (Icons.local_offer_rounded, 'New coupon', '/coupons/new', Color(0xFFDB2777)),
    (Icons.auto_awesome_rounded, 'Ask Bora', '/assistant', Color(0xFF7C3AED)),
  ];
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.ink.withValues(alpha: 0.45),
    builder: (c) => Container(
      margin: EdgeInsets.fromLTRB(12, 0, 12, MediaQuery.paddingOf(c).bottom + 12),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        const Align(alignment: Alignment.centerLeft, child: Text('Create', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
        const SizedBox(height: 16),
        GridView.count(
                  padding: EdgeInsets.zero,
          crossAxisCount: 3,
          shrinkWrap: true,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.95,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final (i, a) in actions.indexed)
              PressScale(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(c);
                  context.push(a.$3);
                },
                child: Container(
                  decoration: BoxDecoration(color: a.$4.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [a.$4, Color.lerp(a.$4, Colors.black, 0.18)!]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: a.$4.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 6))],
                      ),
                      child: Icon(a.$1, color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    Text(a.$2, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ]),
                ),
              ).animate(delay: (40 * i).ms).fadeIn(duration: 250.ms).scaleXY(begin: 0.7, end: 1, duration: 380.ms, curve: Curves.easeOutBack),
          ],
        ),
      ]),
    ).animate().slideY(begin: 0.2, end: 0, duration: 320.ms, curve: Curves.easeOutCubic),
  );
}
