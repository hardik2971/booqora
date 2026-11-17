import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'anim.dart';

class ColumnX<T> {
  final String label;
  final Widget Function(T row) cell;
  final Comparable Function(T row)? sort;
  final double? width; // fixed width; otherwise flex
  final int flex;
  final bool numeric;
  const ColumnX(this.label, this.cell, {this.sort, this.width, this.flex = 1, this.numeric = false});
}

/// Bulk action shown when rows are selected.
class BulkAction<T> {
  final String label;
  final IconData icon;
  final Future<void> Function(List<T> rows) run;
  final bool danger;
  const BulkAction(this.label, this.icon, this.run, {this.danger = false});
}

/// Sortable, selectable, paginated data table with animated rows.
class DataTableX<T> extends StatefulWidget {
  final List<ColumnX<T>> columns;
  final List<T> rows;
  final String Function(T) idOf;
  final void Function(T)? onTap;
  final List<BulkAction<T>> bulkActions;
  final Widget? empty;
  final int pageSize;
  final double minWidth;
  final String noun;
  const DataTableX({
    super.key,
    required this.columns,
    required this.rows,
    required this.idOf,
    this.onTap,
    this.bulkActions = const [],
    this.empty,
    this.pageSize = 25,
    this.minWidth = 760,
    this.noun = 'items',
  });

  @override
  State<DataTableX<T>> createState() => _DataTableXState<T>();
}

class _DataTableXState<T> extends State<DataTableX<T>> {
  int? _sortCol;
  bool _asc = true;
  int _page = 0;
  final Set<String> _sel = {};

  List<T> get _sorted {
    final r = [...widget.rows];
    if (_sortCol != null && widget.columns[_sortCol!].sort != null) {
      final f = widget.columns[_sortCol!].sort!;
      r.sort((a, b) => _asc ? f(a).compareTo(f(b)) : f(b).compareTo(f(a)));
    }
    return r;
  }

  @override
  void didUpdateWidget(covariant DataTableX<T> old) {
    super.didUpdateWidget(old);
    final ids = widget.rows.map(widget.idOf).toSet();
    _sel.removeWhere((id) => !ids.contains(id));
    final pages = (widget.rows.length / widget.pageSize).ceil();
    if (_page >= pages && pages > 0) _page = pages - 1;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty && widget.empty != null) return widget.empty!;
    final sorted = _sorted;
    final start = _page * widget.pageSize;
    final pageRows = sorted.skip(start).take(widget.pageSize).toList();
    final selectable = widget.bulkActions.isNotEmpty;
    final pages = (sorted.length / widget.pageSize).ceil();

    Widget cellBox(ColumnX<T> c, Widget child) {
      final aligned = Align(alignment: c.numeric ? Alignment.centerRight : Alignment.centerLeft, child: child);
      return c.width != null ? SizedBox(width: c.width, child: aligned) : Expanded(flex: c.flex, child: aligned);
    }

    final header = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFFAF8FE),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(children: [
        if (selectable)
          SizedBox(
            width: 40,
            child: Checkbox(
              value: pageRows.isNotEmpty && pageRows.every((r) => _sel.contains(widget.idOf(r))),
              tristate: false,
              onChanged: (v) => setState(() {
                for (final r in pageRows) {
                  v == true ? _sel.add(widget.idOf(r)) : _sel.remove(widget.idOf(r));
                }
              }),
            ),
          ),
        for (var i = 0; i < widget.columns.length; i++)
          cellBox(
            widget.columns[i],
            InkWell(
              onTap: widget.columns[i].sort == null
                  ? null
                  : () => setState(() {
                        if (_sortCol == i) {
                          _asc = !_asc;
                        } else {
                          _sortCol = i;
                          _asc = true;
                        }
                      }),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Flexible(
                  child: Text(widget.columns[i].label.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.muted)),
                ),
                if (widget.columns[i].sort != null)
                  Icon(
                    _sortCol == i ? (_asc ? Icons.arrow_upward : Icons.arrow_downward) : Icons.unfold_more,
                    size: 14,
                    color: _sortCol == i ? AppColors.primary : AppColors.muted,
                  ),
              ]),
            ),
          ),
      ]),
    );

    final rows = Column(children: [
      for (var idx = 0; idx < pageRows.length; idx++)
        _Row(
          key: ValueKey(widget.idOf(pageRows[idx])),
          onTap: widget.onTap == null ? null : () => widget.onTap!(pageRows[idx]),
          selected: _sel.contains(widget.idOf(pageRows[idx])),
          child: Row(children: [
            if (selectable)
              SizedBox(
                width: 40,
                child: Checkbox(
                  value: _sel.contains(widget.idOf(pageRows[idx])),
                  onChanged: (v) => setState(() => v == true ? _sel.add(widget.idOf(pageRows[idx])) : _sel.remove(widget.idOf(pageRows[idx]))),
                ),
              ),
            for (final c in widget.columns) cellBox(c, c.cell(pageRows[idx])),
          ]),
        ).enter(idx, 0.03),
    ]);

    final table = LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth < widget.minWidth ? widget.minWidth : c.maxWidth;
      final content = SizedBox(width: w, child: Column(children: [header, rows]));
      return c.maxWidth < widget.minWidth ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: content) : content;
    });

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _sel.isEmpty
              ? const SizedBox.shrink()
              : Container(
                  color: AppColors.primarySoft,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 8, children: [
                    Text('${_sel.length} ${widget.noun} selected', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primaryDeep)),
                    TextButton(
                      onPressed: () => setState(() => _sel.addAll(widget.rows.map(widget.idOf))),
                      child: Text('Select all ${widget.rows.length} ${widget.noun}'),
                    ),
                    for (final a in widget.bulkActions)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: a.danger ? AppColors.danger : AppColors.ink,
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        icon: Icon(a.icon, size: 16),
                        label: Text(a.label),
                        onPressed: () async {
                          final chosen = widget.rows.where((r) => _sel.contains(widget.idOf(r))).toList();
                          await a.run(chosen);
                          if (mounted) setState(_sel.clear);
                        },
                      ),
                    TextButton(onPressed: () => setState(_sel.clear), child: const Text('Clear')),
                  ]),
                ),
        ),
        table,
        if (sorted.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
            child: Row(children: [
              Text('Showing ${start + 1} - ${start + pageRows.length} of ${sorted.length}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _page > 0 ? () => setState(() => _page--) : null,
              ),
              Text('${_page + 1} / ${pages == 0 ? 1 : pages}', style: const TextStyle(fontSize: 12)),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _page < pages - 1 ? () => setState(() => _page++) : null,
              ),
            ]),
          ),
      ]),
    );
  }
}

class _Row extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool selected;
  const _Row({super.key, required this.child, this.onTap, this.selected = false});

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppColors.primarySoft.withValues(alpha: 0.6)
                : _hover
                    ? const Color(0xFFFAF8FF)
                    : Colors.white,
            border: const Border(bottom: BorderSide(color: Color(0xFFF1EEF7))),
          ),
          child: DefaultTextStyle.merge(style: const TextStyle(fontSize: 14, color: AppColors.ink), child: widget.child),
        ),
      ),
    );
  }
}

/// Two-line cell: bold title + muted subtitle.
class CellText extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  const CellText(this.title, {super.key, this.subtitle, this.leading});

  @override
  Widget build(BuildContext context) {
    final text = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
      if (subtitle != null && subtitle!.isNotEmpty)
        Text(subtitle!, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
    ]);
    if (leading == null) return text;
    return Row(children: [leading!, const SizedBox(width: 10), Flexible(child: text)]);
  }
}
