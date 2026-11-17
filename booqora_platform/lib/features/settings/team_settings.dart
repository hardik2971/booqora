import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue, QuerySnapshot;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../data/session.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/table.dart';
import 'settings_kit.dart';

const _seats = {'trial': 5, 'starter': 3, 'pro': 10, 'business': 25};

class TeamSettings extends StatelessWidget {
  const TeamSettings({super.key});

  Future<void> _invite(BuildContext context, int seatsLeft) async {
    if (seatsLeft <= 0) {
      toast(context, 'No seats left on your plan. Upgrade to invite more people.', error: true);
      return;
    }
    final email = TextEditingController();
    var role = 'member';
    final ok = await formDialog(
      context: context,
      title: 'Invite team member',
      saveLabel: 'Send invite',
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
          onChanged: (r) => setS(() => role = r),
        ),
        const SizedBox(height: 4),
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
    email.dispose();
    if (ok && context.mounted) toast(context, 'Invitation created. They will join automatically when they sign up or sign in with this email.');
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
            return SettingsView(
              title: 'Team — ${members.length} active, $left seats left',
              subtitle: 'Invite colleagues and choose what they can access. Your ${Fmt.label(plan)} plan includes $seats seats.',
              actions: [
                if (s.isAdmin)
                  FilledButton.icon(
                    onPressed: () => _invite(context, left),
                    icon: const Icon(Icons.person_add_alt_1, size: 18),
                    label: const Text('Invite team member'),
                  ),
              ],
              children: [
                if (!s.isAdmin) ...[adminOnly(), const SizedBox(height: 16)],
                _SeatBar(used: used, seats: seats).enter(1),
                const SizedBox(height: 20),
                if (ms.hasError)
                  ErrorView(ms.error!)
                else if (!ms.hasData)
                  const LoadingView(rows: 3)
                else
                  _MembersTable(members: members).enter(2),
                const SizedBox(height: 28),
                SectionTitle('Pending invites', subtitle: 'Invitations waiting for the person to sign up or sign in').enter(3),
                if (invites.isEmpty)
                  AppCard(
                    child: Row(children: const [
                      Icon(Icons.mark_email_read_outlined, color: AppColors.muted),
                      SizedBox(width: 12),
                      Expanded(child: Text('No pending invites', style: TextStyle(color: AppColors.muted))),
                    ]),
                  ).enter(4)
                else
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(children: [
                      for (var i = 0; i < invites.length; i++)
                        _InviteRow(invite: invites[i], last: i == invites.length - 1, canRevoke: s.isAdmin).enter(i),
                    ]),
                  ).enter(4),
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
  const _SeatBar({required this.used, required this.seats});

  @override
  Widget build(BuildContext context) {
    final ratio = seats == 0 ? 1.0 : (used / seats).clamp(0.0, 1.0);
    final color = ratio >= 1 ? AppColors.danger : (ratio > 0.8 ? AppColors.warning : AppColors.primary);
    return AppCard(
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.groups_2_outlined, color: AppColors.primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$used of $seats seats used', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ratio),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: v, minHeight: 8, color: color, backgroundColor: const Color(0xFFEFEBF8)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _MembersTable extends StatelessWidget {
  final List<Doc> members;
  const _MembersTable({required this.members});

  Future<void> _setRole(BuildContext context, Doc m, String role) async {
    try {
      await Db.update(C.members, m.id, {'role': role}, label: m.s('name'));
      if (context.mounted) toast(context, '${m.s('name')} is now ${Fmt.label(role).toLowerCase()}');
    } catch (e) {
      if (context.mounted) toast(context, friendlyError(e), error: true);
    }
  }

  Future<void> _remove(BuildContext context, Doc m) async {
    final ok = await confirmDialog(context,
        title: 'Remove ${m.s('name')}?',
        message: 'They will immediately lose access to this workspace.',
        confirmLabel: 'Remove',
        danger: true);
    if (!ok) return;
    try {
      await Db.remove(C.members, m.id, label: m.s('name'));
      if (context.mounted) toast(context, 'Team member removed');
    } catch (e) {
      if (context.mounted) toast(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser?.uid;
    final owner = Session.instance.isOwner;
    return DataTableX<Doc>(
      rows: members,
      idOf: (d) => d.id,
      noun: 'members',
      minWidth: 680,
      columns: [
        ColumnX('Name', (d) => CellText(d.s('name', 'Unnamed'), subtitle: d.s('email'), leading: Avatar(d.s('name', d.s('email')), size: 34)),
            flex: 3, sort: (d) => d.s('name').toLowerCase()),
        ColumnX('Role', (d) {
          final role = d.s('role', 'member');
          final editable = owner && role != 'owner' && d.id != me;
          if (!editable) {
            return StatusPill(role == 'owner' ? 'active' : (role == 'admin' ? 'scheduled' : 'default'), label: Fmt.label(role), dot: false);
          }
          return PopupMenuButton<String>(
            tooltip: 'Change role',
            onSelected: (r) => _setRole(context, d, r),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'admin', child: Text('Admin')),
              PopupMenuItem(value: 'member', child: Text('Member')),
            ],
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              StatusPill(role == 'admin' ? 'scheduled' : 'default', label: Fmt.label(role), dot: false),
              const Icon(Icons.arrow_drop_down, color: AppColors.muted),
            ]),
          );
        }, flex: 2, sort: (d) => d.s('role')),
        ColumnX('Joined', (d) => Text(Fmt.date(d.d('joinedAt') ?? d.d('createdAt')), style: const TextStyle(color: AppColors.inkSoft)),
            flex: 2, sort: (d) => d.d('joinedAt') ?? DateTime(2000)),
        ColumnX('', (d) {
          final removable = owner && d.s('role') != 'owner' && d.id != me;
          if (!removable) return d.id == me ? const Badge2('You') : const SizedBox.shrink();
          return IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.person_remove_outlined, size: 18, color: AppColors.danger),
            onPressed: () => _remove(context, d),
          );
        }, width: 70, numeric: true),
      ],
    );
  }
}

class _InviteRow extends StatelessWidget {
  final Doc invite;
  final bool last;
  final bool canRevoke;
  const _InviteRow({required this.invite, required this.last, required this.canRevoke});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: Color(0xFFF1EEF7)))),
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(color: AppColors.warningSoft, shape: BoxShape.circle),
          child: const Icon(Icons.schedule_send_outlined, size: 18, color: AppColors.warning),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: CellText(invite.id,
              subtitle: '${Fmt.label(invite.s('role', 'member'))} · invited by ${invite.s('invitedBy')} · ${Fmt.relative(invite.d('createdAt'))}'),
        ),
        if (canRevoke)
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Revoke'),
            onPressed: () async {
              final ok = await confirmDialog(context,
                  title: 'Revoke invite?', message: '${invite.id} will no longer be able to join.', confirmLabel: 'Revoke', danger: true);
              if (!ok) return;
              try {
                await Db.fs.collection(C.invites).doc(invite.id).delete();
                if (context.mounted) toast(context, 'Invite revoked');
              } catch (e) {
                if (context.mounted) toast(context, friendlyError(e), error: true);
              }
            },
          ),
      ]),
    );
  }
}
