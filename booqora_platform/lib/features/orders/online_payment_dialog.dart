import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/browser.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/payments.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';

/// Staff dialog: take an online payment now (Razorpay) or create a hosted
/// payment link (Stripe / PayPal) to share with the customer.
Future<void> showOnlinePaymentDialog(
  BuildContext context, {
  required String orderId,
  required String orderLabel,
  required num due,
  required String customerName,
  required String customerEmail,
  required String companyName,
}) =>
    showDialog(
      context: context,
      builder: (_) => _OnlinePaymentDialog(
        orderId: orderId,
        orderLabel: orderLabel,
        due: due,
        customerName: customerName,
        customerEmail: customerEmail,
        companyName: companyName,
      ),
    );

class _OnlinePaymentDialog extends StatefulWidget {
  final String orderId, orderLabel, customerName, customerEmail, companyName;
  final num due;
  const _OnlinePaymentDialog({
    required this.orderId,
    required this.orderLabel,
    required this.due,
    required this.customerName,
    required this.customerEmail,
    required this.companyName,
  });

  @override
  State<_OnlinePaymentDialog> createState() => _OnlinePaymentDialogState();
}

class _OnlinePaymentDialogState extends State<_OnlinePaymentDialog> {
  late final _amount = TextEditingController(text: widget.due.toStringAsFixed(2));
  PayConfig? _cfg;
  String? _loadError;
  String? _busy;
  String? _link;
  String? _linkProvider;
  String? _error;

  @override
  void initState() {
    super.initState();
    Payments.config(workspaceId: Db.wid).then((c) {
      if (mounted) setState(() => _cfg = c);
    }).catchError((Object e) {
      if (mounted) setState(() => _loadError = friendlyError(e));
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  num get _amt => parseNum(_amount.text);

  bool _validAmount() {
    if (_amt < 1 || _amt > widget.due + 0.001) {
      setState(() => _error = 'Enter an amount between 1 and ${Fmt.money(widget.due)}.');
      return false;
    }
    return true;
  }

  Future<void> _chargeNow(PayProvider p) async {
    if (!_validAmount()) return;
    setState(() => (_busy = p.id, _error = null));
    try {
      final r = await Payments.pay(workspaceId: Db.wid, orderId: widget.orderId, provider: p.id, purpose: 'custom', amount: _amt);
      if (!mounted || r == null) return;
      if (r.ok) {
        Navigator.pop(context);
        toast(context, 'Payment of ${Fmt.money(r.amount)} received via ${p.name}');
      } else {
        setState(() => (_busy = null, _error = r.cancelled ? null : r.message));
      }
    } catch (e) {
      if (mounted) setState(() => (_busy = null, _error = friendlyError(e)));
    }
  }

  Future<void> _createLink(PayProvider p) async {
    if (!_validAmount()) return;
    setState(() => (_busy = p.id, _error = null, _link = null));
    try {
      final s = await Payments.create(workspaceId: Db.wid, orderId: widget.orderId, provider: p.id, purpose: 'custom', amount: _amt);
      if (!mounted) return;
      setState(() => (_busy = null, _link = s['url']?.toString(), _linkProvider = p.name));
    } catch (e) {
      if (mounted) setState(() => (_busy = null, _error = friendlyError(e)));
    }
  }

  Future<void> _emailLink() async {
    final to = widget.customerEmail;
    if (!to.contains('@')) {
      toast(context, 'This customer has no email address', error: true);
      return;
    }
    setState(() => _busy = 'email');
    try {
      await Payments.sendEmail(
        workspaceId: Db.wid,
        to: to,
        subject: 'Payment request for order ${widget.orderLabel} — ${widget.companyName}',
        body: 'Hi ${widget.customerName.isEmpty ? 'there' : widget.customerName},\n\n'
            'Please use the secure link below to pay ${Fmt.money(_amt)} for order ${widget.orderLabel}:\n\n$_link\n\n'
            'Kind regards,\n${widget.companyName}',
        context: 'payments',
        entityId: widget.orderId,
      );
      if (mounted) toast(context, 'Payment link emailed to $to');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _cfg;
    return AlertDialog(
      title: const Row(children: [Icon(Icons.bolt_rounded, color: AppColors.primary), SizedBox(width: 10), Text('Collect online payment')]),
      content: SizedBox(
        width: 480,
        child: _loadError != null
            ? InfoBanner(_loadError!, tone: Tone.danger)
            : c == null
                ? const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
                : SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Field.money(label: 'Amount', controller: _amount, helper: 'Due on ${widget.orderLabel}: ${Fmt.money(widget.due)}'),
                      const SizedBox(height: 16),
                      if (c.available.isEmpty)
                        const InfoBanner('No payment provider is available for this store. Check Settings → Payment providers.', tone: Tone.warning)
                      else
                        for (final p in c.available) _providerRow(p),
                      if (c.available.any((p) => p.mode == 'test'))
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text('Test mode — use test cards / sandbox accounts. No real money moves.', style: TextStyle(fontSize: 12, color: AppColors.warning)),
                        ),
                      if (_link != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Text('$_linkProvider payment link', style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            SelectableText(_link!, style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                            const SizedBox(height: 10),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              OutlinedButton.icon(
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: _link!));
                                  toast(context, 'Link copied');
                                },
                                icon: const Icon(Icons.copy, size: 16),
                                label: const Text('Copy'),
                              ),
                              OutlinedButton.icon(onPressed: () => Browser.openUrl(_link!), icon: const Icon(Icons.open_in_new, size: 16), label: const Text('Open')),
                              FilledButton.icon(
                                onPressed: _busy == null ? _emailLink : null,
                                icon: const Icon(Icons.send_rounded, size: 16),
                                label: Text(_busy == 'email' ? 'Sending…' : 'Email to customer'),
                              ),
                            ]),
                            const SizedBox(height: 6),
                            const Text('The order updates automatically once the customer pays.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                          ]),
                        ),
                      ],
                      if (_error != null) ...[const SizedBox(height: 12), InfoBanner(_error!, tone: Tone.danger, icon: Icons.error_outline)],
                      if (c.providers.values.any((p) => !p.available)) ...[
                        const SizedBox(height: 12),
                        for (final p in c.providers.values.where((p) => !p.available))
                          Text('${p.name}: ${p.reason ?? 'unavailable'}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                      ],
                    ]),
                  ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    );
  }

  Widget _providerRow(PayProvider p) {
    final busy = _busy == p.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('${p.blurb} · ${p.currency}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ]),
        ),
        if (busy)
          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
        else if (p.id == 'razorpay')
          FilledButton(onPressed: _busy == null ? () => _chargeNow(p) : null, child: const Text('Charge now'))
        else
          OutlinedButton(onPressed: _busy == null ? () => _createLink(p) : null, child: const Text('Create link')),
      ]),
    );
  }
}
