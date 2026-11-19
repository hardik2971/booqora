import 'package:cloud_firestore/cloud_firestore.dart' show SetOptions;
import 'package:flutter/material.dart' hide Thumb;
import 'package:flutter/services.dart';

import '../../core/browser.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../data/session.dart';
import '../../widgets/common.dart';
import '../../widgets/mobile.dart';

/// Parses `#RRGGBB` / `RRGGBB` / `#RGB` into a colour.
Color? parseHex(String? hex) {
  if (hex == null) return null;
  var h = hex.trim().replaceAll('#', '');
  if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
  if (h.length != 6) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}

String toHex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Darker shade of [c] used for gradients / announcement bars.
Color shade(Color c, [double f = 0.55]) {
  final h = HSLColor.fromColor(c);
  return h.withLightness((h.lightness * f).clamp(0.0, 1.0)).toColor();
}

/// Saves online-store settings and mirrors the public fields into `publicStores/{slug}`.
/// Identical contract to the web `StoreSync`.
class StoreSync {
  static String get slug => Session.instance.workspace?.s('slug') ?? '';
  static String get url => '${Browser.origin}/s/$slug';

  /// Saves several settings sections, mirrors public data and marks onboarding.
  static Future<void> save(Map<String, Map<String, dynamic>> sections) async {
    final s = Session.instance;
    for (final e in sections.entries) {
      await s.saveSettings(e.key, e.value);
    }
    await mirror(overrides: sections);
    await s.markOnboarding('store');
  }

  static Future<void> mirror({Map<String, Map<String, dynamic>> overrides = const {}}) async {
    final s = Session.instance;
    final ws = s.workspace;
    if (ws == null || slug.isEmpty) return;
    Map<String, dynamic> sec(String k) => {...s.settings(k), ...?overrides[k]};
    final store = sec('store'), general = sec('general'), pricing = sec('pricing');
    final checkout = sec('checkout'), seo = sec('seo'), cross = sec('crossSell'), ful = sec('fulfillment');
    await Db.fs.collection(C.publicStores).doc(slug).set({
      'workspaceId': ws.id,
      'name': (store['name'] as String?)?.isNotEmpty == true ? store['name'] : (general['companyName'] ?? ws.s('name')),
      'enabled': store['enabled'] ?? true,
      'brandColor': store['brandColor'] ?? '#6431DD',
      'description': store['description'] ?? '',
      'logoUrl': general['logoUrl'] ?? '',
      'currency': pricing['currency'] ?? 'INR',
      'symbol': pricing['symbol'] ?? '₹',
      'position': pricing['position'] ?? 'before',
      'showPrices': store['showPrices'] ?? true,
      'seoTitle': seo['title'] ?? ws.s('name'),
      'seoDescription': seo['description'] ?? '',
      'termsRequired': checkout['termsRequired'] ?? false,
      'termsLabel': checkout['termsLabel'] ?? 'I accept the Terms and conditions',
      'termsText': checkout['termsText'] ?? '',
      'email': general['email'] ?? '',
      'phone': general['phone'] ?? '',
      'heroTitle': store['heroTitle'] ?? '',
      'heroSubtitle': store['heroSubtitle'] ?? '',
      'announcement': store['announcement'] ?? '',
      'availabilityEnabled': store['availability'] ?? true,
      'addToCart': store['addToCart'] ?? 'cart',
      'fulfillmentDefault': ful['defaultMethod'] ?? 'pickup',
      'crossSell': {
        'enabled': cross['enabled'] ?? false,
        'title': cross['title'] ?? 'Recommended products',
        'subtitle': cross['subtitle'] ?? '',
        'maxItems': cross['maxItems'] ?? 4,
      },
    }, SetOptions(merge: true));
  }
}

Future<void> copyText(BuildContext context, String text, [String label = 'Copied to clipboard']) async {
  HapticFeedback.selectionClick();
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) toast(context, label);
}

/// Text controller helper bound to a settings value.
TextEditingController ctl(Map<String, dynamic> m, String key, [String def = '']) =>
    TextEditingController(text: (m[key] ?? def).toString());

/// Read-only value with a copy button (URLs and code snippets).
class CopyField extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool code;
  final String copiedLabel;
  const CopyField(this.text, {super.key, this.icon = Icons.link_rounded, this.code = false, this.copiedLabel = 'Copied to clipboard'});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: code ? const Color(0xFF1C0938) : AppColors.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: code ? Colors.transparent : AppColors.border),
      ),
      child: Row(crossAxisAlignment: code ? CrossAxisAlignment.start : CrossAxisAlignment.center, children: [
        Padding(
          padding: EdgeInsets.only(top: code ? 12 : 0),
          child: Icon(icon, size: 16, color: code ? AppColors.lavender : AppColors.muted),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: SelectableText(
              text,
              maxLines: code ? 6 : 1,
              style: TextStyle(
                fontSize: code ? 11.5 : 13,
                fontFamily: code ? 'monospace' : null,
                color: code ? const Color(0xFFE9E3FB) : AppColors.ink,
                height: 1.45,
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Copy',
          icon: Icon(Icons.copy_rounded, size: 18, color: code ? Colors.white : AppColors.primary),
          onPressed: () => copyText(context, text, copiedLabel),
        ),
      ]),
    );
  }
}

/// White grouped card with an icon title row (mobile counterpart of web `TitledCard`).
class StoreCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final List<Widget> children;
  const StoreCard({super.key, required this.title, this.subtitle, this.icon, this.trailing, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Group(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (icon != null) ...[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.16), AppColors.primary.withValues(alpha: 0.06)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 19, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.ink)),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: const TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.4)),
              ],
            ]),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ]),
        ...children,
      ]),
    );
  }
}

/// State helper for store setting forms: dirty tracking, save, sticky save bar and discard guard.
mixin StoreFormState<T extends StatefulWidget> on State<T> {
  bool saving = false;
  bool dirty = false;

  void touch(VoidCallback fn) => setState(() {
        fn();
        dirty = true;
      });

  void changed([String? _]) => setState(() => dirty = true);

  Future<void> runSave(Map<String, Map<String, dynamic>> sections) async {
    FocusScope.of(context).unfocus();
    setState(() => saving = true);
    try {
      await StoreSync.save(sections);
      if (mounted) {
        HapticFeedback.mediumImpact();
        toast(context, 'Online store settings saved');
        setState(() => dirty = false);
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  /// Sticky bottom bar: unsaved hint + gradient save button.
  Widget saveBar(VoidCallback onSave) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: dirty
              ? const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.circle, size: 8, color: AppColors.warning),
                    SizedBox(width: 8),
                    Text('Unsaved changes', style: TextStyle(color: AppColors.inkSoft, fontSize: 13, fontWeight: FontWeight.w500)),
                  ]),
                )
              : const SizedBox(width: double.infinity),
        ),
        GradientButton(label: 'Save changes', icon: Icons.check_rounded, busy: saving, onPressed: onSave),
      ]);

  /// Asks before leaving with unsaved edits.
  Widget guard(Widget child) => PopScope(
        canPop: !dirty || saving,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final ok = await confirmDialog(context,
              title: 'Discard changes?', message: 'You have unsaved changes in this section.', confirmLabel: 'Discard', danger: true);
          if (ok && mounted) {
            setState(() => dirty = false);
            Navigator.of(context).pop();
          }
        },
        child: child,
      );
}

/// Formats the storefront price label for a product doc.
String productPriceLabel(Doc p) {
  final method = p.s('pricingMethod', 'flat');
  if (method == 'none') return '';
  final price = p.n('price');
  if (method == 'fixed') return Fmt.money(price);
  if (method == 'structure') return 'From ${Fmt.money(price)}';
  return '${Fmt.money(price)} / ${p.s('pricePer', 'day')}';
}

/// Phone-frame live preview of the storefront.
class StorePreview extends StatelessWidget {
  final String name;
  final Color brand;
  final String heroTitle;
  final String heroSubtitle;
  final String announcement;
  final String? logoUrl;
  final List<Doc> products;
  final bool showPrices;
  final double width;
  const StorePreview({
    super.key,
    required this.name,
    required this.brand,
    this.heroTitle = '',
    this.heroSubtitle = '',
    this.announcement = '',
    this.logoUrl,
    this.products = const [],
    this.showPrices = true,
    this.width = 230,
  });

  @override
  Widget build(BuildContext context) {
    final dark = shade(brand);
    final shown = products.take(4).toList();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: width,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: const Color(0xFF120526),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: [BoxShadow(color: brand.withValues(alpha: 0.38), blurRadius: 34, offset: const Offset(0, 16))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: ColoredBox(
          color: Colors.white,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Notch
            Container(
              height: 20,
              alignment: Alignment.center,
              child: Container(width: 60, height: 6, decoration: BoxDecoration(color: const Color(0xFF120526), borderRadius: BorderRadius.circular(4))),
            ),
            if (announcement.trim().isNotEmpty)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                color: dark,
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Text(announcement,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w600)),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(children: [
                if (logoUrl != null && logoUrl!.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(right: 6), child: Thumb(url: logoUrl, size: 18))
                else
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 18,
                    height: 18,
                    margin: const EdgeInsets.only(right: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: brand, borderRadius: BorderRadius.circular(5)),
                    child: Text(name.isEmpty ? 'S' : name[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                Expanded(
                  child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
                ),
                Icon(Icons.shopping_bag_outlined, size: 14, color: brand),
              ]),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
              decoration: BoxDecoration(gradient: LinearGradient(colors: [brand, dark], begin: Alignment.topLeft, end: Alignment.bottomRight)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(heroTitle.trim().isEmpty ? 'Rent the best gear' : heroTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, height: 1.2)),
                const SizedBox(height: 4),
                Text(heroSubtitle.trim().isEmpty ? 'Pick your dates and book online in minutes.' : heroSubtitle,
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 9)),
                const SizedBox(height: 9),
                Row(children: [
                  for (final l in ['From', 'Until'])
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                        child: Row(children: [
                          Icon(Icons.event_outlined, size: 9, color: brand),
                          const SizedBox(width: 3),
                          Text(l, style: const TextStyle(fontSize: 8, color: AppColors.muted)),
                        ]),
                      ),
                    ),
                ]),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 9, 9, 12),
              child: Column(children: [
                for (var r = 0; r < 2; r++) ...[
                  if (r > 0) const SizedBox(height: 8),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (var c = 0; c < 2; c++) ...[
                      if (c > 0) const SizedBox(width: 8),
                      Expanded(child: _tile(r * 2 + c < shown.length ? shown[r * 2 + c] : null, r * 2 + c)),
                    ],
                  ]),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _tile(Doc? p, int i) {
    const icons = [Icons.camera_alt_outlined, Icons.speaker_outlined, Icons.pedal_bike_outlined, Icons.celebration_outlined];
    final img = p?.l<String>('imageUrls').firstOrNull ?? (p?.s('imageUrl'));
    final price = p == null ? '' : productPriceLabel(p);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AspectRatio(
        aspectRatio: 1.15,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            color: brand.withValues(alpha: 0.10),
            child: img != null && img.isNotEmpty
                ? Image.network(img, fit: BoxFit.cover, errorBuilder: (_, _, _) => Icon(icons[i % 4], color: brand.withValues(alpha: 0.7), size: 20))
                : Icon(icons[i % 4], color: brand.withValues(alpha: 0.7), size: 20),
          ),
        ),
      ),
      const SizedBox(height: 4),
      if (p == null) ...[
        Container(height: 5, width: 60, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(3))),
        const SizedBox(height: 3),
        Container(height: 5, width: 32, decoration: BoxDecoration(color: brand.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(3))),
      ] else ...[
        Text(p.s('name', 'Product'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
        if (showPrices && price.isNotEmpty)
          Text(price, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: brand)),
      ],
    ]);
  }
}

/// Preview bound to current workspace settings + live store products, with optional overrides.
class LiveStorePreview extends StatefulWidget {
  final Map<String, dynamic> store;
  final double width;
  const LiveStorePreview({super.key, this.store = const {}, this.width = 230});

  @override
  State<LiveStorePreview> createState() => _LiveStorePreviewState();
}

class _LiveStorePreviewState extends State<LiveStorePreview> {
  late final Stream<List<Doc>> _stream = Db.watchWhere(C.products, 'showInStore', true);

  @override
  Widget build(BuildContext context) {
    final s = Session.instance;
    final st = {...s.settings('store'), ...widget.store};
    final general = s.settings('general');
    final name = (st['name'] as String?)?.isNotEmpty == true ? st['name'] as String : (general['companyName'] ?? s.workspace?.s('name') ?? 'Your store').toString();
    return StreamBuilder<List<Doc>>(
      stream: _stream,
      builder: (context, snap) {
        final products = (snap.data ?? const <Doc>[]).where((p) => p.s('status', 'active') != 'archived').toList();
        return StorePreview(
          name: name,
          brand: parseHex(st['brandColor'] as String?) ?? AppColors.primary,
          heroTitle: (st['heroTitle'] ?? '').toString(),
          heroSubtitle: (st['heroSubtitle'] ?? '').toString(),
          announcement: (st['announcement'] ?? '').toString(),
          logoUrl: general['logoUrl'] as String?,
          products: products,
          showPrices: st['showPrices'] != false,
          width: widget.width,
        );
      },
    );
  }
}

/// Collapsible "Live preview" block for section forms.
class PreviewPanel extends StatelessWidget {
  final Widget preview;
  final String title;
  const PreviewPanel({super.key, required this.preview, this.title = 'Live preview'});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primarySoft, Colors.white.withValues(alpha: 0.6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(children: [
          Row(children: [
            const Icon(Icons.visibility_outlined, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.inkSoft, fontSize: 13)),
          ]),
          const SizedBox(height: 16),
          Center(child: preview),
        ]),
      ),
    );
  }
}
