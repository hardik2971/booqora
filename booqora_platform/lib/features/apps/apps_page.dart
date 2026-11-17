import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/page.dart';
import 'app_catalog.dart';

/// Installs [app] into the workspace (doc id = app id) and opens its detail page.
Future<void> installApp(BuildContext context, AppDef app) async {
  try {
    await Db.create(
      C.apps,
      {
        'appId': app.id,
        'name': app.name,
        'category': app.category,
        'status': 'needs_attention',
        'config': <String, dynamic>{},
        'installedAt': FieldValue.serverTimestamp(),
      },
      id: app.id,
      label: app.name,
    );
    if (!context.mounted) return;
    toast(context, '${app.name} installed');
    context.go('/apps/${app.id}');
  } catch (e) {
    if (context.mounted) toast(context, friendlyError(e), error: true);
  }
}

class AppsPage extends StatefulWidget {
  const AppsPage({super.key});

  @override
  State<AppsPage> createState() => _AppsPageState();
}

class _AppsPageState extends State<AppsPage> {
  int _tab = 1;
  Set<String> _cats = {};
  bool _az = false;
  String _q = '';

  List<AppDef> _filter(Iterable<AppDef> apps) {
    final q = _q.trim().toLowerCase();
    final r = apps
        .where((a) => _cats.isEmpty || _cats.contains(a.category))
        .where((a) => q.isEmpty || a.name.toLowerCase().contains(q) || a.short.toLowerCase().contains(q))
        .toList();
    if (_az) r.sort((a, b) => a.name.compareTo(b.name));
    return r;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Doc>>(
      stream: Db.watch(C.apps),
      builder: (context, snap) {
        final installed = {for (final d in snap.data ?? <Doc>[]) d.s('appId', d.id): d};
        final counts = <String, int>{};
        for (final a in appCatalog) {
          if (_tab == 0 && !installed.containsKey(a.id)) continue;
          counts[a.category] = (counts[a.category] ?? 0) + 1;
        }
        final source = _tab == 0 ? appCatalog.where((a) => installed.containsKey(a.id)) : appCatalog;
        final apps = _filter(source);
        final narrow = MediaQuery.sizeOf(context).width < 700;

        Widget body;
        if (snap.hasError) {
          body = ErrorView(snap.error!);
        } else if (!snap.hasData) {
          body = const LoadingView();
        } else if (_tab == 0 && installed.isEmpty) {
          body = EmptyState(
            icon: Icons.extension_outlined,
            title: 'No apps installed yet',
            message: 'Browse the app store to connect analytics, payments, accounting and more.',
            actionLabel: 'Browse app store',
            onAction: () => setState(() => _tab = 1),
          );
        } else if (apps.isEmpty) {
          body = const EmptyState(icon: Icons.search_off, title: 'No apps match', message: 'Try clearing the category filter or search.', compact: true);
        } else {
          body = LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth > 1050 ? 3 : (c.maxWidth > 640 ? 2 : 1);
            final w = (c.maxWidth - (cols - 1) * 16) / cols;
            return Wrap(spacing: 16, runSpacing: 16, children: [
              for (var i = 0; i < apps.length; i++)
                SizedBox(width: w, child: _AppCard(app: apps[i], installed: installed[apps[i].id]).enter(i)),
            ]);
          });
        }

        return ListLayout(
          header: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const PageHeader(title: 'Apps', subtitle: 'Extend Booqora with integrations for payments, marketing, accounting and more'),
            Padding(
              padding: EdgeInsets.fromLTRB(narrow ? 16 : 28, 0, narrow ? 16 : 28, 12),
              child: Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
                PillTabs(
                  tabs: const ['Installed', 'App store'],
                  index: _tab,
                  badges: [installed.length, appCatalog.length],
                  onChanged: (i) => setState(() => _tab = i),
                ),
                SearchField(hint: 'Search apps…', width: narrow ? 220 : 260, onChanged: (v) => setState(() => _q = v)),
              ]),
            ),
          ]),
          filters: [
            FilterSection(
              title: 'Categories',
              child: CheckFacet(
                options: appCategories,
                counts: counts,
                selected: _cats,
                labeler: (s) => s,
                onChanged: (s) => setState(() => _cats = s),
              ),
            ),
            FilterSection(
              title: 'Sort',
              child: CheckboxListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Sort A-Z', style: TextStyle(fontSize: 13)),
                value: _az,
                onChanged: (v) => setState(() => _az = v ?? false),
              ),
            ),
          ],
          body: PageBody(children: [
            body,
            const SizedBox(height: 24),
            InfoBanner(
              "Looking for something we don't have yet? Tell us which tool you'd like to connect.",
              tone: Tone.brand,
              icon: Icons.lightbulb_outline,
              actionLabel: 'Request an app',
              onAction: () => launchUrl(Uri.parse('mailto:support@booqora.app?subject=${Uri.encodeComponent('App request')}')),
            ).enter(4),
          ]),
        );
      },
    );
  }
}

class _AppCard extends StatelessWidget {
  final AppDef app;
  final Doc? installed;
  const _AppCard({required this.app, this.installed});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return HoverLift(
      onTap: () => context.go('/apps/${app.id}'),
      child: AppCard(
        padding: const EdgeInsets.all(18),
        child: SizedBox(
          height: 150,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AppIconTile(app),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(app.name, style: t.titleSmall, overflow: TextOverflow.ellipsis)),
                    if (app.beta) ...[const SizedBox(width: 6), const BetaBadge()],
                  ]),
                  const SizedBox(height: 2),
                  Text(app.category, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            Expanded(
              child: Text(app.short,
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.inkSoft, fontSize: 13, height: 1.45)),
            ),
            Row(children: [
              Text(app.pricing, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted)),
              const Spacer(),
              if (installed != null)
                StatusPill(installed!.s('status', 'needs_attention'))
              else
                TextButton.icon(
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  onPressed: () => installApp(context, app),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Install'),
                ),
            ]),
          ]),
        ),
      ),
    );
  }
}
