import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../data/session.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/mobile.dart';
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

  static const _tabs = [(0, 'Themes'), (1, 'Pages'), (2, 'Menus'), (3, 'Blog posts'), (4, 'Redirects')];

  @override
  Widget build(BuildContext context) {
    final body = switch (_tab) {
      1 => const _PagesTab(),
      2 => const _MenusTab(),
      3 => const _BlogTab(),
      4 => const _RedirectsTab(),
      _ => const _ThemesTab(),
    };
    final add = switch (_tab) {
      1 => ('Add page', _PagesTab.edit),
      2 => ('Add menu', _MenusTab.edit),
      3 => ('Add blog post', _BlogTabState.edit),
      4 => ('Add redirect', _RedirectsTab.edit),
      _ => null,
    };
    return FormScaffold(
      title: 'Website',
      bottom: add == null ? null : GradientButton(label: add.$1, icon: Icons.add_rounded, onPressed: () => add.$2(context, null)),
      children: [
        ChoiceChipsBar<int>(options: _tabs, value: _tab, onChanged: (i) => setState(() => _tab = i)),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (c, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(a), child: c),
          ),
          child: KeyedSubtree(key: ValueKey(_tab), child: body),
        ),
      ],
    );
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
    HapticFeedback.mediumImpact();
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
    return ListenableBuilder(
      listenable: Session.instance,
      builder: (context, _) {
        final current = (Session.instance.setting('store', 'theme', '') ?? '').toString();
        final industries = ['All', ...storeThemes.map((e) => e.industry)];
        final shown = storeThemes.where((t) => _industry == 'All' || t.industry == _industry).toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ChoiceChipsBar<String>(
            options: [for (final i in industries) (i, i)],
            value: _industry,
            onChanged: (v) => setState(() => _industry = v),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, c) {
            final w = (c.maxWidth - 12) / 2;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              for (var i = 0; i < shown.length; i++)
                SizedBox(
                  width: w,
                  child: _ThemeCard(
                    key: ValueKey(shown[i].id),
                    theme: shown[i],
                    active: shown[i].id == current,
                    busy: _applying == shown[i].id,
                    onApply: () => _apply(shown[i]),
                  ).pop(i),
                ),
            ]);
          }),
        ]);
      },
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final StoreTheme theme;
  final bool active;
  final bool busy;
  final VoidCallback onApply;
  const _ThemeCard({super.key, required this.theme, required this.active, required this.busy, required this.onApply});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: active || busy ? null : onApply,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: active ? AppColors.primary : AppColors.border, width: active ? 2 : 1),
          boxShadow: [
            BoxShadow(color: active ? AppColors.primary.withValues(alpha: 0.25) : const Color(0x0A1C0938), blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            height: 118,
            decoration: BoxDecoration(gradient: LinearGradient(colors: theme.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight)),
            child: Stack(children: [
              Positioned(right: -16, bottom: -16, child: Icon(theme.icon, size: 96, color: Colors.white.withValues(alpha: 0.16))),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 22, height: 5, decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(3))),
                    const Spacer(),
                    for (var i = 0; i < 3; i++)
                      Container(
                        width: 10,
                        height: 4,
                        margin: const EdgeInsets.only(left: 3),
                        decoration: BoxDecoration(color: Colors.white38, borderRadius: BorderRadius.circular(3)),
                      ),
                  ]),
                  const Spacer(),
                  Icon(theme.icon, color: Colors.white, size: 24),
                  const SizedBox(height: 5),
                  Container(width: 80, height: 7, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 4),
                  Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.white60, borderRadius: BorderRadius.circular(3))),
                ]),
              ),
              if (active)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: const Text('Active', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(theme.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(theme.industry, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                ]),
              ),
              if (active)
                const Icon(Icons.check_circle_rounded, color: AppColors.success)
              else if (busy)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              else
                const Text('Apply', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
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
  final String Function(Doc d) title;
  final String? Function(Doc d)? subtitle;
  final Widget Function(Doc d)? trailing;
  final bool Function(Doc d)? filter;
  final String Function(Doc d) label;
  const _CrudList({
    super.key,
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
  });

  Future<bool> _delete(BuildContext context, Doc d) async {
    final ok = await confirmDialog(context, title: 'Delete', message: 'Delete "${label(d)}"? This cannot be undone.', confirmLabel: 'Delete', danger: true);
    if (!ok) return false;
    try {
      await Db.remove(collection, d.id, label: label(d));
      StoreSync.mirror().catchError((_) {});
      if (context.mounted) toast(context, 'Deleted');
      return true;
    } catch (e) {
      if (context.mounted) toast(context, friendlyError(e), error: true);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Doc>>(
      stream: Db.watch(collection),
      builder: (context, snap) {
        if (snap.hasError) return ErrorView(snap.error!);
        if (!snap.hasData) {
          return Column(children: [for (var i = 0; i < 3; i++) const Padding(padding: EdgeInsets.only(bottom: 10), child: Skeleton(height: 70, radius: 18))]);
        }
        final all = snap.data!;
        final items = filter == null ? all : all.where(filter!).toList();
        if (items.isEmpty) {
          return Group(children: [
            EmptyState(icon: icon, title: emptyTitle, message: emptyMessage, compact: true, actionLabel: addLabel, onAction: () => onEdit(context, null)),
          ]);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('Tap to edit · swipe left to delete', style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ),
          for (var i = 0; i < items.length; i++)
            Padding(
              key: ValueKey(items[i].id),
              padding: const EdgeInsets.only(bottom: 10),
              child: Dismissible(
                key: ValueKey('d-${items[i].id}'),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => _delete(context, items[i]),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 22),
                  decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(18)),
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                ),
                child: MTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, size: 19, color: AppColors.primary),
                  ),
                  title: title(items[i]),
                  subtitle: subtitle?.call(items[i]),
                  trailing: trailing?.call(items[i]),
                  onTap: () => onEdit(context, items[i]),
                  onLongPress: () => _delete(context, items[i]),
                ),
              ).enter(i),
            ),
        ]);
      },
    );
  }
}

/// Generic edit bottom sheet with a form and a gradient save button.
Future<bool> _editSheet(BuildContext context,
    {required String title, required List<Widget> Function(StateSetter setState) fields, required Future<void> Function() onSave}) async {
  final formKey = GlobalKey<FormState>();
  final r = await showAppSheet<bool>(
    context,
    title: title,
    builder: (c) {
      var busy = false;
      return StatefulBuilder(builder: (c, setState) {
        return Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final f in fields(setState)) Padding(padding: const EdgeInsets.only(bottom: 14), child: f),
            const SizedBox(height: 4),
            GradientButton(
              label: 'Save',
              icon: Icons.check_rounded,
              busy: busy,
              onPressed: () async {
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
            ),
          ]),
        );
      });
    },
  );
  if (r == true) {
    StoreSync.mirror().catchError((_) {});
    HapticFeedback.mediumImpact();
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
    await _editSheet(
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
        title: (d) => d.s('title', 'Untitled'),
        subtitle: (d) => '/${d.s('slug')}',
        trailing: (d) => StatusPill(d.b('published', true) ? 'published' : 'draft', label: d.b('published', true) ? 'Published' : 'Hidden'),
      );
}

// ---------------- Menus ----------------

class _MenusTab extends StatelessWidget {
  const _MenusTab();

  static Future<void> edit(BuildContext context, Doc? d) async {
    final name = TextEditingController(text: d?.s('name'));
    final items = (d?.maps('items') ??
            [
              {'label': 'Home', 'url': '/'},
            ])
        .map((m) => (TextEditingController(text: (m['label'] ?? '').toString()), TextEditingController(text: (m['url'] ?? '').toString())))
        .toList();
    await _editSheet(
      context,
      title: d == null ? 'New menu' : 'Edit menu',
      fields: (setState) => [
        Field(label: 'Menu name', controller: name, required: true, hint: 'Main menu'),
        const FieldLabel('Menu items'),
        for (var i = 0; i < items.length; i++)
          Container(
            key: ObjectKey(items[i]),
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
            child: Row(children: [
              Expanded(
                child: Column(children: [
                  TextField(controller: items[i].$1, decoration: const InputDecoration(hintText: 'Label', isDense: true)),
                  const SizedBox(height: 8),
                  TextField(controller: items[i].$2, keyboardType: TextInputType.url, decoration: const InputDecoration(hintText: 'URL, e.g. /about', isDense: true)),
                ]),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.danger),
                onPressed: () => setState(() => items.removeAt(i)),
              ),
            ]),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => items.add((TextEditingController(), TextEditingController()))),
            icon: const Icon(Icons.add_rounded, size: 18),
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
        icon: Icons.menu_rounded,
        emptyTitle: 'No menus yet',
        emptyMessage: 'Menus control the navigation links shown in your website header and footer.',
        addLabel: 'Add menu',
        onEdit: edit,
        label: (d) => d.s('name'),
        title: (d) => d.s('name', 'Menu'),
        subtitle: (d) {
          final it = d.maps('items');
          return it.isEmpty ? 'No items' : it.map((e) => e['label']).join(' · ');
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
  String? _filter;

  static Future<void> edit(BuildContext context, Doc? d) async {
    final title = TextEditingController(text: d?.s('title'));
    final body = TextEditingController(text: d?.s('body'));
    var status = d?.s('status', 'draft') ?? 'draft';
    DateTime? publishAt = d?.d('publishAt');
    await _editSheet(
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
    final f = _filter;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ChoiceChipsBar<String?>(
        options: const [(null, 'All'), ('published', 'Published'), ('scheduled', 'Scheduled'), ('draft', 'Drafts')],
        value: _filter,
        onChanged: (v) => setState(() => _filter = v),
      ),
      const SizedBox(height: 12),
      _CrudList(
        key: ValueKey(f),
        collection: C.blogPosts,
        icon: Icons.article_outlined,
        emptyTitle: f == null ? 'No blog posts yet' : 'No ${f == 'draft' ? 'drafts' : '$f posts'}',
        emptyMessage: 'Share news, rental guides and tips to bring visitors to your store.',
        addLabel: 'Add blog post',
        onEdit: edit,
        filter: f == null ? null : (d) => d.s('status', 'draft') == f,
        label: (d) => d.s('title'),
        title: (d) => d.s('title', 'Untitled'),
        subtitle: (d) {
          final at = d.d('publishAt');
          final st = d.s('status', 'draft');
          return st == 'scheduled' && at != null
              ? 'Publishes ${Fmt.dateTime(at)}'
              : (st == 'published' && at != null ? 'Published ${Fmt.date(at)}' : 'Edited ${Fmt.relative(d.d('updatedAt') ?? d.created)}');
        },
        trailing: (d) => StatusPill(d.s('status', 'draft')),
      ),
    ]);
  }
}

// ---------------- Redirects ----------------

class _RedirectsTab extends StatelessWidget {
  const _RedirectsTab();

  static Future<void> edit(BuildContext context, Doc? d) async {
    final from = TextEditingController(text: d?.s('from'));
    final to = TextEditingController(text: d?.s('to'));
    String? path(String? v) => (v == null || v.trim().isEmpty) ? 'Is a required field' : null;
    await _editSheet(
      context,
      title: d == null ? 'New URL redirect' : 'Edit URL redirect',
      fields: (setState) => [
        Field(label: 'Redirect from', controller: from, hint: '/old-page', validator: path),
        const Center(child: Icon(Icons.arrow_downward_rounded, color: AppColors.muted)),
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
        icon: Icons.alt_route_rounded,
        emptyTitle: 'No URL redirects',
        emptyMessage: 'Redirect old links to new pages so visitors and search engines never hit a dead end.',
        addLabel: 'Add redirect',
        onEdit: edit,
        label: (d) => d.s('from'),
        title: (d) => d.s('from'),
        subtitle: (d) => '→  ${d.s('to')}',
      );
}
