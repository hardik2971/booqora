import 'dart:typed_data';

import 'package:flutter/material.dart' show Color;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/session.dart';
import '../orders/order_shared.dart';

/// Company details from workspace settings (Settings → General / Store).
class CompanyInfo {
  final String name, address, email, phone, logoUrl, brandColor;
  const CompanyInfo(this.name, this.address, this.email, this.phone, this.logoUrl, this.brandColor);

  factory CompanyInfo.current() {
    final g = Session.instance.settings('general');
    final s = Session.instance.settings('store');
    String v(String k) => (g[k] ?? '').toString();
    final address = [
      v('addressLine1'),
      v('addressLine2'),
      [v('zip'), v('city'), v('state')].where((e) => e.isNotEmpty).join(' '),
      v('country'),
    ].where((e) => e.trim().isNotEmpty).join('\n');
    var color = (s['brandColor'] ?? '#6431DD').toString();
    if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(color)) color = '#6431DD';
    return CompanyInfo(companyName, address, v('email'), v('phone'), v('logoUrl'), color);
  }

  Color get brand {
    final v = int.tryParse(brandColor.replaceFirst('#', ''), radix: 16);
    return v == null ? AppColors.primary : Color(0xFF000000 | v);
  }

  PdfColor get pdfBrand => PdfColor.fromHex(brandColor);
}

class _Fonts {
  final pw.Font? base, bold, script;
  const _Fonts(this.base, this.bold, this.script);
}

_Fonts? _cachedFonts;

Future<_Fonts> _loadFonts() async {
  if (_cachedFonts != null) return _cachedFonts!;
  pw.Font? base, bold, script;
  try {
    base = await PdfGoogleFonts.notoSansRegular();
    bold = await PdfGoogleFonts.notoSansBold();
  } catch (_) {}
  try {
    script = await PdfGoogleFonts.dancingScriptRegular();
  } catch (_) {}
  final f = _Fonts(base, bold, script);
  if (base != null) _cachedFonts = f;
  return f;
}

/// Builds a print-ready A4 PDF of a document (invoice, quote, contract, packing slip).
Future<Uint8List> buildDocumentPdf(Doc d, Doc? order, {PdfPageFormat format = PdfPageFormat.a4}) async {
  final c = CompanyInfo.current();
  final fonts = await _loadFonts();
  final unicode = fonts.base != null;
  final code = (Session.instance.setting('pricing', 'currency', '') ?? '').toString();
  // Without a Unicode font, fall back to the ISO currency code for symbols like ₹.
  String money(num? v) {
    final s = Fmt.money(v);
    if (unicode) return s;
    final sym = Fmt.symbol;
    return s.replaceAll(sym, code.isEmpty ? '' : '$code ').replaceAll(RegExp(r'[^\x00-\xFF]'), '').trim();
  }

  String txt(String s) => unicode ? s : s.replaceAll(RegExp(r'[^\x00-\xFF]'), '');

  pw.ImageProvider? logo;
  if (c.logoUrl.isNotEmpty) {
    try {
      logo = await networkImage(c.logoUrl);
    } catch (_) {}
  }

  final type = d.s('type', 'invoice');
  final title = DocType.title[type] ?? 'Document';
  final number = DocType.number(d);
  final packing = type == 'packing';
  final lines = d.maps('lines');
  final packed = d.l<String>('packed').toSet();
  final sig = d.m('signature');
  final signed = (sig['name'] ?? '').toString().isNotEmpty;
  final billing = order == null ? '' : addressText(order.m('billingAddress'));
  final email = order?.s('customerEmail') ?? d.s('customerEmail');
  final brand = c.pdfBrand;
  const muted = PdfColor.fromInt(0xFF7A7090);
  const ink = PdfColor.fromInt(0xFF1C0938);
  const line = PdfColor.fromInt(0xFFE6E1F0);

  pw.Widget label(String s) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Text(s.toUpperCase(), style: pw.TextStyle(fontSize: 7.5, color: muted, fontWeight: pw.FontWeight.bold, letterSpacing: 0.6)),
      );
  pw.Widget meta(String l, String v) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        label(l),
        pw.Text(txt(v), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      ]);

  final theme = fonts.base != null ? pw.ThemeData.withFont(base: fonts.base!, bold: fonts.bold ?? fonts.base!) : pw.ThemeData();

  final doc = pw.Document(title: '$title $number', author: c.name, creator: 'Booqora');
  doc.addPage(
    pw.MultiPage(
      pageFormat: format,
      theme: theme,
      margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
      header: (ctx) => ctx.pageNumber == 1
          ? pw.Container(height: 5, margin: const pw.EdgeInsets.only(bottom: 22), color: brand)
          : pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 14),
              child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text(txt(c.name), style: const pw.TextStyle(fontSize: 9, color: muted)),
                pw.Text('$title $number', style: const pw.TextStyle(fontSize: 9, color: muted)),
              ]),
            ),
      footer: (ctx) => pw.Column(children: [
        if (d.s('footer').isNotEmpty && ctx.pageNumber == ctx.pagesCount) ...[
          pw.Divider(color: line, thickness: 0.8),
          pw.Text(txt(d.s('footer')), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8.5, color: muted, lineSpacing: 2)),
          pw.SizedBox(height: 6),
        ],
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('$title $number', style: const pw.TextStyle(fontSize: 8, color: muted)),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: muted)),
        ]),
      ]),
      build: (ctx) => [
        // Company + title
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              if (logo != null) pw.Container(height: 46, margin: const pw.EdgeInsets.only(bottom: 8), child: pw.Image(logo, fit: pw.BoxFit.contain)),
              pw.Text(txt(c.name), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: ink)),
              if (c.address.isNotEmpty) pw.Text(txt(c.address), style: const pw.TextStyle(fontSize: 9, color: muted, lineSpacing: 1.5)),
              if (c.email.isNotEmpty || c.phone.isNotEmpty)
                pw.Text(txt([c.email, c.phone].where((e) => e.isNotEmpty).join('  ·  ')), style: const pw.TextStyle(fontSize: 9, color: muted)),
            ]),
          ),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text(title.toUpperCase(), style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: brand, letterSpacing: 1.2)),
            pw.SizedBox(height: 2),
            pw.Text(number, style: pw.TextStyle(fontSize: 11, color: muted, fontWeight: pw.FontWeight.bold)),
            if (d.b('finalized')) ...[
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: brand), borderRadius: pw.BorderRadius.circular(10)),
                child: pw.Text('FINALIZED', style: pw.TextStyle(fontSize: 7, color: brand, fontWeight: pw.FontWeight.bold, letterSpacing: 0.8)),
              ),
            ],
          ]),
        ]),
        pw.SizedBox(height: 24),
        // Meta
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(color: const PdfColor.fromInt(0xFFF7F5FC), borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Row(children: [
            pw.Expanded(child: meta('Date', Fmt.date(d.d('date') ?? d.created))),
            if (type == 'invoice') pw.Expanded(child: meta('Due date', Fmt.date(d.d('dueDate')))),
            pw.Expanded(child: meta('Order', d.i('orderNumber') > 0 ? '#${d.i('orderNumber')}' : '—')),
            pw.Expanded(child: meta('Reference', d.s('reference').isEmpty ? '—' : d.s('reference'))),
          ]),
        ),
        pw.SizedBox(height: 18),
        // Parties
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              label('Bill to'),
              pw.Text(txt(d.s('customerName').isEmpty ? 'No customer' : d.s('customerName')),
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              if (billing.isNotEmpty) pw.Text(txt(billing), style: const pw.TextStyle(fontSize: 9.5, lineSpacing: 1.5)),
              if (email.isNotEmpty) pw.Text(txt(email), style: const pw.TextStyle(fontSize: 9.5, color: muted)),
            ]),
          ),
          if (order != null)
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                label('Rental period'),
                pw.Text(txt('${Fmt.dateTime(order.d('startsAt'))}\n→ ${Fmt.dateTime(order.d('stopsAt'))}'),
                    style: const pw.TextStyle(fontSize: 10, lineSpacing: 2)),
              ]),
            ),
        ]),
        pw.SizedBox(height: 22),
        // Lines
        if (packing)
          pw.TableHelper.fromTextArray(
            headers: ['', 'QTY', 'ITEM'],
            data: [
              for (final l in lines) [packed.contains(l['id']) ? 'Packed' : '', '${l['qty'] ?? 1}', txt('${l['name'] ?? ''}')],
            ],
            border: null,
            headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: brand, letterSpacing: 0.6),
            headerDecoration: pw.BoxDecoration(color: PdfColor(1 - (1 - brand.red) * 0.1, 1 - (1 - brand.green) * 0.1, 1 - (1 - brand.blue) * 0.1)),
            cellStyle: const pw.TextStyle(fontSize: 10),
            rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: line, width: 0.6))),
            columnWidths: {0: const pw.FixedColumnWidth(60), 1: const pw.FixedColumnWidth(40), 2: const pw.FlexColumnWidth()},
            cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerRight, 2: pw.Alignment.centerLeft},
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          )
        else
          pw.TableHelper.fromTextArray(
            headers: ['QTY', 'ITEM', 'PRICE', 'TAX', 'TOTAL'],
            data: [
              for (final l in lines)
                [
                  '${l['qty'] ?? 1}',
                  txt('${l['name'] ?? ''}'),
                  money(l['unitPrice'] as num?),
                  ((l['taxRate'] as num?) ?? 0) > 0 ? '${l['taxRate']}%' : txt('—'),
                  money(l['total'] as num?),
                ],
            ],
            border: null,
            headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: brand, letterSpacing: 0.6),
            headerDecoration: pw.BoxDecoration(color: PdfColor(1 - (1 - brand.red) * 0.1, 1 - (1 - brand.green) * 0.1, 1 - (1 - brand.blue) * 0.1)),
            cellStyle: const pw.TextStyle(fontSize: 10),
            rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: line, width: 0.6))),
            columnWidths: {
              0: const pw.FixedColumnWidth(36),
              1: const pw.FlexColumnWidth(),
              2: const pw.FixedColumnWidth(80),
              3: const pw.FixedColumnWidth(44),
              4: const pw.FixedColumnWidth(86),
            },
            cellAlignments: {
              0: pw.Alignment.centerRight,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
            },
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          ),
        if (lines.isEmpty) pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Text('No lines', style: const pw.TextStyle(color: muted))),
        // Totals
        if (!packing) ...[
          pw.SizedBox(height: 14),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 230,
              child: pw.Column(children: [
                _kv('Subtotal', money(d.n('subtotal'))),
                if (d.n('discountTotal') > 0) _kv('Discount', '-${money(d.n('discountTotal'))}'),
                _kv('Tax', money(d.n('taxTotal'))),
                pw.Divider(color: brand, thickness: 1.2, height: 10),
                _kv('Total incl. taxes', money(d.n('total')), bold: true, size: 12),
                if (d.n('deposit') > 0) _kv('Security deposit', money(d.n('deposit')), color: muted),
                if (type == 'invoice') ...[
                  _kv('Paid', money(d.n('paid')), color: const PdfColor.fromInt(0xFF16A34A)),
                  _kv('Due', money(d.n('due')), bold: true, color: d.n('due') > 0 ? const PdfColor.fromInt(0xFFDC2626) : ink),
                ],
              ]),
            ),
          ),
        ],
        // Notes
        if (d.s('text').isNotEmpty) ...[
          pw.SizedBox(height: 22),
          label('Notes'),
          pw.Text(txt(d.s('text')), style: const pw.TextStyle(fontSize: 9.5, lineSpacing: 2)),
        ],
        // Signature
        if (type == 'quote' || type == 'contract') ...[
          pw.SizedBox(height: 28),
          pw.SizedBox(
            width: 240,
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              label('Signature'),
              pw.Container(
                height: 46,
                alignment: pw.Alignment.bottomLeft,
                decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: ink, width: 0.8))),
                child: signed
                    ? pw.Text(txt('${sig['name']}'),
                        style: pw.TextStyle(font: fonts.script, fontSize: fonts.script != null ? 26 : 16, color: brand, fontStyle: fonts.script == null ? pw.FontStyle.italic : null))
                    : pw.SizedBox(),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                txt(signed ? 'Signed by ${sig['name']} on ${Fmt.dateTime(Doc.toDate(sig['signedAt']))}' : 'Name, date and signature'),
                style: const pw.TextStyle(fontSize: 8.5, color: muted),
              ),
            ]),
          ),
        ],
      ],
    ),
  );
  return doc.save();
}

pw.Widget _kv(String k, String v, {bool bold = false, PdfColor? color, double size = 10}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(children: [
        pw.Expanded(child: pw.Text(k, style: pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : null))),
        pw.Text(v, style: pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : null, color: color)),
      ]),
    );
