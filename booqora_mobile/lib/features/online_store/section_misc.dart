import 'package:flutter/material.dart';

import '../../core/browser.dart';
import '../../core/theme.dart';
import '../../data/session.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/mobile.dart';
import 'store_common.dart';

// ============================ Integration ============================

class IntegrationSection extends StatelessWidget {
  const IntegrationSection({super.key});

  @override
  Widget build(BuildContext context) {
    final url = StoreSync.url;
    final brand = (Session.instance.setting('store', 'brandColor', '#6431DD') ?? '#6431DD').toString();
    final iframe = '<iframe src="$url" style="width:100%;height:900px;border:0" title="Book online"></iframe>';
    final button = '<a href="$url" target="_blank" rel="noopener" '
        'style="display:inline-block;padding:12px 22px;background:$brand;color:#fff;border-radius:10px;'
        'font-family:sans-serif;font-weight:600;text-decoration:none">Book now</a>';
    final platforms = [
      (
        'WordPress',
        Icons.language_rounded,
        const Color(0xFF21759B),
        [
          'Edit the page where you want bookings to appear.',
          'Add a "Custom HTML" block and paste the embed code.',
          'Paste the "Book now" button into your header or menu via a Custom HTML widget.',
          'Update the page and test a booking.',
        ],
      ),
      (
        'Shopify',
        Icons.shopping_bag_outlined,
        const Color(0xFF5E8E3E),
        [
          'In Online Store → Pages, create a page such as "Rent".',
          'Click "Show HTML" (<>) in the editor and paste the embed code.',
          'Add the page to your navigation under Online Store → Navigation.',
          'Save and preview your theme.',
        ],
      ),
      (
        'Squarespace',
        Icons.crop_square_rounded,
        const Color(0xFF111111),
        [
          'Edit a page and add a "Code" block.',
          'Paste the embed code and turn off "Display source".',
          'For a button, add another Code block with the "Book now" snippet.',
          'Save and publish.',
        ],
      ),
      (
        'Custom website',
        Icons.code_rounded,
        AppColors.primary,
        [
          'Paste the embed code where the booking page should appear.',
          'Or link any button to your booking page with the "Book now" snippet.',
          'Works with Wix, Webflow, Framer and any HTML site.',
        ],
      ),
    ];
    return FormScaffold(
      title: 'Website integration',
      actions: [
        IconButton(
          tooltip: 'Share snippets',
          icon: const Icon(Icons.ios_share_rounded),
          onPressed: () => Browser.shareText('Booqora embed code:\n$iframe\n\n"Book now" button:\n$button', subject: 'Booking page embed code'),
        ),
      ],
      children: [
        const InfoBanner(
          'Your booking page can be embedded on any website. Customers stay on your site while they pick dates and request a booking.',
          tone: Tone.brand,
          icon: Icons.integration_instructions_outlined,
        ),
        const SizedBox(height: 14),
        StoreCard(
          icon: Icons.link_rounded,
          title: 'Booking page link',
          children: [CopyField(url, copiedLabel: 'Link copied')],
        ),
        for (var i = 0; i < platforms.length; i++)
          _PlatformCard(
            name: platforms[i].$1,
            icon: platforms[i].$2,
            color: platforms[i].$3,
            steps: platforms[i].$4,
            iframe: iframe,
            button: button,
            initiallyExpanded: i == 0,
          ),
      ],
    );
  }
}

class _PlatformCard extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;
  final List<String> steps;
  final String iframe;
  final String button;
  final bool initiallyExpanded;
  const _PlatformCard({
    required this.name,
    required this.icon,
    required this.color,
    required this.steps,
    required this.iframe,
    required this.button,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: const [BoxShadow(color: Color(0x0A1C0938), blurRadius: 14, offset: Offset(0, 6))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
            shape: const RoundedRectangleBorder(),
            collapsedShape: const RoundedRectangleBorder(),
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color),
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Embed with an iframe or link a button', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
            expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(gradient: AppColors.brandGradient, shape: BoxShape.circle),
                      child: Text('${i + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Padding(padding: const EdgeInsets.only(top: 2), child: Text(steps[i], style: const TextStyle(height: 1.4, fontSize: 13.5)))),
                  ]).enterX(i),
                ),
              const SizedBox(height: 6),
              const FieldLabel('Embed code'),
              CopyField(iframe, icon: Icons.code_rounded, code: true, copiedLabel: 'Embed code copied'),
              const SizedBox(height: 12),
              const FieldLabel('"Book now" button'),
              CopyField(button, icon: Icons.smart_button_outlined, code: true, copiedLabel: 'Button code copied'),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================ Cross-sell ============================

class CrossSellSection extends StatefulWidget {
  const CrossSellSection({super.key});

  @override
  State<CrossSellSection> createState() => _CrossSellSectionState();
}

class _CrossSellSectionState extends State<CrossSellSection> with StoreFormState {
  late final Map<String, dynamic> _m = Session.instance.settings('crossSell');
  late bool _enabled = _m['enabled'] == true;
  late final _title = ctl(_m, 'title', 'Recommended products');
  late final _subtitle = ctl(_m, 'subtitle');
  late String _layout = (_m['layout'] ?? 'list').toString();
  late bool _onlyAvailable = _m['onlyAvailable'] != false;
  late final _max = ctl(_m, 'maxItems', '4');

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _max.dispose();
    super.dispose();
  }

  Future<void> _save() => runSave({
        'crossSell': {
          'enabled': _enabled,
          'title': _title.text.trim().isEmpty ? 'Recommended products' : _title.text.trim(),
          'subtitle': _subtitle.text.trim(),
          'layout': _layout,
          'onlyAvailable': _onlyAvailable,
          'maxItems': parseNum(_max.text, 4).toInt().clamp(1, 12),
        },
      });

  @override
  Widget build(BuildContext context) {
    final brand = parseHex(Session.instance.setting('store', 'brandColor') as String?) ?? AppColors.primary;
    final n = parseNum(_max.text, 4).toInt().clamp(1, 6);
    return guard(FormScaffold(
      title: 'Cross-sell',
      bottom: saveBar(_save),
      children: [
        PreviewPanel(
          title: 'Product page preview',
          preview: AnimatedOpacity(
            opacity: _enabled ? 1 : 0.35,
            duration: const Duration(milliseconds: 250),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_title.text.isEmpty ? 'Recommended products' : _title.text, style: const TextStyle(fontWeight: FontWeight.w700)),
                if (_subtitle.text.isNotEmpty) Text(_subtitle.text, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: _layout == 'carousel'
                      ? SizedBox(
                          key: const ValueKey('carousel'),
                          height: 90,
                          child: ListView(scrollDirection: Axis.horizontal, children: [
                            for (var i = 0; i < n; i++)
                              Container(
                                width: 78,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(color: brand.withValues(alpha: 0.08 + i * 0.03), borderRadius: BorderRadius.circular(12)),
                                child: Icon(Icons.inventory_2_outlined, color: brand),
                              ).pop(i),
                          ]),
                        )
                      : Column(key: const ValueKey('list'), children: [
                          for (var i = 0; i < n; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(color: brand.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                                  child: Icon(Icons.inventory_2_outlined, size: 18, color: brand),
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: Container(height: 8, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)))),
                                const SizedBox(width: 10),
                                Icon(Icons.add_circle_outline_rounded, color: brand, size: 20),
                              ]),
                            ).enterX(i),
                        ]),
                ),
              ]),
            ),
          ),
        ),
        StoreCard(
          icon: Icons.auto_awesome_motion_outlined,
          title: 'Cross-sell',
          subtitle: 'Recommend related products on product pages. Pick recommendations per product under Inventory.',
          children: [
            SwitchTile(value: _enabled, title: 'Show cross-sell on product pages', onChanged: (v) => touch(() => _enabled = v)),
            Field(label: 'Section title', controller: _title, onChanged: changed),
            Field(label: 'Subtitle', controller: _subtitle, hint: 'Customers often rent these together', onChanged: changed),
          ],
        ),
        StoreCard(
          icon: Icons.view_carousel_outlined,
          title: 'Layout',
          children: [
            RadioCards<String>(
              value: _layout,
              options: const [
                ('list', 'List', 'Compact rows with an add button.'),
                ('carousel', 'Carousel', 'Horizontally scrolling product cards.'),
              ],
              onChanged: (v) => touch(() => _layout = v),
            ),
            CheckTile(value: _onlyAvailable, title: 'Only show available products', onChanged: (v) => touch(() => _onlyAvailable = v)),
            Field.number(label: 'Maximum products shown', controller: _max, decimal: false, helper: '1 – 12', onChanged: changed),
          ],
        ),
      ],
    ));
  }
}

// ============================ SEO ============================

class SeoSection extends StatefulWidget {
  const SeoSection({super.key});

  @override
  State<SeoSection> createState() => _SeoSectionState();
}

class _SeoSectionState extends State<SeoSection> with StoreFormState {
  late final Map<String, dynamic> _m = Session.instance.settings('seo');
  late final _title = ctl(_m, 'title', Session.instance.workspace?.s('name') ?? '');
  late final _desc = ctl(_m, 'description');

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() => runSave({
        'seo': {'title': _title.text.trim(), 'description': _desc.text.trim()},
      });

  @override
  Widget build(BuildContext context) {
    final url = StoreSync.url;
    final title = _title.text.isEmpty ? (Session.instance.workspace?.s('name') ?? 'Your store') : _title.text;
    final desc = _desc.text.isEmpty ? 'Book rentals online. Choose your dates, pick your products and request a booking in minutes.' : _desc.text;
    return guard(FormScaffold(
      title: 'SEO',
      bottom: saveBar(_save),
      children: [
        StoreCard(
          icon: Icons.search_rounded,
          title: 'Search preview',
          subtitle: 'How your booking page appears in Google.',
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: Color(0xFFF1F3F4), shape: BoxShape.circle),
                    child: Text(title.isEmpty ? 'S' : title[0].toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Color(0xFF202124))),
                      Text(url, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: Color(0xFF4D5156))),
                    ]),
                  ),
                ]),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(title,
                      key: ValueKey(title),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18, color: Color(0xFF1A0DAB), fontWeight: FontWeight.w400)),
                ),
                const SizedBox(height: 4),
                Text(desc, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Color(0xFF4D5156), height: 1.45)),
              ]),
            ),
          ],
        ),
        StoreCard(
          icon: Icons.travel_explore_outlined,
          title: 'Search engine listing',
          subtitle: 'Control how your booking page appears in Google and when shared on social media.',
          children: [
            Field(label: 'Page title', controller: _title, maxLength: 60, onChanged: changed),
            Field(label: 'Meta description', controller: _desc, maxLength: 160, maxLines: 3, onChanged: changed),
          ],
        ),
      ],
    ));
  }
}
