import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/customers/screens/customer_detail_screen.dart';
import '../features/customers/screens/customers_screen.dart';
import '../features/cashflow/screens/cashflow_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/employees/screens/employees_screen.dart';
import '../features/inventory/screens/low_stock_screen.dart';
import '../features/invitations/screens/invitation_screen.dart';
import '../features/more/screens/more_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/onboarding/screens/onboarding_screen.dart';
import '../features/products/screens/categories_screen.dart';
import '../features/products/screens/product_detail_screen.dart';
import '../features/products/screens/product_form_screen.dart';
import '../features/products/screens/products_screen.dart';
import '../features/reports/screens/reports_screen.dart';
import '../features/sales/screens/pos_screen.dart';
import '../features/sales/screens/sale_detail_screen.dart';
import '../features/sales/screens/sales_list_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/workspace/screens/personal_workspace_screen.dart';
import 'gate.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final gate = ValueNotifier<GateStatus>(GateStatus.loading);
  ref.listen(gateProvider.select((s) => s.status), (_, next) {
    gate.value = next;
  });
  ref.onDispose(gate.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: gate,
    redirect: (context, state) {
      final status = ref.read(gateProvider).status;
      final location = state.matchedLocation;
      final isPublic = location == '/login' ||
          location == '/register' ||
          location == '/forgot-password';
      final isOnboarding = location == '/onboarding' ||
          location == '/personal-workspace-choice';
      final isInvitation = location == '/invitation';

      switch (status) {
        case GateStatus.loading:
          return isPublic || isOnboarding || isInvitation ? '/' : null;
        case GateStatus.signedOut:
          if (isPublic) return null;
          return '/login';
        case GateStatus.hasInvitations:
          if (!isInvitation) return '/invitation';
          return null;
        case GateStatus.needsOnboarding:
          if (isOnboarding) return null;
          if (isPublic) return '/personal-workspace-choice';
          return '/personal-workspace-choice';
        case GateStatus.ready:
          if (isPublic || isOnboarding || isInvitation) {
            if (isInvitation && location == '/invitation') return '/home';
            return '/home';
          }
          return null;
      }
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/personal-workspace-choice',
        builder: (context, state) => const PersonalWorkspaceScreen(),
      ),
      GoRoute(
        path: '/invitation',
        builder: (context, state) => const InvitationScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/sales',
        builder: (context, state) => const SalesListScreen(),
      ),
      GoRoute(
        path: '/sales/new',
        pageBuilder: (context, state) {
          final orderTypeRaw = state.uri.queryParameters['type'];
          final orderType = orderTypeRaw == 'preorder'
              ? OrderTypeRouter.preOrder
              : OrderTypeRouter.readyStock;
          return MaterialPage(
            key: state.pageKey,
            child: PosScreen(initialOrderType: orderType),
          );
        },
      ),
      GoRoute(
        path: '/sales/:id',
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: SaleDetailScreen(saleId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/products',
        builder: (context, state) => const ProductsScreen(),
      ),
      GoRoute(
        path: '/products/new',
        builder: (context, state) => const ProductFormScreen(),
      ),
      GoRoute(
        path: '/products/edit/:id',
        builder: (context, state) => ProductFormScreen(
          productId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/products/detail/:id',
        builder: (context, state) =>
            ProductDetailScreen(productId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/categories',
        builder: (context, state) => const CategoriesScreen(),
      ),
      GoRoute(
        path: '/inventory/low-stock',
        builder: (context, state) => const LowStockScreen(),
      ),
      GoRoute(
        path: '/finance',
        builder: (context, state) => const CashflowScreen(),
      ),
      GoRoute(
        path: '/more',
        builder: (context, state) => const MoreScreen(),
      ),
      GoRoute(
        path: '/customers',
        builder: (context, state) => const CustomersScreen(),
      ),
      GoRoute(
        path: '/customers/:id',
        builder: (context, state) =>
            CustomerDetailScreen(customerId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/reports',
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/employees',
        builder: (context, state) => const EmployeesScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
    ],
  );
});

enum OrderTypeRouter { readyStock, preOrder }
