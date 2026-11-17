import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/theme.dart';
import 'common.dart';

/// Labeled text field.
class Field extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final String? hint;
  final String? helper;
  final bool required;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? maxLength;
  final Widget? prefix;
  final String? prefixText;
  final String? suffixText;
  final Widget? suffix;
  final bool enabled;
  final bool obscure;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final bool autofocus;
  final Iterable<String>? autofillHints;
  const Field({
    super.key,
    required this.label,
    this.controller,
    this.initialValue,
    this.hint,
    this.helper,
    this.required = false,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.prefix,
    this.prefixText,
    this.suffixText,
    this.suffix,
    this.enabled = true,
    this.obscure = false,
    this.onChanged,
    this.onSubmitted,
    this.inputFormatters,
    this.autofocus = false,
    this.autofillHints,
  });

  /// Numeric (decimal) variant.
  factory Field.number({
    Key? key,
    required String label,
    TextEditingController? controller,
    String? hint,
    String? helper,
    String? prefixText,
    String? suffixText,
    bool required = false,
    bool decimal = true,
    ValueChanged<String>? onChanged,
    bool enabled = true,
  }) =>
      Field(
        key: key,
        label: label,
        controller: controller,
        hint: hint,
        helper: helper,
        prefixText: prefixText,
        suffixText: suffixText,
        required: required,
        enabled: enabled,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.]' : r'[0-9]'))],
        onChanged: onChanged,
      );

  /// Money variant with the workspace currency symbol.
  factory Field.money({Key? key, required String label, TextEditingController? controller, String? helper, ValueChanged<String>? onChanged, bool enabled = true}) =>
      Field.number(key: key, label: label, controller: controller, helper: helper, prefixText: '${Fmt.symbol} ', onChanged: onChanged, enabled: enabled);

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      FieldLabel(label, required: required),
      TextFormField(
        controller: controller,
        initialValue: controller == null ? initialValue : null,
        enabled: enabled,
        obscureText: obscure,
        autofocus: autofocus,
        autofillHints: autofillHints,
        keyboardType: keyboardType,
        maxLines: obscure ? 1 : maxLines,
        maxLength: maxLength,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        onFieldSubmitted: onSubmitted,
        validator: validator ?? (required ? (v) => (v == null || v.trim().isEmpty) ? 'Is a required field' : null : null),
        decoration: InputDecoration(
          hintText: hint,
          helperText: helper,
          helperMaxLines: 3,
          prefixIcon: prefix,
          prefixText: prefixText,
          suffixText: suffixText,
          suffixIcon: suffix,
        ),
      ),
    ]);
  }
}

class FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const FieldLabel(this.text, {super.key, this.required = false});

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(TextSpan(children: [
        TextSpan(text: text),
        if (required) const TextSpan(text: ' *', style: TextStyle(color: AppColors.danger)),
      ]), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.inkSoft)),
    );
  }
}

/// Labeled dropdown.
class DropdownX<T> extends StatelessWidget {
  final String label;
  final T? value;
  final Map<T, String> items;
  final ValueChanged<T?>? onChanged;
  final String? hint;
  final String? helper;
  const DropdownX({super.key, required this.label, required this.value, required this.items, this.onChanged, this.hint, this.helper});

  @override
  Widget build(BuildContext context) {
    final v = items.containsKey(value) ? value : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      FieldLabel(label),
      DropdownButtonFormField<T>(
        initialValue: v,
        isExpanded: true,
        hint: hint != null ? Text(hint!) : null,
        decoration: InputDecoration(helperText: helper, helperMaxLines: 2),
        borderRadius: BorderRadius.circular(12),
        items: items.entries.map((e) => DropdownMenuItem<T>(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: onChanged,
      ),
    ]);
  }
}

/// Selectable option cards (radio group).
class RadioCards<T> extends StatelessWidget {
  final T value;
  final List<(T, String, String?)> options;
  final ValueChanged<T> onChanged;
  final Map<T, Widget>? expanded;
  final bool horizontal;
  const RadioCards({super.key, required this.value, required this.options, required this.onChanged, this.expanded, this.horizontal = false});

  @override
  Widget build(BuildContext context) {
    final cards = options.map((o) {
      final sel = o.$1 == value;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: sel ? AppColors.primarySoft.withValues(alpha: 0.55) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? AppColors.primary : AppColors.border, width: sel ? 1.6 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onChanged(o.$1),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(sel ? Icons.radio_button_checked : Icons.radio_button_off, size: 20, color: sel ? AppColors.primary : AppColors.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(o.$2, style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (o.$3 != null) ...[
                      const SizedBox(height: 2),
                      Text(o.$3!, style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4)),
                    ],
                  ]),
                ),
              ]),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: sel && expanded?[o.$1] != null
                    ? Padding(padding: const EdgeInsets.only(top: 14, left: 30), child: expanded![o.$1]!)
                    : const SizedBox(width: double.infinity),
              ),
            ]),
          ),
        ),
      );
    }).toList();
    if (horizontal) {
      return Wrap(spacing: 10, children: cards.map((c) => SizedBox(width: 240, child: c)).toList());
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: cards);
  }
}

class CheckTile extends StatelessWidget {
  final bool value;
  final String title;
  final String? subtitle;
  final ValueChanged<bool> onChanged;
  const CheckTile({super.key, required this.value, required this.title, this.subtitle, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(height: 24, width: 24, child: Checkbox(value: value, onChanged: (v) => onChanged(v ?? false))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(top: 2), child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
              if (subtitle != null) Text(subtitle!, style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class SwitchTile extends StatelessWidget {
  final bool value;
  final String title;
  final String? subtitle;
  final ValueChanged<bool> onChanged;
  const SwitchTile({super.key, required this.value, required this.title, this.subtitle, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (subtitle != null) Text(subtitle!, style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4)),
        ]),
      ),
      Switch(value: value, onChanged: onChanged),
    ]);
  }
}

/// Date (+ optional time) picker field.
class DateTimeField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool withTime;
  final bool clearable;
  final DateTime? firstDate;
  const DateTimeField({super.key, required this.label, required this.value, required this.onChanged, this.withTime = true, this.clearable = false, this.firstDate});

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: value ?? now,
      firstDate: firstDate ?? DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (d == null) return;
    var result = DateTime(d.year, d.month, d.day, value?.hour ?? 9, value?.minute ?? 0);
    if (withTime && context.mounted) {
      final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(result));
      if (t != null) result = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    }
    onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      FieldLabel(label),
      InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _pick(context),
        child: InputDecorator(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.event_outlined, size: 18),
            suffixIcon: clearable && value != null
                ? IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => onChanged(null))
                : null,
          ),
          child: Text(
            value == null ? 'Select date' : (withTime ? Fmt.dateTime(value) : Fmt.date(value)),
            style: TextStyle(color: value == null ? AppColors.muted : AppColors.ink),
          ),
        ),
      ),
    ]);
  }
}

class PickedFile {
  final Uint8List bytes;
  final String name;
  PickedFile(this.bytes, this.name);
}

Future<PickedFile?> pickImage() async {
  final files = await FilePicker.pickFiles(type: FileType.image);
  final f = files.firstOrNull;
  if (f == null) return null;
  final bytes = await f.readAsBytes();
  if (bytes.length > 8 * 1024 * 1024) throw Exception('Image is larger than 8 MB');
  return PickedFile(bytes, f.name);
}

/// Image upload box. Calls [onUpload] with picked bytes; shows [url] preview.
class ImageBox extends StatefulWidget {
  final String? url;
  final Future<void> Function(PickedFile file) onUpload;
  final VoidCallback? onRemove;
  final double size;
  final String label;
  const ImageBox({super.key, this.url, required this.onUpload, this.onRemove, this.size = 120, this.label = 'Upload image'});

  @override
  State<ImageBox> createState() => _ImageBoxState();
}

class _ImageBoxState extends State<ImageBox> {
  bool _busy = false;

  Future<void> _go() async {
    final f = await pickImage();
    if (f == null) return;
    setState(() => _busy = true);
    try {
      await widget.onUpload(f);
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final has = widget.url != null && widget.url!.isNotEmpty;
    return Stack(children: [
      InkWell(
        onTap: _busy ? null : _go,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.lavender, width: 1.2),
          ),
          clipBehavior: Clip.antiAlias,
          child: _busy
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : has
                  ? Image.network(widget.url!, fit: BoxFit.cover)
                  : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.cloud_upload_outlined, color: AppColors.primary),
                      const SizedBox(height: 6),
                      Text(widget.label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    ]),
        ),
      ),
      if (has && widget.onRemove != null)
        Positioned(
          right: 4,
          top: 4,
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.onRemove,
              child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close, size: 14)),
            ),
          ),
        ),
    ]);
  }
}

/// Editable chip list of tags.
class TagEditor extends StatefulWidget {
  final List<String> tags;
  final ValueChanged<List<String>> onChanged;
  const TagEditor({super.key, required this.tags, required this.onChanged});

  @override
  State<TagEditor> createState() => _TagEditorState();
}

class _TagEditorState extends State<TagEditor> {
  final _c = TextEditingController();

  void _add() {
    final v = _c.text.trim();
    if (v.isEmpty || widget.tags.contains(v)) return;
    widget.onChanged([...widget.tags, v]);
    _c.clear();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (widget.tags.isNotEmpty)
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final t in widget.tags)
            Chip(
              label: Text(t),
              visualDensity: VisualDensity.compact,
              onDeleted: () => widget.onChanged(widget.tags.where((x) => x != t).toList()),
              deleteIconColor: AppColors.primaryDeep,
            ),
        ]),
      const SizedBox(height: 8),
      TextField(
        controller: _c,
        decoration: InputDecoration(
          hintText: 'Add tag and press Enter',
          prefixIcon: const Icon(Icons.sell_outlined, size: 18),
          suffixIcon: IconButton(icon: const Icon(Icons.add, size: 18), onPressed: _add),
        ),
        onSubmitted: (_) => _add(),
      ),
    ]);
  }
}

/// Sticky footer with Cancel / Save.
class SaveBar extends StatelessWidget {
  final VoidCallback? onSave;
  final VoidCallback? onCancel;
  final bool saving;
  final String saveLabel;
  final Widget? leading;
  const SaveBar({super.key, this.onSave, this.onCancel, this.saving = false, this.saveLabel = 'Save', this.leading});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [BoxShadow(color: Color(0x101C0938), blurRadius: 16, offset: Offset(0, -4))],
      ),
      child: Row(children: [
        if (leading != null) leading!,
        const Spacer(),
        if (onCancel != null) ...[
          OutlinedButton(onPressed: saving ? null : onCancel, child: const Text('Cancel')),
          const SizedBox(width: 12),
        ],
        FilledButton(
          onPressed: saving ? null : onSave,
          child: saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(saveLabel),
        ),
      ]),
    );
  }
}

/// Responsive grid of form fields (2 columns on wide screens).
class FieldGrid extends StatelessWidget {
  final List<Widget> children;
  final int columns;
  const FieldGrid({super.key, required this.children, this.columns = 2});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth < 520 ? 1 : columns;
      final w = (c.maxWidth - (cols - 1) * 16) / cols;
      return Wrap(spacing: 16, runSpacing: 16, children: [for (final ch in children) SizedBox(width: w, child: ch)]);
    });
  }
}

num parseNum(String s, [num def = 0]) => num.tryParse(s.trim()) ?? def;
