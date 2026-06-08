import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../utils/inactivity_service.dart';

class AppShell extends StatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  void initState() {
    super.initState();
    InactivityService.instance.start(
      () { if (mounted) context.go('/login'); },
      onWarning: _showSessionWarning,
    );
  }

  void _showSessionWarning() {
    if (!mounted) return;
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SessionWarningDialog(
        onExtend:  () { Navigator.pop(ctx); InactivityService.instance.extendSession(); },
        onLogout:  () { Navigator.pop(ctx); _forceLogout(); },
      ),
    );
  }

  Future<void> _forceLogout() async {
    await InactivityService.instance.forceLogout();
    if (mounted) context.go('/login');
  }

  @override
  void dispose() {
    InactivityService.instance.stop();
    super.dispose();
  }

  void _onActivity() => InactivityService.instance.onUserActivity();

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text('Vous allez être déconnecté de GesPro.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Déconnecter',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _forceLogout();
  }

  static const _tabs = [
    _TabItem(icon: Icons.dashboard_outlined,    activeIcon: Icons.dashboard,      label: AppStrings.dashboard, path: '/'),
    _TabItem(icon: Icons.handshake_outlined,    activeIcon: Icons.handshake,      label: AppStrings.markets,   path: '/markets'),
    _TabItem(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long,   label: AppStrings.invoices,  path: '/invoices'),
    _TabItem(icon: Icons.money_off_outlined,    activeIcon: Icons.money_off,      label: 'Dépenses',           path: '/expenses'),
    _TabItem(icon: Icons.badge_outlined,        activeIcon: Icons.badge,          label: 'Personnel',          path: '/employes'),
    _TabItem(icon: Icons.people_outline,        activeIcon: Icons.people,         label: AppStrings.clients,   path: '/clients'),
    _TabItem(icon: Icons.settings_outlined,     activeIcon: Icons.settings,       label: 'Réglages',           path: '/settings'),
  ];

  int _currentIndex(String location) {
    if (location.startsWith('/markets'))    return 1;
    if (location.startsWith('/invoices'))   return 2;
    if (location.startsWith('/expenses'))   return 3;
    if (location.startsWith('/employes'))   return 4;
    if (location.startsWith('/clients'))    return 5;
    if (location.startsWith('/settings') ||
        location.startsWith('/notifications')) return 6;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final current  = _currentIndex(location);

    return Scaffold(
      body: Listener(
        onPointerDown: (_) => _onActivity(),
        onPointerMove: (_) => _onActivity(),
        child: GestureDetector(
          onHorizontalDragEnd: (details) {
            const threshold = 150.0;
            final velocity = details.primaryVelocity ?? 0;
            if (velocity > threshold && current > 0) {
              context.go(_tabs[current - 1].path);
            } else if (velocity < -threshold && current < _tabs.length - 1) {
              context.go(_tabs[current + 1].path);
            }
          },
          behavior: HitTestBehavior.translucent,
          child: widget.child,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.s100)),
          color: AppColors.white,
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              ...List.generate(_tabs.length, (i) {
                final tab     = _tabs[i];
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
            ],
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

class _SessionWarningDialog extends StatefulWidget {
  final VoidCallback onExtend;
  final VoidCallback onLogout;
  const _SessionWarningDialog({required this.onExtend, required this.onLogout});

  @override
  State<_SessionWarningDialog> createState() => _SessionWarningDialogState();
}

class _SessionWarningDialogState extends State<_SessionWarningDialog> {
  late int _seconds;
  late final _timer = _startTimer();

  @override
  void initState() {
    super.initState();
    _seconds = 120; // 2 minutes
  }

  Timer _startTimer() => Timer.periodic(const Duration(seconds: 1), (t) {
    if (!mounted) { t.cancel(); return; }
    setState(() => _seconds--);
    if (_seconds <= 0) {
      t.cancel();
      widget.onLogout();
    }
  });

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String get _countdown {
    final m = _seconds ~/ 60;
    final s = _seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: const Icon(Icons.access_time_outlined,
        color: AppColors.g600, size: 40),
    title: const Text('Session inactive',
        textAlign: TextAlign.center),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Vous êtes inactif depuis 28 minutes.\nDéconnexion automatique dans :',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          _countdown,
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: _seconds <= 30 ? AppColors.red : AppColors.g600,
          ),
        ),
      ],
    ),
    actionsAlignment: MainAxisAlignment.center,
    actions: [
      OutlinedButton.icon(
        icon: const Icon(Icons.logout, size: 18),
        label: const Text('Se déconnecter'),
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.red),
        onPressed: widget.onLogout,
      ),
      const SizedBox(width: 8),
      ElevatedButton.icon(
        icon: const Icon(Icons.refresh, size: 18),
        label: const Text('Continuer'),
        onPressed: widget.onExtend,
      ),
    ],
  );
}
