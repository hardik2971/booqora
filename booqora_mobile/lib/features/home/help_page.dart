import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/browser.dart';
import '../../core/theme.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/mobile.dart';
import 'help_articles.dart';

/// Opens a route from help content: tab routes switch tabs, others are pushed.
void openAppRoute(BuildContext context, String route) {
  final path = Uri.parse(route).path;
  if (const {'/home', '/orders', '/inventory', '/more'}.contains(path)) {
    context.go(route);
  } else {
    context.push(route);
  }
}

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  String _q = '';
  String _cat = 'all';
  String? _open;

  Future<void> _email() async {
    HapticFeedback.lightImpact();
    try {
      await Browser.openUrl('mailto:support@booqora.app?subject=Booqora%20support');
    } catch (_) {
      if (mounted) toast(context, 'Email us at support@booqora.app');
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final rows = helpArticles.where((a) {
      if (_cat != 'all' && a.category != _cat) return false;
      if (q.isEmpty) return true;
      return a.title.toLowerCase().contains(q) ||
          a.summary.toLowerCase().contains(q) ||
          a.category.toLowerCase().contains(q) ||
          a.steps.any((s) => s.toLowerCase().contains(q));
    }).toList();
    final counts = <String, int>{'all': helpArticles.length};
    for (final a in helpArticles) {
      counts[a.category] = (counts[a.category] ?? 0) + 1;
    }

    return MPage(
      title: 'Help center',
      subtitle: 'Guides for every part of Booqora',
      headerHeight: 116,
      header: Column(children: [
        MSearch(hint: 'Search guides', onChanged: (v) => setState(() => _q = v)),
        const SizedBox(height: 10),
        ChoiceChipsBar<String>(
          value: _cat,
          counts: counts,
          options: [('all', 'All'), for (final c in helpCategories.keys) (c, c)],
          onChanged: (v) => setState(() => _cat = v),
        ),
      ]),
      slivers: [
        SPad(
          _AskBoraCard(onAsk: () => context.push('/assistant')).enter(0),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        ),
        if (rows.isEmpty)
          SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No guides found',
              message: 'Try a different search, or ask Bora — it knows Booqora inside out.',
              compact: true,
            ),
          )
        else
          SList(
            count: rows.length,
            builder: (_, i) => _ArticleCard(
              article: rows[i],
              expanded: _open == rows[i].title,
              onToggle: () {
                HapticFeedback.selectionClick();
                setState(() => _open = _open == rows[i].title ? null : rows[i].title);
              },
            ),
          ),
        SPad(
          Group(children: [
            const Row(children: [
              Icon(Icons.support_agent_rounded, color: AppColors.primary),
              SizedBox(width: 10),
              Expanded(child: Text('Still need help?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
            ]),
            const Text('Our support team usually replies within one business day.', style: TextStyle(color: AppColors.muted, height: 1.4)),
            NavRow(icon: Icons.mail_outline_rounded, title: 'Email support', subtitle: 'support@booqora.app', onTap: _email),
            NavRow(
              icon: Icons.auto_awesome,
              title: 'Ask Bora',
              subtitle: 'Instant answers from your AI assistant',
              onTap: () => context.push('/assistant'),
            ),
            NavRow(icon: Icons.rocket_launch_outlined, title: 'Setup guide', subtitle: 'Your onboarding checklist', onTap: () => context.push('/setup')),
          ]),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        ),
      ],
    );
  }
}

class _AskBoraCard extends StatelessWidget {
  final VoidCallback onAsk;
  const _AskBoraCard({required this.onAsk});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: () {
        HapticFeedback.lightImpact();
        onAsk();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppColors.heroGradient,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: AppColors.primaryDeep.withValues(alpha: 0.28), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.auto_awesome, color: AppColors.lavender),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ask Bora anything', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
              SizedBox(height: 2),
              Text('“How do I set a weekend price?”', style: TextStyle(color: Color(0xFFD9CCF8), fontSize: 13, fontStyle: FontStyle.italic)),
            ]),
          ),
          const Icon(Icons.arrow_forward_rounded, color: Colors.white),
        ]),
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  final HelpArticle article;
  final bool expanded;
  final VoidCallback onToggle;
  const _ArticleCard({required this.article, required this.expanded, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final icon = helpCategories[article.category] ?? Icons.help_outline;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: expanded ? AppColors.primary.withValues(alpha: 0.5) : AppColors.border, width: expanded ? 1.4 : 1),
        boxShadow: expanded
            ? const [BoxShadow(color: Color(0x1A6431DD), blurRadius: 18, offset: Offset(0, 6))]
            : const [BoxShadow(color: Color(0x0A1C0938), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.16), AppColors.lavender.withValues(alpha: 0.1)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(article.category.toUpperCase(),
                        style: const TextStyle(fontSize: 10.5, letterSpacing: 0.8, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    const SizedBox(height: 2),
                    Text(article.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(article.summary, style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.35)),
                  ]),
                ),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: const Icon(Icons.expand_more_rounded, color: AppColors.muted),
                ),
              ]),
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: !expanded
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          for (var i = 0; i < article.steps.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(gradient: AppColors.brandGradient, shape: BoxShape.circle),
                                  child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: Text(article.steps[i], style: const TextStyle(height: 1.45, color: AppColors.inkSoft))),
                              ]),
                            ).enterX(i),
                          if (article.route != null) ...[
                            const SizedBox(height: 4),
                            FilledButton.icon(
                              onPressed: () => openAppRoute(context, article.route!),
                              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                              label: Text(article.routeLabel ?? 'Open'),
                            ),
                          ],
                        ]),
                      ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
