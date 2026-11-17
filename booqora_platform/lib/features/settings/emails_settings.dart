import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/table.dart';
import 'settings_kit.dart';

const _contexts = {
  'orders': 'Orders',
  'invoices': 'Invoices',
  'quotes': 'Quotes',
  'contracts': 'Contracts',
  'customers': 'Customers',
};

const _placeholders = ['{{customer.name}}', '{{order.number}}', '{{document.number}}', '{{company.name}}'];

void _insertAtCursor(TextEditingController c, String s) {
  final text = c.text;
  final sel = c.selection;
  final start = sel.isValid ? sel.start : text.length;
  final end = sel.isValid ? sel.end : text.length;
  c.value = TextEditingValue(
    text: text.replaceRange(start, end, s),
    selection: TextSelection.collapsed(offset: start + s.length),
  );
}

class EmailsSettings extends StatefulWidget {
  const EmailsSettings({super.key});

  @override
  State<EmailsSettings> createState() => _EmailsSettingsState();
}

class _EmailsSettingsState extends SettingsState<EmailsSettings> {
  @override
  String get section => 'emails';

  @override
  bool validate() {
    final bad = text('ccAll')
        .text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e))
        .toList();
    final reply = text('replyTo').text.trim();
    if (reply.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(reply)) bad.add(reply);
    if (bad.isNotEmpty) {
      toast(context, 'Invalid email address: ${bad.join(', ')}', error: true);
      return false;
    }
    return true;
  }

  Future<void> _editTemplate([Doc? d]) async {
    final name = TextEditingController(text: d?.s('name') ?? '');
    final subject = TextEditingController(text: d?.s('subject') ?? '');
    final body = TextEditingController(text: d?.s('body') ?? 'Hi {{customer.name}},\n\n\n\nKind regards,\n{{company.name}}');
    var ctx = d?.s('context', 'orders') ?? 'orders';
    if (!_contexts.containsKey(ctx)) ctx = 'orders';
    final ok = await formDialog(
      context: context,
      title: d == null ? 'New email template' : 'Edit email template',
      width: 600,
      body: (c, setS) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Field(label: 'Template name', controller: name, required: true, autofocus: d == null),
        const SizedBox(height: 14),
        DropdownX<String>(
          label: 'Available when viewing',
          value: ctx,
          items: _contexts,
          onChanged: (x) => setS(() => ctx = x ?? ctx),
        ),
        const SizedBox(height: 14),
        Field(label: 'Subject', controller: subject, required: true),
        const SizedBox(height: 14),
        Field(label: 'Body', controller: body, maxLines: 8, required: true),
        const SizedBox(height: 10),
        const Text('Insert placeholder', style: TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final p in _placeholders)
            ActionChip(
              avatar: const Icon(Icons.data_object, size: 14, color: AppColors.primary),
              label: Text(p, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
              visualDensity: VisualDensity.compact,
              onPressed: () => _insertAtCursor(body, p),
            ),
        ]),
      ]),
      onSave: () async {
        final data = {
          'name': name.text.trim(),
          'context': ctx,
          'subject': subject.text.trim(),
          'body': body.text,
        };
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

  @override
  Widget build(BuildContext context) {
    final fromName = text('fromName').text.trim();
    return view(
      title: 'Emails',
      subtitle: 'Control how emails are sent to your customers and which templates your team can use.',
      children: [
        FormSection(
          index: 0,
          title: 'General',
          description: 'Keep a record of everything sent from Booqora.',
          children: [
            Field(
              label: 'Send a copy of all outgoing emails to',
              controller: text('ccAll'),
              hint: 'owner@example.com, bookings@example.com',
              helper: 'Separate multiple addresses with commas.',
            ),
          ],
        ),
        FormSection(
          index: 1,
          title: 'Sending address',
          description: 'How your emails appear in your customer\'s inbox.',
          children: [
            FieldGrid(children: [
              Field(label: 'From name', controller: text('fromName'), hint: 'Your company name'),
              Field(label: 'Reply-to email', controller: text('replyTo'), hint: 'hello@yourcompany.com', keyboardType: TextInputType.emailAddress),
            ]),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              child: Row(children: [
                const Icon(Icons.dns_outlined, color: AppColors.inkSoft, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Custom sending domain', style: TextStyle(fontWeight: FontWeight.w600)),
                    SizedBox(height: 2),
                    Text(
                      'Emails are sent from a Booqora address with your reply-to set. Sending from your own domain requires DNS (SPF/DKIM) verification, which is not set up for this workspace.',
                      style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
                    ),
                  ]),
                ),
                const SizedBox(width: 12),
                const StatusPill('needs_attention', label: 'Not verified'),
              ]),
            ),
            if (fromName.isNotEmpty)
              Text('Preview: "$fromName" <notifications@booqora.app>', style: const TextStyle(color: AppColors.inkSoft, fontSize: 13)),
          ],
        ),
        FormSection(
          index: 2,
          title: 'Header and footer',
          description: 'Added to the top and bottom of every email you send.',
          children: [
            Field(label: 'Header text', controller: text('header'), maxLines: 3),
            Field(label: 'Footer text', controller: text('footer'), maxLines: 3, hint: 'e.g. address, opening hours, social links'),
          ],
        ),
        FormSection(
          index: 3,
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
        FormSection(
          index: 4,
          title: 'Manual email templates',
          description: 'Templates your team can send from orders, documents and customers. Changes are saved immediately.',
          trailing: OutlinedButton.icon(onPressed: () => _editTemplate(), icon: const Icon(Icons.add, size: 18), label: const Text('Add template')),
          children: [
            StreamBuilder<List<Doc>>(
              stream: Db.watch(C.emailTemplates),
              builder: (context, s) {
                if (s.hasError) return ErrorView(s.error!);
                if (!s.hasData) return const LoadingView(rows: 3);
                final rows = s.data!.where((d) => d.s('kind', 'manual') == 'manual').toList()
                  ..sort((a, b) => a.s('name').toLowerCase().compareTo(b.s('name').toLowerCase()));
                return DataTableX<Doc>(
                  rows: rows,
                  idOf: (d) => d.id,
                  noun: 'templates',
                  minWidth: 520,
                  pageSize: 20,
                  onTap: _editTemplate,
                  empty: const EmptyState(icon: Icons.mail_outline, title: 'No templates', message: 'Add a template to send emails faster.', compact: true),
                  columns: [
                    ColumnX('Template', (d) => CellText(d.s('name'), subtitle: d.s('subject')), flex: 3, sort: (d) => d.s('name').toLowerCase()),
                    ColumnX('Available when viewing', (d) => Text(_contexts[d.s('context')] ?? Fmt.label(d.s('context'))), flex: 2,
                        sort: (d) => d.s('context')),
                    ColumnX(
                      'Enabled',
                      (d) => Switch(
                        value: d.b('enabled', true),
                        onChanged: (x) => Db.update(C.emailTemplates, d.id, {'enabled': x}, silent: true),
                      ),
                      width: 80,
                    ),
                    ColumnX(
                      '',
                      (d) => IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.muted),
                        onPressed: () => _deleteTemplate(d),
                      ),
                      width: 48,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        FormSection(
          index: 5,
          title: 'Email log',
          description: 'The 50 most recent emails sent from this workspace.',
          children: [
            StreamBuilder<List<Doc>>(
              stream: Db.watch(C.emailLog, limit: 50),
              builder: (context, s) {
                if (s.hasError) return ErrorView(s.error!);
                if (!s.hasData) return const LoadingView(rows: 3);
                return DataTableX<Doc>(
                  rows: s.data!,
                  idOf: (d) => d.id,
                  noun: 'emails',
                  minWidth: 560,
                  pageSize: 10,
                  empty: const EmptyState(
                      icon: Icons.outbox_outlined, title: 'No emails yet', message: 'Emails you send to customers will appear here.', compact: true),
                  columns: [
                    ColumnX('To', (d) => Text(d.s('to'), overflow: TextOverflow.ellipsis), flex: 2, sort: (d) => d.s('to')),
                    ColumnX('Subject', (d) => Text(d.s('subject'), overflow: TextOverflow.ellipsis), flex: 3),
                    ColumnX('Status', (d) => StatusPill(d.s('status', 'queued')), width: 100, sort: (d) => d.s('status')),
                    ColumnX('Date', (d) => Text(Fmt.dateTime(d.d('createdAt')), style: const TextStyle(fontSize: 13)), width: 150,
                        sort: (d) => d.created),
                  ],
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}
