import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../data/session.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/mobile.dart';

/// Deep copy of Firestore-ish maps/lists so edits don't mutate session state.
dynamic deepCopy(dynamic v) {
  if (v is Map) return <String, dynamic>{for (final e in v.entries) e.key.toString(): deepCopy(e.value)};
  if (v is List) return [for (final x in v) deepCopy(x)];
  return v;
}

/// Base state for a settings section backed by `workspace.settings.<section>`.
///
/// Holds an editable copy in [v], tracks [dirty], and offers lazily-created
/// text controllers bound to keys via [text] and [number]. [view] renders a
/// full-screen mobile form with a sticky Save bar and an unsaved-changes guard.
abstract class SettingsState<W extends StatefulWidget> extends State<W> {
  /// Key under `workspace.settings`.
  String get section;

  late Map<String, dynamic> v;
  final Map<String, TextEditingController> _ctl = {};
  final Set<String> _numeric = {};
  bool dirty = false;
  bool saving = false;
  bool _muted = false;
  int gen = 0;

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
          setState(() => dirty = true);
        });
        return c;
      });

  TextEditingController number(String k, [num def = 0]) => _ctl.putIfAbsent(k, () {
        _numeric.add(k);
        final c = TextEditingController(text: fmtNum(v[k] is num ? v[k] as num : def));
        c.addListener(() {
          if (_muted) return;
          final n = num.tryParse(c.text.trim()) ?? 0;
          if (v[k] == n) return;
          v[k] = n;
          setState(() => dirty = true);
        });
        return c;
      });

  /// Hook to validate before saving.
  bool validate() => true;

  /// Persists [v]. Override to add side effects (call super).
  Future<void> persist() => Session.instance.saveSettings(section, v);

  Future<void> save() async {
    FocusScope.of(context).unfocus();
    if (!validate()) {
      HapticFeedback.heavyImpact();
      return;
    }
    setState(() => saving = true);
    try {
      await persist();
      if (!mounted) return;
      HapticFeedback.mediumImpact();
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
      e.value.text = _numeric.contains(e.key) ? fmtNum(v[e.key] is num ? v[e.key] as num : 0) : (v[e.key] ?? '').toString();
    }
    _muted = false;
    onDiscard();
    gen++;
    setState(() => dirty = false);
  }

  /// Override to reset non-controller local state.
  void onDiscard() {}

  Future<void> _onPop() async {
    final ok = await confirmDialog(context,
        title: 'Discard changes?', message: 'You have unsaved changes on this page.', confirmLabel: 'Discard', danger: true);
    if (!ok || !mounted) return;
    discard();
    Navigator.of(context).pop();
  }

  Widget view({required String title, String? subtitle, required List<Widget> children, List<Widget> actions = const []}) {
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onPop();
      },
      child: FormScaffold(
        title: title,
        actions: actions,
        bottom: SaveBarM(dirty: dirty, saving: saving, onSave: save, onDiscard: discard),
        children: [
          if (subtitle != null) PageIntro(subtitle),
          for (var i = 0; i < children.length; i++) KeyedSubtree(key: ValueKey('$gen-$i'), child: children[i]),
        ],
      ),
    );
  }
}

String fmtNum(num n) => n == n.roundToDouble() ? n.toInt().toString() : n.toString();

/// Sticky save bar for settings pages.
class SaveBarM extends StatelessWidget {
  final bool dirty;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback? onDiscard;
  final String label;
  const SaveBarM({super.key, required this.dirty, required this.saving, required this.onSave, this.onDiscard, this.label = 'Save changes'});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: dirty && onDiscard != null && !saving
            ? Padding(
                padding: const EdgeInsets.only(right: 10),
                child: TextButton(onPressed: onDiscard, child: const Text('Discard')),
              )
            : const SizedBox.shrink(),
      ),
      Expanded(
        child: GradientButton(
          label: dirty || saving ? label : 'All changes saved',
          icon: dirty || saving ? Icons.check_rounded : Icons.cloud_done_outlined,
          busy: saving,
          height: 50,
          onPressed: dirty ? onSave : null,
        ),
      ),
    ]);
  }
}

/// Muted intro text at the top of a settings page.
class PageIntro extends StatelessWidget {
  final String text;
  const PageIntro(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
        child: Text(text, style: const TextStyle(color: AppColors.muted, fontSize: 13.5, height: 1.45)),
      );
}

/// Section label + optional description + white grouped card.
class SGroup extends StatelessWidget {
  final String title;
  final String? description;
  final List<Widget> children;
  final Widget? trailing;
  final EdgeInsets padding;
  const SGroup({super.key, required this.title, this.description, required this.children, this.trailing, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionLabel(title, trailing: trailing),
        if (description != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Text(description!, style: const TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.4)),
          ),
        Group(padding: padding, children: children),
      ]),
    );
  }
}

/// Coloured rounded icon square.
class IconBubble extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final bool solid;
  const IconBubble(this.icon, {super.key, this.color = AppColors.primary, this.size = 40, this.solid = false});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: solid
              ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color, Color.lerp(color, Colors.black, 0.22)!])
              : LinearGradient(colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.07)]),
          borderRadius: BorderRadius.circular(size * 0.3),
          boxShadow: solid ? [BoxShadow(color: color.withValues(alpha: 0.28), blurRadius: 10, offset: const Offset(0, 4))] : null,
        ),
        child: Icon(icon, color: solid ? Colors.white : color, size: size * 0.52),
      );
}

/// Compact list row used inside [Group]s (icon, title, subtitle, trailing).
class ListRow extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const ListRow({super.key, this.leading, required this.title, this.subtitle, this.trailing, this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      onLongPress: onLongPress == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              onLongPress!();
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
            ]),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ]),
      ),
    );
  }
}

/// Bottom-sheet form with validation and async save. Returns true when saved.
Future<bool> sheetForm({
  required BuildContext context,
  required String title,
  required Widget Function(BuildContext context, StateSetter setState) body,
  required Future<void> Function() onSave,
  String saveLabel = 'Save',
  IconData saveIcon = Icons.check_rounded,
}) async {
  final r = await showAppSheet<bool>(
    context,
    title: title,
    builder: (c) => _SheetForm(body: body, onSave: onSave, saveLabel: saveLabel, saveIcon: saveIcon),
  );
  return r == true;
}

class _SheetForm extends StatefulWidget {
  final Widget Function(BuildContext context, StateSetter setState) body;
  final Future<void> Function() onSave;
  final String saveLabel;
  final IconData saveIcon;
  const _SheetForm({required this.body, required this.onSave, required this.saveLabel, required this.saveIcon});

  @override
  State<_SheetForm> createState() => _SheetFormState();
}

class _SheetFormState extends State<_SheetForm> {
  final _key = GlobalKey<FormState>();
  bool _busy = false;

  Future<void> _save() async {
    if (!(_key.currentState?.validate() ?? true)) {
      HapticFeedback.heavyImpact();
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.onSave();
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        toast(context, friendlyError(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _key,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        StatefulBuilder(builder: (c, setS) => widget.body(c, setS)),
        const SizedBox(height: 20),
        GradientButton(label: widget.saveLabel, icon: widget.saveIcon, busy: _busy, onPressed: _save),
      ]),
    );
  }
}

/// Action sheet with a list of options; returns the chosen value.
Future<T?> showActionSheet<T>(BuildContext context, {required String title, required List<(T, IconData, String, bool)> actions}) {
  return showAppSheet<T>(
    context,
    title: title,
    builder: (c) => Column(mainAxisSize: MainAxisSize.min, children: [
      for (final a in actions)
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: Icon(a.$2, color: a.$4 ? AppColors.danger : AppColors.primary),
          title: Text(a.$3, style: TextStyle(fontWeight: FontWeight.w600, color: a.$4 ? AppColors.danger : AppColors.ink)),
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.pop(c, a.$1);
          },
        ),
    ]),
  );
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
        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Expanded(child: Text(value, style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5))),
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy_rounded, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              HapticFeedback.lightImpact();
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
      for (var m = 0; m < 24 * 60; m += stepMinutes) '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}',
    ];

class MiniHeading extends StatelessWidget {
  final String text;
  const MiniHeading(this.text, {super.key});

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.muted));
}

/// Light preview / note box.
class SoftBox extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const SoftBox({super.key, required this.child, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: child,
      );
}

/// Dashed-style "add" button used at the end of lists.
class AddRowButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const AddRowButton({super.key, required this.label, required this.onTap, this.icon = Icons.add_rounded});

  @override
  Widget build(BuildContext context) => PressScale(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primarySoft.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.lavender.withValues(alpha: 0.7)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}

/// Non-admin guard banner.
Widget adminOnly() => const InfoBanner('Only workspace owners and admins can change these settings.', tone: Tone.warning, icon: Icons.lock_outline);
