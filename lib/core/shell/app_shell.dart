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

  // Seuils responsive
  static const double _railBreakpoint = 840;  // ≥ : rail latéral au lieu de la barre du bas
  static const double _extendedBreakpoint = 1100; // ≥ : rail étendu (icône + libellé)
  static const double _maxContentWidth = 1200; // largeur max du contenu sur grand écran

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final current  = _currentIndex(location);
    final width    = MediaQuery.sizeOf(context).width;
    final useRail  = width >= _railBreakpoint;

    // Le swipe horizontal n'a de sens que sur mobile (barre du bas).
    final content = Listener(
      onPointerDown: (_) => _onActivity(),
      onPointerMove: (_) => _onActivity(),
      child: useRail
          ? widget.child
          : GestureDetector(
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
    );

    // Grand écran : rail latéral + contenu centré avec largeur maximale.
    if (useRail) {
      return Scaffold(
        backgroundColor: AppColors.s50,
        body: SafeArea(
          child: Row(
            children: [
              _SideNav(
                tabs: _tabs,
                current: current,
                extended: width >= _extendedBreakpoint,
                onTap: (path) => context.go(path),
              ),
              const VerticalDivider(width: 1, color: AppColors.s100),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: _maxContentWidth),
                    child: content,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Mobile : barre de navigation en bas (comportement d'origine).
    return Scaffold(
      body: content,
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

// Rail de navigation latéral (tablette / laptop).
class _SideNav extends StatelessWidget {
  final List<_TabItem> tabs;
  final int current;
  final bool extended;
  final ValueChanged<String> onTap;
  const _SideNav({
    required this.tabs,
    required this.current,
    required this.extended,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: extended ? 220 : 76,
      color: AppColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: extended ? 16 : 8),
            child: Row(
              mainAxisAlignment:
                  extended ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/logo.png', width: 32, height: 32,
                    errorBuilder: (_, e, s) =>
                        const Icon(Icons.business, color: AppColors.g600)),
                if (extended) ...[
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('GesPro',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: AppColors.g700),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                for (var i = 0; i < tabs.length; i++)
                  _SideNavItem(
                    tab: tabs[i],
                    active: i == current,
                    extended: extended,
                    onTap: () => onTap(tabs[i].path),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SideNavItem extends StatelessWidget {
  final _TabItem tab;
  final bool active;
  final bool extended;
  final VoidCallback onTap;
  const _SideNavItem({
    required this.tab,
    required this.active,
    required this.extended,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.g600 : AppColors.s400;
    final icon = Icon(active ? tab.activeIcon : tab.icon, size: 24, color: color);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Material(
        color: active ? AppColors.g50 : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Tooltip(
            message: extended ? '' : tab.label,
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: extended ? 12 : 0, vertical: 12),
              child: extended
                  ? Row(
                      children: [
                        icon,
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            tab.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  active ? FontWeight.w700 : FontWeight.w500,
                              color: color,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    )
                  : Center(child: icon),
            ),
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
