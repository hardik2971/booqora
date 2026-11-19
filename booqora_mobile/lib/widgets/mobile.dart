import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/theme.dart';
import 'anim.dart';

/// Standard mobile page: collapsing large title, optional actions/search/header,
/// sliver content, and an optional floating action button.
class MPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final List<Widget> slivers;
  final Widget? header; // pinned under the app bar (search, tabs, chips)
  final double headerHeight;
  final Widget? fab;
  final bool showBack;
  final Future<void> Function()? onRefresh;
  const MPage({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    required this.slivers,
    this.header,
    this.headerHeight = 64,
    this.fab,
    this.showBack = false,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = showBack || Navigator.of(context).canPop();
    final scroll = CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverAppBar.large(
          pinned: true,
          stretch: true,
          backgroundColor: AppColors.bg,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: canPop,
          leading: canPop ? const _BackButton() : null,
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
          actions: [...actions, const SizedBox(width: 8)],
          bottom: subtitle == null
              ? null
              : PreferredSize(
                  preferredSize: const Size.fromHeight(22),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(subtitle!, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                    ),
                  ),
                ),
        ),
        if (header != null)
          SliverPersistentHeader(pinned: true, delegate: _PinnedHeader(header!, headerHeight)),
        ...slivers,
        const SliverToBoxAdapter(child: SizedBox(height: 110)),
      ],
    );
    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: fab,
      body: onRefresh == null ? scroll : RefreshIndicator(onRefresh: onRefresh!, color: AppColors.primary, child: scroll),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();
  @override
  Widget build(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () => Navigator.of(context).maybePop(),
      );
}

class _PinnedHeader extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;
  _PinnedHeader(this.child, this.height);
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(
        color: AppColors.bg,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        alignment: Alignment.center,
        child: child,
      );
  @override
  bool shouldRebuild(covariant _PinnedHeader old) => old.child != child || old.height != height;
}

/// Wraps content as a padded sliver.
class SPad extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const SPad(this.child, {super.key, this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 6)});
  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(child: Padding(padding: padding, child: child));
}

/// Rounded search box.
class MSearch extends StatelessWidget {
  final ValueChanged<String> onChanged;
  final String hint;
  final Widget? trailing;
  const MSearch({super.key, required this.onChanged, this.hint = 'Search', this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: TextField(
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.search_rounded, size: 22),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
          ),
        ),
      ),
      if (trailing != null) ...[const SizedBox(width: 10), trailing!],
    ]);
  }
}

/// Square icon button used next to search (filters, sort…), with optional badge.
class SquareIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final int badge;
  final String? tooltip;
  const SquareIconButton({super.key, required this.icon, required this.onTap, this.badge = 0, this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: PressScale(
        onTap: onTap,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
            child: Icon(icon, color: AppColors.primary),
          ),
          if (badge > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(10)),
                child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ).animate().scaleXY(begin: 0, end: 1, curve: Curves.easeOutBack),
            ),
        ]),
      ),
    );
  }
}

/// Horizontal scrolling choice chips (single select).
class ChoiceChipsBar<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final Map<T, int>? counts;
  const ChoiceChipsBar({super.key, required this.options, required this.value, required this.onChanged, this.counts});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final o = options[i];
          final sel = o.$1 == value;
          final c = counts?[o.$1];
          return PressScale(
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(o.$1);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: sel ? AppColors.brandGradient : null,
                color: sel ? null : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? Colors.transparent : AppColors.border),
                boxShadow: sel ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.28), blurRadius: 12, offset: const Offset(0, 4))] : null,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(o.$2, style: TextStyle(color: sel ? Colors.white : AppColors.inkSoft, fontWeight: FontWeight.w600, fontSize: 13)),
                if (c != null) ...[
                  const SizedBox(width: 6),
                  Text('$c', style: TextStyle(color: sel ? Colors.white70 : AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ]),
            ),
          );
        },
      ),
    );
  }
}

/// Horizontally scrolling row of compact metric cards.
class MetricScroller extends StatelessWidget {
  final List<MiniMetric> items;
  const MetricScroller({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => SizedBox(width: 168, child: items[i].enterX(i, 0.12)),
      ),
    );
  }
}

class MiniMetric extends StatelessWidget {
  final String label;
  final num value;
  final String Function(num) format;
  final IconData icon;
  final Color color;
  const MiniMetric({super.key, required this.label, required this.value, required this.format, required this.icon, this.color = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: Color(0x0D1C0938), blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w500))),
        ]),
        CountUp(value: value, format: format, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.3)),
      ]),
    );
  }
}

/// Card-style list row with tap feedback.
class MTile extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? footer;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  const MTile({super.key, this.leading, required this.title, this.subtitle, this.trailing, this.footer, this.onTap, this.onLongPress, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.5 : 1),
          boxShadow: const [BoxShadow(color: Color(0x0A1C0938), blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                ],
              ]),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ]),
          if (footer != null) ...[const SizedBox(height: 10), footer!],
        ]),
      ),
    );
  }
}

/// Sliver list of items with staggered entrance and spacing.
class SList extends StatelessWidget {
  final int count;
  final Widget Function(BuildContext, int) builder;
  const SList({super.key, required this.count, required this.builder});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.separated(
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (c, i) => builder(c, i).enter(i, 0.08),
      ),
    );
  }
}

/// Section label for grouped content.
class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Row(children: [
        Expanded(child: Text(text.toUpperCase(), style: const TextStyle(fontSize: 12, letterSpacing: 0.8, fontWeight: FontWeight.w700, color: AppColors.muted))),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

/// White rounded group container (iOS-style grouped list).
class Group extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets padding;
  const Group({super.key, required this.children, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: Color(0x0A1C0938), blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 14), children[i]],
      ]),
    );
  }
}

/// Navigation row inside a [Group] or menu.
class NavRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color color;
  final Widget? trailing;
  const NavRow({super.key, required this.icon, required this.title, this.subtitle, required this.onTap, this.color = AppColors.primary, this.trailing});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.07)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              if (subtitle != null) Text(subtitle!, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
            ]),
          ),
          trailing ?? const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ]),
      ),
    );
  }
}

/// Full-screen form page with app bar and a sticky bottom action bar.
class FormScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? bottom;
  final List<Widget> actions;
  final GlobalKey<FormState>? formKey;
  const FormScaffold({super.key, required this.title, required this.children, this.bottom, this.actions = const [], this.formKey});

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [for (var i = 0; i < children.length; i++) children[i].enter(i, 0.05)],
    );
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        leading: const _BackButton(),
        title: Text(title),
        actions: [...actions, const SizedBox(width: 6)],
      ),
      body: formKey == null ? list : Form(key: formKey, child: list),
      bottomNavigationBar: bottom == null
          ? null
          : Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
                boxShadow: [BoxShadow(color: Color(0x141C0938), blurRadius: 18, offset: Offset(0, -6))],
              ),
              child: bottom,
            ),
    );
  }
}

/// Full-width gradient primary button.
class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool busy;
  final double height;
  const GradientButton({super.key, required this.label, this.icon, this.onPressed, this.busy = false, this.height = 54});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return PressScale(
      onTap: enabled
          ? () {
              HapticFeedback.lightImpact();
              onPressed!();
            }
          : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled || busy ? 1 : 0.5,
        child: Container(
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.38), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  if (icon != null) ...[Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8)],
                  Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                ]),
        ),
      ),
    );
  }
}

/// Shows a rounded, draggable bottom sheet with a title.
Future<T?> showAppSheet<T>(BuildContext context, {required String title, required Widget Function(BuildContext) builder, bool scroll = true}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (c) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * 0.88),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(title, style: Theme.of(c).textTheme.titleLarge),
          ),
          Flexible(
            child: scroll
                ? SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), child: builder(c))
                : Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), child: builder(c)),
          ),
        ]),
      ),
    ),
  );
}
