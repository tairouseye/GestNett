import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  static const _tabs = [
    _TabItem(icon: Icons.dashboard_outlined,      activeIcon: Icons.dashboard,          label: AppStrings.dashboard,  path: '/'),
    _TabItem(icon: Icons.handshake_outlined,       activeIcon: Icons.handshake,          label: AppStrings.markets,    path: '/markets'),
    _TabItem(icon: Icons.people_outline,           activeIcon: Icons.people,             label: AppStrings.clients,    path: '/clients'),
    _TabItem(icon: Icons.receipt_long_outlined,    activeIcon: Icons.receipt_long,       label: AppStrings.invoices,   path: '/invoices'),
    _TabItem(icon: Icons.more_horiz_outlined,      activeIcon: Icons.more_horiz,         label: AppStrings.more,       path: '/expenses'),
  ];

  int _currentIndex(String location) {
    if (location.startsWith('/markets')) return 1;
    if (location.startsWith('/clients')) return 2;
    if (location.startsWith('/invoices')) return 3;
    if (location.startsWith('/expenses') || location.startsWith('/notifications')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final current = _currentIndex(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.s100)),
          color: AppColors.white,
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: List.generate(_tabs.length, (i) {
              final tab = _tabs[i];
              final isActive = i == current;
              return Expanded(
                child: InkWell(
                  onTap: () => context.go(tab.path),
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isActive ? tab.activeIcon : tab.icon,
                          size: 24,
                          color: isActive ? AppColors.g600 : AppColors.s300,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tab.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isActive
                                ? FontWeight.w700 : FontWeight.w500,
                            color: isActive ? AppColors.g600 : AppColors.s300,
                          ),
                        ),
                        const SizedBox(height: 2),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 2,
                          width: isActive ? 20 : 0,
                          decoration: BoxDecoration(
                            color: AppColors.g500,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;
  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.path,
  });
}
