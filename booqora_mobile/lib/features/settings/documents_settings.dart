import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import 'settings_kit.dart';

const _swatches = ['#6431DD', '#351DB1', '#2563EB', '#0E7490', '#16A34A', '#D97706', '#DC2626', '#DB2777', '#1C0938', '#475569'];

const _docTypes = [
  ('Invoice', Icons.receipt_long_outlined, 'INV'),
  ('Quote', Icons.request_quote_outlined, 'QUO'),
  ('Contract', Icons.handshake_outlined, 'CON'),
  ('Packing slip', Icons.inventory_outlined, 'PCK'),
];

class DocumentsSettings extends StatefulWidget {
  const DocumentsSettings({super.key});

  @override
  State<DocumentsSettings> createState() => _DocumentsSettingsState();
}

class _DocumentsSettingsState extends SettingsState<DocumentsSettings> {
  @override
  String get section => 'documents';

  Color get _accent => hexColor(text('accentColor', '#6431DD').text) ?? AppColors.primary;

  @override
  bool validate() {
    if (hexColor(text('accentColor', '#6431DD').text) == null) {
      toast(context, 'Accent colour must be a hex value like #6431DD', error: true);
      return false;
    }
    return true;
  }

  @override
  Future<void> persist() {
    final c = text('accentColor', '#6431DD').text.trim().toUpperCase();
    v['accentColor'] = c.startsWith('#') ? c : '#$c';
    return super.persist();
  }

  String _number(String prefix, int n) => val<String>('numbering', 'global') == 'prefix' ? '$prefix-${n.toString().padLeft(4, '0')}' : '#$n';

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    final hexCtl = text('accentColor', '#6431DD');
    return view(
      title: 'Documents',
      subtitle: 'Customize the look and defaults of invoices, quotes, contracts and packing slips.',
      children: [
        SGroup(
          title: 'Templates',
          description: 'Accent colour used for headings and table headers on all documents.',
          children: [
            SizedBox(
              height: 196,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _docTypes.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, i) => SizedBox(
                  width: 140,
                  child: _DocPreview(
                    title: _docTypes[i].$1,
                    icon: _docTypes[i].$2,
                    number: _number(_docTypes[i].$3, 1),
                    accent: accent,
                    showTime: val<bool>('showTime', false),
                  ).pop(i),
                ),
              ),
            ),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final s in _swatches)
                PressScale(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    hexCtl.text = s;
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: hexColor(s),
                      shape: BoxShape.circle,
                      border: Border.all(color: hexCtl.text.toUpperCase() == s ? AppColors.ink : Colors.white, width: hexCtl.text.toUpperCase() == s ? 3 : 2),
                      boxShadow: const [BoxShadow(color: Color(0x221C0938), blurRadius: 4)],
                    ),
                    child: hexCtl.text.toUpperCase() == s ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                  ),
                ),
            ]),
            Field(
              label: 'Accent colour (hex)',
              controller: hexCtl,
              hint: '#6431DD',
              prefix: Padding(
                padding: const EdgeInsets.all(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(5)),
                ),
              ),
            ),
          ],
        ),
        SGroup(
          title: 'Layout',
          children: [
            const MiniHeading('Dates on documents'),
            RadioCards<bool>(
              value: val<bool>('showTime', false),
              options: const [
                (true, 'Show date and time', 'e.g. 12-05-2026 09:00'),
                (false, 'Show date only', 'e.g. 12-05-2026'),
              ],
              onChanged: (x) => put('showTime', x),
            ),
            const MiniHeading('Page size'),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'A4', label: Text('A4'), icon: Icon(Icons.description_outlined)),
                ButtonSegment(value: 'Letter', label: Text('Letter'), icon: Icon(Icons.article_outlined)),
              ],
              selected: {val<String>('pageSize', 'A4')},
              onSelectionChanged: (s) {
                HapticFeedback.selectionClick();
                put('pageSize', s.first);
              },
            ),
          ],
        ),
        SGroup(
          title: 'Numbering',
          children: [
            RadioCards<String>(
              value: val<String>('numbering', 'global'),
              options: const [
                ('global', 'Global', 'Simple sequential numbers: #1, #2, #3…'),
                ('prefix', 'Prefix per document type', 'INV-0001, QUO-0001, CON-0001…'),
              ],
              onChanged: (x) => put('numbering', x),
            ),
          ],
        ),
        SGroup(
          title: 'Invoice due dates',
          children: [
            SwitchTile(
              value: val<bool>('dueEnabled', true),
              title: 'Set a due date on invoices',
              subtitle: 'Due date is calculated from the invoice date.',
              onChanged: (x) => put('dueEnabled', x),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: val<bool>('dueEnabled', true)
                  ? Field.number(label: 'Days until due', controller: number('dueDays', 14), decimal: false, suffixText: 'days')
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
        SGroup(
          title: 'Default text',
          description: 'Printed on new documents. You can still edit the text per document.',
          children: [
            Field(label: 'Default contract terms', controller: text('contractTerms'), maxLines: 8, hint: 'Terms and conditions of the rental agreement…'),
            Field(label: 'Invoice footer', controller: text('invoiceFooter'), maxLines: 4, hint: 'e.g. payment instructions or a thank-you note'),
          ],
        ),
      ],
    );
  }
}

class _DocPreview extends StatelessWidget {
  final String title;
  final IconData icon;
  final String number;
  final Color accent;
  final bool showTime;
  const _DocPreview({required this.title, required this.icon, required this.number, required this.accent, required this.showTime});

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, [Color c = const Color(0xFFE9E5F2)]) =>
        Container(height: 5, width: w, margin: const EdgeInsets.only(bottom: 5), decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)));
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: Color(0x0D1C0938), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 6),
          Expanded(child: Text(title, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: accent))),
        ]),
        const SizedBox(height: 2),
        Text('$number · ${showTime ? '12-05 09:00' : '12-05-2026'}', style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
        const SizedBox(height: 10),
        bar(70),
        bar(50),
        const SizedBox(height: 8),
        AnimatedContainer(duration: const Duration(milliseconds: 250), height: 12, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(3))),
        const SizedBox(height: 6),
        for (var i = 0; i < 3; i++) Row(children: [Expanded(child: bar(double.infinity)), const SizedBox(width: 10), bar(24)]),
        const Spacer(),
        Align(alignment: Alignment.centerRight, child: bar(48, accent.withValues(alpha: 0.5))),
      ]),
    );
  }
}
