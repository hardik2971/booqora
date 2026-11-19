import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/browser.dart';
import '../../core/theme.dart';
import '../../data/session.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/mobile.dart';
import 'settings_kit.dart';

/// Validates an IPv4 address or IPv4 CIDR block.
bool _validIp(String s) {
  final m = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})(?:/(\d{1,2}))?$').firstMatch(s.trim());
  if (m == null) return false;
  for (var i = 1; i <= 4; i++) {
    if (int.parse(m.group(i)!) > 255) return false;
  }
  final p = m.group(5);
  return p == null || int.parse(p) <= 32;
}

class SecuritySettings extends StatefulWidget {
  const SecuritySettings({super.key});

  @override
  State<SecuritySettings> createState() => _SecuritySettingsState();
}

class _SecuritySettingsState extends SettingsState<SecuritySettings> {
  @override
  String get section => 'security';

  final _ip = TextEditingController();
  String? _ipError;

  @override
  void dispose() {
    _ip.dispose();
    super.dispose();
  }

  void _addIp() {
    final x = _ip.text.trim();
    if (x.isEmpty) return;
    if (!_validIp(x)) {
      HapticFeedback.heavyImpact();
      setState(() => _ipError = 'Enter a valid IPv4 address or CIDR range, e.g. 203.0.113.4 or 10.0.0.0/24');
      return;
    }
    final list = strings('allowedIps');
    if (list.contains(x)) {
      setState(() => _ipError = 'This address is already in the list');
      return;
    }
    HapticFeedback.selectionClick();
    _ip.clear();
    _ipError = null;
    put('allowedIps', [...list, x]);
  }

  @override
  bool validate() {
    if (val<bool>('ipRestrictions', false) && strings('allowedIps').isEmpty) {
      toast(context, 'Add at least one allowed IP address before enabling IP restrictions', error: true);
      return false;
    }
    if (val<bool>('ssoRequired', false)) {
      final url = text('ssoLoginUrl').text.trim();
      if (!(Uri.tryParse(url)?.isAbsolute ?? false) || !url.startsWith('https://')) {
        toast(context, 'Enter a valid https:// identity provider login URL', error: true);
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (!Session.instance.isAdmin) {
      return FormScaffold(title: 'Security', children: [const PageIntro('Protect access to your Booqora workspace.'), adminOnly()]);
    }
    const origin = Browser.origin;
    final ips = strings('allowedIps');
    return view(
      title: 'Security',
      subtitle: 'Protect access to your Booqora workspace.',
      children: [
        SGroup(
          title: 'Authentication',
          description: 'Requirements that apply to every member of your team.',
          children: [
            SwitchTile(
              value: val<bool>('require2fa', false),
              title: 'Require two-factor authentication',
              subtitle: 'Team members must set up a second factor before accessing the workspace.',
              onChanged: (x) => put('require2fa', x),
            ),
            SwitchTile(
              value: val<bool>('emailConfirmNewDevices', true),
              title: 'Email confirmation on new devices',
              subtitle: 'A confirmation link is sent when someone signs in from an unrecognised device.',
              onChanged: (x) => put('emailConfirmNewDevices', x),
            ),
          ],
        ),
        SGroup(
          title: 'IP restrictions',
          description: 'Only allow sign-ins from trusted networks such as your shop or office.',
          children: [
            SwitchTile(
              value: val<bool>('ipRestrictions', false),
              title: 'Enable IP restrictions',
              subtitle: 'Sign-ins from addresses outside the list will be blocked.',
              onChanged: (x) => put('ipRestrictions', x),
            ),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: TextField(
                  controller: _ip,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onSubmitted: (_) => _addIp(),
                  onChanged: (_) {
                    if (_ipError != null) setState(() => _ipError = null);
                  },
                  decoration: InputDecoration(
                    hintText: '203.0.113.4 or 10.0.0.0/24',
                    prefixIcon: const Icon(Icons.lan_outlined, size: 18),
                    errorText: _ipError,
                    errorMaxLines: 3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(padding: const EdgeInsets.only(top: 4), child: IconButton.filled(onPressed: _addIp, icon: const Icon(Icons.add))),
            ]),
            if (ips.isEmpty)
              const Text('No allowed IP addresses yet.', style: TextStyle(color: AppColors.muted, fontSize: 13))
            else
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final ip in ips)
                  Chip(
                    avatar: const Icon(Icons.verified_user_outlined, size: 16, color: AppColors.primary),
                    label: Text(ip, style: const TextStyle(fontFamily: 'monospace')),
                    onDeleted: () => put('allowedIps', ips.where((e) => e != ip).toList()),
                  ),
              ]),
          ],
        ),
        SGroup(
          title: 'Single sign-on (SSO)',
          description: 'Let your team sign in through your identity provider using SAML.',
          children: [
            SwitchTile(
              value: val<bool>('ssoRequired', false),
              title: 'Require SSO',
              subtitle: 'Team members must sign in through your identity provider.',
              onChanged: (x) => put('ssoRequired', x),
            ),
            Field(label: 'Identity provider login URL', controller: text('ssoLoginUrl'), hint: 'https://idp.example.com/sso/saml', keyboardType: TextInputType.url),
            Field(label: 'X.509 certificate', controller: text('ssoCertificate'), maxLines: 6, hint: '-----BEGIN CERTIFICATE-----\n…\n-----END CERTIFICATE-----'),
            const MiniHeading('Service provider details'),
            const CopyField(label: 'ACS URL (Reply URL)', value: '$origin/__/auth/sso/acs'),
            const CopyField(label: 'Entity ID (Audience)', value: '$origin/sso/metadata'),
          ],
        ),
        const InfoBanner(
          'These preferences are saved to your workspace. Enforcement of SSO and IP allow-lists requires the enterprise plan — contact the Booqora team to activate it.',
          tone: Tone.info,
          icon: Icons.shield_outlined,
        ),
      ],
    );
  }
}
