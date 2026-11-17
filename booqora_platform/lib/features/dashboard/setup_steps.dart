import 'package:flutter/material.dart';

import '../../data/session.dart';

class SetupStep {
  final String key;
  final String title;
  final String description;
  final String action;
  final String route;
  final IconData icon;
  const SetupStep(this.key, this.title, this.description, this.action, this.route, this.icon);

  bool get done => Session.instance.workspace?.m('onboarding')[key] == true;
}

const setupSteps = <SetupStep>[
  SetupStep(
    'product',
    'Add your first product',
    'Create a rental product with photos, a price per day or hour and the quantity you own. Booqora tracks its availability automatically.',
    'Add product',
    '/inventory/products/new',
    Icons.inventory_2_outlined,
  ),
  SetupStep(
    'customer',
    'Add your first customer',
    'Save contact details, addresses and a default discount so orders fill in faster.',
    'Add customer',
    '/customers/new',
    Icons.person_add_alt_1_outlined,
  ),
  SetupStep(
    'order',
    'Create your first order',
    'Pick dates, add products and Booqora calculates the price, deposit and availability for you.',
    'Create order',
    '/orders/new',
    Icons.receipt_long_outlined,
  ),
  SetupStep(
    'tax',
    'Set up taxes',
    'Add tax profiles such as GST 18% and choose whether your prices include tax.',
    'Set up taxes',
    '/settings/taxes',
    Icons.percent_rounded,
  ),
  SetupStep(
    'store',
    'Customize your online store',
    'Choose your brand colour, pick which products to show and let customers book online 24/7.',
    'Customize store',
    '/online-store',
    Icons.storefront_outlined,
  ),
  SetupStep(
    'payments',
    'Connect payments',
    'Accept card and UPI payments at checkout and record cash or bank transfers on orders.',
    'Connect payments',
    '/settings/payments',
    Icons.credit_card_outlined,
  ),
  SetupStep(
    'team',
    'Invite your team',
    'Give staff their own login so everyone sees the same live schedule.',
    'Invite team',
    '/settings/team',
    Icons.groups_outlined,
  ),
  SetupStep(
    'branding',
    'Upload your logo',
    'Your logo appears on quotes, contracts, invoices and your online store.',
    'Upload logo',
    '/settings/general',
    Icons.palette_outlined,
  ),
];

int get setupDoneCount => setupSteps.where((s) => s.done).length;
