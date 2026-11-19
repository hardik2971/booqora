import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/session.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/mobile.dart';
import '../welcome/welcome_pages.dart';

String authError(Object e) {
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password should be at least 8 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again in a few minutes.';
      case 'network-request-failed':
        return 'No connection. Check your internet and try again.';
    }
    return e.message ?? e.code;
  }
  return friendlyError(e);
}

/// Aurora header + rounded white form sheet.
class AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget form;
  final bool canBack;
  const AuthScaffold({super.key, required this.title, required this.subtitle, required this.icon, required this.form, this.canBack = true});

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.ink,
        resizeToAvoidBottomInset: true,
        body: AuroraBackground(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, pad.top + 6, 20, 26),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      if (canBack && context.canPop())
                        IconButton(
                          style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.12)),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                          onPressed: () => context.pop(),
                        )
                      else
                        const SizedBox(height: 48),
                      const Spacer(),
                      Image.asset('assets/brand/logo_mark.png', height: 34),
                    ]),
                    const SizedBox(height: 22),
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                      ),
                      child: Icon(icon, color: Colors.white, size: 28),
                    ).animate().scaleXY(begin: 0.4, end: 1, duration: 600.ms, curve: Curves.easeOutBack),
                    const SizedBox(height: 18),
                    AuthHeader(title: title, subtitle: subtitle),
                  ]),
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Container(
                  padding: EdgeInsets.fromLTRB(24, 28, 24, pad.bottom + 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  child: form,
                ).animate().slideY(begin: 0.25, end: 0, duration: 600.ms, curve: Curves.easeOutCubic).fadeIn(duration: 400.ms),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _errorBox(String? error) => AnimatedSize(
      duration: const Duration(milliseconds: 220),
      child: error == null
          ? const SizedBox(width: double.infinity)
          : Padding(padding: const EdgeInsets.only(bottom: 16), child: InfoBanner(error, tone: Tone.danger, icon: Icons.error_outline)),
    );

// ---------------------------------------------------------------------------
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false, _hide = true;
  String? _error;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() => (_busy = true, _error = null));
    try {
      await Session.instance.signIn(_email.text, _pass.text);
      HapticFeedback.mediumImpact();
    } catch (e) {
      HapticFeedback.heavyImpact();
      setState(() => _error = authError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to manage your rentals.',
      icon: Icons.lock_open_rounded,
      form: AutofillGroup(
        child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _errorBox(_error),
            Field(
              label: 'Email',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              prefix: const Icon(Icons.mail_outline_rounded, size: 20),
              validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
            ).enter(3),
            const SizedBox(height: 16),
            Field(
              label: 'Password',
              controller: _pass,
              obscure: _hide,
              autofillHints: const [AutofillHints.password],
              prefix: const Icon(Icons.lock_outline_rounded, size: 20),
              suffix: IconButton(icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20), onPressed: () => setState(() => _hide = !_hide)),
              validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
              onSubmitted: (_) => _submit(),
            ).enter(4),
            Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => context.push('/forgot'), child: const Text('Forgot password?'))),
            const SizedBox(height: 8),
            GradientButton(label: 'Sign in', busy: _busy, onPressed: _submit).enter(5),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text("New to Booqora?", style: TextStyle(color: AppColors.muted)),
              TextButton(onPressed: () => context.pushReplacement('/signup'), child: const Text('Create account')),
            ]).enter(6),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class SignupPage extends StatefulWidget {
  const SignupPage({super.key});
  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false, _hide = true, _agree = true;
  String? _error;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    if (!_agree) {
      setState(() => _error = 'Please accept the terms to continue.');
      return;
    }
    setState(() => (_busy = true, _error = null));
    try {
      await Session.instance.signUp(_name.text.trim(), _email.text, _pass.text);
      HapticFeedback.mediumImpact();
    } catch (e) {
      setState(() => _error = authError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Start your free trial',
      subtitle: '14 days free. No credit card required.',
      icon: Icons.rocket_launch_rounded,
      form: AutofillGroup(
        child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _errorBox(_error),
            Field(label: 'Full name', controller: _name, required: true, prefix: const Icon(Icons.person_outline_rounded, size: 20), autofillHints: const [AutofillHints.name]).enter(3),
            const SizedBox(height: 16),
            Field(
              label: 'Work email',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              prefix: const Icon(Icons.mail_outline_rounded, size: 20),
              autofillHints: const [AutofillHints.email],
              validator: (v) => (v == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) ? 'Enter a valid email' : null,
            ).enter(4),
            const SizedBox(height: 16),
            Field(
              label: 'Password',
              controller: _pass,
              obscure: _hide,
              helper: 'At least 8 characters',
              prefix: const Icon(Icons.lock_outline_rounded, size: 20),
              autofillHints: const [AutofillHints.newPassword],
              suffix: IconButton(icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20), onPressed: () => setState(() => _hide = !_hide)),
              validator: (v) => (v == null || v.length < 8) ? 'Use at least 8 characters' : null,
              onSubmitted: (_) => _submit(),
            ).enter(5),
            const SizedBox(height: 10),
            CheckTile(value: _agree, title: 'I agree to the Terms of Service and Privacy Policy', onChanged: (v) => setState(() => _agree = v)),
            const SizedBox(height: 16),
            GradientButton(label: 'Create account', busy: _busy, onPressed: _submit).enter(6),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('Already have an account?', style: TextStyle(color: AppColors.muted)),
              TextButton(onPressed: () => context.pushReplacement('/login'), child: const Text('Sign in')),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _email = TextEditingController();
  bool _busy = false, _sent = false;
  String? _error;

  Future<void> _submit() async {
    if (!_email.text.contains('@')) {
      setState(() => _error = 'Enter a valid email');
      return;
    }
    setState(() => (_busy = true, _error = null));
    try {
      await Session.instance.resetPassword(_email.text);
      setState(() => _sent = true);
    } catch (e) {
      setState(() => _error = authError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Reset password',
      subtitle: "We'll email you a secure reset link.",
      icon: Icons.key_rounded,
      form: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _errorBox(_error),
        if (_sent)
          const InfoBanner('Check your inbox — a password reset link is on its way.', tone: Tone.success, icon: Icons.mark_email_read_outlined).pop()
        else ...[
          Field(label: 'Email', controller: _email, keyboardType: TextInputType.emailAddress, prefix: const Icon(Icons.mail_outline_rounded, size: 20), onSubmitted: (_) => _submit()).enter(3),
          const SizedBox(height: 22),
          GradientButton(label: 'Send reset link', busy: _busy, onPressed: _submit).enter(4),
        ],
        const SizedBox(height: 16),
        TextButton.icon(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back_rounded, size: 18), label: const Text('Back to sign in')),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
/// After sign-up: create a workspace or accept a team invite.
class WorkspaceOnboardingPage extends StatefulWidget {
  const WorkspaceOnboardingPage({super.key});
  @override
  State<WorkspaceOnboardingPage> createState() => _WorkspaceOnboardingPageState();
}

class _WorkspaceOnboardingPageState extends State<WorkspaceOnboardingPage> {
  final _form = GlobalKey<FormState>();
  final _company = TextEditingController();
  String _industry = 'AV / Camera';
  String _currency = 'INR';
  bool _busy = false;
  String? _error;

  static const industries = [
    'AV / Camera', 'Bikes / Scooters', 'Event / Party', 'Sports / Activities', 'Boats / Kayaks', 'Tools / Construction',
    'Vehicles / Trailers', 'Technology / IT', 'House / Storage', 'Clothing', 'Medical / Healthcare', 'Baby / Child care', 'Other',
  ];
  static const currencies = {
    'INR': ('₹', 'Indian Rupee (₹)'),
    'USD': (r'$', r'US Dollar ($)'),
    'EUR': ('€', 'Euro (€)'),
    'GBP': ('£', 'British Pound (£)'),
    'AED': ('AED', 'UAE Dirham (AED)'),
    'AUD': (r'A$', r'Australian Dollar (A$)'),
    'CAD': (r'C$', r'Canadian Dollar (C$)'),
    'SGD': (r'S$', r'Singapore Dollar (S$)'),
  };

  Future<void> _create() async {
    if (!_form.currentState!.validate()) return;
    setState(() => (_busy = true, _error = null));
    try {
      await Session.instance.createWorkspace(
        companyName: _company.text.trim(),
        industry: _industry,
        currency: _currency,
        currencySymbol: currencies[_currency]!.$1,
      );
      HapticFeedback.mediumImpact();
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final invite = s.pendingInvite;
    return AuthScaffold(
      title: 'Set up your business',
      subtitle: 'A few details and you are ready to rent.',
      icon: Icons.storefront_rounded,
      canBack: false,
      form: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (invite != null) ...[
            AppCard(
              color: AppColors.primarySoft,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("You're invited to ${invite.s('workspaceName', 'a workspace')}", style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Role: ${invite.s('role', 'member')}', style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          try {
                            await Session.instance.acceptInvite();
                          } catch (e) {
                            setState(() => _error = friendlyError(e));
                          } finally {
                            if (mounted) setState(() => _busy = false);
                          }
                        },
                  child: const Text('Accept invitation'),
                ),
              ]),
            ).pop(),
            const SizedBox(height: 18),
            const Row(children: [
              Expanded(child: Divider()),
              Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('or create your own', style: TextStyle(color: AppColors.muted))),
              Expanded(child: Divider()),
            ]),
            const SizedBox(height: 18),
          ],
          _errorBox(_error),
          Field(label: 'Company name', controller: _company, required: true, prefix: const Icon(Icons.business_rounded, size: 20), hint: 'e.g. Lensly Rentals').enter(3),
          const SizedBox(height: 16),
          DropdownX<String>(label: 'Industry', value: _industry, items: {for (final i in industries) i: i}, onChanged: (v) => setState(() => _industry = v ?? _industry)).enter(4),
          const SizedBox(height: 16),
          DropdownX<String>(
            label: 'Currency',
            value: _currency,
            items: {for (final c in currencies.entries) c.key: c.value.$2},
            onChanged: (v) => setState(() => _currency = v ?? _currency),
          ).enter(5),
          const SizedBox(height: 26),
          GradientButton(label: 'Create workspace', icon: Icons.check_rounded, busy: _busy, onPressed: _create).enter(6),
          const SizedBox(height: 10),
          TextButton(onPressed: () => Session.instance.signOut(), child: const Text('Sign out')),
        ]),
      ),
    );
  }
}
