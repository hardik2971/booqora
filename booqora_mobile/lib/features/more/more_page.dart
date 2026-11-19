import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/browser.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/session.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/mobile.dart';

const appVersion = '1.0.0 (1)';

class _Module {
  final String label;
  final IconData icon;
  final String route;
  final List<Color> colors;
  const _Module(this.label, this.icon, this.route, this.colors);
}

const _modules = [
  _Module('Calendar', Icons.calendar_month_rounded, '/calendar', [Color(0xFF60A5FA), Color(0xFF2563EB)]),
  _Module('Customers', Icons.people_alt_rounded, '/customers', [Color(0xFFF472B6), Color(0xFFDB2777)]),
  _Module('Coupons', Icons.local_offer_rounded, '/coupons', [Color(0xFFFBBF24), Color(0xFFD97706)]),
  _Module('Documents', Icons.description_rounded, '/documents', [Color(0xFF34D399), Color(0xFF059669)]),
  _Module('Online store', Icons.storefront_rounded, '/online-store', [Color(0xFFA78BFA), Color(0xFF6431DD)]),
  _Module('Reports', Icons.insights_rounded, '/reports', [Color(0xFF22D3EE), Color(0xFF0E7490)]),
  _Module('Apps', Icons.extension_rounded, '/apps', [Color(0xFFFB923C), Color(0xFFEA580C)]),
  _Module('Ask Bora', Icons.auto_awesome_rounded, '/assistant', [Color(0xFF7B3FF2), Color(0xFF351DB1)]),
];

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  String get _storeUrl => '${Browser.origin}/s/${Session.instance.workspace?.s('slug') ?? ''}';

  Future<void> _signOut(BuildContext context) async {
    final ok = await confirmDialog(context,
        title: 'Sign out?', message: 'You will need to sign in again to access your workspace.', confirmLabel: 'Sign out', danger: true);
    if (!ok) return;
    HapticFeedback.mediumImpact();
    await Session.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Session.instance,
      builder: (context, _) {
        final s = Session.instance;
        final hasSlug = (s.workspace?.s('slug') ?? '').isNotEmpty;
        return MPage(
          title: 'More',
          slivers: [
            SPad(_ProfileCard(onTap: () => context.push('/profile')).enter(0), padding: const EdgeInsets.fromLTRB(16, 4, 16, 6)),
            const SPad(SectionLabel('Modules')),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 10,
                  mainAxisExtent: 96,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _ModuleTile(_modules[i]).pop(i + 1),
                  childCount: _modules.length,
                ),
              ),
            ),
            const SPad(SectionLabel('Workspace'), padding: EdgeInsets.fromLTRB(16, 14, 16, 0)),
            SPad(
              Group(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), children: [
                NavRow(
                  icon: Icons.settings_rounded,
                  color: const Color(0xFF475569),
                  title: 'Settings',
                  subtitle: 'Business, payments, team and more',
                  onTap: () => context.push('/settings'),
                ),
                NavRow(
                  icon: Icons.rocket_launch_rounded,
                  color: AppColors.primary,
                  title: 'Setup guide',
                  subtitle: 'Finish setting up your workspace',
                  onTap: () => context.push('/setup'),
                ),
                NavRow(
                  icon: Icons.help_rounded,
                  color: AppColors.info,
                  title: 'Help',
                  subtitle: 'Guides, FAQs and support',
                  onTap: () => context.push('/help'),
                ),
              ]).enter(10),
            ),
            const SPad(SectionLabel('Online store')),
            SPad(
              Group(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), children: [
                NavRow(
                  icon: Icons.open_in_new_rounded,
                  color: AppColors.success,
                  title: 'View online store',
                  subtitle: hasSlug ? _storeUrl.replaceFirst('https://', '') : 'Store link not available yet',
                  trailing: const Icon(Icons.arrow_outward_rounded, size: 18, color: AppColors.muted),
                  onTap: () {
                    if (!hasSlug) return toast(context, 'Your store link is not available yet', error: true);
                    Browser.openUrl(_storeUrl);
                  },
                ),
                NavRow(
                  icon: Icons.ios_share_rounded,
                  color: const Color(0xFFDB2777),
                  title: 'Share store link',
                  subtitle: 'Send your booking page to customers',
                  trailing: const Icon(Icons.share_rounded, size: 18, color: AppColors.muted),
                  onTap: () {
                    if (!hasSlug) return toast(context, 'Your store link is not available yet', error: true);
                    Browser.shareText('Book with ${s.workspace?.s('name') ?? 'us'} online: $_storeUrl', subject: s.workspace?.s('name'));
                  },
                ),
              ]).enter(11),
            ),
            const SPad(SectionLabel('App')),
            SPad(
              Group(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), children: [
                NavRow(
                  icon: Icons.info_rounded,
                  color: AppColors.muted,
                  title: 'App version',
                  subtitle: 'Booqora for mobile',
                  trailing: const Text(appVersion, style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'Booqora',
                      applicationVersion: appVersion,
                      applicationIcon: const AppLogo(mark: true, height: 40),
                      applicationLegalese: 'Rental management for growing businesses.',
                    );
                  },
                ),
                NavRow(
                  icon: Icons.logout_rounded,
                  color: AppColors.danger,
                  title: 'Sign out',
                  subtitle: s.user?.email,
                  trailing: const SizedBox.shrink(),
                  onTap: () => _signOut(context),
                ),
              ]).enter(12),
            ),
            SPad(
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Column(children: [
                  const AppLogo(mark: true, height: 28),
                  const SizedBox(height: 6),
                  Text('Booqora $appVersion', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                ]),
              ).enter(13),
            ),
          ],
        );
      },
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final VoidCallback onTap;
  const _ProfileCard({required this.onTap});

  String _planLabel(Session s) {
    final plan = s.workspace?.s('plan', 'trial') ?? 'trial';
    if (plan != 'trial') return '${Fmt.label(plan)} plan';
    final ends = s.workspace?.d('trialEndsAt');
    if (ends == null) return 'Free trial';
    final h = ends.difference(DateTime.now()).inHours;
    if (h <= 0) return 'Trial ended';
    final d = (h / 24).ceil();
    return 'Trial · $d day${d == 1 ? '' : 's'} left';
  }

  @override
  Widget build(BuildContext context) {
    final s = Session.instance;
    final avatar = s.profile?.s('avatarUrl') ?? '';
    final plan = s.workspace?.s('plan', 'trial') ?? 'trial';
    final trialEnded = plan == 'trial' && (s.workspace?.d('trialEndsAt')?.isBefore(DateTime.now()) ?? false);
    return PressScale(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.heroGradient,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [BoxShadow(color: AppColors.primaryDeep.withValues(alpha: 0.32), blurRadius: 26, offset: const Offset(0, 12))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          Positioned(
            right: -40,
            top: -50,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.lavender.withValues(alpha: 0.14)),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -60,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.06)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [AppColors.lavender, Colors.white])),
                  child: Avatar(s.displayName, url: avatar, size: 58),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.displayName,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(s.workspace?.s('name') ?? '',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 13.5)),
                  ]),
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), shape: BoxShape.circle),
                  child: const Icon(Icons.chevron_right_rounded, color: Colors.white),
                ),
              ]),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 6, children: [
                _Chip(icon: Icons.verified_user_rounded, text: Fmt.label(s.role)),
                _Chip(
                  icon: plan == 'trial' ? Icons.hourglass_bottom_rounded : Icons.workspace_premium_rounded,
                  text: _planLabel(s),
                  highlight: trialEnded,
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool highlight;
  const _Chip({required this.icon, required this.text, this.highlight = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: highlight ? AppColors.warning.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      );
}

class _ModuleTile extends StatelessWidget {
  final _Module m;
  const _ModuleTile(this.m);

  @override
  Widget build(BuildContext context) {
    return PressScale(
      scale: 0.92,
      onTap: () {
        HapticFeedback.lightImpact();
        context.push(m.route);
      },
      child: Column(children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: m.colors),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: m.colors.last.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6))],
          ),
          child: Stack(children: [
            Positioned(
              left: 6,
              top: 4,
              child: Container(
                width: 22,
                height: 10,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(6)),
              ),
            ),
            Center(child: Icon(m.icon, color: Colors.white, size: 27)),
          ]),
        ),
        const SizedBox(height: 8),
        Text(m.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink)),
      ]),
    );
  }
}
