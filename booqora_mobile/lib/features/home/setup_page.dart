import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/session.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/mobile.dart';
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
    HapticFeedback.mediumImpact();
    setState(() => _busy.add(s.key));
    try {
      await Session.instance.markOnboarding(s.key);
      if (!mounted) return;
      toast(context, '“${s.title}” marked as done');
      final next = setupSteps.where((x) => !x.done && x.key != s.key).firstOrNull;
      setState(() => _open = next?.key ?? '');
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

    return MPage(
      title: 'Setup guide',
      slivers: [
        SPad(
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [BoxShadow(color: AppColors.primaryDeep.withValues(alpha: 0.3), blurRadius: 26, offset: const Offset(0, 12))],
            ),
            child: Row(children: [
              ProgressRing(done: done, total: total, size: 92),
              const SizedBox(width: 18),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(done == total ? 'You’re all set' : 'Set up your rental business',
                      style: t.titleLarge?.copyWith(color: Colors.white, fontSize: 19, height: 1.25)),
                  const SizedBox(height: 6),
                  Text(
                    done == total
                        ? 'Your workspace is ready to take bookings.'
                        : '${total - done} step${total - done == 1 ? '' : 's'} left. Finish these to start taking bookings with confidence.',
                    style: const TextStyle(color: Color(0xFFD9CCF8), height: 1.45, fontSize: 13),
                  ),
                ]),
              ),
            ]),
          ).enter(0),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
        ),
        SList(
          count: setupSteps.length,
          builder: (_, i) => _StepCard(
            step: setupSteps[i],
            number: i + 1,
            expanded: open == setupSteps[i].key,
            busy: _busy.contains(setupSteps[i].key),
            onToggle: () {
              HapticFeedback.selectionClick();
              setState(() => _open = open == setupSteps[i].key ? '' : setupSteps[i].key);
            },
            onMarkDone: () => _markDone(setupSteps[i]),
          ),
        ),
        SPad(
          Group(children: [
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.support_agent_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Need a hand?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  Text('Browse the guides or ask Bora, your AI assistant.', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                ]),
              ),
            ]),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/help'),
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  label: const Text('Help center'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => context.push('/assistant'),
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Ask Bora'),
                ),
              ),
            ]),
          ]).enter(setupSteps.length + 1),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
        ),
      ],
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
  const _StepCard({required this.step, required this.number, required this.expanded, required this.busy, required this.onToggle, required this.onMarkDone});

  @override
  Widget build(BuildContext context) {
    final done = step.done;
    final t = Theme.of(context).textTheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: expanded ? AppColors.primary.withValues(alpha: 0.55) : AppColors.border, width: expanded ? 1.5 : 1),
        boxShadow: expanded
            ? const [BoxShadow(color: Color(0x1F6431DD), blurRadius: 20, offset: Offset(0, 8))]
            : const [BoxShadow(color: Color(0x0A1C0938), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 380),
                  transitionBuilder: (c, a) => ScaleTransition(scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack), child: c),
                  child: done
                      ? Container(
                          key: const ValueKey('done'),
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                          child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                        )
                      : Container(
                          key: const ValueKey('todo'),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: expanded ? AppColors.brandGradient : null,
                            shape: BoxShape.circle,
                            border: expanded ? null : Border.all(color: AppColors.border, width: 2),
                          ),
                          alignment: Alignment.center,
                          child: Text('$number',
                              style: TextStyle(fontWeight: FontWeight.w800, color: expanded ? Colors.white : AppColors.muted, fontSize: 14)),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      style: (t.titleSmall ?? const TextStyle()).copyWith(
                        fontSize: 15,
                        color: done ? AppColors.muted : AppColors.ink,
                        decoration: done ? TextDecoration.lineThrough : null,
                      ),
                      child: Text(step.title),
                    ),
                    Row(children: [
                      Icon(step.icon, size: 13, color: done ? AppColors.muted : AppColors.primary),
                      const SizedBox(width: 4),
                      Text(done ? 'Completed' : 'Step $number', style: TextStyle(fontSize: 12, color: done ? AppColors.success : AppColors.muted)),
                    ]),
                  ]),
                ),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: const Icon(Icons.expand_more_rounded, color: AppColors.muted),
                ),
              ]),
              AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: expanded
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Text(step.description, style: t.bodyMedium?.copyWith(color: AppColors.inkSoft, height: 1.5)),
                          const SizedBox(height: 14),
                          GradientButton(
                            label: step.action,
                            icon: step.icon,
                            height: 48,
                            onPressed: () => context.push(step.route),
                          ),
                          const SizedBox(height: 8),
                          if (!done)
                            OutlinedButton.icon(
                              onPressed: busy ? null : onMarkDone,
                              icon: busy
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.check_rounded, size: 18),
                              label: const Text('Mark as done'),
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Icon(Icons.verified_rounded, color: AppColors.success, size: 18),
                                SizedBox(width: 6),
                                Text('Completed', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700)),
                              ]),
                            ).animate().fadeIn(duration: 300.ms),
                        ]),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
