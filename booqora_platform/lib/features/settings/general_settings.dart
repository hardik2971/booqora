import 'package:cloud_firestore/cloud_firestore.dart' show SetOptions;
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/schema.dart';
import '../../data/session.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import 'settings_kit.dart';

const _timezones = {
  'Asia/Kolkata': '(GMT+05:30) India — Kolkata',
  'Asia/Dubai': '(GMT+04:00) Dubai',
  'Asia/Singapore': '(GMT+08:00) Singapore',
  'Asia/Tokyo': '(GMT+09:00) Tokyo',
  'Asia/Shanghai': '(GMT+08:00) Shanghai',
  'Australia/Sydney': '(GMT+10:00) Sydney',
  'Pacific/Auckland': '(GMT+12:00) Auckland',
  'Europe/London': '(GMT+00:00) London',
  'Europe/Paris': '(GMT+01:00) Paris',
  'Europe/Berlin': '(GMT+01:00) Berlin',
  'Europe/Amsterdam': '(GMT+01:00) Amsterdam',
  'Africa/Johannesburg': '(GMT+02:00) Johannesburg',
  'America/New_York': '(GMT-05:00) New York',
  'America/Chicago': '(GMT-06:00) Chicago',
  'America/Denver': '(GMT-07:00) Denver',
  'America/Los_Angeles': '(GMT-08:00) Los Angeles',
  'America/Toronto': '(GMT-05:00) Toronto',
  'America/Sao_Paulo': '(GMT-03:00) São Paulo',
  'UTC': '(GMT+00:00) UTC',
};

const _countries = [
  'India', 'United States', 'United Kingdom', 'United Arab Emirates', 'Australia', 'Canada', 'Singapore',
  'Germany', 'France', 'Netherlands', 'New Zealand', 'South Africa', 'Ireland', 'Spain', 'Italy', 'Other',
];

class GeneralSettings extends StatefulWidget {
  const GeneralSettings({super.key});

  @override
  State<GeneralSettings> createState() => _GeneralSettingsState();
}

class _GeneralSettingsState extends SettingsState<GeneralSettings> {
  @override
  String get section => 'general';

  late final String _originalName = val<String>('companyName', Session.instance.workspace?.s('name') ?? '');

  @override
  bool validate() {
    if (text('companyName').text.trim().isEmpty) {
      toast(context, 'Company name is required', error: true);
      return false;
    }
    return true;
  }

  @override
  Future<void> persist() async {
    v['companyName'] = text('companyName').text.trim();
    await super.persist();
    final name = v['companyName'] as String;
    final ws = Session.instance.workspace;
    final storeUpdate = <String, dynamic>{};
    if (name != _originalName || ws?.s('name') != name) {
      await Db.workspaceRef.update({'name': name});
      storeUpdate['name'] = name;
    }
    final logo = val<String>('logoUrl', '');
    storeUpdate['logoUrl'] = logo;
    final email = val<String>('email', '');
    if (email.isNotEmpty) storeUpdate['email'] = email;
    final phone = val<String>('phone', '');
    if (phone.isNotEmpty) storeUpdate['phone'] = phone;
    await _updateStore(storeUpdate);
  }

  Future<void> _updateStore(Map<String, dynamic> data) async {
    final slug = Session.instance.workspace?.s('slug') ?? '';
    if (slug.isEmpty || data.isEmpty) return;
    try {
      await Db.fs.collection(C.publicStores).doc(slug).set(data, SetOptions(merge: true));
    } catch (_) {
      // Store doc is best-effort; workspace settings are the source of truth.
    }
  }

  Future<void> _uploadLogo(PickedFile f) async {
    final url = await Db.upload('branding', f.name, f.bytes);
    v['logoUrl'] = url;
    await Session.instance.saveSettings('general', {'logoUrl': url});
    await _updateStore({'logoUrl': url});
    await Session.instance.markOnboarding('branding');
    if (!mounted) return;
    setState(() {});
    toast(context, 'Logo updated');
  }

  Future<void> _removeLogo() async {
    v['logoUrl'] = '';
    await Session.instance.saveSettings('general', {'logoUrl': ''});
    await _updateStore({'logoUrl': ''});
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final metric = val<String>('unitSystem', 'metric') == 'metric';
    return view(
      title: 'General',
      subtitle: 'Your company details, regional preferences and the labels used across Booqora.',
      children: [
        FormSection(
          index: 0,
          title: 'Company info',
          description: 'Shown on documents, emails and your online store.',
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ImageBox(
                url: val<String>('logoUrl', ''),
                size: 104,
                label: 'Upload logo',
                onUpload: _uploadLogo,
                onRemove: _removeLogo,
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Company logo\nPNG, JPG or SVG, up to 8 MB. A square or wide logo on a transparent background works best. '
                    'The logo is saved as soon as it is uploaded.',
                    style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.5),
                  ),
                ),
              ),
            ]),
            FieldGrid(children: [
              Field(label: 'Company name', required: true, controller: text('companyName', Session.instance.workspace?.s('name') ?? '')),
              Field(label: 'Email shown on documents', controller: text('email'), keyboardType: TextInputType.emailAddress),
              Field(label: 'Phone', controller: text('phone'), keyboardType: TextInputType.phone),
              Field(label: 'Website', controller: text('website'), hint: 'https://'),
            ]),
          ],
        ),
        FormSection(
          index: 1,
          title: 'Address',
          description: 'Your business address, printed on invoices, quotes and contracts.',
          children: [
            DropdownX<String>(
              label: 'Country',
              value: val<String>('country', 'India'),
              items: {
                for (final c in {..._countries, val<String>('country', 'India')}) c: c,
              },
              onChanged: (x) => put('country', x),
            ),
            Field(label: 'Address line 1', controller: text('addressLine1')),
            Field(label: 'Address line 2', controller: text('addressLine2')),
            FieldGrid(columns: 3, children: [
              Field(label: 'City', controller: text('city')),
              Field(label: 'State', controller: text('state')),
              Field(label: 'Pincode', controller: text('zip')),
            ]),
          ],
        ),
        FormSection(
          index: 2,
          title: 'Extra details for documents',
          description: 'Two extra lines for things like bank details or your tax registration number.',
          children: [
            Field(label: 'Line 1', controller: text('extraLine1'), hint: 'e.g. GSTIN 29ABCDE1234F1Z5'),
            Field(label: 'Line 2', controller: text('extraLine2'), hint: 'e.g. Bank: HDFC · A/C 0123456789 · IFSC HDFC0000123'),
          ],
        ),
        FormSection(
          index: 3,
          title: 'Regional settings',
          description: 'Time zone, date formats and units used throughout the app.',
          children: [
            DropdownX<String>(
              label: 'Time zone',
              value: val<String>('timezone', 'Asia/Kolkata'),
              items: {
                ..._timezones,
                if (!_timezones.containsKey(val<String>('timezone', 'Asia/Kolkata'))) val<String>('timezone', 'Asia/Kolkata'): val<String>('timezone', 'Asia/Kolkata'),
              },
              onChanged: (x) => put('timezone', x),
            ),
            FieldGrid(children: [
              DropdownX<String>(
                label: 'First day of the week',
                value: val<String>('weekStart', 'monday'),
                items: const {'monday': 'Monday', 'sunday': 'Sunday', 'saturday': 'Saturday'},
                onChanged: (x) => put('weekStart', x),
              ),
              DropdownX<String>(
                label: 'Date format',
                value: val<String>('dateFormat', 'dd-MM-yyyy'),
                items: const {'dd-MM-yyyy': 'dd-MM-yyyy (31-12-2026)', 'MM/dd/yyyy': 'MM/dd/yyyy (12/31/2026)', 'yyyy-MM-dd': 'yyyy-MM-dd (2026-12-31)'},
                onChanged: (x) => put('dateFormat', x),
              ),
            ]),
            SwitchTile(
              value: val<bool>('use12h', false),
              title: 'Use AM/PM',
              subtitle: 'Show times as 2:30 PM instead of 14:30.',
              onChanged: (x) => put('use12h', x),
            ),
            const Divider(),
            const MiniHeading('Unit system'),
            RadioCards<String>(
              horizontal: true,
              value: val<String>('unitSystem', 'metric'),
              options: const [('metric', 'Metric', 'Kilograms, centimetres'), ('imperial', 'Imperial', 'Pounds, inches')],
              onChanged: (x) => touch(() {
                v['unitSystem'] = x;
                v['weightUnit'] = x == 'metric' ? 'kg' : 'lb';
              }),
            ),
            DropdownX<String>(
              key: ValueKey('wu-${val<String>('unitSystem', 'metric')}'),
              label: 'Default weight unit',
              value: val<String>('weightUnit', metric ? 'kg' : 'lb'),
              items: metric ? const {'kg': 'Kilogram (kg)', 'g': 'Gram (g)'} : const {'lb': 'Pound (lb)', 'oz': 'Ounce (oz)'},
              onChanged: (x) => put('weightUnit', x),
            ),
          ],
        ),
        FormSection(
          index: 4,
          title: 'Personalize labels',
          description: 'Rename core concepts to match the language of your business. Leave empty to use the default.',
          children: [
            FieldGrid(children: [
              Field(label: 'Customer', controller: text('labelCustomer'), hint: 'Customer'),
              Field(label: 'Order', controller: text('labelOrder'), hint: 'Order'),
              Field(label: 'Quote', controller: text('labelQuote'), hint: 'Quote'),
              Field(label: 'Contract', controller: text('labelContract'), hint: 'Contract'),
              Field(label: 'Packing slip', controller: text('labelPacking'), hint: 'Packing slip'),
            ]),
          ],
        ),
      ],
    );
  }
}

