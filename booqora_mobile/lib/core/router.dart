import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/session.dart';
import '../features/apps/app_detail_page.dart';
import '../features/apps/apps_page.dart';
import '../features/assistant/assistant_page.dart';
import '../features/auth/auth_pages.dart';
import '../features/calendar/calendar_page.dart';
import '../features/coupons/coupon_form_page.dart';
import '../features/coupons/coupons_page.dart';
import '../features/customers/customer_form_page.dart';
import '../features/customers/customers_page.dart';
import '../features/documents/document_page.dart';
import '../features/documents/documents_page.dart';
import '../features/home/help_page.dart';
import '../features/home/home_page.dart';
import '../features/home/setup_page.dart';
import '../features/inventory/bundle_form_page.dart';
import '../features/inventory/collection_form_page.dart';
import '../features/inventory/inventory_page.dart';
import '../features/inventory/product_detail_page.dart';
import '../features/inventory/product_new_page.dart';
import '../features/inventory/scan_page.dart';
import '../features/more/more_page.dart';
import '../features/online_store/online_store_page.dart';
import '../features/orders/order_editor_page.dart';
import '../features/orders/orders_page.dart';
import '../features/profile/profile_page.dart';
import '../features/reports/report_page.dart';
import '../features/reports/reports_page.dart';
import '../features/settings/settings_page.dart';
import '../features/welcome/welcome_pages.dart';
import '../widgets/shell.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Material shared-axis (horizontal) transition for pushed screens.
CustomTransitionPage<void> _axis(GoRouterState s, Widget child) => CustomTransitionPage<void>(
      key: s.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 340),
      transitionsBuilder: (_, a, b, c) => SharedAxisTransition(
        animation: a,
        secondaryAnimation: b,
        transitionType: SharedAxisTransitionType.horizontal,
        fillColor: Colors.transparent,
        child: c,
      ),
    );

/// Fade-through for top-level flow changes (splash → onboarding → intro → home).
CustomTransitionPage<void> _fade(GoRouterState s, Widget child) => CustomTransitionPage<void>(
      key: s.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 600),
      transitionsBuilder: (_, a, b, c) => FadeThroughTransition(animation: a, secondaryAnimation: b, fillColor: Colors.transparent, child: c),
    );

GoRoute _p(String path, Widget Function(GoRouterState s) b) =>
    GoRoute(path: path, parentNavigatorKey: rootNavigatorKey, pageBuilder: (_, s) => _axis(s, b(s)));
GoRoute _f(String path, Widget Function(GoRouterState s) b) => GoRoute(path: path, pageBuilder: (_, s) => _fade(s, b(s)));

const _public = {'/onboarding', '/intro', '/login', '/signup', '/forgot'};

GoRouter buildRouter(Session session) => GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: '/splash',
      refreshListenable: session,
      redirect: (context, state) {
        final loc = state.matchedLocation;
        if (loc == '/splash') return null; // splash decides where to go
        if (!session.authResolved || (session.signedIn && session.loading)) return null;
        if (!session.signedIn) return _public.contains(loc) ? null : '/intro';
        if (!session.hasWorkspace) return loc == '/welcome' ? null : '/welcome';
        if (_public.contains(loc) || loc == '/welcome') return '/home';
        return null;
      },
      routes: [
        _f('/splash', (_) => const SplashPage()),
        _f('/onboarding', (_) => const OnboardingPage()),
        _f('/intro', (_) => const IntroPage()),
        _p('/login', (_) => const LoginPage()),
        _p('/signup', (_) => const SignupPage()),
        _p('/forgot', (_) => const ForgotPasswordPage()),
        _f('/welcome', (_) => const WorkspaceOnboardingPage()),
        StatefulShellRoute(
          builder: (context, state, shell) => shell,
          navigatorContainerBuilder: (context, shell, children) => AppShell(shell: shell, children: children),
          branches: [
            StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, __) => const HomePage())]),
            StatefulShellBranch(routes: [GoRoute(path: '/orders', builder: (_, __) => const OrdersPage())]),
            StatefulShellBranch(routes: [GoRoute(path: '/inventory', builder: (_, s) => InventoryPage(tab: s.uri.queryParameters['tab'] ?? 'products'))]),
            StatefulShellBranch(routes: [GoRoute(path: '/more', builder: (_, __) => const MorePage())]),
          ],
        ),
        // Pushed full-screen routes (above the tab bar).
        _p('/calendar', (_) => const CalendarPage()),
        _p('/orders/new', (s) => OrderEditorPage(customerId: s.uri.queryParameters['customer'])),
        _p('/orders/:id', (s) => OrderEditorPage(id: s.pathParameters['id'])),
        _p('/customers', (_) => const CustomersPage()),
        _p('/customers/new', (_) => const CustomerFormPage()),
        _p('/customers/:id', (s) => CustomerFormPage(id: s.pathParameters['id'])),
        _p('/inventory/products/new', (_) => const ProductNewPage()),
        _p('/inventory/products/:id', (s) => ProductDetailPage(id: s.pathParameters['id']!, tab: s.uri.queryParameters['tab'])),
        _p('/inventory/bundles/new', (_) => const BundleFormPage()),
        _p('/inventory/bundles/:id', (s) => BundleFormPage(id: s.pathParameters['id'])),
        _p('/inventory/collections/new', (_) => const CollectionFormPage()),
        _p('/inventory/collections/:id', (s) => CollectionFormPage(id: s.pathParameters['id'])),
        _p('/scan', (_) => const ScanPage()),
        _p('/coupons', (_) => const CouponsPage()),
        _p('/coupons/new', (_) => const CouponFormPage()),
        _p('/coupons/:id', (s) => CouponFormPage(id: s.pathParameters['id'])),
        _p('/documents', (s) => DocumentsPage(tab: s.uri.queryParameters['tab'] ?? 'invoice')),
        _p('/documents/:id', (s) => DocumentPage(id: s.pathParameters['id']!)),
        _p('/online-store', (_) => const OnlineStorePage()),
        _p('/online-store/:section', (s) => OnlineStorePage(section: s.pathParameters['section']!)),
        _p('/apps', (_) => const AppsPage()),
        _p('/apps/:id', (s) => AppDetailPage(appId: s.pathParameters['id']!)),
        _p('/reports', (_) => const ReportsPage()),
        _p('/reports/:type', (s) => ReportPage(type: s.pathParameters['type']!)),
        _p('/settings', (_) => const SettingsPage()),
        _p('/settings/:section', (s) => SettingsPage(section: s.pathParameters['section'])),
        _p('/profile', (_) => const ProfilePage()),
        _p('/assistant', (_) => const AssistantPage()),
        _p('/help', (_) => const HelpPage()),
        _p('/setup', (_) => const SetupPage()),
      ],
    );
