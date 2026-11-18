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
import '../features/dashboard/dashboard_page.dart';
import '../features/dashboard/help_page.dart';
import '../features/dashboard/setup_page.dart';
import '../features/documents/document_page.dart';
import '../features/documents/documents_page.dart';
import '../features/inventory/bundle_form_page.dart';
import '../features/inventory/collection_form_page.dart';
import '../features/inventory/inventory_page.dart';
import '../features/inventory/product_detail_page.dart';
import '../features/inventory/product_new_page.dart';
import '../features/online_store/online_store_page.dart';
import '../features/orders/order_editor_page.dart';
import '../features/orders/orders_page.dart';
import '../features/payments/pay_return_page.dart';
import '../features/profile/profile_page.dart';
import '../features/reports/report_page.dart';
import '../features/reports/reports_page.dart';
import '../features/settings/settings_page.dart';
import '../features/storefront/storefront_page.dart';
import '../widgets/shell.dart';

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

/// Premium fade + rise page transition.
CustomTransitionPage<void> _page(GoRouterState state, Widget child) => CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 340),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (context, anim, secondary, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.014), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
    );

GoRoute _r(String path, Widget Function(GoRouterState s) build) =>
    GoRoute(path: path, pageBuilder: (context, state) => _page(state, build(state)));

const _authPages = {'/login', '/signup', '/forgot'};

GoRouter buildRouter(Session session) => GoRouter(
      navigatorKey: _rootKey,
      initialLocation: '/',
      refreshListenable: session,
      redirect: (context, state) {
        final loc = state.matchedLocation;
        if (loc.startsWith('/s/') || loc == '/pay/return') return null; // public storefront + payment return
        final from = state.uri.queryParameters['from'];
        if (!session.authResolved || (session.signedIn && session.loading)) {
          if (loc == '/loading') return null;
          return '/loading?from=${Uri.encodeComponent(state.uri.toString())}';
        }
        if (!session.signedIn) {
          if (_authPages.contains(loc)) return null;
          final target = loc == '/loading' ? from : state.uri.toString();
          return (target == null || target == '/') ? '/login' : '/login?from=${Uri.encodeComponent(target)}';
        }
        if (!session.hasWorkspace) return loc == '/welcome' ? null : '/welcome';
        if (_authPages.contains(loc) || loc == '/welcome' || loc == '/loading') {
          return (from != null && from.startsWith('/') && !from.startsWith('/loading')) ? from : '/';
        }
        return null;
      },
      errorPageBuilder: (context, state) => _page(state, const NotFoundPage()),
      routes: [
        _r('/loading', (_) => const SplashPage()),
        _r('/login', (_) => const LoginPage()),
        _r('/signup', (_) => const SignupPage()),
        _r('/forgot', (_) => const ForgotPasswordPage()),
        _r('/welcome', (_) => const WorkspaceOnboardingPage()),
        _r('/pay/return', (s) => PayReturnPage(params: s.uri.queryParameters)),
        _r('/s/:slug', (s) => StorefrontPage(slug: s.pathParameters['slug']!)),
        _r('/s/:slug/p/:pid', (s) => StorefrontPage(slug: s.pathParameters['slug']!, productId: s.pathParameters['pid'])),
        ShellRoute(
          navigatorKey: _shellKey,
          builder: (context, state, child) => AppShell(location: state.uri.path, child: child),
          routes: [
            _r('/', (_) => const DashboardPage()),
            _r('/setup', (_) => const SetupPage()),
            _r('/help', (_) => const HelpPage()),
            _r('/calendar', (_) => const CalendarPage()),
            _r('/orders', (_) => const OrdersPage()),
            _r('/orders/new', (s) => OrderEditorPage(customerId: s.uri.queryParameters['customer'])),
            _r('/orders/:id', (s) => OrderEditorPage(id: s.pathParameters['id'])),
            _r('/customers', (_) => const CustomersPage()),
            _r('/customers/new', (_) => const CustomerFormPage()),
            _r('/customers/:id', (s) => CustomerFormPage(id: s.pathParameters['id'])),
            _r('/inventory', (s) => InventoryPage(tab: s.uri.queryParameters['tab'] ?? 'products')),
            _r('/inventory/products/new', (_) => const ProductNewPage()),
            _r('/inventory/products/:id', (s) => ProductDetailPage(id: s.pathParameters['id']!, tab: s.uri.queryParameters['tab'])),
            _r('/inventory/bundles/new', (_) => const BundleFormPage()),
            _r('/inventory/bundles/:id', (s) => BundleFormPage(id: s.pathParameters['id'])),
            _r('/inventory/collections/new', (_) => const CollectionFormPage()),
            _r('/inventory/collections/:id', (s) => CollectionFormPage(id: s.pathParameters['id'])),
            _r('/coupons', (_) => const CouponsPage()),
            _r('/coupons/new', (_) => const CouponFormPage()),
            _r('/coupons/:id', (s) => CouponFormPage(id: s.pathParameters['id'])),
            _r('/documents', (s) => DocumentsPage(tab: s.uri.queryParameters['tab'] ?? 'invoice')),
            _r('/documents/:id', (s) => DocumentPage(id: s.pathParameters['id']!)),
            _r('/online-store', (_) => const OnlineStorePage()),
            _r('/online-store/:section', (s) => OnlineStorePage(section: s.pathParameters['section']!)),
            _r('/apps', (_) => const AppsPage()),
            _r('/apps/:id', (s) => AppDetailPage(appId: s.pathParameters['id']!)),
            _r('/reports', (_) => const ReportsPage()),
            _r('/reports/:type', (s) => ReportPage(type: s.pathParameters['type']!)),
            _r('/settings', (_) => const SettingsPage()),
            _r('/settings/:section', (s) => SettingsPage(section: s.pathParameters['section']!)),
            _r('/profile', (_) => const ProfilePage()),
            _r('/assistant', (_) => const AssistantPage()),
          ],
        ),
      ],
    );
