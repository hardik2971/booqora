import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/payments.dart';
import '../../data/schema.dart';
import '../../data/session.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/mobile.dart';
import 'settings_kit.dart';

const _contexts = {
  'orders': 'Orders',
  'invoices': 'Invoices',
  'quotes': 'Quotes',
  'contracts': 'Contracts',
  'customers': 'Customers',
};

const _contextIcons = {
  'orders': Icons.receipt_long_outlined,
  'invoices': Icons.request_page_outlined,
  'quotes': Icons.request_quote_outlined,
  'contracts': Icons.handshake_outlined,
  'customers': Icons.people_alt_outlined,
};

const _placeholders = ['{{customer.name}}', '{{order.number}}', '{{document.number}}', '{{company.name}}'];

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

void _insertAtCursor(TextEditingController c, String s) {
  final text = c.text;
  final sel = c.selection;
  final start = sel.isValid ? sel.start : text.length;
  final end = sel.isValid ? sel.end : text.length;
  c.value = TextEditingValue(text: text.replaceRange(start, end, s), selection: TextSelection.collapsed(offset: start + s.length));
}

class EmailsSettings extends StatefulWidget {
  const EmailsSettings({super.key});

  @override
  State<EmailsSettings> createState() => _EmailsSettingsState();
}

class _EmailsSettingsState extends SettingsState<EmailsSettings> {
  @override
  String get section => 'emails';

  bool _testing = false;
  bool _allLog = false;

  @override
  bool validate() {
    final bad = text('ccAll').text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty && !_emailRe.hasMatch(e)).toList();
    final reply = text('replyTo').text.trim();
    if (reply.isNotEmpty && !_emailRe.hasMatch(reply)) bad.add(reply);
    if (bad.isNotEmpty) {
      toast(context, 'Invalid email address: ${bad.join(', ')}', error: true);
      return false;
    }
    return true;
  }

  Future<void> _sendTest() async {
    final to = FirebaseAuth.instance.currentUser?.email ?? Session.instance.user?.email ?? '';
    if (to.isEmpty) {
      toast(context, 'Your account has no email address', error: true);
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _testing = true);
    final company = Session.instance.workspace?.s('name') ?? 'Booqora';
    final header = text('header').text.trim();
    final footer = text('footer').text.trim();
    try {
      await Payments.sendEmail(
        workspaceId: Db.wid,
        to: to,
        subject: 'Test email from $company',
        body: [
          if (header.isNotEmpty) header,
          'Hi ${Session.instance.displayName},',
          'This is a test email sent from the Booqora mobile app to confirm that emails from $company are delivered.',
          'If you can read this, your email settings are working.',
          if (footer.isNotEmpty) footer,
        ].join('\n\n'),
        context: 'general',
      );
      if (mounted) {
        HapticFeedback.mediumImpact();
        toast(context, 'Test email sent to $to');
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _editTemplate([Doc? d]) async {
    final name = TextEditingController(text: d?.s('name') ?? '');
    final subject = TextEditingController(text: d?.s('subject') ?? '');
    final body = TextEditingController(text: d?.s('body') ?? 'Hi {{customer.name}},\n\n\n\nKind regards,\n{{company.name}}');
    var ctx = d?.s('context', 'orders') ?? 'orders';
    if (!_contexts.containsKey(ctx)) ctx = 'orders';
    final ok = await sheetForm(
      context: context,
      title: d == null ? 'New email template' : 'Edit email template',
      body: (c, setS) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Field(label: 'Template name', controller: name, required: true, autofocus: d == null),
        const SizedBox(height: 14),
        DropdownX<String>(label: 'Available when viewing', value: ctx, items: _contexts, onChanged: (x) => setS(() => ctx = x ?? ctx)),
        const SizedBox(height: 14),
        Field(label: 'Subject', controller: subject, required: true),
        const SizedBox(height: 14),
        Field(label: 'Body', controller: body, maxLines: 8, required: true),
        const SizedBox(height: 10),
        const Text('Tap to insert a placeholder', style: TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final p in _placeholders)
            ActionChip(
              avatar: const Icon(Icons.data_object, size: 14, color: AppColors.primary),
              label: Text(p, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
              visualDensity: VisualDensity.compact,
              onPressed: () {
                HapticFeedback.selectionClick();
                _insertAtCursor(body, p);
              },
            ),
        ]),
      ]),
      onSave: () async {
        final data = {'name': name.text.trim(), 'context': ctx, 'subject': subject.text.trim(), 'body': body.text};
        if (d == null) {
          await Db.create(C.emailTemplates, {...data, 'kind': 'manual', 'enabled': true});
        } else {
          await Db.update(C.emailTemplates, d.id, data);
        }
      },
    );
    if (ok && mounted) toast(context, d == null ? 'Template created' : 'Template saved');
  }

  Future<void> _deleteTemplate(Doc d) async {
    final ok = await confirmDialog(context,
        title: 'Delete template?', message: '"${d.s('name')}" will be removed permanently.', confirmLabel: 'Delete', danger: true);
    if (!ok) return;
    await Db.remove(C.emailTemplates, d.id, label: d.s('name'));
    if (mounted) toast(context, 'Template deleted');
  }

  void _showLog(Doc d) {
    showAppSheet<void>(
      context,
      title: d.s('subject', '(no subject)'),
      builder: (c) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [StatusPill(d.s('status', 'queued')), const Spacer(), Text(Fmt.dateTime(d.d('createdAt')), style: const TextStyle(color: AppColors.muted))]),
        const SizedBox(height: 12),
        KV('To', d.s('to')),
        if (d.s('context').isNotEmpty) KV('Context', Fmt.label(d.s('context'))),
        if (d.s('body').isNotEmpty) ...[
          const SizedBox(height: 12),
          SoftBox(child: SelectableText(d.s('body'), style: const TextStyle(height: 1.5))),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fromName = text('fromName').text.trim();
    final me = FirebaseAuth.instance.currentUser?.email ?? '';
    return view(
      title: 'Emails',
      subtitle: 'Control how emails are sent to your customers and which templates your team can use.',
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.forward_to_inbox_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Send a test email', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                Text(me.isEmpty ? 'To your account email' : 'To $me',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
              ]),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primaryDeep),
              onPressed: _testing ? null : _sendTest,
              child: _testing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Send'),
            ),
          ]),
        ),
        SGroup(
          title: 'General',
          description: 'Keep a record of everything sent from Booqora.',
          children: [
            Field(
              label: 'Send a copy of all outgoing emails to',
              controller: text('ccAll'),
              hint: 'owner@example.com, bookings@example.com',
              helper: 'Separate multiple addresses with commas.',
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        SGroup(
          title: 'Sending address',
          description: "How your emails appear in your customer's inbox.",
          children: [
            Field(label: 'From name', controller: text('fromName'), hint: 'Your company name'),
            Field(label: 'Reply-to email', controller: text('replyTo'), hint: 'hello@yourcompany.com', keyboardType: TextInputType.emailAddress),
            if (fromName.isNotEmpty)
              Text('Preview: "$fromName" <notifications@booqora.app>', style: const TextStyle(color: AppColors.inkSoft, fontSize: 13)),
            SoftBox(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                Row(children: [
                  Icon(Icons.dns_outlined, color: AppColors.inkSoft, size: 20),
                  SizedBox(width: 10),
                  Expanded(child: Text('Custom sending domain', style: TextStyle(fontWeight: FontWeight.w600))),
                  StatusPill('needs_attention', label: 'Not verified'),
                ]),
                SizedBox(height: 6),
                Text(
                  'Emails are sent from a Booqora address with your reply-to set. Sending from your own domain requires DNS (SPF/DKIM) verification.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.4),
                ),
              ]),
            ),
          ],
        ),
        SGroup(
          title: 'Header and footer',
          description: 'Added to the top and bottom of every email you send.',
          children: [
            Field(label: 'Header text', controller: text('header'), maxLines: 3),
            Field(label: 'Footer text', controller: text('footer'), maxLines: 3, hint: 'e.g. address, opening hours, social links'),
          ],
        ),
        SGroup(
          title: 'System emails',
          description: 'Sent automatically when customers interact with your online store.',
          children: [
            SwitchTile(
              value: val<bool>('sysOrderConfirmation', true),
              title: 'Online order confirmation',
              subtitle: 'Sent when a customer places an order online.',
              onChanged: (x) => put('sysOrderConfirmation', x),
            ),
            SwitchTile(
              value: val<bool>('sysAccountConfirmation', true),
              title: 'Account confirmation',
              subtitle: 'Sent when a customer creates an account.',
              onChanged: (x) => put('sysAccountConfirmation', x),
            ),
            SwitchTile(
              value: val<bool>('sysPasswordReset', true),
              title: 'Password reset',
              subtitle: 'Sent when a customer requests a new password.',
              onChanged: (x) => put('sysPasswordReset', x),
            ),
          ],
        ),
        SGroup(
          title: 'Manual email templates',
          description: 'Templates your team can send from orders, documents and customers. Saved immediately.',
          children: [
            StreamBuilder<List<Doc>>(
              stream: Db.watch(C.emailTemplates),
              builder: (context, s) {
                if (s.hasError) return ErrorView(s.error!);
                if (!s.hasData) return const LoadingView(rows: 3);
                final rows = s.data!.where((d) => d.s('kind', 'manual') == 'manual').toList()
                  ..sort((a, b) => a.s('name').toLowerCase().compareTo(b.s('name').toLowerCase()));
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (rows.isEmpty)
                    const EmptyState(icon: Icons.mail_outline, title: 'No templates', message: 'Add a template to send emails faster.', compact: true),
                  for (var i = 0; i < rows.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: ListRow(
                        leading: IconBubble(_contextIcons[rows[i].s('context')] ?? Icons.mail_outline, size: 38),
                        title: rows[i].s('name'),
                        subtitle: '${_contexts[rows[i].s('context')] ?? Fmt.label(rows[i].s('context'))} · ${rows[i].s('subject')}',
                        onTap: () => _editTemplate(rows[i]),
                        onLongPress: () => _deleteTemplate(rows[i]),
                        trailing: Switch(
                          value: rows[i].b('enabled', true),
                          onChanged: (x) {
                            HapticFeedback.selectionClick();
                            Db.update(C.emailTemplates, rows[i].id, {'enabled': x}, silent: true);
                          },
                        ),
                      ),
                    ).enter(i, 0.03),
                  const SizedBox(height: 4),
                  AddRowButton(label: 'Add template', onTap: () => _editTemplate()),
                  if (rows.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Tip: long-press a template to delete it.', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                    ),
                ]);
              },
            ),
          ],
        ),
        SGroup(
          title: 'Email log',
          description: 'The 50 most recent emails sent from this workspace.',
          children: [
            StreamBuilder<List<Doc>>(
              stream: Db.watch(C.emailLog, limit: 50),
              builder: (context, s) {
                if (s.hasError) return ErrorView(s.error!);
                if (!s.hasData) return const LoadingView(rows: 3);
                final all = s.data!;
                if (all.isEmpty) {
                  return const EmptyState(
                      icon: Icons.outbox_outlined, title: 'No emails yet', message: 'Emails you send to customers will appear here.', compact: true);
                }
                final rows = _allLog ? all : all.take(8).toList();
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (var i = 0; i < rows.length; i++)
                    ListRow(
                      leading: IconBubble(Icons.outgoing_mail, size: 36, color: statusColors(rows[i].s('status', 'queued')).$1),
                      title: rows[i].s('subject', '(no subject)'),
                      subtitle: '${rows[i].s('to')} · ${Fmt.relative(rows[i].d('createdAt'))}',
                      trailing: StatusPill(rows[i].s('status', 'queued'), dot: false),
                      onTap: () => _showLog(rows[i]),
                    ).enterX(i),
                  if (all.length > rows.length)
                    TextButton(onPressed: () => setState(() => _allLog = true), child: Text('Show all ${all.length}')),
                ]);
              },
            ),
          ],
        ),
      ],
    );
  }
}
