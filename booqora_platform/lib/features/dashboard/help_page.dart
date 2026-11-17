import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/page.dart';

class _Article {
  final String category;
  final String title;
  final String summary;
  final List<String> steps;
  final String? route;
  final String? routeLabel;
  const _Article(this.category, this.title, this.summary, this.steps, {this.route, this.routeLabel});
}

const _categories = <String, IconData>{
  'Getting started': Icons.rocket_launch_outlined,
  'Inventory': Icons.inventory_2_outlined,
  'Pricing': Icons.sell_outlined,
  'Orders': Icons.receipt_long_outlined,
  'Customers': Icons.people_alt_outlined,
  'Documents': Icons.description_outlined,
  'Online store': Icons.storefront_outlined,
  'Payments': Icons.credit_card_outlined,
  'Reports': Icons.query_stats_rounded,
  'Account & billing': Icons.manage_accounts_outlined,
};

const _articles = <_Article>[
  _Article(
    'Getting started',
    'Your first 10 minutes in Booqora',
    'The fastest path from sign-up to your first booking.',
    [
      'Open the Setup guide from the dashboard to see your checklist.',
      'Go to Inventory → Add product and create one rental product with a price and quantity.',
      'Go to Customers → Add customer and save a test customer.',
      'Go to Orders → New order, pick dates, add the product and click Reserve.',
      'Check the dashboard — the order now appears under “Going out”.',
    ],
    route: '/setup',
    routeLabel: 'Open setup guide',
  ),
  _Article(
    'Getting started',
    'Inviting your team',
    'Give every staff member their own login and role.',
    [
      'Go to Settings → Team.',
      'Enter a colleague’s email and choose a role: Admin or Member.',
      'They receive access as soon as they sign up with that email.',
      'Admins can change settings; members can manage orders, customers and inventory.',
    ],
    route: '/settings/team',
    routeLabel: 'Open team settings',
  ),
  _Article(
    'Inventory',
    'Adding a rental product',
    'Create products customers can book by the hour, day or week.',
    [
      'Go to Inventory → Add product.',
      'Choose the type Rental and enter a name, photos and a description.',
      'Set the quantity you own — Booqora uses it to calculate availability.',
      'Pick a pricing method and price, then save.',
      'Toggle “Show in store” if customers should be able to book it online.',
    ],
    route: '/inventory/products/new',
    routeLabel: 'Add a product',
  ),
  _Article(
    'Inventory',
    'Bundles and collections',
    'Group products into kits and organise your catalogue.',
    [
      'Go to Inventory and open the Bundles tab to combine products into one bookable kit.',
      'Set a bundle price or a per-item discount.',
      'Use the Collections tab to group products, e.g. “Cameras” or “Party tents”.',
      'Collections appear as categories in your online store.',
    ],
    route: '/inventory?tab=bundles',
    routeLabel: 'Open bundles',
  ),
  _Article('Inventory', 'Scheduling maintenance downtime', 'Block items that are being repaired so they can’t be double-booked.', [
    'Open a product from Inventory.',
    'Go to its Downtime tab and add a downtime with a reason and dates.',
    'The blocked quantity is removed from availability for that period.',
    'End the downtime once the item is back in service.',
  ]),
  _Article('Pricing', 'Choosing a pricing method', 'Flat, fixed and tiered pricing explained.', [
    'Flat rate: a price per hour, day, week or month multiplied by the rental length.',
    'Fixed price: one price regardless of how long the item is rented.',
    'Pricing structure: tiers such as “1 day ₹500, 3 days ₹1,200, 7 days ₹2,000”.',
    'Set the method per product under Inventory → product → Pricing.',
  ]),
  _Article(
    'Pricing',
    'Setting up security deposits',
    'Collect a refundable deposit on every order.',
    [
      'Go to Settings → Pricing and choose the default deposit rule.',
      'Use product-specific deposits to charge each product’s own deposit amount.',
      'Override the rule for a single customer on their customer page.',
      'Deposits show on the order and are tracked separately from payments.',
    ],
    route: '/settings/pricing',
    routeLabel: 'Open pricing settings',
  ),
  _Article(
    'Pricing',
    'Taxes and tax profiles',
    'Charge GST or VAT correctly on every order.',
    [
      'Go to Settings → Taxes.',
      'Add a product tax profile (e.g. GST 18%) and assign it to products.',
      'Add customer tax profiles for exemptions or special rates.',
      'Choose whether your prices include tax.',
    ],
    route: '/settings/taxes',
    routeLabel: 'Open tax settings',
  ),
  _Article(
    'Orders',
    'Creating and reserving an order',
    'Book products for a customer in a few clicks.',
    [
      'Go to Orders → New order.',
      'Select a customer and the pickup and return dates.',
      'Add products — availability is checked live for the selected dates.',
      'Apply a coupon or discount if needed.',
      'Click Reserve to hold the stock. Drafts don’t reserve stock.',
    ],
    route: '/orders/new',
    routeLabel: 'New order',
  ),
  _Article(
    'Orders',
    'Picking up and returning items',
    'Move orders through their lifecycle.',
    [
      'Open a reserved order and click Pick up when the customer collects the items. Its status becomes Started.',
      'When items come back, open the order and click Return.',
      'Late returns show on the dashboard under “Coming back”.',
      'Archive completed orders to keep your list tidy.',
    ],
    route: '/orders',
    routeLabel: 'Open orders',
  ),
  _Article(
    'Orders',
    'Using the calendar',
    'See every booking on a timeline.',
    ['Go to Calendar from the sidebar.', 'Switch between day, week and month views.', 'Click a booking to open its order.'],
    route: '/calendar',
    routeLabel: 'Open calendar',
  ),
  _Article(
    'Customers',
    'Importing customers from a spreadsheet',
    'Bring your existing customer list into Booqora.',
    [
      'Save your spreadsheet as CSV with the columns name, email, phone and type.',
      'Use “individual” or “company” in the type column.',
      'Go to Customers and click Import at the bottom of the filter panel.',
      'Choose your file — customers are created and numbered automatically.',
    ],
    route: '/customers',
    routeLabel: 'Open customers',
  ),
  _Article('Customers', 'Customer discounts and balances', 'Reward loyal customers and follow up on unpaid orders.', [
    'Open a customer and set a Discount percentage under Settings.',
    'The discount applies automatically to new orders for that customer.',
    'The summary at the top shows revenue and balance due across all orders.',
    'Use the Balance due column on the Customers list to find unpaid accounts.',
  ]),
  _Article(
    'Documents',
    'Sending quotes, contracts and invoices',
    'Generate professional documents from any order.',
    [
      'Open an order and choose Create quote, contract or invoice.',
      'Review the document, then Finalize it to lock the number and lines.',
      'Click Send to email it to the customer, or Print to save a PDF.',
      'Find every document under Documents in the sidebar.',
    ],
    route: '/documents',
    routeLabel: 'Open documents',
  ),
  _Article(
    'Online store',
    'Launching your online store',
    'Let customers browse and book 24/7.',
    [
      'Go to Online store and set your brand colour and logo.',
      'Make sure the products you want to offer have “Show in store” enabled.',
      'Use View store on the dashboard to preview what customers see.',
      'Share your store link on your website, Instagram and WhatsApp.',
    ],
    route: '/online-store',
    routeLabel: 'Open online store',
  ),
  _Article(
    'Online store',
    'Creating coupon codes',
    'Run promotions for online and manual orders.',
    [
      'Go to Coupons → Add coupon.',
      'Enter a code such as SUMMER20 and choose a percentage or fixed discount.',
      'Optionally limit dates, products, minimum spend or number of uses.',
      'Customers enter the code at checkout; staff can apply it on manual orders.',
    ],
    route: '/coupons/new',
    routeLabel: 'Add coupon',
  ),
  _Article('Payments', 'Recording payments on an order', 'Keep balances accurate for cash, card, UPI and bank transfers.', [
    'Open the order and click Add payment.',
    'Enter the amount and choose the method.',
    'The payment status updates automatically: payment due, partially paid or paid.',
    'Record deposit refunds the same way using the refund option.',
  ]),
  _Article(
    'Payments',
    'Accepting online payments',
    'Get paid at checkout in your online store.',
    [
      'Go to Settings → Payments.',
      'Connect your payment provider and choose whether payment is required at checkout.',
      'Online payments are recorded on the order automatically.',
    ],
    route: '/settings/payments',
    routeLabel: 'Open payment settings',
  ),
  _Article(
    'Reports',
    'Understanding your reports',
    'Turn your bookings into decisions.',
    [
      'Go to Reports and pick a report, e.g. Company performance.',
      'Choose a period in the filter panel — This month is selected by default.',
      'Use Product performance to see ROI per product.',
      'Click Export CSV to analyse the data in a spreadsheet.',
    ],
    route: '/reports',
    routeLabel: 'Open reports',
  ),
  _Article(
    'Account & billing',
    'Managing your profile and password',
    'Keep your account details up to date.',
    [
      'Click your avatar in the top bar and choose Profile.',
      'Update your name and preferred language.',
      'Use “Forgot password” on the sign-in page to reset your password.',
    ],
    route: '/profile',
    routeLabel: 'Open profile',
  ),
  _Article(
    'Account & billing',
    'Company details and branding',
    'Set the information that appears on documents.',
    [
      'Go to Settings → General.',
      'Enter your company name, address, email and tax number.',
      'Upload your logo — it appears on documents and your store.',
      'Choose your date format and time zone.',
    ],
    route: '/settings/general',
    routeLabel: 'Open general settings',
  ),
];

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  String _q = '';

  void _open(_Article a) {
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              a.category.toUpperCase(),
              style: const TextStyle(fontSize: 11, letterSpacing: 0.8, fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
            const SizedBox(height: 6),
            Text(a.title),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(a.summary, style: const TextStyle(color: AppColors.muted, height: 1.5)),
                const SizedBox(height: 16),
                for (var i = 0; i < a.steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(a.steps[i], style: const TextStyle(height: 1.45)),
                          ),
                        ),
                      ],
                    ),
                  ).enterX(i),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close')),
          if (a.route != null)
            FilledButton(
              onPressed: () {
                Navigator.pop(c);
                context.go(a.route!);
              },
              child: Text(a.routeLabel ?? 'Open'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final matches = _articles
        .where((a) => q.isEmpty || '${a.title} ${a.summary} ${a.category} ${a.steps.join(' ')}'.toLowerCase().contains(q))
        .toList();
    final t = Theme.of(context).textTheme;
    var idx = 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(title: 'Help Center', subtitle: 'Practical guides for running your rental business on Booqora.'),
        Expanded(
          child: PageBody(
            maxWidth: 1080,
            children: [
              AppCard(
                gradient: AppColors.heroGradient,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('How can we help?', style: t.titleLarge?.copyWith(color: Colors.white, fontSize: 22)),
                    const SizedBox(height: 14),
                    TextField(
                      onChanged: (v) => setState(() => _q = v),
                      decoration: const InputDecoration(
                        hintText: 'Search guides, e.g. “deposit” or “import”',
                        prefixIcon: Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ).enter(0),
              const SizedBox(height: 24),
              if (matches.isEmpty)
                EmptyState(
                  icon: Icons.manage_search_rounded,
                  title: 'No guides found',
                  message: 'Try another word, or ask Bora — our assistant can answer questions about your workspace.',
                  actionLabel: 'Ask Bora',
                  onAction: () => context.go('/assistant'),
                ),
              for (final cat in _categories.entries)
                if (matches.any((a) => a.category == cat.key)) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10, top: 4),
                    child: Row(
                      children: [
                        Icon(cat.value, size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(cat.key, style: t.titleMedium),
                      ],
                    ),
                  ).enter(idx++),
                  LayoutBuilder(
                    builder: (context, c) {
                      final cols = c.maxWidth > 760 ? 2 : 1;
                      final w = (c.maxWidth - (cols - 1) * 12) / cols;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final a in matches.where((a) => a.category == cat.key))
                            SizedBox(
                              width: w,
                              child: AppCard(
                                padding: const EdgeInsets.all(16),
                                onTap: () => _open(a),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(a.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 4),
                                          Text(
                                            a.summary,
                                            style: const TextStyle(color: AppColors.muted, fontSize: 13),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ).enter(idx++),
                  const SizedBox(height: 22),
                ],
              AppCard(
                child: Wrap(
                  spacing: 16,
                  runSpacing: 14,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.support_agent_rounded, color: Colors.white),
                        ),
                        const SizedBox(width: 14),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Still need help?', style: t.titleSmall),
                              const Text('Our team replies within one business day.', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            final ok = await launchUrl(Uri.parse('mailto:support@booqora.app?subject=Booqora%20support'));
                            if (!ok && context.mounted) toast(context, 'Email us at support@booqora.app');
                          },
                          icon: const Icon(Icons.mail_outline, size: 18),
                          label: const Text('Email support'),
                        ),
                        FilledButton.icon(
                          onPressed: () => context.go('/assistant'),
                          icon: const Icon(Icons.auto_awesome, size: 18),
                          label: const Text('Ask Bora'),
                        ),
                      ],
                    ),
                  ],
                ),
              ).enter(idx),
            ],
          ),
        ),
      ],
    );
  }
}
