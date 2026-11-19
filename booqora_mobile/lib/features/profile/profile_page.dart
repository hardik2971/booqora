import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/session.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/mobile.dart';

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
  bool _avatarBusy = false;
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
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();
    final name = '${_first.text.trim()} ${_last.text.trim()}'.trim();
    if (name.isEmpty) {
      HapticFeedback.heavyImpact();
      toast(context, 'Please enter your name', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await s.updateProfile({'name': name, 'locale': _locale});
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _dirty = false);
      toast(context, 'Profile saved');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changeAvatar() async {
    final hasAvatar = (s.profile?.s('avatarUrl') ?? '').isNotEmpty;
    if (hasAvatar) {
      final a = await showAppSheet<String>(
        context,
        title: 'Profile photo',
        builder: (c) => Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined, color: AppColors.primary),
            title: const Text('Change photo'),
            onTap: () => Navigator.pop(c, 'change'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: AppColors.danger),
            title: const Text('Remove photo', style: TextStyle(color: AppColors.danger)),
            onTap: () => Navigator.pop(c, 'remove'),
          ),
        ]),
      );
      if (a == null || !mounted) return;
      if (a == 'remove') return _removeAvatar();
    }
    if (!mounted) return;
    PickedFile? f;
    try {
      f = await pickImage(context);
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
      return;
    }
    if (f == null || !mounted) return;
    final u = user;
    if (u == null) return;
    setState(() => _avatarBusy = true);
    try {
      final ref = FirebaseStorage.instance.ref('users/${u.uid}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putData(f.bytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      await s.updateProfile({'avatarUrl': url});
      if (mounted) {
        HapticFeedback.mediumImpact();
        toast(context, 'Profile photo updated');
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  Future<void> _removeAvatar() async {
    try {
      await s.updateProfile({'avatarUrl': ''});
      if (mounted) toast(context, 'Profile photo removed');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  Future<void> _pickLocale() async {
    final l = await showAppSheet<String>(
      context,
      title: 'Locale',
      builder: (c) => Column(mainAxisSize: MainAxisSize.min, children: [
        for (final e in _locales.entries)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: Text(e.value, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(e.key, style: const TextStyle(color: AppColors.muted)),
            trailing: e.key == _locale ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.pop(c, e.key);
            },
          ),
      ]),
    );
    if (l == null || l == _locale) return;
    setState(() {
      _locale = l;
      _dirty = true;
    });
  }

  Future<void> _changePassword() async {
    final u = user;
    if (u == null || u.email == null) return;
    final key = GlobalKey<FormState>();
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    var busy = false;
    await showAppSheet<void>(
      context,
      title: 'Change password',
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => Form(
          key: key,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('For security, enter your current password before choosing a new one.', style: TextStyle(color: AppColors.muted, fontSize: 13)),
            const SizedBox(height: 16),
            Field(label: 'Current password', controller: current, obscure: true, required: true, autofocus: true, autofillHints: const [AutofillHints.password]),
            const SizedBox(height: 14),
            Field(
              label: 'New password',
              controller: next,
              obscure: true,
              required: true,
              autofillHints: const [AutofillHints.newPassword],
              validator: (v) => (v == null || v.length < 8) ? 'Use at least 8 characters' : null,
            ),
            const SizedBox(height: 14),
            Field(
              label: 'Confirm new password',
              controller: confirm,
              obscure: true,
              required: true,
              validator: (v) => v != next.text ? 'Passwords do not match' : null,
            ),
            const SizedBox(height: 20),
            GradientButton(
              label: 'Update password',
              icon: Icons.lock_reset_rounded,
              busy: busy,
              onPressed: () async {
                if (!(key.currentState?.validate() ?? false)) {
                  HapticFeedback.heavyImpact();
                  return;
                }
                setS(() => busy = true);
                try {
                  await u.reauthenticateWithCredential(EmailAuthProvider.credential(email: u.email!, password: current.text));
                  await u.updatePassword(next.text);
                  if (c.mounted) Navigator.pop(c);
                  if (mounted) {
                    HapticFeedback.mediumImpact();
                    toast(context, 'Password updated');
                  }
                } on FirebaseAuthException catch (e) {
                  final msg = switch (e.code) {
                    'wrong-password' || 'invalid-credential' => 'Your current password is incorrect.',
                    'weak-password' => 'Choose a stronger password (at least 8 characters).',
                    'too-many-requests' => 'Too many attempts. Please try again later.',
                    'requires-recent-login' => 'Please sign in again and retry.',
                    _ => e.message ?? e.code,
                  };
                  setS(() => busy = false);
                  if (c.mounted) toast(c, msg, error: true);
                } catch (e) {
                  setS(() => busy = false);
                  if (c.mounted) toast(c, friendlyError(e), error: true);
                }
              },
            ),
          ]),
        ),
      ),
    );
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
      if (!mounted) return;
      setState(() {});
      final ok = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
      toast(context, ok ? 'Email verified' : 'Not verified yet — check your inbox', error: !ok);
    } catch (_) {}
  }

  Future<void> _signOut() async {
    final ok = await confirmDialog(context, title: 'Sign out?', message: 'You will need to sign in again to access your workspace.', confirmLabel: 'Sign out');
    if (!ok) return;
    HapticFeedback.mediumImpact();
    await s.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final u = user;
    final avatar = s.profile?.s('avatarUrl') ?? '';
    final verified = u?.emailVerified ?? false;
    final meta = u?.metadata;

    final hero = Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [BoxShadow(color: AppColors.primaryDeep.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 12))],
      ),
      child: Column(children: [
        PressScale(
          onTap: _avatarBusy ? null : _changeAvatar,
          child: Stack(clipBehavior: Clip.none, children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [AppColors.lavender, Colors.white])),
              child: _avatarBusy
                  ? Container(
                      width: 92,
                      height: 92,
                      decoration: const BoxDecoration(color: AppColors.primaryDeep, shape: BoxShape.circle),
                      child: const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4)),
                    )
                  : Avatar(s.displayName, url: avatar, size: 92),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8)],
                ),
                child: const Icon(Icons.photo_camera_rounded, size: 17, color: AppColors.primary),
              ),
            ),
          ]),
        ).pop(),
        const SizedBox(height: 14),
        Text(s.displayName,
            textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(u?.email ?? '', style: const TextStyle(color: Colors.white70), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 12),
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 6, children: [
          _HeroChip(Fmt.label(s.role), icon: Icons.verified_user_outlined),
          if (s.workspace != null) _HeroChip(s.workspace!.s('name'), icon: Icons.storefront_outlined),
        ]),
      ]),
    );

    return MPage(
      title: 'My profile',
      showBack: true,
      slivers: [
        SPad(hero.enter(0)),
        SPad(const SectionLabel('Personal details').enter(1)),
        SPad(
          Group(children: [
            Field(label: 'First name', controller: _first, required: true, autofillHints: const [AutofillHints.givenName]),
            Field(label: 'Last name', controller: _last, autofillHints: const [AutofillHints.familyName]),
            Field(
              key: ValueKey('email-${u?.email}'),
              label: 'Login email',
              initialValue: u?.email ?? '',
              enabled: false,
              prefix: const Icon(Icons.lock_outline, size: 18),
              helper: 'Your login email cannot be changed here.',
            ),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _pickLocale,
              child: InputDecorator(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.language_rounded, size: 18), suffixIcon: Icon(Icons.expand_more_rounded)),
                child: Text(_locales[_locale] ?? _locale),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              child: _dirty || _saving
                  ? GradientButton(label: 'Save profile', icon: Icons.check_rounded, busy: _saving, height: 50, onPressed: _saveProfile)
                  : const SizedBox(width: double.infinity),
            ),
          ]).enter(2),
        ),
        SPad(const SectionLabel('Security').enter(3)),
        SPad(
          Group(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), children: [
            NavRow(
              icon: Icons.lock_reset_rounded,
              color: AppColors.primary,
              title: 'Change password',
              subtitle: 'Requires your current password',
              onTap: _changePassword,
            ),
            NavRow(
              icon: verified ? Icons.mark_email_read_rounded : Icons.mark_email_unread_rounded,
              color: verified ? AppColors.success : AppColors.warning,
              title: 'Email verification',
              subtitle: verified ? 'Your email is verified' : 'Tap to send a verification email',
              trailing: StatusPill(verified ? 'success' : 'needs_attention', label: verified ? 'Verified' : 'Not verified'),
              onTap: verified ? () {} : (_verifyBusy ? () {} : _sendVerification),
            ),
            if (!verified)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(onPressed: _refreshVerification, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('I have verified')),
              ),
          ]).enter(4),
        ),
        SPad(const SectionLabel('Account').enter(5)),
        SPad(
          Group(children: [
            _InfoRow(icon: Icons.person_add_alt, label: 'Account created', value: Fmt.dateTime(meta?.creationTime)),
            _InfoRow(
              icon: Icons.login_rounded,
              label: 'Last sign-in',
              value: meta?.lastSignInTime == null ? '—' : Fmt.relative(meta!.lastSignInTime),
            ),
            _InfoRow(icon: Icons.key_outlined, label: 'Sign-in method', value: u?.providerData.map((p) => p.providerId).join(', ') ?? '—'),
          ]).enter(6),
        ),
        SPad(
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _signOut,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign out of this device', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ).enter(7),
        ),
        SPad(
          InfoBanner(
            s.isOwner
                ? 'You own this workspace. To delete your account or the workspace, contact Booqora support so your data and billing can be closed safely.'
                : 'To delete your account, ask a workspace owner to remove you from the team, then contact Booqora support.',
            tone: Tone.danger,
            icon: Icons.warning_amber_rounded,
          ).enter(8),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        ),
      ],
    );
  }
}

class _HeroChip extends StatelessWidget {
  final String text;
  final IconData icon;
  const _HeroChip(this.text, {required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

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
      ]);
}
