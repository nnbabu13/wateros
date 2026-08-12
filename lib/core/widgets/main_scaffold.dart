import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/dashboard/presentation/providers/dashboard_provider.dart';

class MainScaffold extends ConsumerStatefulWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _currentIndex = 0;
  String _previousPath = '';

  final _navItems = [
    _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home', route: '/dashboard'),
    _NavItem(icon: Icons.people_outline, activeIcon: Icons.people, label: 'Customers', route: '/customers'),
    _NavItem(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long, label: 'Sales', route: '/sales'),
    _NavItem(icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet, label: 'Reports', route: '/reports'),
    _NavItem(icon: Icons.menu_outlined, activeIcon: Icons.menu, label: 'More', route: '/settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).matchedLocation;

    // Detect navigation back to dashboard from another screen
    if (currentPath == '/dashboard' && _previousPath != '/dashboard') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(dashboardRefreshProvider.notifier).state++;
      });
    }
    _previousPath = currentPath;

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _getCurrentIndex(currentPath),
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
          // Refresh dashboard when Home tab is tapped
          if (index == 0) {
            ref.read(dashboardRefreshProvider.notifier).state++;
          }
          context.go(_navItems[index].route);
        },
        destinations: _navItems.map((item) {
          return NavigationDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.activeIcon),
            label: item.label,
          );
        }).toList(),
      ),
    );
  }

  int _getCurrentIndex(String path) {
    for (int i = 0; i < _navItems.length; i++) {
      if (path.startsWith(_navItems[i].route)) return i;
    }
    return 0;
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;

  _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });
}
