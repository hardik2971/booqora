import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/browser.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/mobile.dart';
import 'app_catalog.dart';

/// Installs [app] into the workspace (doc id = app id). Opens its detail page when [open].
Future<bool> installApp(BuildContext context, AppDef app, {bool open = true}) async {
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
    HapticFeedback.mediumImpact();
    if (!context.mounted) return true;
    toast(context, '${app.name} installed');
    if (open) context.push('/apps/${app.id}');
    return true;
  } catch (e) {
    if (context.mounted) toast(context, friendlyError(e), error: true);
    return false;
  }
}

class AppsPage extends StatefulWidget {
  const AppsPage({super.key});

  @override
  State<AppsPage> createState() => _AppsPageState();
}

class _AppsPageState extends State<AppsPage> {
  int _tab = 1; // 0 installed, 1 app store
  String _cat = '';
  String _q = '';
  bool _az = false;

  List<AppDef> _filter(Iterable<AppDef> apps) {
    final q = _q.trim().toLowerCase();
    final r = apps
        .where((a) => _cat.isEmpty || a.category == _cat)
        .where((a) => q.isEmpty || a.name.toLowerCase().contains(q) || a.short.toLowerCase().contains(q) || a.category.toLowerCase().contains(q))
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
        final source = _tab == 0 ? appCatalog.where((a) => installed.containsKey(a.id)) : appCatalog;
        final counts = <String, int>{'': source.length};
        for (final a in source) {
          counts[a.category] = (counts[a.category] ?? 0) + 1;
        }
        final apps = _filter(source);

        final List<Widget> body;
        if (snap.hasError) {
          body = [SPad(ErrorView(snap.error!))];
        } else if (!snap.hasData) {
          body = const [SPad(LoadingView())];
        } else if (_tab == 0 && installed.isEmpty) {
          body = [
            SPad(EmptyState(
              icon: Icons.extension_outlined,
              title: 'No apps installed yet',
              message: 'Browse the app store to connect analytics, payments, accounting and more.',
              actionLabel: 'Browse app store',
              onAction: () => setState(() => _tab = 1),
            )),
          ];
        } else if (apps.isEmpty) {
          body = const [SPad(EmptyState(icon: Icons.search_off, title: 'No apps match', message: 'Try another category or search.', compact: true))];
        } else {
          body = [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 214,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _AppCard(key: ValueKey('${apps[i].id}-$_tab-$_cat'), app: apps[i], installed: installed[apps[i].id]).pop(i),
                  childCount: apps.length,
                ),
              ),
            ),
          ];
        }

        return MPage(
          title: 'Apps',
          subtitle: 'Integrations for payments, marketing, accounting and more',
          showBack: true,
          headerHeight: 108,
          actions: [
            IconButton(
              tooltip: _az ? 'Default order' : 'Sort A–Z',
              icon: Icon(_az ? Icons.sort_by_alpha_rounded : Icons.sort_rounded, color: _az ? AppColors.primary : null),
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => _az = !_az);
              },
            ),
          ],
          header: Column(mainAxisSize: MainAxisSize.min, children: [
            ChoiceChipsBar<int>(
              options: const [(0, 'Installed'), (1, 'App store')],
              value: _tab,
              counts: {0: installed.length, 1: appCatalog.length},
              onChanged: (t) => setState(() {
                _tab = t;
                _cat = '';
              }),
            ),
            const SizedBox(height: 8),
            ChoiceChipsBar<String>(
              options: [('', 'All'), for (final c in appCategories) if ((counts[c] ?? 0) > 0) (c, c)],
              value: _cat,
              counts: counts,
              onChanged: (c) => setState(() => _cat = c),
            ),
          ]),
          slivers: [
            SPad(MSearch(hint: 'Search apps', onChanged: (v) => setState(() => _q = v)), padding: const EdgeInsets.fromLTRB(16, 2, 16, 8)),
            ...body,
            SPad(
              InfoBanner(
                "Looking for something we don't have yet? Tell us which tool you'd like to connect.",
                tone: Tone.brand,
                icon: Icons.lightbulb_outline,
                actionLabel: 'Request',
                onAction: () => Browser.openUrl('mailto:support@booqora.app?subject=${Uri.encodeComponent('App request')}'),
              ).enter(4),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
            ),
          ],
        );
      },
    );
  }
}

class _AppCard extends StatefulWidget {
  final AppDef app;
  final Doc? installed;
  const _AppCard({super.key, required this.app, this.installed});

  @override
  State<_AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<_AppCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final inst = widget.installed;
    return PressScale(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/apps/${app.id}');
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: inst != null ? app.color.withValues(alpha: 0.35) : AppColors.border),
          boxShadow: [BoxShadow(color: app.color.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Hero(tag: 'app-icon-${app.id}', child: AppIconTile(app, size: 46)),
            const Spacer(),
            if (app.beta) const BetaBadge(),
          ]),
          const SizedBox(height: 10),
          Text(app.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          Text(app.category, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 6),
          Expanded(
            child: Text(app.short, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.inkSoft, fontSize: 12.5, height: 1.4)),
          ),
          if (inst != null)
            StatusPill(inst.s('status', 'needs_attention'))
          else
            SizedBox(
              height: 34,
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        await installApp(context, app);
                        if (mounted) setState(() => _busy = false);
                      },
                icon: _busy
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.add_rounded, size: 18),
                label: Text(app.pricing == 'Free' ? 'Install · Free' : 'Install'),
              ),
            ),
        ]),
      ),
    );
  }
}
