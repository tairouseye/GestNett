import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/login_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/clients/clients_list_screen.dart';
import '../../features/clients/client_detail_screen.dart';
import '../../features/clients/client_form_screen.dart';
import '../../features/markets/markets_list_screen.dart';
import '../../features/markets/market_detail_screen.dart';
import '../../features/markets/market_form_screen.dart';
import '../../features/invoices/invoices_list_screen.dart';
import '../../features/invoices/invoice_wizard_screen.dart';
import '../../features/invoices/invoice_detail_screen.dart';
import '../../features/invoices/unpaid_screen.dart';
import '../../features/employes/employes_list_screen.dart';
import '../../features/employes/employe_form_screen.dart';
import '../../features/employes/employe_detail_screen.dart';
import '../../features/expenses/expenses_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../core/shell/app_shell.dart';

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggingIn = state.matchedLocation == '/login';
      if (session == null && !isLoggingIn) return '/login';
      if (session != null && isLoggingIn) return '/';
      return null;
    },
    refreshListenable: _SupabaseAuthListenable(),
    routes: [
      // Route auth (hors shell)
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),

      // Shell avec bottom navigation
      ShellRoute(
        navigatorKey: _shellKey,
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/clients',
            builder: (_, __) => const ClientsListScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, __) => const ClientFormScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    ClientDetailScreen(clientId: state.pathParameters['id']!),
              ),
              GoRoute(
                path: ':id/edit',
                builder: (_, state) =>
                    ClientFormScreen(clientId: state.pathParameters['id']),
              ),
            ],
          ),
          GoRoute(
            path: '/markets',
            builder: (_, __) => const MarketsListScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, __) => const MarketFormScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    MarketDetailScreen(marketId: state.pathParameters['id']!),
              ),
              GoRoute(
                path: ':id/edit',
                builder: (_, state) =>
                    MarketFormScreen(marketId: state.pathParameters['id']),
              ),
            ],
          ),
          GoRoute(
            path: '/invoices',
            builder: (_, __) => const InvoicesListScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, __) => const InvoiceWizardScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (_, state) => InvoiceDetailScreen(
                  invoiceId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/employes',
            builder: (_, __) => const EmployesListScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, __) => const EmployeFormScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    EmployeDetailScreen(employeId: state.pathParameters['id']!),
              ),
              GoRoute(
                path: ':id/edit',
                builder: (_, state) =>
                    EmployeFormScreen(employeId: state.pathParameters['id']),
              ),
            ],
          ),
          GoRoute(
            path: '/unpaid',
            builder: (_, __) => const UnpaidScreen(),
          ),
          GoRoute(
            path: '/expenses',
            builder: (_, __) => const ExpensesScreen(),
          ),
          GoRoute(
            path: '/notifications',
            builder: (_, __) => const NotificationsScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, __) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});

// Fait écouter GoRouter les changements d'auth Supabase
class _SupabaseAuthListenable extends ChangeNotifier {
  _SupabaseAuthListenable() {
    Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }
}
