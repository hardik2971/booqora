import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../data/session.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';

/// Deep copy of Firestore-ish maps/lists so edits don't mutate session state.
dynamic deepCopy(dynamic v) {
  if (v is Map) return <String, dynamic>{for (final e in v.entries) e.key.toString(): deepCopy(e.value)};
  if (v is List) return [for (final x in v) deepCopy(x)];
  return v;
}

/// Base state for a settings section backed by `workspace.settings.<section>`.
///
/// Holds an editable copy in [v], tracks [dirty], and offers lazily-created
/// text controllers bound to keys via [text] and [number].
abstract class SettingsState<W extends StatefulWidget> extends State<W> {
  /// Key under `workspace.settings`.
  String get section;

  late Map<String, dynamic> v;
  final Map<String, TextEditingController> _ctl = {};
  final Set<String> _numeric = {};
  bool dirty = false;
  bool saving = false;
  bool _muted = false;
  int _gen = 0;

  Map<String, dynamic> load() => deepCopy(Session.instance.settings(section)) as Map<String, dynamic>;

  @override
  void initState() {
    super.initState();
    v = load();
  }

  @override
  void dispose() {
    for (final c in _ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  T val<T>(String k, T def) {
    final x = v[k];
    return x is T ? x : def;
  }

  num numVal(String k, [num def = 0]) {
    final x = v[k];
    if (x is num) return x;
    if (x is String) return num.tryParse(x) ?? def;
    return def;
  }

  List<String> strings(String k) => v[k] is List ? (v[k] as List).map((e) => e.toString()).toList() : <String>[];

  Map<String, dynamic> sub(String k) {
    if (v[k] is! Map) v[k] = <String, dynamic>{};
    return v[k] as Map<String, dynamic>;
  }

  void put(String k, dynamic x) => setState(() {
        v[k] = x;
        dirty = true;
      });

  /// Mutate state and mark dirty.
  void touch(VoidCallback f) => setState(() {
        f();
        dirty = true;
      });

  TextEditingController text(String k, [String def = '']) => _ctl.putIfAbsent(k, () {
        final c = TextEditingController(text: (v[k] ?? def).toString());
        c.addListener(() {
          if (_muted) return;
          if ((v[k] ?? def).toString() == c.text) return;
          v[k] = c.text;
          if (!dirty) {
            setState(() => dirty = true);
          } else {
            setState(() {});
          }
        });
        return c;
      });

  TextEditingController number(String k, [num def = 0]) => _ctl.putIfAbsent(k, () {
        _numeric.add(k);
        final c = TextEditingController(text: _fmtNum(v[k] is num ? v[k] as num : def));
        c.addListener(() {
          if (_muted) return;
          final n = num.tryParse(c.text.trim()) ?? 0;
          if (v[k] == n) return;
          v[k] = n;
          setState(() => dirty = true);
        });
        return c;
      });

  static String _fmtNum(num n) => n == n.roundToDouble() ? n.toInt().toString() : n.toString();

  /// Hook to validate before saving.
  bool validate() => true;

  /// Persists [v]. Override to add side effects (call super).
  Future<void> persist() => Session.instance.saveSettings(section, v);

  Future<void> save() async {
    if (!validate()) return;
    setState(() => saving = true);
    try {
      await persist();
      if (!mounted) return;
      setState(() => dirty = false);
      toast(context, 'Settings saved');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  /// Reverts unsaved edits.
  void discard() {
    _muted = true;
    v = load();
    for (final e in _ctl.entries) {
      e.value.text = _numeric.contains(e.key)
          ? _fmtNum(v[e.key] is num ? v[e.key] as num : 0)
          : (v[e.key] ?? '').toString();
    }
    _muted = false;
    onDiscard();
    _gen++;
    setState(() => dirty = false);
  }

  /// Override to reset non-controller local state.
  void onDiscard() {}

  Widget view({required String title, String? subtitle, required List<Widget> children, List<Widget> actions = const []}) =>
      SettingsView(
        title: title,
        subtitle: subtitle,
        actions: actions,
        dirty: dirty,
        saving: saving,
        onSave: save,
        onDiscard: discard,
        children: [KeyedSubtree(key: ValueKey(_gen), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children))],
      );
}

/// Scrollable settings content with header, Save button and unsaved-changes bar.
class SettingsView extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final List<Widget> actions;
  final bool dirty;
  final bool saving;
  final VoidCallback? onSave;
  final VoidCallback? onDiscard;
  const SettingsView({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.actions = const [],
    this.dirty = false,
    this.saving = false,
    this.onSave,
    this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final narrow = MediaQuery.sizeOf(context).width < 700;
    final saveBtn = onSave == null
        ? null
        : FilledButton.icon(
            onPressed: dirty && !saving ? onSave : null,
            icon: saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check, size: 18),
            label: const Text('Save'),
          );
    final header = Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: t.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: t.bodyMedium?.copyWith(color: AppColors.muted, height: 1.45)),
              ],
            ]),
          ),
          Wrap(spacing: 10, runSpacing: 10, children: [...actions, ?saveBtn]),
        ],
      ),
    ).enterX(0, 0.02);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(narrow ? 16 : 4, 4, narrow ? 16 : 28, 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [header, ...children]),
        ),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: dirty && onSave != null
            ? Container(
                padding: EdgeInsets.symmetric(horizontal: narrow ? 16 : 24, vertical: 10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.border)),
                  boxShadow: [BoxShadow(color: Color(0x101C0938), blurRadius: 16, offset: Offset(0, -4))],
                ),
                child: Row(children: [
                  const Icon(Icons.edit_note, color: AppColors.warning, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('You have unsaved changes', style: TextStyle(fontWeight: FontWeight.w600))),
                  if (onDiscard != null) TextButton(onPressed: saving ? null : onDiscard, child: const Text('Discard')),
                  const SizedBox(width: 8),
                  ?saveBtn,
                ]),
              )
            : const SizedBox(width: double.infinity),
      ),
    ]);
  }
}

/// Generic dialog with a form body and async save.
Future<bool> formDialog({
  required BuildContext context,
  required String title,
  required Widget Function(BuildContext context, StateSetter setState) body,
  required Future<void> Function() onSave,
  String saveLabel = 'Save',
  double width = 520,
}) async {
  final key = GlobalKey<FormState>();
  var busy = false;
  final r = await showDialog<bool>(
    context: context,
    builder: (dctx) => StatefulBuilder(
      builder: (dctx, setS) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: width,
          child: Form(
            key: key,
            child: SingleChildScrollView(child: body(dctx, setS)),
          ),
        ),
        actions: [
          TextButton(onPressed: busy ? null : () => Navigator.pop(dctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    if (!(key.currentState?.validate() ?? true)) return;
                    setS(() => busy = true);
                    try {
                      await onSave();
                      if (dctx.mounted) Navigator.pop(dctx, true);
                    } catch (e) {
                      setS(() => busy = false);
                      if (dctx.mounted) toast(dctx, friendlyError(e), error: true);
                    }
                  },
            child: busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(saveLabel),
          ),
        ],
      ),
    ),
  );
  return r == true;
}

/// Read-only value with a copy button.
class CopyField extends StatelessWidget {
  final String label;
  final String value;
  const CopyField({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.inkSoft)),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.only(left: 14),
        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Expanded(child: SelectableText(value, style: const TextStyle(fontFamily: 'monospace', fontSize: 13))),
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy_rounded, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              toast(context, 'Copied to clipboard');
            },
          ),
        ]),
      ),
    ]);
  }
}

/// Small rounded badge.
class Badge2 extends StatelessWidget {
  final String text;
  final Color color;
  final Color? bg;
  const Badge2(this.text, {super.key, this.color = AppColors.primary, this.bg});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg ?? color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
      );
}

/// Parses `#RRGGBB` (or `RRGGBB`) into a colour.
Color? hexColor(String s) {
  final h = s.trim().replaceAll('#', '');
  if (h.length != 6) return null;
  final n = int.tryParse(h, radix: 16);
  return n == null ? null : Color(0xFF000000 | n);
}

/// Time options in [stepMinutes] steps, as 'HH:mm'.
List<String> timeOptions([int stepMinutes = 30]) => [
      for (var m = 0; m < 24 * 60; m += stepMinutes)
        '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}',
    ];

/// Plain inline card section heading used inside FormSections.
class MiniHeading extends StatelessWidget {
  final String text;
  const MiniHeading(this.text, {super.key});

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.muted));
}

/// Non-admin guard banner.
Widget adminOnly() => const InfoBanner('Only workspace owners and admins can change these settings.', tone: Tone.warning, icon: Icons.lock_outline);
