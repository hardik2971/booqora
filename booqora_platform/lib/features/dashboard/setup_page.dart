import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/session.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/page.dart';
import 'setup_steps.dart';

class SetupPage extends StatefulWidget {
  const SetupPage({super.key});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  String? _open;
  final Set<String> _busy = {};

  Future<void> _markDone(SetupStep s) async {
    setState(() => _busy.add(s.key));
    try {
      await Session.instance.markOnboarding(s.key);
      if (!mounted) return;
      toast(context, '“${s.title}” marked as done');
      final next = setupSteps.where((x) => !x.done && x.key != s.key).firstOrNull;
      setState(() => _open = next?.key);
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(s.key));
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<Session>();
    final done = setupDoneCount;
    final total = setupSteps.length;
    final open = _open ?? setupSteps.where((s) => !s.done).firstOrNull?.key;
    final t = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(title: 'Setup guide', breadcrumbs: [('Dashboard', '/')]),
        Expanded(
          child: PageBody(
            maxWidth: 920,
            children: [
              AppCard(
                gradient: AppColors.heroGradient,
                padding: const EdgeInsets.all(24),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final ring = ProgressRing(done: done, total: total, size: 96);
                    final text = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Set up your rental business', style: t.titleLarge?.copyWith(color: Colors.white, fontSize: 22)),
                        const SizedBox(height: 6),
                        Text(
                          done == total
                              ? 'All done — your workspace is ready to take bookings.'
                              : '$done of $total steps complete. Finish these to start taking bookings with confidence.',
                          style: const TextStyle(color: Color(0xFFD9CCF8), height: 1.5),
                        ),
                      ],
                    );
                    if (c.maxWidth < 480) {
                      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ring, const SizedBox(height: 16), text]);
                    }
                    return Row(
                      children: [
                        ring,
                        const SizedBox(width: 24),
                        Expanded(child: text),
                      ],
                    );
                  },
                ),
              ).enter(0),
              const SizedBox(height: 20),
              for (var i = 0; i < setupSteps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _StepCard(
                    step: setupSteps[i],
                    number: i + 1,
                    expanded: open == setupSteps[i].key,
                    busy: _busy.contains(setupSteps[i].key),
                    onToggle: () => setState(() => _open = open == setupSteps[i].key ? '' : setupSteps[i].key),
                    onMarkDone: () => _markDone(setupSteps[i]),
                  ).enter(i + 1),
                ),
              const SizedBox(height: 12),
              AppCard(
                child: Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.support_agent_rounded, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Need help?', style: t.titleSmall),
                            const Text('Browse guides or ask Bora, your AI assistant.', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => context.go('/help'),
                          icon: const Icon(Icons.menu_book_outlined, size: 18),
                          label: const Text('Help Center'),
                        ),
                        FilledButton.icon(
                          onPressed: () => context.go('/assistant'),
                          icon: const Icon(Icons.auto_awesome, size: 18),
                          label: const Text('Ask Bora'),
                        ),
                      ],
                    ),
                  ],
                ),
              ).enter(setupSteps.length + 1),
            ],
          ),
        ),
      ],
    );
  }
}

/// Circular progress ring with a centered "x/y" label.
class ProgressRing extends StatelessWidget {
  final int done;
  final int total;
  final double size;
  final bool light;
  const ProgressRing({super.key, required this.done, required this.total, this.size = 88, this.light = true});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : done / total;
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: pct),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Stack(
          fit: StackFit.expand,
          children: [
            CircularProgressIndicator(
              value: v,
              strokeWidth: size / 11,
              strokeCap: StrokeCap.round,
              color: light ? AppColors.lavender : AppColors.primary,
              backgroundColor: light ? Colors.white.withValues(alpha: 0.14) : AppColors.primarySoft,
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(v * 100).round()}%',
                    style: TextStyle(color: light ? Colors.white : AppColors.ink, fontWeight: FontWeight.w800, fontSize: size / 4.6),
                  ),
                  Text(
                    '$done of $total',
                    style: TextStyle(color: light ? Colors.white70 : AppColors.muted, fontSize: size / 9),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final SetupStep step;
  final int number;
  final bool expanded;
  final bool busy;
  final VoidCallback onToggle;
  final VoidCallback onMarkDone;
  const _StepCard({
    required this.step,
    required this.number,
    required this.expanded,
    required this.busy,
    required this.onToggle,
    required this.onMarkDone,
  });

  @override
  Widget build(BuildContext context) {
    final done = step.done;
    final t = Theme.of(context).textTheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: expanded ? AppColors.primary.withValues(alpha: 0.5) : AppColors.border, width: expanded ? 1.4 : 1),
        boxShadow: expanded ? const [BoxShadow(color: Color(0x146431DD), blurRadius: 18, offset: Offset(0, 6))] : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      transitionBuilder: (c, a) => ScaleTransition(
                        scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
                        child: c,
                      ),
                      child: done
                          ? Container(
                              key: const ValueKey('done'),
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                              child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                            )
                          : Container(
                              key: const ValueKey('todo'),
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.border, width: 2),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '$number',
                                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.muted, fontSize: 13),
                              ),
                            ),
                    ),
                    const SizedBox(width: 14),
                    Icon(step.icon, size: 20, color: done ? AppColors.muted : AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 250),
                        style: (t.titleSmall ?? const TextStyle()).copyWith(
                          color: done ? AppColors.muted : AppColors.ink,
                          decoration: done ? TextDecoration.lineThrough : null,
                        ),
                        child: Text(step.title),
                      ),
                    ),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: const Icon(Icons.expand_more_rounded, color: AppColors.muted),
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  child: expanded
                      ? Padding(
                          padding: const EdgeInsets.only(left: 46, top: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(step.description, style: t.bodyMedium?.copyWith(color: AppColors.inkSoft, height: 1.5)),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  FilledButton(onPressed: () => context.go(step.route), child: Text(step.action)),
                                  if (!done)
                                    OutlinedButton.icon(
                                      onPressed: busy ? null : onMarkDone,
                                      icon: busy
                                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                          : const Icon(Icons.check_rounded, size: 18),
                                      label: const Text('Mark as done'),
                                    ),
                                  if (done)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.verified_rounded, color: AppColors.success, size: 18),
                                          SizedBox(width: 6),
                                          Text(
                                            'Completed',
                                            style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ).animate().fadeIn(duration: 300.ms),
                                ],
                              ),
                            ],
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
