import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../responsive/responsive.dart';
import 'nestap_logo.dart';

typedef _Destination = ({IconData icon, IconData selectedIcon, String label});

const _destinations = <_Destination>[
  (icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Home'),
  (
    icon: Icons.auto_awesome_outlined,
    selectedIcon: Icons.auto_awesome_rounded,
    label: 'Scenes',
  ),
  (icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Me'),
];

/// Top-level navigation: bottom bar on phones, rail on tablets,
/// extended rail with the logo on large screens.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _select(int index) => navigationShell.goBranch(
        index,
        // Tapping the current tab again returns to its first page.
        initialLocation: index == navigationShell.currentIndex,
      );

  @override
  Widget build(BuildContext context) {
    final size = context.windowSize;

    if (size == WindowSize.compact) {
      return Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _select,
          destinations: [
            for (final d in _destinations)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
              ),
          ],
        ),
      );
    }

    final extended = size == WindowSize.expanded;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: extended,
            minExtendedWidth: 220,
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _select,
            labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: NestapLogo(height: extended ? 36 : 18),
            ),
            destinations: [
              for (final d in _destinations)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}
