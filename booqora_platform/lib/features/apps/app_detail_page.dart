import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/page.dart';
import '../../widgets/side_panel.dart';
import 'app_catalog.dart';
import 'apps_page.dart';

class AppDetailPage extends StatelessWidget {
  final String appId;
  const AppDetailPage({super.key, required this.appId});

  @override
  Widget build(BuildContext context) {
    final app = appById(appId);
    if (app == null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const PageHeader(title: 'App not found', breadcrumbs: [('Apps', '/apps')]),
        Expanded(
          child: EmptyState(
            icon: Icons.extension_off_outlined,
            title: 'This app does not exist',
            message: 'It may have been removed from the app store.',
            actionLabel: 'Back to apps',
            onAction: () => context.go('/apps'),
          ),
        ),
      ]);
    }
    return StreamBuilder<Doc?>(
      stream: Db.watchDoc(C.apps, appId),
      builder: (context, snap) {
        if (snap.hasError) return ErrorView(snap.error!);
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) return const LoadingView();
        return _AppDetail(key: ValueKey(snap.data == null), app: app, doc: snap.data);
      },
    );
  }
}

class _AppDetail extends StatefulWidget {
  final AppDef app;
  final Doc? doc;
  const _AppDetail({super.key, required this.app, required this.doc});

  @override
  State<_AppDetail> createState() => _AppDetailState();
}

class _AppDetailState extends State<_AppDetail> {
  late int _tab;
  final Map<String, TextEditingController> _c = {};
  bool _saving = false;
  bool _installing = false;

  AppDef get app => widget.app;
  bool get installed => widget.doc != null;
  bool get configured => widget.doc?.s('status') == 'configured';

  List<String> get _tabs => [if (!configured) 'Needs attention', 'Configure', 'Description', 'Manage'];

  @override
  void initState() {
    super.initState();
    final cfg = widget.doc?.m('config') ?? {};
    for (final f in app.configFields) {
      _c[f.$1] = TextEditingController(text: (cfg[f.$1] ?? '').toString());
    }
    _tab = 0;
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final cfg = {for (final e in _c.entries) e.key: e.value.text.trim()};
      final complete = cfg.values.every((v) => v.isNotEmpty);
      final wasConfigured = configured;
      await Db.update(C.apps, app.id, {'config': cfg, 'status': complete ? 'configured' : 'needs_attention'}, label: app.name);
      if (!mounted) return;
      toast(context, complete ? 'Configuration saved' : 'Saved — fill in all fields to finish setup');
      // Tab list shrinks when the app becomes configured; keep "Configure" selected.
      if (complete && !wasConfigured) setState(() => _tab = 0);
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _uninstall() async {
    final ok = await confirmDialog(context,
        title: 'Uninstall ${app.name}?',
        message: 'The configuration for this app will be removed. You can install it again at any time.',
        confirmLabel: 'Uninstall',
        danger: true);
    if (!ok || !mounted) return;
    try {
      await Db.remove(C.apps, app.id, label: app.name);
      if (!mounted) return;
      toast(context, '${app.name} uninstalled');
      context.go('/apps');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  Future<void> _install() async {
    setState(() => _installing = true);
    await installApp(context, app);
    if (mounted) setState(() => _installing = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tabs = _tabs;
    final tab = _tab.clamp(0, tabs.length - 1);
    final header = AppCard(
      child: Row(children: [
        AppIconTile(app, size: 56),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(app.name, style: t.titleLarge),
              if (app.beta) const BetaBadge(),
            ]),
            const SizedBox(height: 4),
            Text(app.short, style: const TextStyle(color: AppColors.muted, height: 1.4)),
          ]),
        ),
        if (!installed) ...[
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _installing ? null : _install,
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Install'),
          ),
        ],
      ]),
    ).enter(0);

    Widget main;
    if (!installed) {
      main = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        header,
        const SizedBox(height: 16),
        _description().enter(1),
      ]);
    } else {
      final name = tabs[tab];
      main = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        header,
        const SizedBox(height: 16),
        Align(alignment: Alignment.centerLeft, child: PillTabs(tabs: tabs, index: tab, onChanged: (i) => setState(() => _tab = i))).enter(1),
        const SizedBox(height: 16),
        KeyedSubtree(
          key: ValueKey(name),
          child: switch (name) {
            'Needs attention' => _attention(),
            'Configure' => _configure(),
            'Description' => _description(),
            _ => _manage(),
          }
              .enter(2),
        ),
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: app.name,
        breadcrumbs: const [('Apps', '/apps')],
        actions: [
          TextButton.icon(onPressed: () => context.go('/apps'), icon: const Icon(Icons.arrow_back, size: 18), label: const Text('Back to apps')),
        ],
      ),
      Expanded(
        child: PageBody(children: [
          DetailLayout(main: main, side: [_info().enterX(1)]),
        ]),
      ),
    ]);
  }

  Widget _attention() => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const InfoBanner('This app needs a few details before it can be used.', tone: Tone.warning, icon: Icons.warning_amber_rounded),
          const SizedBox(height: 16),
          for (final f in app.configFields)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Icon(
                  _c[f.$1]!.text.trim().isEmpty ? Icons.radio_button_unchecked : Icons.check_circle,
                  size: 18,
                  color: _c[f.$1]!.text.trim().isEmpty ? AppColors.muted : AppColors.success,
                ),
                const SizedBox(width: 10),
                Text(f.$2),
              ]),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(onPressed: () => setState(() => _tab = 1), child: const Text('Configure now')),
          ),
        ]),
      );

  Widget _configure() => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Configuration', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('All fields are required to finish setup. Never paste secret keys here — they belong on your server.',
              style: TextStyle(color: AppColors.muted, fontSize: 13)),
          const SizedBox(height: 16),
          FieldGrid(children: [
            for (final f in app.configFields) Field(label: f.$2, controller: _c[f.$1], required: true, onChanged: (_) => setState(() {})),
          ]),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save configuration'),
            ),
          ),
        ]),
      );

  Widget _description() => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('About ${app.name}', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Text(app.long, style: const TextStyle(color: AppColors.inkSoft, height: 1.6)),
          const SizedBox(height: 16),
          const MiniLabel('Information required'),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final f in app.configFields) Chip(label: Text(f.$2))]),
        ]),
      );

  Widget _manage() => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Uninstall app', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          const Text('Removing the app deletes its stored configuration from this workspace.', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
            onPressed: _uninstall,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Uninstall'),
          ),
        ]),
      );

  Widget _info() {
    final d = widget.doc;
    return PanelCard(
      title: 'App information',
      icon: Icons.info_outline,
      trailing: installed ? StatusPill(d!.s('status', 'needs_attention')) : const StatusPill('inactive', label: 'Not installed'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (installed)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Icon(Icons.check_circle, color: AppColors.success, size: 18),
              SizedBox(width: 8),
              Text('Installed', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.success)),
            ]),
          ),
        if (installed) KV('Installed on', Fmt.date(d!.d('installedAt') ?? d.d('createdAt'))),
        KV('Category', app.category),
        KV('Price', app.pricing),
        if (app.beta) const KV('Release', 'Beta'),
      ]),
    );
  }
}

class MiniLabel extends StatelessWidget {
  final String text;
  const MiniLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.muted));
}
