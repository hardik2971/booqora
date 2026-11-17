import '../../core/format.dart';
import '../../data/db.dart';
import '../../data/session.dart';
import '../orders/order_dialogs.dart' show addressText;
import '../orders/order_shared.dart';

String _e(Object? v) => (v ?? '')
    .toString()
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll('\n', '<br>');

/// Company details from workspace settings.
class CompanyInfo {
  final String name, address, email, phone, logoUrl, brandColor;
  const CompanyInfo(this.name, this.address, this.email, this.phone, this.logoUrl, this.brandColor);

  factory CompanyInfo.current() {
    final g = Session.instance.settings('general');
    final s = Session.instance.settings('store');
    String v(String k) => (g[k] ?? '').toString();
    // Keys written by Settings → General.
    final address = [
      v('addressLine1'),
      v('addressLine2'),
      [v('zip'), v('city'), v('state')].where((e) => e.isNotEmpty).join(' '),
      v('country'),
      v('extraLine1'),
      v('extraLine2'),
    ]
        .where((e) => e.trim().isNotEmpty)
        .join('\n');
    var color = (s['brandColor'] ?? '#6431DD').toString();
    if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(color)) color = '#6431DD';
    return CompanyInfo(companyName, address, v('email'), v('phone'), v('logoUrl'), color);
  }
}

/// Builds a standalone, print-ready HTML version of a document.
String buildDocumentHtml(Doc d, Doc? order) {
  final c = CompanyInfo.current();
  final type = d.s('type', 'invoice');
  final title = DocType.title[type] ?? 'Document';
  final number = DocType.number(d);
  final packing = type == 'packing';
  final lines = d.maps('lines');
  final packed = d.l<String>('packed').toSet();
  final sig = d.m('signature');
  final billing = order == null ? '' : addressText(order.m('billingAddress'));

  final rows = StringBuffer();
  for (final l in lines) {
    final qty = (l['qty'] as num?) ?? 1;
    if (packing) {
      rows.write('<tr><td class="chk">${packed.contains(l['id']) ? '&#9745;' : '&#9744;'}</td>'
          '<td class="num">${_e(qty)}</td><td>${_e(l['name'])}</td></tr>');
    } else {
      rows.write('<tr><td class="num">${_e(qty)}</td><td>${_e(l['name'])}</td>'
          '<td class="num">${_e(Fmt.money(l['unitPrice'] as num?))}</td>'
          '<td class="num">${_e(((l['taxRate'] as num?) ?? 0) > 0 ? '${l['taxRate']}%' : '—')}</td>'
          '<td class="num">${_e(Fmt.money(l['total'] as num?))}</td></tr>');
    }
  }

  String tr(String k, String v, {bool bold = false}) =>
      '<tr class="${bold ? 'grand' : ''}"><td>${_e(k)}</td><td class="num">${_e(v)}</td></tr>';
  final totals = packing
      ? ''
      : '<table class="totals">'
          '${tr('Subtotal', Fmt.money(d.n('subtotal')))}'
          '${d.n('discountTotal') > 0 ? tr('Discount', '-${Fmt.money(d.n('discountTotal'))}') : ''}'
          '${tr('Tax', Fmt.money(d.n('taxTotal')))}'
          '${tr('Total incl. taxes', Fmt.money(d.n('total')), bold: true)}'
          '${d.n('deposit') > 0 ? tr('Security deposit', Fmt.money(d.n('deposit'))) : ''}'
          '${type == 'invoice' ? tr('Paid', Fmt.money(d.n('paid'))) + tr('Due', Fmt.money(d.n('due')), bold: true) : ''}'
          '</table>';

  final signature = (type == 'quote' || type == 'contract')
      ? '<div class="sig"><div class="sigline">${sig['name'] != null ? '<span class="script">${_e(sig['name'])}</span>' : ''}</div>'
          '<div class="muted">${sig['name'] != null ? 'Signed by ${_e(sig['name'])} on ${_e(Fmt.dateTime(Doc.toDate(sig['signedAt'])))}' : 'Signature'}</div></div>'
      : '';

  return '''<!doctype html>
<html><head><meta charset="utf-8"><title>${_e(title)} $number</title>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&family=Dancing+Script:wght@600&display=swap" rel="stylesheet">
<style>
*{box-sizing:border-box}body{margin:0;background:#f4f2f9;font-family:Inter,Arial,sans-serif;color:#1C0938;font-size:13px}
.page{max-width:820px;margin:24px auto;background:#fff;padding:48px;border-top:6px solid ${c.brandColor}}
.head{display:flex;justify-content:space-between;gap:24px;align-items:flex-start}
.logo{max-height:56px;max-width:200px;margin-bottom:8px}
h1{margin:0;font-size:26px;color:${c.brandColor};letter-spacing:-.3px;text-align:right}
.muted{color:#7A7090}.right{text-align:right}
.meta{display:flex;gap:32px;margin:28px 0;flex-wrap:wrap}.meta div b{display:block;font-size:11px;text-transform:uppercase;color:#7A7090;letter-spacing:.6px;margin-bottom:4px}
table{width:100%;border-collapse:collapse}
table.lines th{background:${c.brandColor}14;color:${c.brandColor};text-align:left;font-size:11px;text-transform:uppercase;letter-spacing:.6px;padding:10px}
table.lines td{padding:10px;border-bottom:1px solid #EEE9F7}
.num{text-align:right}.chk{width:36px;font-size:18px}
table.totals{width:300px;margin:20px 0 0 auto}table.totals td{padding:6px 10px}
table.totals tr.grand td{font-weight:700;border-top:2px solid ${c.brandColor}}
.text{margin-top:28px;line-height:1.6}
.sig{margin-top:40px;width:280px}.sigline{border-bottom:1px solid #1C0938;height:52px;display:flex;align-items:flex-end}
.script{font-family:'Dancing Script',cursive;font-size:30px;color:${c.brandColor}}
.footer{margin-top:40px;padding-top:16px;border-top:1px solid #EEE9F7;color:#7A7090;font-size:12px;text-align:center}
@media print{body{background:#fff}.page{margin:0;max-width:none;padding:24px}}
</style></head><body><div class="page">
<div class="head"><div>
${c.logoUrl.isNotEmpty ? '<img class="logo" src="${_e(c.logoUrl)}" alt="">' : ''}
<div style="font-weight:700;font-size:16px">${_e(c.name)}</div>
<div class="muted">${_e(c.address)}</div><div class="muted">${_e(c.email)}${c.phone.isNotEmpty ? ' · ${_e(c.phone)}' : ''}</div>
</div><div><h1>${_e(title)}</h1><div class="right muted">$number</div></div></div>
<div class="meta">
<div><b>Date</b>${_e(Fmt.date(d.d('date') ?? d.created))}</div>
${type == 'invoice' ? '<div><b>Due date</b>${_e(Fmt.date(d.d('dueDate')))}</div>' : ''}
<div><b>Order</b>#${_e(d.i('orderNumber'))}</div>
${d.s('reference').isNotEmpty ? '<div><b>Reference</b>${_e(d.s('reference'))}</div>' : ''}
</div>
<div class="meta">
<div><b>Bill to</b><span style="font-weight:600">${_e(d.s('customerName'))}</span><br>${_e(billing)}${order != null && order.s('customerEmail').isNotEmpty ? '<br>${_e(order.s('customerEmail'))}' : ''}</div>
${order != null ? '<div><b>Rental period</b>${_e(Fmt.dateTime(order.d('startsAt')))}<br>→ ${_e(Fmt.dateTime(order.d('stopsAt')))}</div>' : ''}
</div>
<table class="lines"><thead><tr>${packing ? '<th></th><th class="num">Qty</th><th>Item</th>' : '<th class="num">Qty</th><th>Item</th><th class="num">Price</th><th class="num">Tax</th><th class="num">Total</th>'}</tr></thead>
<tbody>$rows</tbody></table>
$totals
${d.s('text').isNotEmpty ? '<div class="text">${_e(d.s('text'))}</div>' : ''}
$signature
${d.s('footer').isNotEmpty ? '<div class="footer">${_e(d.s('footer'))}</div>' : ''}
</div></body></html>''';
}
