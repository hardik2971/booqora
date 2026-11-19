import 'package:flutter/material.dart';

import '../core/browser.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/db.dart';
import '../data/schema.dart';
import 'common.dart';
import 'inputs.dart';

/// Card used in the right-hand side panel of detail pages.
class PanelCard extends StatelessWidget {
  final String title;
  final Widget child;
  final IconData? icon;
  final Widget? trailing;
  const PanelCard({super.key, required this.title, required this.child, this.icon, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            if (icon != null) ...[Icon(icon, size: 18, color: AppColors.primary), const SizedBox(width: 8)],
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 12),
          child,
        ]),
      ),
    );
  }
}

/// Tags card bound to a document's `tags` field.
class TagsCard extends StatelessWidget {
  final String collection;
  final String id;
  final List<String> tags;
  const TagsCard({super.key, required this.collection, required this.id, required this.tags});

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      title: 'Tags',
      icon: Icons.sell_outlined,
      child: TagEditor(tags: tags, onChanged: (t) => Db.update(collection, id, {'tags': t}, silent: true)),
    );
  }
}

/// Notes card (live) for an entity.
class NotesCard extends StatefulWidget {
  final String entity;
  final String entityId;
  const NotesCard({super.key, required this.entity, required this.entityId});

  @override
  State<NotesCard> createState() => _NotesCardState();
}

class _NotesCardState extends State<NotesCard> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final t = _c.text.trim();
    if (t.isEmpty) return;
    _c.clear();
    await Db.addNote(widget.entity, widget.entityId, t);
  }

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      title: 'Notes',
      icon: Icons.sticky_note_2_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          controller: _c,
          minLines: 1,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Add note',
            suffixIcon: IconButton(icon: const Icon(Icons.send_rounded, size: 18, color: AppColors.primary), onPressed: _add),
          ),
          onSubmitted: (_) => _add(),
        ),
        StreamBuilder<List<Doc>>(
          stream: Db.watchWhere(C.notes, 'entityId', widget.entityId),
          builder: (context, s) {
            final notes = s.data ?? [];
            if (notes.isEmpty) return const SizedBox.shrink();
            return Column(children: [
              for (final n in notes.take(8))
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(10)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(n.s('text'), style: const TextStyle(height: 1.4)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Text('${n.s('authorName')} · ${Fmt.relative(n.d('createdAt'))}', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                      const Spacer(),
                      InkWell(
                        onTap: () => Db.remove(C.notes, n.id),
                        child: const Icon(Icons.delete_outline, size: 14, color: AppColors.muted),
                      ),
                    ]),
                  ]),
                ),
            ]);
          },
        ),
      ]),
    );
  }
}

/// Activity timeline for an entity (or whole workspace when [entityId] is null).
class ActivityCard extends StatelessWidget {
  final String? entityId;
  final int limit;
  const ActivityCard({super.key, this.entityId, this.limit = 8});

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      title: 'Activity log',
      icon: Icons.history,
      child: StreamBuilder<List<Doc>>(
        stream: entityId == null ? Db.watch(C.activity, limit: limit) : Db.watchWhere(C.activity, 'entityId', entityId),
        builder: (context, s) {
          final items = (s.data ?? []).take(limit).toList();
          if (items.isEmpty) return const Text('No activity yet', style: TextStyle(color: AppColors.muted, fontSize: 13));
          return Column(children: [
            for (var i = 0; i < items.length; i++) ActivityTile(items[i], last: i == items.length - 1),
          ]);
        },
      ),
    );
  }
}

class ActivityTile extends StatelessWidget {
  final Doc a;
  final bool last;
  const ActivityTile(this.a, {super.key, this.last = false});

  @override
  Widget build(BuildContext context) {
    final action = a.s('action');
    final color = switch (action) {
      'created' => AppColors.success,
      'deleted' => AppColors.danger,
      _ => AppColors.primary,
    };
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Container(width: 10, height: 10, margin: const EdgeInsets.only(top: 4), decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          if (!last) Expanded(child: Container(width: 1.5, color: AppColors.border)),
        ]),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text.rich(TextSpan(children: [
                TextSpan(text: a.s('actorName'), style: const TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: ' $action ${Fmt.label(a.s('entity')).replaceAll(RegExp(r's$'), '')} '),
                TextSpan(text: a.s('label'), style: const TextStyle(fontWeight: FontWeight.w600)),
              ]), style: const TextStyle(fontSize: 13)),
              Text(Fmt.relative(a.d('createdAt')), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Detail layout: main column + right side panel (stacks on narrow screens).
class DetailLayout extends StatelessWidget {
  final Widget main;
  final List<Widget> side;
  const DetailLayout({super.key, required this.main, required this.side});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 980) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [main, const SizedBox(height: 16), ...side]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: main),
        const SizedBox(width: 24),
        SizedBox(width: 320, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: side)),
      ]);
    });
  }
}

/// Downloads rows as a CSV file in the browser.
Future<void> exportCsv(String fileName, List<String> headers, List<List<Object?>> rows) async {
  String esc(Object? v) {
    final s = v?.toString() ?? '';
    return (s.contains(',') || s.contains('"') || s.contains('\n')) ? '"${s.replaceAll('"', '""')}"' : s;
  }

  final csv = StringBuffer()..writeln(headers.map(esc).join(','));
  for (final r in rows) {
    csv.writeln(r.map(esc).join(','));
  }
  Browser.downloadText(csv.toString(), fileName.endsWith('.csv') ? fileName : '$fileName.csv', 'text/csv;charset=utf-8');
}
