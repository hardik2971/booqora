import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../data/session.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import 'bora_engine.dart';

class _Msg {
  final String role;
  final String text;
  final List<BoraAction> actions;
  final DateTime at;
  final bool fresh;
  _Msg(this.role, this.text, {this.actions = const [], DateTime? at, this.fresh = false}) : at = at ?? DateTime.now();
  bool get user => role == 'user';
}

const _suggestionIcons = [
  Icons.receipt_long_rounded,
  Icons.local_shipping_rounded,
  Icons.trending_up_rounded,
  Icons.account_balance_wallet_rounded,
  Icons.add_box_rounded,
  Icons.percent_rounded,
];

/// Web routes that are bottom-nav tabs on mobile.
const _tabRoutes = {'/': '/home', '/home': '/home', '/orders': '/orders', '/inventory': '/inventory', '/more': '/more'};

class AssistantPage extends StatefulWidget {
  const AssistantPage({super.key});

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  final _engine = BoraEngine();
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final List<_Msg> _msgs = [];
  bool _loading = true;
  bool _typing = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final docs = await Db.list(C.assistantChats); // newest first
      final last = docs.take(30).toList().reversed.toList();
      for (var i = 0; i < last.length; i++) {
        final d = last[i];
        _msgs.add(_Msg(d.s('role', 'assistant'), d.s('text'),
            actions: BoraAction.fromList(d['actions']), at: d.created, fresh: i >= last.length - 4));
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(0, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
    });
  }

  Future<void> _persist(_Msg m) async {
    try {
      await Db.col(C.assistantChats).add({
        'role': m.role,
        'text': m.text,
        if (m.actions.isNotEmpty) 'actions': m.actions.map((a) => a.toMap()).toList(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': FirebaseAuth.instance.currentUser?.uid ?? '',
      });
    } catch (_) {}
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _typing) return;
    HapticFeedback.lightImpact();
    _input.clear();
    final userMsg = _Msg('user', text, fresh: true);
    setState(() {
      _msgs.add(userMsg);
      _typing = true;
    });
    _toBottom();
    _persist(userMsg);
    BoraReply reply;
    try {
      final r = await Future.wait([
        _engine.reply(text),
        Future<BoraReply?>.delayed(const Duration(milliseconds: 750), () => null),
      ]);
      reply = r.first!;
    } catch (e) {
      reply = BoraReply('Something went wrong while answering: ${friendlyError(e)}');
    }
    if (!mounted) return;
    final botMsg = _Msg('assistant', reply.text, actions: reply.actions, fresh: true);
    HapticFeedback.selectionClick();
    setState(() {
      _typing = false;
      _msgs.add(botMsg);
    });
    _toBottom();
    _persist(botMsg);
  }

  Future<void> _clear() async {
    final ok = await confirmDialog(context,
        title: 'Clear conversation', message: 'This deletes your chat history with Bora.', confirmLabel: 'Clear', danger: true);
    if (!ok) return;
    HapticFeedback.mediumImpact();
    setState(() => _msgs.clear());
    try {
      final snap = await Db.col(C.assistantChats).get();
      final batch = Db.fs.batch();
      for (final d in snap.docs.take(450)) {
        batch.delete(d.reference);
      }
      await batch.commit();
      if (mounted) toast(context, 'Conversation cleared');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  void _onAction(BoraAction a) {
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    final tab = _tabRoutes[a.route];
    if (tab != null) {
      context.go(tab);
    } else {
      context.push(a.route);
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final bottomPad = keyboard ? 10.0 : MediaQuery.paddingOf(context).bottom + 10;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        resizeToAvoidBottomInset: true,
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _Header(onBack: _back, onClear: _msgs.isEmpty ? null : _clear, typing: _typing),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusScope.of(context).unfocus(),
              child: _loading
                  ? const Center(child: _BoraOrb(size: 56))
                  : _msgs.isEmpty
                      ? ListView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                          children: [_Welcome(onPick: _send)],
                        )
                      : ListView.builder(
                          controller: _scroll,
                          reverse: true,
                          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          itemCount: _msgs.length + (_typing ? 1 : 0),
                          itemBuilder: (context, i) {
                            if (_typing && i == 0) return const _Typing(key: ValueKey('typing'));
                            final m = _msgs[_msgs.length - 1 - (i - (_typing ? 1 : 0))];
                            return _Bubble(key: ObjectKey(m), msg: m, onAction: _onAction);
                          },
                        ),
            ),
          ),
          if (_msgs.isNotEmpty && !_loading)
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
                itemCount: BoraEngine.suggestions.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _QuickChip(
                  label: BoraEngine.suggestions[i],
                  icon: _suggestionIcons[i % _suggestionIcons.length],
                  onTap: _typing ? null : () => _send(BoraEngine.suggestions[i]),
                ),
              ),
            ),
          _InputBar(controller: _input, focus: _focus, busy: _typing, bottomPad: bottomPad, onSend: () => _send()),
        ]),
      ),
    );
  }
}

// ============================ Header ============================

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback? onClear;
  final bool typing;
  const _Header({required this.onBack, required this.onClear, required this.typing});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(8, top + 6, 8, 16),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [BoxShadow(color: AppColors.primaryDeep.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Row(children: [
        IconButton(
          style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.12)),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: onBack,
        ),
        const SizedBox(width: 10),
        const _BoraOrb(size: 46),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Ask Bora', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 19, letterSpacing: -0.3)),
            const SizedBox(height: 2),
            Row(children: [
              Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF86EFAC), shape: BoxShape.circle))
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .fadeOut(begin: 1, duration: 1100.ms),
              const SizedBox(width: 6),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Text(
                  typing ? 'Bora is typing…' : 'Online · Your rental assistant',
                  key: ValueKey(typing),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5),
                ),
              ),
            ]),
          ]),
        ),
        if (onClear != null)
          IconButton(
            tooltip: 'Clear conversation',
            style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.12)),
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white, size: 20),
            onPressed: onClear,
          ).animate().fadeIn().scaleXY(begin: 0.6, end: 1, curve: Curves.easeOutBack),
      ]),
    );
  }
}

// ============================ Bora orb ============================

/// Animated Bora avatar: rotating gradient ring, breathing glow and the logo mark.
class _BoraOrb extends StatelessWidget {
  final double size;
  final bool animated;
  const _BoraOrb({this.size = 34, this.animated = true});

  @override
  Widget build(BuildContext context) {
    final ring = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(colors: [AppColors.lavender, AppColors.primary, Color(0xFF22D3EE), AppColors.primaryDeep, AppColors.lavender]),
      ),
    );
    final glow = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: AppColors.lavender.withValues(alpha: 0.55), blurRadius: size * 0.45, spreadRadius: size * 0.02)],
      ),
    );
    final core = Container(
      width: size - size * 0.14,
      height: size - size * 0.14,
      padding: EdgeInsets.all(size * 0.16),
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: AppLogo(mark: true, height: size),
    );
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        animated ? glow.animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 0.88, end: 1.08, duration: 1600.ms, curve: Curves.easeInOut) : glow,
        animated ? ring.animate(onPlay: (c) => c.repeat()).rotate(duration: 3200.ms) : ring,
        core,
      ]),
    );
  }
}

// ============================ Welcome ============================

class _Welcome extends StatelessWidget {
  final ValueChanged<String> onPick;
  const _Welcome({required this.onPick});

  @override
  Widget build(BuildContext context) {
    final first = Session.instance.displayName.split(' ').first;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.border),
          boxShadow: const [BoxShadow(color: Color(0x146431DD), blurRadius: 30, offset: Offset(0, 12))],
        ),
        child: Column(children: [
          const _BoraOrb(size: 76).animate(onPlay: (c) => c.repeat(reverse: true)).moveY(begin: 0, end: -6, duration: 1700.ms, curve: Curves.easeInOut),
          const SizedBox(height: 18),
          Text("Hi $first, I'm Bora 👋",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.4)),
          const SizedBox(height: 8),
          const Text(
            'Ask me about orders, revenue, stock or customers — I answer with your live data and take you where you need to go.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 14, height: 1.5),
          ),
        ]),
      ).enter(0),
      const SizedBox(height: 22),
      const Padding(
        padding: EdgeInsets.only(left: 4),
        child: Text('TRY ASKING', style: TextStyle(fontSize: 12, letterSpacing: 0.8, fontWeight: FontWeight.w700, color: AppColors.muted)),
      ).enter(1),
      const SizedBox(height: 10),
      SizedBox(
        height: 132,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          physics: const BouncingScrollPhysics(),
          itemCount: BoraEngine.suggestions.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, i) => _SuggestionCard(
            text: BoraEngine.suggestions[i],
            icon: _suggestionIcons[i % _suggestionIcons.length],
            onTap: () => onPick(BoraEngine.suggestions[i]),
          ).enterX(i + 2, 0.15),
        ),
      ),
    ]);
  }
}

class _SuggestionCard extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onTap;
  const _SuggestionCard({required this.text, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: const [BoxShadow(color: Color(0x0D1C0938), blurRadius: 14, offset: Offset(0, 6))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
          const Spacer(),
          Text(text, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, height: 1.3, color: AppColors.ink)),
        ]),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  const _QuickChip({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
          ]),
        ),
      ),
    );
  }
}

// ============================ Bubbles ============================

class _Bubble extends StatelessWidget {
  final _Msg msg;
  final ValueChanged<BoraAction> onAction;
  const _Bubble({super.key, required this.msg, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final user = msg.user;
    final maxW = MediaQuery.sizeOf(context).width * 0.8;
    final bubble = GestureDetector(
      onLongPress: () async {
        HapticFeedback.mediumImpact();
        await Clipboard.setData(ClipboardData(text: msg.text.replaceAll('**', '')));
        if (context.mounted) toast(context, 'Message copied');
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: BoxDecoration(
            gradient: user ? AppColors.brandGradient : null,
            color: user ? null : Colors.white,
            border: user ? null : Border.all(color: AppColors.border),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(user ? 20 : 6),
              bottomRight: Radius.circular(user ? 6 : 20),
            ),
            boxShadow: [
              BoxShadow(color: user ? const Color(0x406431DD) : const Color(0x0D1C0938), blurRadius: 16, offset: const Offset(0, 6)),
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(
              _rich(msg.text, user),
              style: TextStyle(color: user ? Colors.white : AppColors.ink, height: 1.5, fontSize: 14.5),
            ),
            if (msg.actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (var i = 0; i < msg.actions.length; i++)
                  _ActionChip(action: msg.actions[i], onTap: () => onAction(msg.actions[i])).pop(msg.fresh ? i + 4 : 0),
              ]),
            ],
          ]),
        ),
      ),
    );
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: user ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!user) ...[const _BoraOrb(size: 30, animated: false), const SizedBox(width: 8)],
          Flexible(child: bubble),
        ],
      ),
    );
    if (!msg.fresh) return row;
    return row
        .animate()
        .fadeIn(duration: 280.ms)
        .slideY(begin: 0.25, end: 0, duration: 420.ms, curve: Curves.easeOutCubic)
        .scaleXY(begin: 0.92, end: 1, duration: 420.ms, curve: Curves.easeOutBack, alignment: user ? Alignment.bottomRight : Alignment.bottomLeft);
  }

  /// Minimal **bold** support.
  static TextSpan _rich(String text, bool user) {
    final spans = <TextSpan>[];
    final parts = text.split('**');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      spans.add(TextSpan(
        text: parts[i],
        style: i.isOdd ? TextStyle(fontWeight: FontWeight.w800, color: user ? Colors.white : AppColors.primaryDeep) : null,
      ));
    }
    return TextSpan(children: spans);
  }
}

class _ActionChip extends StatelessWidget {
  final BoraAction action;
  final VoidCallback onTap;
  const _ActionChip({required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(action.label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primaryDeep)),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_outward_rounded, size: 14, color: AppColors.primary),
        ]),
      ),
    );
  }
}

// ============================ Typing ============================

class _Typing extends StatefulWidget {
  const _Typing({super.key});

  @override
  State<_Typing> createState() => _TypingState();
}

class _TypingState extends State<_Typing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        const _BoraOrb(size: 30),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomRight: Radius.circular(20),
              bottomLeft: Radius.circular(6),
            ),
          ),
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) => Row(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < 3; i++) _dot(i),
            ]),
          ),
        ),
      ]),
    ).animate().fadeIn(duration: 220.ms).slideY(begin: 0.3, end: 0, duration: 300.ms, curve: Curves.easeOutCubic);
  }

  Widget _dot(int i) {
    // Each dot bounces during its own slice of the cycle.
    final t = (_c.value - i * 0.16) % 1.0;
    final bounce = t < 0.4 ? math.sin(t / 0.4 * math.pi) : 0.0;
    return Transform.translate(
      offset: Offset(0, -7 * bounce),
      child: Container(
        width: 8,
        height: 8,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: Color.lerp(AppColors.lavender, AppColors.primary, bounce),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ============================ Input bar ============================

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focus;
  final bool busy;
  final double bottomPad;
  final VoidCallback onSend;
  const _InputBar({required this.controller, required this.focus, required this.busy, required this.bottomPad, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, bottomPad),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [BoxShadow(color: Color(0x101C0938), blurRadius: 18, offset: Offset(0, -6))],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.only(left: 14, right: 6),
            decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.border)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focus,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: const InputDecoration(
                    hintText: 'Ask Bora anything…',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final enabled = !busy && controller.text.trim().isNotEmpty;
            return PressScale(
              onTap: enabled ? onSend : null,
              scale: 0.88,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: enabled ? AppColors.brandGradient : null,
                  color: enabled ? null : AppColors.border,
                  shape: BoxShape.circle,
                  boxShadow: enabled ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 5))] : null,
                ),
                child: AnimatedRotation(
                  turns: enabled ? 0 : -0.125,
                  duration: const Duration(milliseconds: 220),
                  child: busy
                      ? const Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.arrow_upward_rounded, color: Colors.white),
                ),
              ),
            );
          },
        ),
      ]),
    );
  }
}
