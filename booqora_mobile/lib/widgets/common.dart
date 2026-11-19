import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/format.dart';
import '../core/theme.dart';
import 'anim.dart';

/// Booqora logo. [mark] shows only the "B" icon.
class AppLogo extends StatelessWidget {
  final bool mark;
  final double height;
  final bool light;
  const AppLogo({super.key, this.mark = false, this.height = 32, this.light = false});

  @override
  Widget build(BuildContext context) {
    if (mark) return Image.asset('assets/brand/logo_mark.png', height: height, filterQuality: FilterQuality.medium);
    if (light) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Image.asset('assets/brand/logo_mark.png', height: height, filterQuality: FilterQuality.medium),
        const SizedBox(width: 8),
        Text('Booqora',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white, fontSize: height * 0.72, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
      ]);
    }
    return Image.asset('assets/brand/logo_full.png', height: height, filterQuality: FilterQuality.medium);
  }
}

/// Colour pair for a status value.
(Color, Color) statusColors(String status) {
  switch (status) {
    case 'paid':
    case 'returned':
    case 'active':
    case 'live':
    case 'configured':
    case 'installed':
    case 'ended':
    case 'published':
    case 'available':
    case 'success':
      return (AppColors.success, AppColors.successSoft);
    case 'reserved':
    case 'scheduled':
    case 'sent':
    case 'finalized':
      return (AppColors.primary, AppColors.primarySoft);
    case 'started':
    case 'out':
    case 'process_deposit':
      return (AppColors.info, AppColors.infoSoft);
    case 'partially_paid':
    case 'late':
    case 'needs_attention':
    case 'shortage':
    case 'downtime':
    case 'maintenance':
    case 'repair':
      return (AppColors.warning, AppColors.warningSoft);
    case 'payment_due':
    case 'canceled':
    case 'cancelled':
    case 'overdue':
    case 'missing':
    case 'inactive':
    case 'failed':
      return (AppColors.danger, AppColors.dangerSoft);
    case 'overpaid':
      return (const Color(0xFF0E7490), const Color(0xFFE0F5F9));
    default:
      return (AppColors.inkSoft, const Color(0xFFF0EEF5));
  }
}

class StatusPill extends StatelessWidget {
  final String status;
  final String? label;
  final bool dot;
  const StatusPill(this.status, {super.key, this.label, this.dot = true});

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = statusColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (dot) ...[
          Container(width: 6, height: 6, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
          const SizedBox(width: 6),
        ],
        Text(label ?? Fmt.label(status), style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12)),
      ]),
    );
  }
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Gradient? gradient;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.onTap, this.color, this.gradient});

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? Colors.white) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(14),
        border: gradient == null ? Border.all(color: AppColors.border) : null,
        boxShadow: const [BoxShadow(color: Color(0x0A1C0938), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: child,
    );
    if (onTap == null) return box;
    return HoverLift(onTap: onTap, child: box);
  }
}

class MetricCard extends StatelessWidget {
  final String label;
  final num value;
  final String Function(num)? format;
  final IconData icon;
  final Color color;
  final String? hint;
  final int index;
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.format,
    this.color = AppColors.primary,
    this.hint,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0.06)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(label, style: t.bodySmall?.copyWith(color: AppColors.muted, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
              if (hint != null) ...[
                const SizedBox(width: 4),
                Tooltip(message: hint!, child: const Icon(Icons.info_outline, size: 14, color: AppColors.muted)),
              ],
            ]),
            const SizedBox(height: 4),
            CountUp(
              value: value,
              format: format ?? (v) => Fmt.integer(v),
              style: t.titleLarge?.copyWith(fontSize: 22),
            ),
          ]),
        ),
      ]),
    ).enter(index);
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 24 : 56, horizontal: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: compact ? 56 : 84,
              height: compact ? 56 : 84,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFF1EAFE), Color(0xFFE3D6FD)]),
                borderRadius: BorderRadius.circular(compact ? 16 : 24),
              ),
              child: Icon(icon, size: compact ? 26 : 38, color: AppColors.primary),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(begin: 0, end: -6, duration: 1800.ms, curve: Curves.easeInOut),
            SizedBox(height: compact ? 12 : 20),
            Text(title, style: compact ? t.titleMedium : t.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, style: t.bodyMedium?.copyWith(color: AppColors.muted, height: 1.5), textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(onPressed: onAction, icon: const Icon(Icons.add, size: 18), label: Text(actionLabel!)),
            ],
          ]),
        ),
      ).enter(),
    );
  }
}

/// Two-column form section: title + description left, fields card right.
class FormSection extends StatelessWidget {
  final String title;
  final String? description;
  final List<Widget> children;
  final Widget? trailing;
  final int index;
  const FormSection({super.key, required this.title, this.description, required this.children, this.trailing, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: t.titleMedium),
      if (description != null) ...[
        const SizedBox(height: 6),
        Text(description!, style: t.bodySmall?.copyWith(color: AppColors.muted, height: 1.5)),
      ],
      if (trailing != null) ...[const SizedBox(height: 12), trailing!],
    ]);
    final card = AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          children[i],
        ],
      ]),
    );
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth > 860;
      return Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: wide
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 280, child: info),
                const SizedBox(width: 32),
                Expanded(child: card),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [info, const SizedBox(height: 12), card]),
      ).enter(index);
    });
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const SectionTitle(this.title, {super.key, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.titleMedium),
            if (subtitle != null) Text(subtitle!, style: t.bodySmall?.copyWith(color: AppColors.muted)),
          ]),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class Avatar extends StatelessWidget {
  final String name;
  final String? url;
  final double size;
  const Avatar(this.name, {super.key, this.url, this.size = 32});

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(url!, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _initials()),
      );
    }
    return _initials();
  }

  Widget _initials() => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(gradient: AppColors.brandGradient, shape: BoxShape.circle),
        child: Text(Fmt.initials(name),
            style: TextStyle(color: Colors.white, fontSize: size * 0.38, fontWeight: FontWeight.w700)),
      );
}

/// Square thumbnail with image or icon fallback.
class Thumb extends StatelessWidget {
  final String? url;
  final double size;
  final IconData icon;
  const Thumb({super.key, this.url, this.size = 40, this.icon = Icons.inventory_2_outlined});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(size * 0.22)),
      child: Icon(icon, size: size * 0.5, color: AppColors.primary),
    );
    if (url == null || url!.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.network(url!, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback),
    );
  }
}

enum Tone { info, success, warning, danger, brand }

class InfoBanner extends StatelessWidget {
  final String text;
  final Tone tone;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;
  const InfoBanner(this.text, {super.key, this.tone = Tone.info, this.actionLabel, this.onAction, this.icon});

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (tone) {
      Tone.success => (AppColors.success, AppColors.successSoft),
      Tone.warning => (AppColors.warning, AppColors.warningSoft),
      Tone.danger => (AppColors.danger, AppColors.dangerSoft),
      Tone.brand => (AppColors.primary, AppColors.primarySoft),
      Tone.info => (AppColors.info, AppColors.infoSoft),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: fg.withValues(alpha: 0.2))),
      child: Row(children: [
        Icon(icon ?? Icons.info_outline, color: fg, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: TextStyle(color: AppColors.ink, height: 1.4))),
        if (actionLabel != null) TextButton(onPressed: onAction, child: Text(actionLabel!, style: TextStyle(color: fg))),
      ]),
    );
  }
}

class KV extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;
  const KV(this.label, this.value, {super.key, this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: color ?? AppColors.ink, fontSize: bold ? 15 : 14);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Expanded(child: Text(label, style: style.copyWith(color: bold ? AppColors.ink : AppColors.inkSoft))),
        Text(value, style: style),
      ]),
    );
  }
}

class LoadingView extends StatelessWidget {
  final int rows;
  const LoadingView({super.key, this.rows = 6});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        for (var i = 0; i < rows; i++)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Skeleton(height: 36, width: 36, radius: 10),
              SizedBox(width: 14),
              Expanded(child: Skeleton(height: 14)),
              SizedBox(width: 24),
              Skeleton(height: 14, width: 80),
            ]),
          ),
      ]),
    );
  }
}

class ErrorView extends StatelessWidget {
  final Object error;
  const ErrorView(this.error, {super.key});

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Something went wrong',
        message: error.toString(),
        compact: true,
      );
}

void toast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline : Icons.check_circle_outline, color: error ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC), size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ]),
      duration: const Duration(seconds: 3),

    ));
}

Future<bool> confirmDialog(BuildContext context,
    {required String title, required String message, String confirmLabel = 'Confirm', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Text(message)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: AppColors.danger) : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return r == true;
}

/// Friendly error text for Firebase exceptions.
String friendlyError(Object e) {
  final s = e.toString();
  final m = RegExp(r'\] (.*)$').firstMatch(s);
  return m?.group(1) ?? s.replaceAll('Exception: ', '');
}
