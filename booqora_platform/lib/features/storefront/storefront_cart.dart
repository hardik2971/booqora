import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import 'storefront_data.dart';
import 'storefront_page.dart';
import 'storefront_pay.dart';

// ---------------- Cart drawer ----------------

class CartDrawer extends StatelessWidget {
  final StoreData data;
  final VoidCallback onCheckout;
  const CartDrawer({super.key, required this.data, required this.onCheckout});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return Drawer(
      width: math.min(440, w),
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(),
      child: ListenableBuilder(
        listenable: data,
        builder: (context, _) {
          return SafeArea(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
                child: Row(children: [
                  Text('Your cart', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(width: 8),
                  if (data.cartCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: data.brand.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                      child: Text('${data.cartCount}', style: TextStyle(color: data.brand, fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
                ]),
              ),
              const Divider(height: 1),
              if (data.cart.isEmpty)
                Expanded(
                  child: EmptyState(
                    icon: Icons.shopping_bag_outlined,
                    title: 'Your cart is empty',
                    message: 'Pick your rental dates and add products to request a booking.',
                    compact: true,
                  ),
                )
              else ...[
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: data.brand.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Icon(Icons.event_outlined, size: 18, color: data.brand),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Rental period', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                        Text(data.periodLabel, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ]),
                    ),
                  ]),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: data.cart.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final l = data.cart[i];
                      final p = data.product(l.productId)!;
                      final imgs = p.l<String>('imageUrls');
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(width: 62, height: 62, child: ProductImage(url: imgs.firstOrNull, brand: data.brand)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(p.s('name'), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                              if (data.showPrices)
                                Text('${data.money(data.unitPrice(p))} each', style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                              const SizedBox(height: 8),
                              Row(children: [
                                QtyStepper(qty: l.qty, onChanged: (v) => data.setQty(p.id, v)),
                                const Spacer(),
                                if (data.showPrices) Text(data.money(data.lineTotal(l)), style: const TextStyle(fontWeight: FontWeight.w700)),
                              ]),
                            ]),
                          ),
                          IconButton(
                            tooltip: 'Remove',
                            icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.muted),
                            onPressed: () => data.setQty(p.id, 0),
                          ),
                        ]),
                      ).enterX(i);
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: AppColors.border)),
                    boxShadow: [BoxShadow(color: Color(0x101C0938), blurRadius: 16, offset: Offset(0, -4))],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (data.showPrices) ...[
                      KV('Subtotal', data.money(data.subtotal), bold: true),
                      if (data.depositTotal > 0) KV('Security deposit', data.money(data.depositTotal)),
                      const Padding(
                        padding: EdgeInsets.only(top: 2, bottom: 12),
                        child: Text('Taxes calculated at confirmation', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
                      ),
                    ] else
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text('Pricing will be confirmed with your booking.', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                      ),
                    FilledButton(
                      onPressed: data.periodValid
                          ? () {
                              Navigator.of(context).pop();
                              onCheckout();
                            }
                          : null,
                      child: const Text('Checkout'),
                    ),
                  ]),
                ),
              ],
            ]),
          );
        },
      ),
    );
  }
}

// ---------------- Checkout ----------------

Future<void> showCheckout(BuildContext context, StoreData data) {
  return showDialog<void>(
    context: context,
    builder: (_) => Theme(data: storeTheme(Theme.of(context), data.brand), child: _CheckoutDialog(data: data)),
  );
}

class _CheckoutDialog extends StatefulWidget {
  final StoreData data;
  const _CheckoutDialog({required this.data});

  @override
  State<_CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<_CheckoutDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _line1 = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _zip = TextEditingController();
  final _country = TextEditingController();
  final _note = TextEditingController();
  late String _fulfillment = widget.data.str('fulfillmentDefault', 'pickup') == 'delivery' ? 'delivery' : 'pickup';
  bool _terms = false;
  bool _showTerms = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _line1, _city, _state, _zip, _country, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final d = widget.data;
    if (!_form.currentState!.validate()) return;
    if (d.flag('termsRequired') && !_terms) {
      setState(() => _error = 'Please accept the terms to continue.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await d.submit(
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        fulfillment: _fulfillment,
        address: _fulfillment == 'delivery'
            ? {
                'line1': _line1.text.trim(),
                'city': _city.text.trim(),
                'state': _state.text.trim(),
                'zip': _zip.text.trim(),
                'country': _country.text.trim(),
              }
            : <String, dynamic>{},
        note: _note.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'We couldn\'t send your request. ${friendlyError(e)}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final w = MediaQuery.sizeOf(context).width;
    String? emailV(String? v) {
      final s = (v ?? '').trim();
      if (s.isEmpty) return 'Is a required field';
      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) return 'Enter a valid email address';
      return null;
    }

    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: w < 600 ? 10 : 40, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 8),
              child: Row(children: [
                Expanded(child: Text('Request booking', style: Theme.of(context).textTheme.titleLarge)),
                IconButton(onPressed: _busy ? null : () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ]),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: d.brand.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        Icon(Icons.event_outlined, size: 18, color: d.brand),
                        const SizedBox(width: 8),
                        Expanded(child: Text(d.periodLabel, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                      ]),
                      const SizedBox(height: 6),
                      Text('${d.cartCount} ${d.cartCount == 1 ? 'item' : 'items'}${d.showPrices ? ' · ${d.money(d.subtotal)}' : ''}',
                          style: const TextStyle(color: AppColors.inkSoft, fontSize: 13)),
                    ]),
                  ).enter(0),
                  const SizedBox(height: 18),
                  const Text('Your details', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  FieldGrid(children: [
                    Field(label: 'Full name', controller: _name, required: true, autofillHints: const [AutofillHints.name]),
                    Field(label: 'Phone', controller: _phone, required: true, keyboardType: TextInputType.phone, autofillHints: const [AutofillHints.telephoneNumber]),
                  ]),
                  const SizedBox(height: 14),
                  Field(
                    label: 'Email',
                    controller: _email,
                    required: true,
                    validator: emailV,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                  ),
                  const SizedBox(height: 20),
                  const Text('Fulfillment', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Row(children: [
                    for (final f in const [('pickup', 'Pickup', Icons.storefront_outlined), ('delivery', 'Delivery', Icons.local_shipping_outlined)]) ...[
                      if (f.$1 == 'delivery') const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => _fulfillment = f.$1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                            decoration: BoxDecoration(
                              color: _fulfillment == f.$1 ? d.brand.withValues(alpha: 0.08) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _fulfillment == f.$1 ? d.brand : AppColors.border, width: _fulfillment == f.$1 ? 1.6 : 1),
                            ),
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(f.$3, size: 18, color: _fulfillment == f.$1 ? d.brand : AppColors.muted),
                              const SizedBox(width: 8),
                              Text(f.$2, style: TextStyle(fontWeight: FontWeight.w600, color: _fulfillment == f.$1 ? d.brand : AppColors.inkSoft)),
                            ]),
                          ),
                        ),
                      ),
                    ],
                  ]),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    child: _fulfillment != 'delivery'
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              Field(label: 'Address', controller: _line1, required: true, autofillHints: const [AutofillHints.streetAddressLine1]),
                              const SizedBox(height: 14),
                              FieldGrid(children: [
                                Field(label: 'City', controller: _city, required: true),
                                Field(label: 'State / region', controller: _state),
                                Field(label: 'Postal code', controller: _zip),
                                Field(label: 'Country', controller: _country),
                              ]),
                            ]),
                          ),
                  ),
                  const SizedBox(height: 18),
                  Field(label: 'Notes', controller: _note, maxLines: 3, hint: 'Anything we should know?'),
                  if (d.flag('termsRequired')) ...[
                    const SizedBox(height: 14),
                    CheckTile(
                      value: _terms,
                      title: d.str('termsLabel', 'I accept the Terms and conditions'),
                      onChanged: (v) => setState(() {
                        _terms = v;
                        _error = null;
                      }),
                    ),
                    if (d.str('termsText').isNotEmpty) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => setState(() => _showTerms = !_showTerms),
                          child: Text(_showTerms ? 'Hide terms' : 'Read terms'),
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        child: _showTerms
                            ? Container(
                                constraints: const BoxConstraints(maxHeight: 200),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(10)),
                                child: SingleChildScrollView(child: Text(d.str('termsText'), style: const TextStyle(fontSize: 13, height: 1.5))),
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                    ],
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    InfoBanner(_error!, tone: Tone.danger, icon: Icons.error_outline).animate().shakeX(hz: 4, amount: 3, duration: 350.ms),
                  ],
                ]),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
              child: Row(children: [
                if (d.showPrices)
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      const Text('Total', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                      Text(d.money(d.subtotal), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                    ]),
                  )
                else
                  const Spacer(),
                FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  icon: _busy
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Request booking'),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ---------------- Success ----------------

class SuccessView extends StatelessWidget {
  final StoreData data;
  final VoidCallback onContinue;
  const SuccessView({super.key, required this.data, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final o = data.lastOrder!;
    final lines = (o['lines'] as List).cast<Map<String, dynamic>>();
    final brand = data.brand;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(alignment: Alignment.center, children: [
                Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, color: brand.withValues(alpha: 0.12)))
                    .animate(onPlay: (c) => c.repeat())
                    .scaleXY(begin: 0.6, end: 1.15, duration: 1600.ms, curve: Curves.easeOut)
                    .fadeOut(duration: 1600.ms),
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [brand, storeDark(brand)]),
                    boxShadow: [BoxShadow(color: brand.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 10))],
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 46)
                      .animate()
                      .scaleXY(begin: 0, end: 1, delay: 250.ms, duration: 500.ms, curve: Curves.elasticOut),
                ).animate().scaleXY(begin: 0.3, end: 1, duration: 500.ms, curve: Curves.easeOutBack),
              ]),
            ),
            const SizedBox(height: 24),
            Text('Booking request received', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800))
                .enter(2),
            const SizedBox(height: 8),
            Text(
              'Thanks ${o['name'].toString().split(' ').first}! We\'ll confirm by email at ${o['email']}.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.inkSoft, height: 1.5),
            ).enter(3),
            const SizedBox(height: 26),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Icon(Icons.event_outlined, size: 18, color: brand),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${Fmt.dateTime(o['start'] as DateTime)}  →  ${Fmt.dateTime(o['end'] as DateTime)}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(o['fulfillment'] == 'delivery' ? 'Delivery' : 'Pickup', style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                for (final l in lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Text('${l['qty']} × ', style: const TextStyle(color: AppColors.muted)),
                      Expanded(child: Text(l['name'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      if (data.showPrices) Text(data.money(l['total'] as num), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ]),
                  ),
                if (data.showPrices) ...[
                  const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1)),
                  KV('Total', data.money(o['total'] as num), bold: true),
                  if ((o['deposit'] as num) > 0) KV('Security deposit', data.money(o['deposit'] as num)),
                  const Text('Taxes calculated at confirmation', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
              ]),
            ).enter(4),
            if (o['orderId'] != null) ...[
              const SizedBox(height: 16),
              PayNowCard(data: data, order: o).enter(5),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: onContinue, icon: const Icon(Icons.storefront_outlined, size: 18), label: const Text('Continue browsing')).enter(5),
          ]),
        ),
      ),
    );
  }
}
