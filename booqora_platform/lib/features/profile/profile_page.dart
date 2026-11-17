import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/session.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/page.dart';

const _locales = {
  'en': 'English',
  'en-IN': 'English (India)',
  'en-GB': 'English (UK)',
  'hi': 'हिन्दी (Hindi)',
  'es': 'Español',
  'fr': 'Français',
  'de': 'Deutsch',
  'ar': 'العربية',
};

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  late String _locale;
  bool _dirty = false;
  bool _saving = false;

  final _pwKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _pwBusy = false;
  bool _verifyBusy = false;

  Session get s => Session.instance;
  User? get user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    final parts = s.displayName.trim().split(RegExp(r'\s+'));
    _first.text = parts.isEmpty ? '' : parts.first;
    _last.text = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    _locale = s.profile?.s('locale', 'en') ?? 'en';
    if (!_locales.containsKey(_locale)) _locale = 'en';
    void mark() {
      if (!_dirty) setState(() => _dirty = true);
    }

    _first.addListener(mark);
    _last.addListener(mark);
    s.addListener(_onSession);
  }

  void _onSession() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    s.removeListener(_onSession);
    for (final c in [_first, _last, _current, _new, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final name = '${_first.text.trim()} ${_last.text.trim()}'.trim();
    if (name.isEmpty) {
      toast(context, 'Please enter your name', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await s.updateProfile({'name': name, 'locale': _locale});
      if (!mounted) return;
      setState(() => _dirty = false);
      toast(context, 'Profile saved');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _uploadAvatar(PickedFile f) async {
    final u = user;
    if (u == null) return;
    final dot = f.name.lastIndexOf('.');
    final ext = dot >= 0 ? f.name.substring(dot + 1).toLowerCase() : 'png';
    final ref = FirebaseStorage.instance.ref('users/${u.uid}/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext');
    await ref.putData(f.bytes, SettableMetadata(contentType: ext == 'jpg' ? 'image/jpeg' : 'image/$ext'));
    final url = await ref.getDownloadURL();
    await s.updateProfile({'avatarUrl': url});
    if (mounted) toast(context, 'Profile photo updated');
  }

  Future<void> _removeAvatar() async {
    try {
      await s.updateProfile({'avatarUrl': ''});
      if (mounted) toast(context, 'Profile photo removed');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  Future<void> _changePassword() async {
    if (!(_pwKey.currentState?.validate() ?? false)) return;
    final u = user;
    if (u == null || u.email == null) return;
    setState(() => _pwBusy = true);
    try {
      await u.reauthenticateWithCredential(EmailAuthProvider.credential(email: u.email!, password: _current.text));
      await u.updatePassword(_new.text);
      _current.clear();
      _new.clear();
      _confirm.clear();
      if (mounted) toast(context, 'Password updated');
    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'wrong-password' || 'invalid-credential' => 'Your current password is incorrect.',
        'weak-password' => 'Choose a stronger password (at least 8 characters).',
        'too-many-requests' => 'Too many attempts. Please try again later.',
        'requires-recent-login' => 'Please sign in again and retry.',
        _ => e.message ?? e.code,
      };
      if (mounted) toast(context, msg, error: true);
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _pwBusy = false);
    }
  }

  Future<void> _sendVerification() async {
    setState(() => _verifyBusy = true);
    try {
      await user?.sendEmailVerification();
      if (mounted) toast(context, 'Verification email sent to ${user?.email}');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _verifyBusy = false);
    }
  }

  Future<void> _refreshVerification() async {
    try {
      await user?.reload();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _signOut() async {
    final ok = await confirmDialog(context, title: 'Sign out?', message: 'You will need to sign in again to access your workspace.', confirmLabel: 'Sign out');
    if (ok) await s.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final u = user;
    final avatar = s.profile?.s('avatarUrl') ?? '';
    final verified = u?.emailVerified ?? false;
    final meta = u?.metadata;
    final t = Theme.of(context).textTheme;

    final hero = AppCard(
      gradient: AppColors.heroGradient,
      child: Row(children: [
        Avatar(s.displayName, url: avatar, size: 64),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.displayName, style: t.titleLarge?.copyWith(color: Colors.white), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(u?.email ?? '', style: const TextStyle(color: Colors.white70), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: [
              _HeroChip(Fmt.label(s.role)),
              if (s.workspace != null) _HeroChip(s.workspace!.s('name')),
            ]),
          ]),
        ),
      ]),
    ).enter(0);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader(title: 'My profile', subtitle: 'Manage your personal account, password and sign-in'),
      Expanded(
        child: PageBody(maxWidth: 1100, children: [
          hero,
          const SizedBox(height: 28),
          FormSection(
            index: 1,
            title: 'User account',
            description: 'Your name is shown to teammates and in the activity log.',
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                ImageBox(url: avatar, size: 88, label: 'Photo', onUpload: _uploadAvatar, onRemove: avatar.isEmpty ? null : _removeAvatar),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text('Upload a square image (PNG or JPG, up to 8 MB).', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                ),
              ]),
              FieldGrid(children: [
                Field(label: 'First name', controller: _first, required: true),
                Field(label: 'Last name', controller: _last),
                Field(
                  label: 'Login email',
                  initialValue: u?.email ?? '',
                  enabled: false,
                  helper: 'Your login email cannot be changed here.',
                ),
                DropdownX<String>(
                  key: ValueKey('locale-$_locale'),
                  label: 'Locale',
                  value: _locale,
                  items: _locales,
                  onChanged: (v) => setState(() {
                    _locale = v ?? 'en';
                    _dirty = true;
                  }),
                ),
              ]),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _dirty && !_saving ? _saveProfile : null,
                  child: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save'),
                ),
              ),
            ],
          ),
          FormSection(
            index: 2,
            title: 'Email verification',
            description: 'Verified email addresses help keep your account secure.',
            children: [
              Row(children: [
                StatusPill(verified ? 'success' : 'needs_attention', label: verified ? 'Verified' : 'Not verified'),
                const SizedBox(width: 12),
                Expanded(child: Text(u?.email ?? '', overflow: TextOverflow.ellipsis)),
              ]),
              if (!verified)
                Wrap(spacing: 10, runSpacing: 10, children: [
                  FilledButton.tonalIcon(
                    onPressed: _verifyBusy ? null : _sendVerification,
                    icon: const Icon(Icons.mark_email_read_outlined, size: 18),
                    label: const Text('Send verification email'),
                  ),
                  TextButton(onPressed: _refreshVerification, child: const Text('I have verified')),
                ]),
            ],
          ),
          FormSection(
            index: 3,
            title: 'Change password',
            description: 'For security, enter your current password before choosing a new one.',
            children: [
              Form(
                key: _pwKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Field(label: 'Current password', controller: _current, obscure: true, required: true, autofillHints: const [AutofillHints.password]),
                  const SizedBox(height: 16),
                  FieldGrid(children: [
                    Field(
                      label: 'New password',
                      controller: _new,
                      obscure: true,
                      required: true,
                      autofillHints: const [AutofillHints.newPassword],
                      validator: (v) => (v == null || v.length < 8) ? 'Use at least 8 characters' : null,
                    ),
                    Field(
                      label: 'Confirm new password',
                      controller: _confirm,
                      obscure: true,
                      required: true,
                      validator: (v) => v != _new.text ? 'Passwords do not match' : null,
                    ),
                  ]),
                ]),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _pwBusy ? null : _changePassword,
                  child: _pwBusy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Update password'),
                ),
              ),
            ],
          ),
          FormSection(
            index: 4,
            title: 'Login activity',
            description: 'Account sign-in details reported by Firebase Authentication.',
            children: [
              _ActivityRow(icon: Icons.person_add_alt, label: 'Account created', value: Fmt.dateTime(meta?.creationTime)),
              _ActivityRow(
                icon: Icons.login,
                label: 'Last sign-in',
                value: meta?.lastSignInTime == null ? '—' : '${Fmt.dateTime(meta!.lastSignInTime)} · ${Fmt.relative(meta.lastSignInTime)}',
              ),
              _ActivityRow(icon: Icons.key_outlined, label: 'Sign-in method', value: (u?.providerData.map((p) => p.providerId).join(', ') ?? '—')),
            ],
          ),
          FormSection(
            index: 5,
            title: 'Sessions',
            description: 'Sign out of Booqora on this browser.',
            children: [
              Row(children: [
                const Icon(Icons.laptop_mac, color: AppColors.primary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('This browser', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('Current session', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                  ]),
                ),
                OutlinedButton.icon(onPressed: _signOut, icon: const Icon(Icons.logout, size: 18), label: const Text('Sign out')),
              ]),
            ],
          ),
          FormSection(
            index: 6,
            title: 'Danger zone',
            description: 'Irreversible account actions.',
            children: [
              InfoBanner(
                s.isOwner
                    ? 'You own this workspace. To delete your account or the workspace, contact Booqora support so your data and billing can be closed safely.'
                    : 'To delete your account, ask a workspace owner to remove you from the team, then contact Booqora support.',
                tone: Tone.danger,
                icon: Icons.warning_amber_rounded,
              ),
            ],
          ),
        ]),
      ),
    ]);
  }
}

class _HeroChip extends StatelessWidget {
  final String text;
  const _HeroChip(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

class _ActivityRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ActivityRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
        Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(color: AppColors.inkSoft))),
      ]).enterX();
}
