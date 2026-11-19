import 'package:flutter/material.dart';

/// Static app catalog definition.
class AppDef {
  final String id;
  final String name;
  final String category;
  final String short;
  final String long;
  final String pricing;
  final IconData icon;
  final Color color;
  final bool beta;
  final List<(String, String)> configFields; // (key, label)
  const AppDef({
    required this.id,
    required this.name,
    required this.category,
    required this.short,
    required this.long,
    required this.pricing,
    required this.icon,
    required this.color,
    this.beta = false,
    this.configFields = const [],
  });
}

const appCategories = ['Accounting', 'CRM', 'Fulfillment', 'Marketing', 'Payment', 'Analytics', 'Communication', 'Website'];

const appCatalog = <AppDef>[
  AppDef(
    id: 'google-analytics',
    name: 'Google Analytics',
    category: 'Analytics',
    short: 'Track visitors and conversions on your online store.',
    long: 'Connect Google Analytics 4 to understand how shoppers find and use your online store. '
        'Page views, product views, cart activity and completed bookings are reported against your measurement ID.',
    pricing: 'Free',
    icon: Icons.insights,
    color: Color(0xFFE37400),
    configFields: [('measurementId', 'Measurement ID')],
  ),
  AppDef(
    id: 'meta-pixel',
    name: 'Meta Pixel',
    category: 'Marketing',
    short: 'Measure ad performance on Facebook and Instagram.',
    long: 'Add the Meta Pixel to your online store to measure the results of your Facebook and Instagram ads '
        'and build audiences from store visitors.',
    pricing: 'Free',
    icon: Icons.all_inclusive,
    color: Color(0xFF0866FF),
    configFields: [('pixelId', 'Pixel ID')],
  ),
  AppDef(
    id: 'mailchimp',
    name: 'Mailchimp',
    category: 'Marketing',
    short: 'Sync customers who opted in to marketing.',
    long: 'Keep your Mailchimp audience up to date with customers who agreed to receive marketing, '
        'so you can send newsletters and seasonal promotions.',
    pricing: 'Free',
    icon: Icons.campaign_outlined,
    color: Color(0xFFB8A000),
    configFields: [('audienceId', 'Audience ID'), ('serverPrefix', 'Server prefix (e.g. us21)')],
  ),
  AppDef(
    id: 'whatsapp-business',
    name: 'WhatsApp Business',
    category: 'Communication',
    short: 'Send order updates to customers on WhatsApp.',
    long: 'Share order confirmations, pickup reminders and return reminders with customers over WhatsApp Business.',
    pricing: 'Free',
    icon: Icons.chat_outlined,
    color: Color(0xFF25D366),
    beta: true,
    configFields: [('phoneNumberId', 'Phone number ID'), ('businessNumber', 'Business phone number')],
  ),
  AppDef(
    id: 'razorpay',
    name: 'Razorpay',
    category: 'Payment',
    short: 'Accept UPI, cards and netbanking in India.',
    long: 'Accept online payments for bookings with Razorpay — UPI, cards, netbanking and wallets. '
        'Secret keys must be configured server-side; only the public key ID is stored here.',
    pricing: 'Processing fees',
    icon: Icons.bolt,
    color: Color(0xFF0C2451),
    configFields: [('keyId', 'Key ID')],
  ),
  AppDef(
    id: 'stripe',
    name: 'Stripe',
    category: 'Payment',
    short: 'Accept card payments and deposits worldwide.',
    long: 'Take card payments and security deposits with Stripe. Only the publishable key is stored in Booqora; '
        'secret keys must be configured server-side.',
    pricing: 'Processing fees',
    icon: Icons.credit_card,
    color: Color(0xFF635BFF),
    configFields: [('publishableKey', 'Publishable key')],
  ),
  AppDef(
    id: 'paypal',
    name: 'PayPal',
    category: 'Payment',
    short: 'Let customers pay with their PayPal account.',
    long: 'Offer PayPal at checkout for customers who prefer to pay with their PayPal balance or linked cards.',
    pricing: 'Processing fees',
    icon: Icons.account_balance_wallet_outlined,
    color: Color(0xFF003087),
    configFields: [('clientId', 'Client ID')],
  ),
  AppDef(
    id: 'zapier',
    name: 'Zapier',
    category: 'CRM',
    short: 'Connect Booqora to thousands of apps.',
    long: 'Automate workflows between Booqora and the tools you already use — post new orders to a spreadsheet, '
        'create CRM contacts for new customers and more.',
    pricing: 'Free',
    icon: Icons.electric_bolt,
    color: Color(0xFFFF4F00),
    beta: true,
    configFields: [('webhookUrl', 'Webhook URL')],
  ),
  AppDef(
    id: 'quickbooks',
    name: 'QuickBooks',
    category: 'Accounting',
    short: 'Sync invoices and payments to QuickBooks Online.',
    long: 'Export finalized invoices and recorded payments to QuickBooks Online to keep your books in sync.',
    pricing: 'Free',
    icon: Icons.account_balance_outlined,
    color: Color(0xFF2CA01C),
    configFields: [('companyId', 'Company ID')],
  ),
  AppDef(
    id: 'xero',
    name: 'Xero',
    category: 'Accounting',
    short: 'Send invoices and payments to Xero.',
    long: 'Keep Xero up to date with invoices and payments from your rental orders.',
    pricing: 'Free',
    icon: Icons.calculate_outlined,
    color: Color(0xFF13B5EA),
    configFields: [('tenantId', 'Organisation (tenant) ID')],
  ),
  AppDef(
    id: 'tally',
    name: 'Tally',
    category: 'Accounting',
    short: 'Export vouchers for Tally Prime.',
    long: 'Prepare sales vouchers from your invoices for import into Tally Prime, including GST details.',
    pricing: 'Free',
    icon: Icons.receipt_outlined,
    color: Color(0xFF1F3A93),
    configFields: [('companyName', 'Tally company name'), ('salesLedger', 'Sales ledger')],
  ),
  AppDef(
    id: 'shiprocket',
    name: 'Shiprocket',
    category: 'Fulfillment',
    short: 'Ship delivery orders with Indian couriers.',
    long: 'Create shipments for delivery orders and track them across Shiprocket courier partners.',
    pricing: 'Processing fees',
    icon: Icons.local_shipping_outlined,
    color: Color(0xFF7A3EF0),
    configFields: [('accountEmail', 'Account email'), ('pickupLocation', 'Pickup location name')],
  ),
  AppDef(
    id: 'google-calendar',
    name: 'Google Calendar',
    category: 'CRM',
    short: 'See pickups and returns in Google Calendar.',
    long: 'Publish order pickups and returns to a Google Calendar so your team always knows what is going out and coming back.',
    pricing: 'Free',
    icon: Icons.event_outlined,
    color: Color(0xFF4285F4),
    configFields: [('calendarId', 'Calendar ID')],
  ),
  AppDef(
    id: 'slack',
    name: 'Slack',
    category: 'Communication',
    short: 'Get notified about new orders in Slack.',
    long: 'Post a message to a Slack channel whenever a new online order comes in or an order becomes overdue.',
    pricing: 'Free',
    icon: Icons.tag,
    color: Color(0xFF4A154B),
    configFields: [('webhookUrl', 'Incoming webhook URL'), ('channel', 'Channel')],
  ),
  AppDef(
    id: 'weglot',
    name: 'Weglot',
    category: 'Website',
    short: 'Translate your online store into other languages.',
    long: 'Offer your online store in multiple languages with Weglot automatic translation.',
    pricing: 'Free',
    icon: Icons.translate,
    color: Color(0xFF3B8AFF),
    configFields: [('apiKey', 'Public API key'), ('languages', 'Languages (comma separated)')],
  ),
  AppDef(
    id: 'tawk-to',
    name: 'Tawk.to chat',
    category: 'Website',
    short: 'Add live chat to your online store.',
    long: 'Answer shopper questions in real time with a Tawk.to live chat widget on your online store.',
    pricing: 'Free',
    icon: Icons.forum_outlined,
    color: Color(0xFF03A84E),
    configFields: [('propertyId', 'Property ID'), ('widgetId', 'Widget ID')],
  ),
];

AppDef? appById(String id) {
  for (final a in appCatalog) {
    if (a.id == id) return a;
  }
  return null;
}

/// Rounded brand-coloured icon tile for an app.
class AppIconTile extends StatelessWidget {
  final AppDef app;
  final double size;
  const AppIconTile(this.app, {super.key, this.size = 44});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [app.color, Color.lerp(app.color, Colors.black, 0.25)!],
          ),
          borderRadius: BorderRadius.circular(size * 0.28),
          boxShadow: [BoxShadow(color: app.color.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Icon(app.icon, color: Colors.white, size: size * 0.5),
      );
}

class BetaBadge extends StatelessWidget {
  const BetaBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: const Color(0xFFFEF3E2), borderRadius: BorderRadius.circular(20)),
        child: const Text('BETA', style: TextStyle(color: Color(0xFFD97706), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
      );
}
