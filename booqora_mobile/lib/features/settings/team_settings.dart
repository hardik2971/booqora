import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue, QuerySnapshot;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../data/session.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/mobile.dart';
import 'settings_kit.dart';

const _seats = {'trial': 5, 'starter': 3, 'pro': 10, 'business': 25};

class TeamSettings extends StatelessWidget {
  const TeamSettings({super.key});

  Future<void> _invite(BuildContext context, int seatsLeft) async {
    if (seatsLeft <= 0) {
      HapticFeedback.heavyImpact();
      toast(context, 'No seats left on your plan. Upgrade to invite more people.', error: true);
      return;
    }
    final email = TextEditingController();
    var role = 'member';
    final ok = await sheetForm(
      context: context,
      title: 'Invite team member',
      saveLabel: 'Send invite',
      saveIcon: Icons.send_rounded,
      body: (c, setS) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Field(
          label: 'Email',
          controller: email,
          required: true,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          validator: (v) {
            final s = (v ?? '').trim();
            if (s.isEmpty) return 'Is a required field';
            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) return 'Enter a valid email address';
            return null;
          },
        ),
        const SizedBox(height: 16),
        const FieldLabel('Role'),
        RadioCards<String>(
          value: role,
          options: const [
            ('member', 'Member', 'Can manage orders, customers and inventory.'),
            ('admin', 'Admin', 'Full access, including settings and team management.'),
          ],
          onChanged: (r) {
            HapticFeedback.selectionClick();
            setS(() => role = r);
          },
        ),
        const InfoBanner('They will join automatically when they sign up or sign in with this email.', tone: Tone.brand),
      ]),
      onSave: () async {
        final e = email.text.trim().toLowerCase();
        await Db.fs.collection(C.invites).doc(e).set({
          'workspaceId': Db.wid,
          'workspaceName': Session.instance.workspace?.s('name') ?? '',
          'role': role,
          'invitedBy': Session.instance.displayName,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await Session.instance.markOnboarding('team');
      },
    );
    if (ok && context.mounted) toast(context, 'Invitation created. They join automatically when they sign in with this email.');
  }

  @override
  Widget build(BuildContext context) {
    final s = Session.instance;
    final plan = s.workspace?.s('plan', 'trial') ?? 'trial';
    final seats = _seats[plan] ?? 5;
    return StreamBuilder<List<Doc>>(
      stream: Db.watch(C.members, orderBy: 'joinedAt', desc: false),
      builder: (context, ms) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: Db.fs.collection(C.invites).where('workspaceId', isEqualTo: Db.wid).snapshots(),
          builder: (context, inv) {
            final members = (ms.data ?? []).where((m) => m.b('active', true)).toList();
            final invites = (inv.data?.docs ?? []).map(Doc.of).toList();
            final used = members.length + invites.length;
            final left = (seats - used).clamp(0, 999);
            return MPage(
              title: 'Team',
              subtitle: '${members.length} active · $left seat${left == 1 ? '' : 's'} left',
              showBack: true,
              fab: s.isAdmin
                  ? FloatingActionButton.extended(
                      onPressed: () => _invite(context, left),
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Invite'),
                    ).pop()
                  : null,
              slivers: [
                if (!s.isAdmin) SPad(adminOnly()),
                SPad(_SeatBar(used: used, seats: seats, plan: plan).enter(0)),
                const SPad(SectionLabel('Members')),
                if (ms.hasError)
                  SPad(ErrorView(ms.error!))
                else if (!ms.hasData)
                  const SPad(LoadingView(rows: 3))
                else
                  SList(count: members.length, builder: (context, i) => _MemberTile(member: members[i])),
                SPad(SectionLabel('Pending invites', trailing: invites.isEmpty ? null : Badge2('${invites.length}', color: AppColors.warning))),
                if (invites.isEmpty)
                  const SPad(
                    Group(children: [
                      Row(children: [
                        Icon(Icons.mark_email_read_outlined, color: AppColors.muted),
                        SizedBox(width: 12),
                        Expanded(child: Text('No pending invites', style: TextStyle(color: AppColors.muted))),
                      ]),
                    ]),
                  )
                else
                  SList(count: invites.length, builder: (context, i) => _InviteTile(invite: invites[i], canRevoke: s.isAdmin)),
              ],
            );
          },
        );
      },
    );
  }
}

class _SeatBar extends StatelessWidget {
  final int used;
  final int seats;
  final String plan;
  const _SeatBar({required this.used, required this.seats, required this.plan});

  @override
  Widget build(BuildContext context) {
    final ratio = seats == 0 ? 1.0 : (used / seats).clamp(0.0, 1.0);
    final color = ratio >= 1 ? const Color(0xFFFCA5A5) : (ratio > 0.8 ? const Color(0xFFFCD34D) : AppColors.lavender);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: AppColors.primaryDeep.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.groups_2_outlined, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$used of $seats seats used', style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 16)),
            Text('${Fmt.label(plan)} plan', style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
            const SizedBox(height: 10),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ratio),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: v, minHeight: 8, color: color, backgroundColor: Colors.white.withValues(alpha: 0.15)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final Doc member;
  const _MemberTile({required this.member});

  Future<void> _setRole(BuildContext context, String role) async {
    try {
      await Db.update(C.members, member.id, {'role': role}, label: member.s('name'));
      if (context.mounted) toast(context, '${member.s('name')} is now ${Fmt.label(role).toLowerCase()}');
    } catch (e) {
      if (context.mounted) toast(context, friendlyError(e), error: true);
    }
  }

  Future<void> _remove(BuildContext context) async {
    final ok = await confirmDialog(context,
        title: 'Remove ${member.s('name')}?', message: 'They will immediately lose access to this workspace.', confirmLabel: 'Remove', danger: true);
    if (!ok) return;
    try {
      await Db.remove(C.members, member.id, label: member.s('name'));
      if (context.mounted) toast(context, 'Team member removed');
    } catch (e) {
      if (context.mounted) toast(context, friendlyError(e), error: true);
    }
  }

  Future<void> _actions(BuildContext context) async {
    final role = member.s('role', 'member');
    final a = await showActionSheet<String>(context, title: member.s('name', member.s('email')), actions: [
      if (role != 'admin') ('admin', Icons.admin_panel_settings_outlined, 'Make admin', false),
      if (role != 'member') ('member', Icons.person_outline, 'Make member', false),
      ('remove', Icons.person_remove_outlined, 'Remove from team', true),
    ]);
    if (!context.mounted || a == null) return;
    if (a == 'remove') return _remove(context);
    await _setRole(context, a);
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser?.uid;
    final role = member.s('role', 'member');
    final editable = Session.instance.isOwner && role != 'owner' && member.id != me;
    final pill = StatusPill(role == 'owner' ? 'active' : (role == 'admin' ? 'scheduled' : 'default'), label: Fmt.label(role), dot: false);
    return MTile(
      leading: Avatar(member.s('name', member.s('email')), size: 44),
      title: '${member.s('name', 'Unnamed')}${member.id == me ? ' (you)' : ''}',
      subtitle: '${member.s('email')}\nJoined ${Fmt.date(member.d('joinedAt') ?? member.d('createdAt'))}',
      trailing: editable ? Row(mainAxisSize: MainAxisSize.min, children: [pill, const Icon(Icons.more_vert_rounded, color: AppColors.muted)]) : pill,
      onTap: editable ? () => _actions(context) : null,
    );
  }
}

class _InviteTile extends StatelessWidget {
  final Doc invite;
  final bool canRevoke;
  const _InviteTile({required this.invite, required this.canRevoke});

  Future<void> _revoke(BuildContext context) async {
    final ok = await confirmDialog(context, title: 'Revoke invite?', message: '${invite.id} will no longer be able to join.', confirmLabel: 'Revoke', danger: true);
    if (!ok) return;
    try {
      await Db.fs.collection(C.invites).doc(invite.id).delete();
      if (context.mounted) toast(context, 'Invite revoked');
    } catch (e) {
      if (context.mounted) toast(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MTile(
      leading: const IconBubble(Icons.schedule_send_outlined, color: AppColors.warning, size: 44),
      title: invite.id,
      subtitle: '${Fmt.label(invite.s('role', 'member'))} · invited by ${invite.s('invitedBy')} · ${Fmt.relative(invite.d('createdAt'))}',
      trailing: canRevoke
          ? IconButton(
              tooltip: 'Revoke',
              icon: const Icon(Icons.close_rounded, color: AppColors.danger),
              onPressed: () => _revoke(context),
            )
          : null,
    );
  }
}
