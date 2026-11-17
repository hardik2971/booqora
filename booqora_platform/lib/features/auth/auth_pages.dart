import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/session.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';

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
        return 'Network error. Check your connection and try again.';
    }
    return e.message ?? e.code;
  }
  return friendlyError(e);
}

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const AppLogo(mark: true, height: 84)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 0.94, end: 1.04, duration: 900.ms, curve: Curves.easeInOut),
            const SizedBox(height: 22),
            const Text('Booqora', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5))
                .animate()
                .fadeIn(duration: 500.ms),
            const SizedBox(height: 18),
            const SizedBox(width: 140, child: LinearProgressIndicator(color: AppColors.lavender, backgroundColor: Colors.white12)),
          ]),
        ),
      ),
    );
  }
}

/// Split-screen layout used by auth pages.
class AuthLayout extends StatelessWidget {
  final Widget form;
  const AuthLayout({super.key, required this.form});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 980;
    final panel = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: form),
      ),
    );
    return Scaffold(
      backgroundColor: Colors.white,
      body: wide ? Row(children: [const Expanded(flex: 11, child: _BrandHero()), Expanded(flex: 10, child: panel)]) : panel,
    );
  }
}

class _BrandHero extends StatelessWidget {
  const _BrandHero();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.heroGradient),
      child: Stack(children: [
        // Ambient glow orbs.
        Positioned(
          top: -120,
          right: -80,
          child: _orb(360, AppColors.primary.withValues(alpha: 0.55)),
        ),
        Positioned(
          bottom: -140,
          left: -100,
          child: _orb(420, AppColors.lavender.withValues(alpha: 0.25)),
        ),
        Padding(
          padding: const EdgeInsets.all(56),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const AppLogo(light: true, height: 40).enterX(),
            const Spacer(),
            Text('Run your rental business\nwith calm, clever clarity.',
                    style: t.displaySmall?.copyWith(color: Colors.white, height: 1.15, fontSize: 40))
                .enter(1),
            const SizedBox(height: 18),
            Text(
              'Bookings, inventory, customers, payments and your online store — one beautifully connected platform.',
              style: t.titleMedium?.copyWith(color: Colors.white70, fontWeight: FontWeight.w400, height: 1.5),
            ).enter(2),
            const SizedBox(height: 40),
            Wrap(spacing: 14, runSpacing: 14, children: const [
              _HeroStat(icon: Icons.event_available, title: 'Live availability', sub: 'No double bookings'),
              _HeroStat(icon: Icons.storefront, title: 'Online store', sub: 'Take bookings 24/7'),
              _HeroStat(icon: Icons.insights, title: 'Smart reports', sub: 'Know what earns'),
            ]).enter(3),
            const Spacer(),
            const Text('© Booqora', style: TextStyle(color: Colors.white38, fontSize: 12)),
          ]),
        ),
      ]),
    );
  }

  Widget _orb(double size, Color c) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [c, c.withValues(alpha: 0)])),
      ).animate(onPlay: (ctl) => ctl.repeat(reverse: true)).scaleXY(begin: 0.9, end: 1.1, duration: 5.seconds, curve: Curves.easeInOut);
}

class _HeroStat extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  const _HeroStat({required this.icon, required this.title, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: AppColors.lavender),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        Text(sub, style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ]),
    );
  }
}

Widget _heading(BuildContext context, String title, String sub) {
  final t = Theme.of(context).textTheme;
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (MediaQuery.sizeOf(context).width <= 980) ...[const AppLogo(height: 34), const SizedBox(height: 32)],
    Text(title, style: t.headlineMedium).enter(),
    const SizedBox(height: 8),
    Text(sub, style: t.bodyLarge?.copyWith(color: AppColors.muted)).enter(1),
    const SizedBox(height: 28),
  ]);
}

Widget _errorBox(String? error) => AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: error == null
          ? const SizedBox(width: double.infinity)
          : Padding(padding: const EdgeInsets.only(bottom: 16), child: InfoBanner(error, tone: Tone.danger, icon: Icons.error_outline)),
    );

Widget _primaryButton(String label, bool busy, VoidCallback onTap) => SizedBox(
      width: double.infinity,
      height: 50,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
          onPressed: busy ? null : onTap,
          child: busy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ),
      ),
    );

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
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Session.instance.signIn(_email.text, _pass.text);
    } catch (e) {
      setState(() => _error = authError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      form: AutofillGroup(
        child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _heading(context, 'Welcome back', 'Sign in to manage your rentals.'),
            _errorBox(_error),
            Field(
              label: 'Email',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              prefix: const Icon(Icons.mail_outline, size: 20),
              validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
            ).enter(2),
            const SizedBox(height: 16),
            Field(
              label: 'Password',
              controller: _pass,
              obscure: _hide,
              autofillHints: const [AutofillHints.password],
              prefix: const Icon(Icons.lock_outline, size: 20),
              suffix: IconButton(icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20), onPressed: () => setState(() => _hide = !_hide)),
              validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
              onSubmitted: (_) => _submit(),
            ).enter(3),
            Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => context.go('/forgot'), child: const Text('Forgot password?'))),
            const SizedBox(height: 8),
            _primaryButton('Sign in', _busy, _submit).enter(4),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text("Don't have an account?", style: TextStyle(color: AppColors.muted)),
              TextButton(onPressed: () => context.go('/signup'), child: const Text('Start free trial')),
            ]).enter(5),
          ]),
        ),
      ),
    );
  }
}

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
    if (!_form.currentState!.validate()) return;
    if (!_agree) {
      setState(() => _error = 'Please accept the terms to continue.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Session.instance.signUp(_name.text.trim(), _email.text, _pass.text);
    } catch (e) {
      setState(() => _error = authError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      form: AutofillGroup(
        child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _heading(context, 'Start your 14-day free trial', 'No credit card required. Set up in minutes.'),
            _errorBox(_error),
            Field(label: 'Full name', controller: _name, required: true, prefix: const Icon(Icons.person_outline, size: 20), autofillHints: const [AutofillHints.name]).enter(2),
            const SizedBox(height: 16),
            Field(
              label: 'Work email',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              prefix: const Icon(Icons.mail_outline, size: 20),
              autofillHints: const [AutofillHints.email],
              validator: (v) => (v == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) ? 'Enter a valid email' : null,
            ).enter(3),
            const SizedBox(height: 16),
            Field(
              label: 'Password',
              controller: _pass,
              obscure: _hide,
              prefix: const Icon(Icons.lock_outline, size: 20),
              autofillHints: const [AutofillHints.newPassword],
              helper: 'At least 8 characters',
              suffix: IconButton(icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20), onPressed: () => setState(() => _hide = !_hide)),
              validator: (v) => (v == null || v.length < 8) ? 'Use at least 8 characters' : null,
              onSubmitted: (_) => _submit(),
            ).enter(4),
            const SizedBox(height: 12),
            CheckTile(value: _agree, title: 'I agree to the Terms of Service and Privacy Policy', onChanged: (v) => setState(() => _agree = v)),
            const SizedBox(height: 16),
            _primaryButton('Create account', _busy, _submit).enter(5),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('Already have an account?', style: TextStyle(color: AppColors.muted)),
              TextButton(onPressed: () => context.go('/login'), child: const Text('Sign in')),
            ]),
          ]),
        ),
      ),
    );
  }
}

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
    setState(() {
      _busy = true;
      _error = null;
    });
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
    return AuthLayout(
      form: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _heading(context, 'Reset your password', "Enter your email and we'll send you a reset link."),
        _errorBox(_error),
        if (_sent)
          const InfoBanner('Check your inbox — a password reset link is on its way.', tone: Tone.success, icon: Icons.mark_email_read_outlined).pop()
        else ...[
          Field(label: 'Email', controller: _email, prefix: const Icon(Icons.mail_outline, size: 20), onSubmitted: (_) => _submit()).enter(2),
          const SizedBox(height: 20),
          _primaryButton('Send reset link', _busy, _submit).enter(3),
        ],
        const SizedBox(height: 20),
        TextButton.icon(onPressed: () => context.go('/login'), icon: const Icon(Icons.arrow_back, size: 18), label: const Text('Back to sign in')),
      ]),
    );
  }
}

/// Shown after sign-up: create a workspace or accept a team invite.
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
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Session.instance.createWorkspace(
        companyName: _company.text.trim(),
        industry: _industry,
        currency: _currency,
        currencySymbol: currencies[_currency]!.$1,
      );
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
    return AuthLayout(
      form: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _heading(context, 'Set up your workspace', 'Tell us a little about your rental business.'),
          if (invite != null) ...[
            AppCard(
              color: AppColors.primarySoft,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("You've been invited to join ${invite.s('workspaceName', 'a workspace')}",
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
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
            const SizedBox(height: 20),
            const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('or create your own', style: TextStyle(color: AppColors.muted))), Expanded(child: Divider())]),
            const SizedBox(height: 20),
          ],
          _errorBox(_error),
          Field(label: 'Company name', controller: _company, required: true, prefix: const Icon(Icons.business_outlined, size: 20), hint: 'e.g. Lensly Rentals').enter(2),
          const SizedBox(height: 16),
          DropdownX<String>(label: 'Industry', value: _industry, items: {for (final i in industries) i: i}, onChanged: (v) => setState(() => _industry = v ?? _industry)).enter(3),
          const SizedBox(height: 16),
          DropdownX<String>(
            label: 'Currency',
            value: _currency,
            items: {for (final c in currencies.entries) c.key: c.value.$2},
            onChanged: (v) => setState(() => _currency = v ?? _currency),
          ).enter(4),
          const SizedBox(height: 24),
          _primaryButton('Create workspace', _busy, _create).enter(5),
          const SizedBox(height: 16),
          TextButton(onPressed: () => Session.instance.signOut(), child: const Text('Sign out')),
        ]),
      ),
    );
  }
}

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: EmptyState(
        icon: Icons.explore_off_outlined,
        title: 'Page not found',
        message: "The page you're looking for doesn't exist or has moved.",
        actionLabel: 'Go to dashboard',
        onAction: () => context.go('/'),
      ),
    );
  }
}
