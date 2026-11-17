import 'package:cloud_firestore/cloud_firestore.dart' show SetOptions;
import 'package:flutter/material.dart' hide Thumb;
import 'package:flutter/services.dart';

import '../../core/browser.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../data/session.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';

/// Parses `#RRGGBB` / `RRGGBB` into a colour.
Color? parseHex(String? hex) {
  if (hex == null) return null;
  var h = hex.trim().replaceAll('#', '');
  if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
  if (h.length != 6) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}

String toHex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Saves online-store settings and mirrors the public fields into `publicStores/{slug}`.
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
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) toast(context, label);
}

/// Read-only URL row with copy button.
class CopyField extends StatelessWidget {
  final String text;
  final IconData icon;
  final int maxLines;
  const CopyField(this.text, {super.key, this.icon = Icons.link, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
      child: Row(crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center, children: [
        Padding(padding: EdgeInsets.only(top: maxLines > 1 ? 8 : 0), child: Icon(icon, size: 16, color: AppColors.muted)),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: SelectableText(text,
                maxLines: maxLines,
                style: TextStyle(fontSize: 13, fontFamily: maxLines > 1 ? 'monospace' : null, color: AppColors.ink, height: 1.4)),
          ),
        ),
        IconButton(
          tooltip: 'Copy',
          icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primary),
          onPressed: () => copyText(context, text),
        ),
      ]),
    );
  }
}

/// Scrollable settings section with sticky save bar.
class SectionFrame extends StatelessWidget {
  final List<Widget> children;
  final VoidCallback? onSave;
  final bool saving;
  final bool dirty;
  const SectionFrame({super.key, required this.children, this.onSave, this.saving = false, this.dirty = false});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 700;
    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(narrow ? 16 : 4, 4, narrow ? 16 : 28, 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ),
      if (onSave != null)
        SaveBar(
          onSave: onSave,
          saving: saving,
          saveLabel: 'Save changes',
          leading: AnimatedOpacity(
            opacity: dirty ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Row(children: [
              Icon(Icons.circle, size: 8, color: AppColors.warning),
              SizedBox(width: 8),
              Text('Unsaved changes', style: TextStyle(color: AppColors.inkSoft, fontSize: 13)),
            ]),
          ),
        ),
    ]);
  }
}

/// Mixin for settings sections: holds `saving` / `dirty` and a save wrapper.
mixin StoreSectionState<T extends StatefulWidget> on State<T> {
  bool saving = false;
  bool dirty = false;

  void touch(VoidCallback fn) => setState(() {
        fn();
        dirty = true;
      });

  Future<void> runSave(Map<String, Map<String, dynamic>> sections) async {
    setState(() => saving = true);
    try {
      await StoreSync.save(sections);
      if (mounted) {
        toast(context, 'Online store settings saved');
        setState(() => dirty = false);
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

/// Phone-frame live preview of the storefront.
class StorePreview extends StatelessWidget {
  final String name;
  final Color brand;
  final String heroTitle;
  final String heroSubtitle;
  final String announcement;
  final String? logoUrl;
  final double width;
  const StorePreview({
    super.key,
    required this.name,
    required this.brand,
    this.heroTitle = '',
    this.heroSubtitle = '',
    this.announcement = '',
    this.logoUrl,
    this.width = 260,
  });

  @override
  Widget build(BuildContext context) {
    final dark = HSLColor.fromColor(brand).withLightness((HSLColor.fromColor(brand).lightness * 0.55).clamp(0.0, 1.0)).toColor();
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: width,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: brand.withValues(alpha: 0.25), blurRadius: 30, offset: const Offset(0, 14))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(23),
          child: Container(
            color: Colors.white,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                height: 18,
                color: Colors.white,
                alignment: Alignment.center,
                child: Container(width: 54, height: 5, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4))),
              ),
              if (announcement.trim().isNotEmpty)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  color: dark,
                  padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                  child: Text(announcement, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(children: [
                  if (logoUrl != null && logoUrl!.isNotEmpty)
                    Padding(padding: const EdgeInsets.only(right: 6), child: Thumb(url: logoUrl, size: 18))
                  else
                    Container(
                      width: 18,
                      height: 18,
                      margin: const EdgeInsets.only(right: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: brand, borderRadius: BorderRadius.circular(5)),
                      child: Text(name.isEmpty ? 'S' : name[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                    ),
                  Expanded(
                    child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                  Icon(Icons.shopping_bag_outlined, size: 14, color: brand),
                ]),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
                decoration: BoxDecoration(gradient: LinearGradient(colors: [brand, dark], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(heroTitle.isEmpty ? 'Rent the best gear' : heroTitle,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15, height: 1.2)),
                  const SizedBox(height: 4),
                  Text(heroSubtitle.isEmpty ? 'Pick your dates and book online in minutes.' : heroSubtitle,
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 9.5)),
                  const SizedBox(height: 10),
                  Row(children: [
                    for (final l in ['From', 'Until'])
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                          child: Text(l, style: const TextStyle(fontSize: 8.5, color: AppColors.muted)),
                        ),
                      ),
                  ]),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(children: [
                  for (var i = 0; i < 2; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        AspectRatio(
                          aspectRatio: 1.1,
                          child: Container(
                            decoration: BoxDecoration(color: brand.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
                            child: Icon(i == 0 ? Icons.camera_alt_outlined : Icons.speaker_outlined, color: brand.withValues(alpha: 0.7), size: 22),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(height: 6, width: 60, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(3))),
                        const SizedBox(height: 4),
                        Container(height: 6, width: 34, decoration: BoxDecoration(color: brand.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(3))),
                      ]),
                    ),
                  ],
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  /// Preview bound to current workspace settings, with optional overrides.
  factory StorePreview.fromSettings({Map<String, dynamic> store = const {}, double width = 260}) {
    final s = Session.instance;
    final st = {...s.settings('store'), ...store};
    final general = s.settings('general');
    final name = (st['name'] as String?)?.isNotEmpty == true ? st['name'] as String : (general['companyName'] ?? s.workspace?.s('name') ?? 'Your store').toString();
    return StorePreview(
      name: name,
      brand: parseHex(st['brandColor'] as String?) ?? AppColors.primary,
      heroTitle: (st['heroTitle'] ?? '').toString(),
      heroSubtitle: (st['heroSubtitle'] ?? '').toString(),
      announcement: (st['announcement'] ?? '').toString(),
      logoUrl: general['logoUrl'] as String?,
      width: width,
    );
  }
}

/// Two column layout: form left, sticky preview right (stacks when narrow).
class WithPreview extends StatelessWidget {
  final List<Widget> children;
  final Widget preview;
  final String previewTitle;
  const WithPreview({super.key, required this.children, required this.preview, this.previewTitle = 'Live preview'});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final side = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.visibility_outlined, size: 16, color: AppColors.muted),
          const SizedBox(width: 6),
          Text(previewTitle, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.inkSoft, fontSize: 13)),
        ]),
        const SizedBox(height: 14),
        preview,
      ]);
      if (c.maxWidth < 900) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [...children, const SizedBox(height: 12), side]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)),
        const SizedBox(width: 28),
        SizedBox(width: 300, child: side),
      ]);
    });
  }
}

/// Card with a title row.
class TitledCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget> children;
  final Widget? trailing;
  final int index;
  const TitledCard({super.key, required this.title, this.subtitle, this.icon, required this.children, this.trailing, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (icon != null) ...[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: t.titleMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: t.bodySmall?.copyWith(color: AppColors.muted, height: 1.4)),
                ],
              ]),
            ),
            ?trailing,
          ]),
          const SizedBox(height: 16),
          for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 14), children[i]],
        ]),
      ),
    );
  }
}

/// Text controller helper bound to a settings value.
TextEditingController ctl(Map<String, dynamic> m, String key, [String def = '']) =>
    TextEditingController(text: (m[key] ?? def).toString());
