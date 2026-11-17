import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import 'anim.dart';

/// Page header with breadcrumbs, title and actions.
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<(String, String?)> breadcrumbs; // (label, route)
  final List<Widget> actions;
  final Widget? titleTrailing;
  const PageHeader({super.key, required this.title, this.subtitle, this.breadcrumbs = const [], this.actions = const [], this.titleTrailing});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final narrow = MediaQuery.sizeOf(context).width < 700;
    final titleBlock = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      if (breadcrumbs.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
            for (var i = 0; i < breadcrumbs.length; i++) ...[
              InkWell(
                onTap: breadcrumbs[i].$2 == null ? null : () => context.go(breadcrumbs[i].$2!),
                child: Text(breadcrumbs[i].$1, style: t.bodySmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
              ),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.chevron_right, size: 14, color: AppColors.muted)),
            ],
          ]),
        ),
      Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(child: Text(title, style: t.headlineSmall?.copyWith(fontSize: narrow ? 22 : 26), overflow: TextOverflow.ellipsis)),
        if (titleTrailing != null) ...[const SizedBox(width: 12), titleTrailing!],
      ]),
      if (subtitle != null) ...[
        const SizedBox(height: 4),
        Text(subtitle!, style: t.bodyMedium?.copyWith(color: AppColors.muted)),
      ],
    ]);
    final acts = Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: actions);
    return Padding(
      padding: EdgeInsets.fromLTRB(narrow ? 16 : 28, narrow ? 16 : 24, narrow ? 16 : 28, 16),
      child: narrow
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [titleBlock, if (actions.isNotEmpty) ...[const SizedBox(height: 12), acts]])
          : Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Expanded(child: titleBlock), acts]),
    ).enterX(0, -0.02);
  }
}

/// Scrollable page body with max width.
class PageBody extends StatelessWidget {
  final List<Widget> children;
  final double maxWidth;
  final EdgeInsets? padding;
  const PageBody({super.key, required this.children, this.maxWidth = 1280, this.padding});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 700;
    return SingleChildScrollView(
      padding: padding ?? EdgeInsets.fromLTRB(narrow ? 16 : 28, 4, narrow ? 16 : 28, 40),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ),
    );
  }
}

/// List page: header, optional left filter panel and main content.
class ListLayout extends StatefulWidget {
  final Widget header;
  final List<Widget> filters;
  final Widget body;
  final Widget? footerFilters;
  const ListLayout({super.key, required this.header, this.filters = const [], required this.body, this.footerFilters});

  @override
  State<ListLayout> createState() => _ListLayoutState();
}

class _ListLayoutState extends State<ListLayout> {
  bool _show = true;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final wide = w >= 1180;
    final hasFilters = widget.filters.isNotEmpty;
    final panel = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
        child: Row(children: [
          const Icon(Icons.tune, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text('Filters', style: Theme.of(context).textTheme.titleSmall),
          const Spacer(),
          if (wide) IconButton(tooltip: 'Hide filters', icon: const Icon(Icons.keyboard_double_arrow_left, size: 18), onPressed: () => setState(() => _show = false)),
        ]),
      ),
      Expanded(child: ListView(padding: const EdgeInsets.only(bottom: 16), children: widget.filters)),
      if (widget.footerFilters != null)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
          child: widget.footerFilters,
        ),
    ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: widget.header),
        if (hasFilters && (!wide || !_show))
          Padding(
            padding: const EdgeInsets.only(right: 24, top: 12),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.tune, size: 18),
              label: const Text('Filters'),
              onPressed: () {
                if (wide) {
                  setState(() => _show = true);
                } else {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (_) => SizedBox(height: MediaQuery.sizeOf(context).height * 0.75, child: panel),
                  );
                }
              },
            ),
          ),
      ]),
      Expanded(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: (hasFilters && wide && _show)
                ? Container(
                    width: 260,
                    margin: const EdgeInsets.only(left: 28, bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: panel,
                  ).enterX(0, -0.05)
                : const SizedBox.shrink(),
          ),
          Expanded(child: widget.body),
        ]),
      ),
    ]);
  }
}

/// Collapsible filter group.
class FilterSection extends StatelessWidget {
  final String title;
  final Widget child;
  final bool initiallyExpanded;
  const FilterSection({super.key, required this.title, required this.child, this.initiallyExpanded = true});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        initiallyExpanded: initiallyExpanded,
        dense: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        children: [child],
      ),
    );
  }
}

/// Checkbox facet list with counts.
class CheckFacet extends StatelessWidget {
  final List<String> options;
  final Map<String, int> counts;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final String Function(String)? labeler;
  const CheckFacet({super.key, required this.options, this.counts = const {}, required this.selected, required this.onChanged, this.labeler});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (final o in options)
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            final s = {...selected};
            s.contains(o) ? s.remove(o) : s.add(o);
            onChanged(s);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              Checkbox(
                value: selected.contains(o),
                visualDensity: VisualDensity.compact,
                onChanged: (_) {
                  final s = {...selected};
                  s.contains(o) ? s.remove(o) : s.add(o);
                  onChanged(s);
                },
              ),
              Expanded(child: Text(labeler?.call(o) ?? Fmt.label(o), style: const TextStyle(fontSize: 13))),
              Text('${counts[o] ?? 0}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              const SizedBox(width: 6),
            ]),
          ),
        ),
    ]);
  }
}

/// Date range facet with presets.
class DateRangeFacet extends StatelessWidget {
  final DateTimeRange? value;
  final ValueChanged<DateTimeRange?> onChanged;
  const DateRangeFacet({super.key, required this.value, required this.onChanged});

  static DateTimeRange? preset(String key) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (key) {
      case 'today':
        return DateTimeRange(start: today, end: today.add(const Duration(days: 1)));
      case 'week':
        final s = today.subtract(Duration(days: today.weekday - 1));
        return DateTimeRange(start: s, end: s.add(const Duration(days: 7)));
      case 'month':
        return DateTimeRange(start: DateTime(now.year, now.month), end: DateTime(now.year, now.month + 1));
      case 'last_month':
        return DateTimeRange(start: DateTime(now.year, now.month - 1), end: DateTime(now.year, now.month));
      case 'year':
        return DateTimeRange(start: DateTime(now.year), end: DateTime(now.year + 1));
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    const presets = {'all': 'All time', 'today': 'Today', 'week': 'This week', 'month': 'This month', 'last_month': 'Last month', 'year': 'This year'};
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final p in presets.entries)
          ChoiceChip(
            label: Text(p.value, style: const TextStyle(fontSize: 12)),
            selected: p.key == 'all' ? value == null : (value != null && preset(p.key) == value),
            onSelected: (_) => onChanged(preset(p.key)),
            visualDensity: VisualDensity.compact,
          ),
      ]),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        icon: const Icon(Icons.date_range, size: 16),
        label: Text(value == null ? 'Custom range' : '${Fmt.date(value!.start)} – ${Fmt.date(value!.end)}', style: const TextStyle(fontSize: 12)),
        onPressed: () async {
          final r = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2035), initialDateRange: value);
          if (r != null) onChanged(DateTimeRange(start: r.start, end: r.end.add(const Duration(days: 1))));
        },
      ),
    ]);
  }
}

class SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  final String hint;
  final double width;
  const SearchField({super.key, required this.onChanged, this.hint = 'Search…', this.width = 260});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search, size: 20),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

/// Animated pill tab bar.
class PillTabs extends StatelessWidget {
  final List<String> tabs;
  final int index;
  final ValueChanged<int> onChanged;
  final List<int?>? badges;
  const PillTabs({super.key, required this.tabs, required this.index, required this.onChanged, this.badges});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: const Color(0xFFEFEBF8), borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < tabs.length; i++)
            GestureDetector(
              onTap: () => onChanged(i),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: i == index ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: i == index ? const [BoxShadow(color: Color(0x1A1C0938), blurRadius: 8, offset: Offset(0, 2))] : null,
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(tabs[i],
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: i == index ? AppColors.primary : AppColors.inkSoft,
                        )),
                    if (badges != null && i < badges!.length && badges![i] != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: i == index ? AppColors.primarySoft : Colors.white, borderRadius: BorderRadius.circular(10)),
                        child: Text('${badges![i]}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryDeep)),
                      ),
                    ],
                  ]),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Responsive grid of metric cards.
class MetricRow extends StatelessWidget {
  final List<Widget> children;
  const MetricRow({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 1000 ? children.length.clamp(1, 4) : (c.maxWidth > 560 ? 2 : 1);
      final w = (c.maxWidth - (cols - 1) * 16) / cols;
      return Wrap(spacing: 16, runSpacing: 16, children: [for (final ch in children) SizedBox(width: w, child: ch)]);
    });
  }
}
