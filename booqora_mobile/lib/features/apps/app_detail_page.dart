import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/mobile.dart';
import 'app_catalog.dart';
import 'apps_page.dart';

class AppDetailPage extends StatelessWidget {
  final String appId;
  const AppDetailPage({super.key, required this.appId});

  @override
  Widget build(BuildContext context) {
    final app = appById(appId);
    if (app == null) {
      return MPage(title: 'App not found', showBack: true, slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.extension_off_outlined,
            title: 'This app does not exist',
            message: 'It may have been removed from the app store.',
            actionLabel: 'Back to apps',
            onAction: () => context.pop(),
          ),
        ),
      ]);
    }
    return StreamBuilder<Doc?>(
      stream: Db.watchDoc(C.apps, appId),
      builder: (context, snap) {
        if (snap.hasError) return MPage(title: app.name, showBack: true, slivers: [SPad(ErrorView(snap.error!))]);
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return MPage(title: app.name, showBack: true, slivers: const [SPad(LoadingView())]);
        }
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
  final Map<String, TextEditingController> _c = {};
  bool _saving = false;
  bool _installing = false;

  AppDef get app => widget.app;
  bool get installed => widget.doc != null;
  bool get configured => widget.doc?.s('status') == 'configured';

  @override
  void initState() {
    super.initState();
    final cfg = widget.doc?.m('config') ?? {};
    for (final f in app.configFields) {
      _c[f.$1] = TextEditingController(text: (cfg[f.$1] ?? '').toString());
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _dirty {
    final cfg = widget.doc?.m('config') ?? {};
    return _c.entries.any((e) => e.value.text.trim() != (cfg[e.key] ?? '').toString());
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final cfg = {for (final e in _c.entries) e.key: e.value.text.trim()};
      final complete = cfg.values.every((v) => v.isNotEmpty);
      await Db.update(C.apps, app.id, {'config': cfg, 'status': complete ? 'configured' : 'needs_attention'}, label: app.name);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      toast(context, complete ? 'Configuration saved' : 'Saved — fill in all fields to finish setup');
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
      HapticFeedback.mediumImpact();
      toast(context, '${app.name} uninstalled');
      context.pop();
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  Future<void> _install() async {
    setState(() => _installing = true);
    await installApp(context, app, open: false);
    if (mounted) setState(() => _installing = false);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.doc;
    final hero = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(app.color, AppColors.ink, 0.35)!, Color.lerp(app.color, AppColors.ink, 0.7)!],
        ),
        boxShadow: [BoxShadow(color: app.color.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(22)),
            child: Hero(tag: 'app-icon-${app.id}', child: AppIconTile(app, size: 62)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(app.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                ),
                if (app.beta) ...[const SizedBox(width: 8), const BetaBadge()],
              ]),
              const SizedBox(height: 2),
              Text('${app.category} · ${app.pricing}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Text(app.short, style: const TextStyle(color: Colors.white, height: 1.45)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(!installed ? Icons.cloud_download_outlined : (configured ? Icons.check_circle : Icons.warning_amber_rounded),
                size: 15, color: !installed ? Colors.white : (configured ? const Color(0xFF86EFAC) : const Color(0xFFFCD34D))),
            const SizedBox(width: 6),
            Text(!installed ? 'Not installed' : (configured ? 'Installed · Configured' : 'Installed · Needs attention'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5)),
          ]),
        ),
      ]),
    );

    final missing = app.configFields.where((f) => _c[f.$1]!.text.trim().isEmpty).toList();

    return FormScaffold(
      title: app.name,
      bottom: !installed
          ? GradientButton(label: 'Install ${app.name}', icon: Icons.download_rounded, busy: _installing, onPressed: _install)
          : GradientButton(
              label: configured && !_dirty ? 'Configuration saved' : 'Save configuration',
              icon: configured && !_dirty ? Icons.cloud_done_outlined : Icons.check_rounded,
              busy: _saving,
              onPressed: _dirty || !configured ? _save : null,
            ),
      children: [
        hero,
        if (installed && !configured)
          Group(children: [
            const InfoBanner('This app needs a few details before it can be used.', tone: Tone.warning, icon: Icons.warning_amber_rounded),
            for (final f in app.configFields)
              Row(children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                  child: Icon(
                    missing.contains(f) ? Icons.radio_button_unchecked : Icons.check_circle,
                    key: ValueKey(missing.contains(f)),
                    size: 20,
                    color: missing.contains(f) ? AppColors.muted : AppColors.success,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(f.$2, style: const TextStyle(fontWeight: FontWeight.w500))),
              ]),
          ]),
        if (installed) ...[
          const SectionLabel('Configure'),
          Group(children: [
            const Text('All fields are required to finish setup. Never paste secret keys here — they belong on the server.',
                style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.4)),
            for (final f in app.configFields) Field(label: f.$2, controller: _c[f.$1], required: true, onChanged: (_) => setState(() {})),
          ]),
        ],
        SectionLabel('About ${app.name}'),
        Group(children: [
          Text(app.long, style: const TextStyle(color: AppColors.inkSoft, height: 1.6)),
          const Text('INFORMATION REQUIRED', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.muted)),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final f in app.configFields)
              Chip(label: Text(f.$2), avatar: Icon(Icons.key_rounded, size: 16, color: app.color), visualDensity: VisualDensity.compact),
          ]),
        ]),
        const SectionLabel('App information'),
        Group(children: [
          Column(children: [
            KV('Status', !installed ? 'Not installed' : Fmt.label(d!.s('status', 'needs_attention'))),
            if (installed) KV('Installed on', Fmt.date(d!.d('installedAt') ?? d.d('createdAt'))),
            KV('Category', app.category),
            KV('Price', app.pricing),
            if (app.beta) const KV('Release', 'Beta'),
          ]),
        ]),
        if (installed) ...[
          const SectionLabel('Manage'),
          Group(children: [
            const Text('Removing the app deletes its stored configuration from this workspace.', style: TextStyle(color: AppColors.muted)),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger), minimumSize: const Size.fromHeight(46)),
              onPressed: _uninstall,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Uninstall'),
            ),
          ]),
        ],
      ],
    );
  }
}
