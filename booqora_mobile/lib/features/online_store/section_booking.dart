import 'package:flutter/material.dart';

import '../../core/browser.dart';
import '../../core/theme.dart';
import '../../data/session.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/mobile.dart';
import 'store_common.dart';

class BookingPageSection extends StatefulWidget {
  const BookingPageSection({super.key});

  @override
  State<BookingPageSection> createState() => _BookingPageSectionState();
}

class _BookingPageSectionState extends State<BookingPageSection> with StoreFormState {
  late final Map<String, dynamic> _store = Session.instance.settings('store');
  late bool _enabled = _store['enabled'] != false;
  late final _heroTitle = ctl(_store, 'heroTitle');
  late final _heroSubtitle = ctl(_store, 'heroSubtitle');
  late final _announcement = ctl(_store, 'announcement');
  late final _description = ctl(_store, 'description');

  @override
  void dispose() {
    for (final c in [_heroTitle, _heroSubtitle, _announcement, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() => runSave({
        'store': {
          'enabled': _enabled,
          'heroTitle': _heroTitle.text.trim(),
          'heroSubtitle': _heroSubtitle.text.trim(),
          'announcement': _announcement.text.trim(),
          'description': _description.text.trim(),
        },
      });

  @override
  Widget build(BuildContext context) {
    final url = StoreSync.url;
    return guard(FormScaffold(
      title: 'Booking page',
      actions: [
        IconButton(tooltip: 'Open', icon: const Icon(Icons.open_in_new_rounded), onPressed: () => Browser.openUrl(url)),
      ],
      bottom: saveBar(_save),
      children: [
        PreviewPanel(
          preview: LiveStorePreview(width: 220, store: {
            'heroTitle': _heroTitle.text,
            'heroSubtitle': _heroSubtitle.text,
            'announcement': _announcement.text,
          }),
        ),
        StoreCard(
          icon: Icons.power_settings_new_rounded,
          title: 'Store status',
          subtitle: 'When disabled, visitors see an offline message and cannot book.',
          trailing: StatusPill(_enabled ? 'live' : 'inactive', label: _enabled ? 'Live' : 'Offline'),
          children: [
            SwitchTile(
              value: _enabled,
              title: 'Enable online store',
              subtitle: 'Accept booking requests from your booking page.',
              onChanged: (v) => touch(() => _enabled = v),
            ),
            CopyField(url, copiedLabel: 'Link copied'),
          ],
        ),
        _ShareCard(url: url),
        StoreCard(
          icon: Icons.brush_outlined,
          title: 'Customize',
          subtitle: 'Headline content shown at the top of your booking page.',
          children: [
            Field(label: 'Hero title', controller: _heroTitle, hint: 'Rent the best gear in town', onChanged: changed),
            Field(label: 'Hero subtitle', controller: _heroSubtitle, hint: 'Pick your dates and book online in minutes.', onChanged: changed),
            Field(label: 'Announcement bar text', controller: _announcement, hint: 'Free delivery on orders over ₹5,000', onChanged: changed),
            Field(label: 'Store description', controller: _description, maxLines: 4, onChanged: changed),
          ],
        ),
      ],
    ));
  }
}

class _ShareCard extends StatelessWidget {
  final String url;
  const _ShareCard({required this.url});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.ios_share_rounded, color: AppColors.lavender, size: 20),
            SizedBox(width: 8),
            Text('Share your booking page', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
          ]),
          const SizedBox(height: 10),
          Text(url.replaceFirst(RegExp(r'^https?://'), ''),
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
          const SizedBox(height: 6),
          Text('Add it to your Instagram bio, WhatsApp status, Google Business profile or email signature.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5, height: 1.4)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primaryDeep, minimumSize: const Size(0, 44)),
                onPressed: () => copyText(context, url, 'Link copied'),
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38), minimumSize: const Size(0, 44)),
                onPressed: () => Browser.shareText('Book with ${Session.instance.workspace?.s('name') ?? 'us'} online: $url', subject: 'Book online'),
                icon: const Icon(Icons.ios_share_rounded, size: 16),
                label: const Text('Share'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
