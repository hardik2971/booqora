import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../data/session.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/page.dart';
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
      final last = docs.take(30).toList().reversed;
      _msgs.addAll(last.map((d) => _Msg(d.s('role', 'assistant'), d.s('text'), actions: BoraAction.fromList(d['actions']), at: d.created)));
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loading = false);
    _toBottom(jump: true);
  }

  void _toBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      jump ? _scroll.jumpTo(max) : _scroll.animateTo(max, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
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
        Future<BoraReply?>.delayed(const Duration(milliseconds: 650), () => null),
      ]);
      reply = r.first!;
    } catch (e) {
      reply = BoraReply('Something went wrong while answering: ${friendlyError(e)}');
    }
    if (!mounted) return;
    final botMsg = _Msg('assistant', reply.text, actions: reply.actions, fresh: true);
    setState(() {
      _typing = false;
      _msgs.add(botMsg);
    });
    _toBottom();
    _persist(botMsg);
    _focus.requestFocus();
  }

  Future<void> _clear() async {
    final ok = await confirmDialog(context,
        title: 'Clear conversation', message: 'This deletes your chat history with Bora.', confirmLabel: 'Clear', danger: true);
    if (!ok) return;
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

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 700;
    final hPad = narrow ? 16.0 : 28.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Ask Bora',
        subtitle: 'Your rental business assistant',
        actions: [
          if (_msgs.isNotEmpty)
            OutlinedButton.icon(onPressed: _clear, icon: const Icon(Icons.delete_sweep_outlined, size: 18), label: const Text('Clear conversation')),
        ],
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: ListView(
                    controller: _scroll,
                    padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 24),
                    children: [
                      if (_msgs.isEmpty) _Welcome(onPick: _send) else ...[
                        for (var i = 0; i < _msgs.length; i++)
                          _Bubble(
                            msg: _msgs[i],
                            key: ObjectKey(_msgs[i]),
                            animate: _msgs[i].fresh || i >= _msgs.length - 6,
                            onAction: (a) => context.go(a.route),
                          ),
                        if (_typing) const _Typing(),
                      ],
                    ],
                  ),
                ),
              ),
      ),
      Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, 0, hPad, narrow ? 12 : 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (_msgs.isNotEmpty)
                SizedBox(
                  height: 40,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    for (final s in BoraEngine.suggestions)
                      Padding(
                        padding: const EdgeInsets.only(right: 8, bottom: 6),
                        child: ActionChip(
                          label: Text(s, style: const TextStyle(fontSize: 12.5)),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: AppColors.border),
                          onPressed: _typing ? null : () => _send(s),
                        ),
                      ),
                  ]),
                ),
              _InputBar(controller: _input, focus: _focus, busy: _typing, onSend: () => _send()),
            ]),
          ),
        ),
      ),
    ]);
  }
}

// ---------------- Widgets ----------------

class _BoraAvatar extends StatelessWidget {
  final double size;
  const _BoraAvatar({this.size = 34});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.16),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
          boxShadow: const [BoxShadow(color: Color(0x146431DD), blurRadius: 10, offset: Offset(0, 3))],
        ),
        child: AppLogo(mark: true, height: size),
      );
}

class _Welcome extends StatelessWidget {
  final ValueChanged<String> onPick;
  const _Welcome({required this.onPick});

  @override
  Widget build(BuildContext context) {
    final first = Session.instance.displayName.split(' ').first;
    final narrow = MediaQuery.sizeOf(context).width < 700;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: EdgeInsets.all(narrow ? 22 : 32),
        decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(
            right: -40,
            top: -50,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.lavender.withValues(alpha: 0.12)),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 0.9, end: 1.12, duration: 3.seconds, curve: Curves.easeInOut),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _BoraAvatar(size: 56)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(begin: 0, end: -5, duration: 1600.ms, curve: Curves.easeInOut),
            const SizedBox(height: 18),
            Text("Hi $first, I'm Bora 👋",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: narrow ? 24 : 28)),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Text(
                'I can answer questions about your rental business and take you where you need to go.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 15, height: 1.5),
              ),
            ),
          ]),
        ]),
      ).enter(0),
      const SizedBox(height: 22),
      const Text('Try asking', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.inkSoft)).enter(1),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth > 640 ? 2 : 1;
        final w = (c.maxWidth - (cols - 1) * 12) / cols;
        const icons = [
          Icons.receipt_long_outlined,
          Icons.local_shipping_outlined,
          Icons.trending_up,
          Icons.account_balance_wallet_outlined,
          Icons.add_box_outlined,
          Icons.percent,
        ];
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (var i = 0; i < BoraEngine.suggestions.length; i++)
            SizedBox(
              width: w,
              child: HoverLift(
                onTap: () => onPick(BoraEngine.suggestions[i]),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                  child: Row(children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
                      child: Icon(icons[i], size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(BoraEngine.suggestions[i], style: const TextStyle(fontWeight: FontWeight.w600))),
                    const Icon(Icons.arrow_forward, size: 16, color: AppColors.muted),
                  ]),
                ),
              ),
            ).enter(i + 2),
        ]);
      }),
    ]);
  }
}

class _Bubble extends StatelessWidget {
  final _Msg msg;
  final bool animate;
  final ValueChanged<BoraAction> onAction;
  const _Bubble({super.key, required this.msg, required this.animate, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final user = msg.user;
    final maxW = MediaQuery.sizeOf(context).width < 700 ? 0.82 : 0.72;
    final bubble = LayoutBuilder(builder: (context, c) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: c.maxWidth * maxW),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: user ? AppColors.brandGradient : null,
            color: user ? null : Colors.white,
            border: user ? null : Border.all(color: AppColors.border),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(user ? 18 : 4),
              bottomRight: Radius.circular(user ? 4 : 18),
            ),
            boxShadow: [
              BoxShadow(color: user ? const Color(0x336431DD) : const Color(0x0A1C0938), blurRadius: 14, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SelectableText.rich(
              _rich(msg.text, user),
              style: TextStyle(color: user ? Colors.white : AppColors.ink, height: 1.55, fontSize: 14.5),
            ),
            if (msg.actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (var i = 0; i < msg.actions.length; i++)
                  ActionChip(
                    avatar: const Icon(Icons.arrow_outward, size: 14, color: AppColors.primary),
                    label: Text(msg.actions[i].label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primaryDeep)),
                    backgroundColor: AppColors.primarySoft,
                    side: BorderSide.none,
                    onPressed: () => onAction(msg.actions[i]),
                  ).pop(animate ? i + 3 : 0),
              ]),
            ],
          ]),
        ),
      );
    });
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: user ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!user) ...[const _BoraAvatar(), const SizedBox(width: 10)],
          Flexible(child: bubble),
          if (user) ...[const SizedBox(width: 10), Avatar(Session.instance.displayName, size: 34)],
        ],
      ),
    );
    if (!animate) return row;
    return row
        .animate()
        .fadeIn(duration: 300.ms)
        .slideX(begin: user ? 0.06 : -0.06, end: 0, duration: 380.ms, curve: Curves.easeOutCubic)
        .scaleXY(begin: 0.97, end: 1, duration: 380.ms, curve: Curves.easeOutBack, alignment: user ? Alignment.bottomRight : Alignment.bottomLeft);
  }

  /// Minimal **bold** support.
  static TextSpan _rich(String text, bool user) {
    final spans = <TextSpan>[];
    final parts = text.split('**');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      spans.add(TextSpan(
        text: parts[i],
        style: i.isOdd ? TextStyle(fontWeight: FontWeight.w700, color: user ? Colors.white : AppColors.primaryDeep) : null,
      ));
    }
    return TextSpan(children: spans);
  }
}

class _Typing extends StatelessWidget {
  const _Typing();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        const _BoraAvatar(),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomRight: Radius.circular(18),
              bottomLeft: Radius.circular(4),
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: const BoxDecoration(color: AppColors.lavender, shape: BoxShape.circle),
              )
                  .animate(onPlay: (c) => c.repeat())
                  .moveY(begin: 0, end: -5, delay: (i * 140).ms, duration: 300.ms, curve: Curves.easeOut)
                  .then()
                  .moveY(begin: 0, end: 5, duration: 300.ms, curve: Curves.easeIn)
                  .then(delay: ((2 - i) * 140).ms),
          ]),
        ),
      ]).animate().fadeIn(duration: 200.ms),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focus;
  final bool busy;
  final VoidCallback onSend;
  const _InputBar({required this.controller, required this.focus, required this.busy, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: Color(0x146431DD), blurRadius: 24, offset: Offset(0, 8))],
      ),
      child: Row(children: [
        const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focus,
            autofocus: true,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onSend(),
            decoration: const InputDecoration(
              hintText: 'Ask about orders, revenue, stock or setup…',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final enabled = !busy && controller.text.trim().isNotEmpty;
            return AnimatedScale(
              scale: enabled ? 1 : 0.9,
              duration: const Duration(milliseconds: 180),
              child: Container(
                decoration: BoxDecoration(
                  gradient: enabled ? AppColors.brandGradient : null,
                  color: enabled ? null : AppColors.border,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  tooltip: 'Send',
                  onPressed: enabled ? onSend : null,
                  icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
                ),
              ),
            );
          },
        ),
      ]),
    );
  }
}
