import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../data/session.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/page.dart';
import 'store_common.dart';

class StoreTheme {
  final String id, name, industry, color;
  final List<Color> gradient;
  final IconData icon;
  const StoreTheme(this.id, this.name, this.industry, this.color, this.gradient, this.icon);
}

const storeThemes = [
  StoreTheme('bliss', 'Bliss', 'Event', '#C2417C', [Color(0xFFF472B6), Color(0xFFBE185D)], Icons.celebration_outlined),
  StoreTheme('radical', 'Radical', 'AV & Camera', '#1F2937', [Color(0xFF374151), Color(0xFF0F172A)], Icons.videocam_outlined),
  StoreTheme('daredevil', 'Daredevil', 'Bikes', '#DC2626', [Color(0xFFF97316), Color(0xFFB91C1C)], Icons.pedal_bike_outlined),
  StoreTheme('construct', 'Construct', 'Tools', '#D97706', [Color(0xFFFBBF24), Color(0xFFB45309)], Icons.construction_outlined),
  StoreTheme('explore', 'Explore', 'Outdoor', '#15803D', [Color(0xFF4ADE80), Color(0xFF166534)], Icons.terrain_outlined),
  StoreTheme('romance', 'Romance', 'Weddings', '#BE7C8F', [Color(0xFFF9C9D4), Color(0xFFB76E87)], Icons.favorite_border),
  StoreTheme('utility', 'Utility', 'Vehicles', '#2563EB', [Color(0xFF60A5FA), Color(0xFF1E3A8A)], Icons.directions_car_outlined),
  StoreTheme('moment', 'Moment', 'Photo booths', '#6431DD', [Color(0xFFA78BFA), Color(0xFF4C1D95)], Icons.photo_camera_front_outlined),
];

class WebsiteSection extends StatefulWidget {
  const WebsiteSection({super.key});

  @override
  State<WebsiteSection> createState() => _WebsiteSectionState();
}

class _WebsiteSectionState extends State<WebsiteSection> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = ['Themes', 'Pages', 'Menus', 'Blog posts', 'URL redirects'];
    final body = switch (_tab) {
      1 => const _PagesTab(),
      2 => const _MenusTab(),
      3 => const _BlogTab(),
      4 => const _RedirectsTab(),
      _ => const _ThemesTab(),
    };
    return SectionFrame(children: [
      Align(alignment: Alignment.centerLeft, child: PillTabs(tabs: tabs, index: _tab, onChanged: (i) => setState(() => _tab = i))),
      const SizedBox(height: 18),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: KeyedSubtree(key: ValueKey(_tab), child: body),
      ),
    ]);
  }
}

// ---------------- Themes ----------------

class _ThemesTab extends StatefulWidget {
  const _ThemesTab();

  @override
  State<_ThemesTab> createState() => _ThemesTabState();
}

class _ThemesTabState extends State<_ThemesTab> {
  String _industry = 'All';
  String? _applying;

  Future<void> _apply(StoreTheme t) async {
    setState(() => _applying = t.id);
    try {
      await StoreSync.save({
        'store': {'theme': t.id, 'brandColor': t.color, 'brandCustomized': true},
      });
      if (mounted) toast(context, '${t.name} theme applied');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _applying = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = (Session.instance.setting('store', 'theme', '') ?? '').toString();
    final industries = ['All', ...storeThemes.map((e) => e.industry)];
    final shown = storeThemes.where((t) => _industry == 'All' || t.industry == _industry).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final i in industries)
          ChoiceChip(label: Text(i), selected: _industry == i, onSelected: (_) => setState(() => _industry = i)),
      ]),
      const SizedBox(height: 18),
      LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth > 1000 ? 4 : (c.maxWidth > 700 ? 3 : (c.maxWidth > 420 ? 2 : 1));
        final w = (c.maxWidth - (cols - 1) * 16) / cols;
        return Wrap(spacing: 16, runSpacing: 16, children: [
          for (var i = 0; i < shown.length; i++)
            SizedBox(
              width: w,
              child: _ThemeCard(
                theme: shown[i],
                active: shown[i].id == current,
                busy: _applying == shown[i].id,
                onApply: () => _apply(shown[i]),
              ).enter(i),
            ),
        ]);
      }),
    ]);
  }
}

class _ThemeCard extends StatelessWidget {
  final StoreTheme theme;
  final bool active;
  final bool busy;
  final VoidCallback onApply;
  const _ThemeCard({required this.theme, required this.active, required this.busy, required this.onApply});

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? AppColors.primary : AppColors.border, width: active ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            height: 150,
            decoration: BoxDecoration(gradient: LinearGradient(colors: theme.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight)),
            child: Stack(children: [
              Positioned(right: -18, bottom: -18, child: Icon(theme.icon, size: 120, color: Colors.white.withValues(alpha: 0.16))),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 26, height: 6, decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(3))),
                    const Spacer(),
                    for (var i = 0; i < 3; i++)
                      Container(
                        width: 14,
                        height: 5,
                        margin: const EdgeInsets.only(left: 4),
                        decoration: BoxDecoration(color: Colors.white38, borderRadius: BorderRadius.circular(3)),
                      ),
                  ]),
                  const Spacer(),
                  Icon(theme.icon, color: Colors.white, size: 28),
                  const SizedBox(height: 6),
                  Container(width: 110, height: 9, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 5),
                  Container(width: 70, height: 6, decoration: BoxDecoration(color: Colors.white60, borderRadius: BorderRadius.circular(3))),
                ]),
              ),
              if (active)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: const Text('Active', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(theme.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(theme.industry, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ]),
              ),
              active
                  ? const Icon(Icons.check_circle, color: AppColors.success)
                  : TextButton(
                      onPressed: busy ? null : onApply,
                      child: busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Apply theme'),
                    ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ---------------- Generic CRUD list ----------------

class _CrudList extends StatelessWidget {
  final String collection;
  final IconData icon;
  final String emptyTitle;
  final String emptyMessage;
  final String addLabel;
  final Future<void> Function(BuildContext context, Doc? doc) onEdit;
  final Widget Function(Doc d) title;
  final Widget Function(Doc d)? subtitle;
  final Widget Function(Doc d)? trailing;
  final bool Function(Doc d)? filter;
  final Widget? header;
  final String Function(Doc d) label;
  const _CrudList({
    required this.collection,
    required this.icon,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.addLabel,
    required this.onEdit,
    required this.title,
    required this.label,
    this.subtitle,
    this.trailing,
    this.filter,
    this.header,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Doc>>(
      stream: Db.watch(collection),
      builder: (context, snap) {
        if (!snap.hasData) return const AppCard(padding: EdgeInsets.zero, child: LoadingView(rows: 3));
        final all = snap.data!;
        final items = filter == null ? all : all.where(filter!).toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            if (header != null) Expanded(child: header!) else const Spacer(),
            const SizedBox(width: 12),
            FilledButton.icon(onPressed: () => onEdit(context, null), icon: const Icon(Icons.add, size: 18), label: Text(addLabel)),
          ]),
          const SizedBox(height: 14),
          if (items.isEmpty)
            AppCard(
              child: EmptyState(
                icon: icon,
                title: emptyTitle,
                message: emptyMessage,
                compact: true,
                actionLabel: addLabel,
                onAction: () => onEdit(context, null),
              ),
            )
          else
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
                      child: Icon(icon, size: 18, color: AppColors.primary),
                    ),
                    title: title(items[i]),
                    subtitle: subtitle?.call(items[i]),
                    onTap: () => onEdit(context, items[i]),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (trailing != null) trailing!(items[i]),
                      IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.muted),
                        onPressed: () async {
                          final ok = await confirmDialog(context,
                              title: 'Delete', message: 'Delete "${label(items[i])}"? This cannot be undone.', confirmLabel: 'Delete', danger: true);
                          if (ok) await Db.remove(collection, items[i].id, label: label(items[i]));
                        },
                      ),
                    ]),
                  ).enter(i),
                ],
              ]),
            ),
        ]);
      },
    );
  }
}

/// Generic edit dialog shell.
Future<bool> _editDialog(BuildContext context,
    {required String title, required List<Widget> Function(StateSetter setState) fields, required Future<void> Function() onSave}) async {
  final formKey = GlobalKey<FormState>();
  final r = await showDialog<bool>(
    context: context,
    builder: (c) {
      var busy = false;
      return StatefulBuilder(builder: (c, setState) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 560,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (final f in fields(setState)) Padding(padding: const EdgeInsets.only(bottom: 14), child: f),
                ]),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: busy ? null : () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setState(() => busy = true);
                      try {
                        await onSave();
                        if (c.mounted) Navigator.pop(c, true);
                      } catch (e) {
                        setState(() => busy = false);
                        if (c.mounted) toast(c, friendlyError(e), error: true);
                      }
                    },
              child: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save'),
            ),
          ],
        );
      });
    },
  );
  if (r == true) {
    StoreSync.mirror().catchError((_) {});
    if (context.mounted) toast(context, 'Saved');
  }
  return r == true;
}

// ---------------- Pages ----------------

class _PagesTab extends StatelessWidget {
  const _PagesTab();

  static Future<void> edit(BuildContext context, Doc? d) async {
    final title = TextEditingController(text: d?.s('title'));
    final slug = TextEditingController(text: d?.s('slug'));
    final body = TextEditingController(text: d?.s('body'));
    var published = d?.b('published', true) ?? true;
    await _editDialog(
      context,
      title: d == null ? 'New page' : 'Edit page',
      fields: (setState) => [
        Field(
          label: 'Title',
          controller: title,
          required: true,
          onChanged: (v) {
            if (d == null) slug.text = Session.slugify(v);
          },
        ),
        Field(label: 'URL slug', controller: slug, prefixText: '/', required: true),
        Field(label: 'Content', controller: body, maxLines: 8),
        SwitchTile(value: published, title: 'Published', subtitle: 'Visible on your website', onChanged: (v) => setState(() => published = v)),
      ],
      onSave: () async {
        final data = {'title': title.text.trim(), 'slug': Session.slugify(slug.text), 'body': body.text, 'published': published};
        d == null ? await Db.create(C.pages, data) : await Db.update(C.pages, d.id, data, label: data['title'] as String);
      },
    );
  }

  @override
  Widget build(BuildContext context) => _CrudList(
        collection: C.pages,
        icon: Icons.description_outlined,
        emptyTitle: 'No pages yet',
        emptyMessage: 'Create pages like About us, FAQ or Rental terms for your website.',
        addLabel: 'Add page',
        onEdit: edit,
        label: (d) => d.s('title'),
        title: (d) => Text(d.s('title', 'Untitled'), style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: (d) => Text('/${d.s('slug')}', style: const TextStyle(color: AppColors.muted)),
        trailing: (d) => StatusPill(d.b('published', true) ? 'published' : 'draft', label: d.b('published', true) ? 'Published' : 'Hidden'),
      );
}

// ---------------- Menus ----------------

class _MenusTab extends StatelessWidget {
  const _MenusTab();

  static Future<void> edit(BuildContext context, Doc? d) async {
    final name = TextEditingController(text: d?.s('name'));
    final items = (d?.maps('items') ?? [
      {'label': 'Home', 'url': '/'},
    ])
        .map((m) => (TextEditingController(text: (m['label'] ?? '').toString()), TextEditingController(text: (m['url'] ?? '').toString())))
        .toList();
    await _editDialog(
      context,
      title: d == null ? 'New menu' : 'Edit menu',
      fields: (setState) => [
        Field(label: 'Menu name', controller: name, required: true, hint: 'Main menu'),
        const FieldLabel('Menu items'),
        for (var i = 0; i < items.length; i++)
          Row(children: [
            Expanded(child: TextField(controller: items[i].$1, decoration: const InputDecoration(hintText: 'Label'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: items[i].$2, decoration: const InputDecoration(hintText: 'URL, e.g. /about'))),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: AppColors.muted),
              onPressed: () => setState(() => items.removeAt(i)),
            ),
          ]),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => items.add((TextEditingController(), TextEditingController()))),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add item'),
          ),
        ),
      ],
      onSave: () async {
        final data = {
          'name': name.text.trim(),
          'items': [
            for (final it in items)
              if (it.$1.text.trim().isNotEmpty) {'label': it.$1.text.trim(), 'url': it.$2.text.trim()},
          ],
        };
        d == null ? await Db.create(C.menus, data) : await Db.update(C.menus, d.id, data);
      },
    );
  }

  @override
  Widget build(BuildContext context) => _CrudList(
        collection: C.menus,
        icon: Icons.menu,
        emptyTitle: 'No menus yet',
        emptyMessage: 'Menus control the navigation links shown in your website header and footer.',
        addLabel: 'Add menu',
        onEdit: edit,
        label: (d) => d.s('name'),
        title: (d) => Text(d.s('name', 'Menu'), style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: (d) {
          final it = d.maps('items');
          return Text(it.isEmpty ? 'No items' : it.map((e) => e['label']).join(' · '),
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted));
        },
      );
}

// ---------------- Blog ----------------

class _BlogTab extends StatefulWidget {
  const _BlogTab();

  @override
  State<_BlogTab> createState() => _BlogTabState();
}

class _BlogTabState extends State<_BlogTab> {
  int _tab = 0;
  static const _filters = [null, 'published', 'scheduled', 'draft'];

  static Future<void> edit(BuildContext context, Doc? d) async {
    final title = TextEditingController(text: d?.s('title'));
    final body = TextEditingController(text: d?.s('body'));
    var status = d?.s('status', 'draft') ?? 'draft';
    DateTime? publishAt = d?.d('publishAt');
    await _editDialog(
      context,
      title: d == null ? 'New blog post' : 'Edit blog post',
      fields: (setState) => [
        Field(label: 'Title', controller: title, required: true),
        Field(label: 'Body', controller: body, maxLines: 10),
        DropdownX<String>(
          label: 'Status',
          value: status,
          items: const {'draft': 'Draft', 'published': 'Published', 'scheduled': 'Scheduled'},
          onChanged: (v) => setState(() => status = v ?? 'draft'),
        ),
        if (status == 'scheduled')
          DateTimeField(label: 'Publish at', value: publishAt, firstDate: DateTime.now(), onChanged: (v) => setState(() => publishAt = v)),
      ],
      onSave: () async {
        final data = <String, dynamic>{
          'title': title.text.trim(),
          'body': body.text,
          'status': status,
          'publishAt': status == 'scheduled' && publishAt != null
              ? Timestamp.fromDate(publishAt!)
              : (status == 'published' ? (d?.data['publishAt'] ?? Timestamp.now()) : null),
        };
        d == null ? await Db.create(C.blogPosts, data) : await Db.update(C.blogPosts, d.id, data, label: data['title'] as String);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = _filters[_tab];
    return _CrudList(
      collection: C.blogPosts,
      icon: Icons.article_outlined,
      emptyTitle: f == null ? 'No blog posts yet' : 'No ${f == 'draft' ? 'drafts' : '$f posts'}',
      emptyMessage: 'Share news, rental guides and tips to bring visitors to your store.',
      addLabel: 'Add blog post',
      onEdit: edit,
      filter: f == null ? null : (d) => d.s('status', 'draft') == f,
      header: Align(
        alignment: Alignment.centerLeft,
        child: PillTabs(tabs: const ['All', 'Published', 'Scheduled', 'Drafts'], index: _tab, onChanged: (i) => setState(() => _tab = i)),
      ),
      label: (d) => d.s('title'),
      title: (d) => Text(d.s('title', 'Untitled'), style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: (d) {
        final at = d.d('publishAt');
        final st = d.s('status', 'draft');
        return Text(
          st == 'scheduled' && at != null ? 'Publishes ${Fmt.dateTime(at)}' : (st == 'published' && at != null ? 'Published ${Fmt.date(at)}' : 'Edited ${Fmt.relative(d.d('updatedAt') ?? d.created)}'),
          style: const TextStyle(color: AppColors.muted),
        );
      },
      trailing: (d) => StatusPill(d.s('status', 'draft')),
    );
  }
}

// ---------------- Redirects ----------------

class _RedirectsTab extends StatelessWidget {
  const _RedirectsTab();

  static Future<void> edit(BuildContext context, Doc? d) async {
    final from = TextEditingController(text: d?.s('from'));
    final to = TextEditingController(text: d?.s('to'));
    String? path(String? v) => (v == null || v.trim().isEmpty) ? 'Is a required field' : null;
    await _editDialog(
      context,
      title: d == null ? 'New URL redirect' : 'Edit URL redirect',
      fields: (setState) => [
        Field(label: 'Redirect from', controller: from, hint: '/old-page', validator: path),
        Field(label: 'Redirect to', controller: to, hint: '/new-page or https://…', validator: path),
      ],
      onSave: () async {
        var f = from.text.trim();
        if (!f.startsWith('/')) f = '/$f';
        final data = {'from': f, 'to': to.text.trim()};
        d == null ? await Db.create(C.redirects, data, label: f) : await Db.update(C.redirects, d.id, data, label: f);
      },
    );
  }

  @override
  Widget build(BuildContext context) => _CrudList(
        collection: C.redirects,
        icon: Icons.alt_route,
        emptyTitle: 'No URL redirects',
        emptyMessage: 'Redirect old links to new pages so visitors and search engines never hit a dead end.',
        addLabel: 'Add redirect',
        onEdit: edit,
        label: (d) => d.s('from'),
        title: (d) => Text.rich(TextSpan(children: [
          TextSpan(text: d.s('from'), style: const TextStyle(fontWeight: FontWeight.w600)),
          const TextSpan(text: '  →  ', style: TextStyle(color: AppColors.muted)),
          TextSpan(text: d.s('to')),
        ])),
      );
}
