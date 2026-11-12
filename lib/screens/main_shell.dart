import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../providers/navigation_provider.dart';
import 'explore/explore_screen.dart';
import 'home/home_screen.dart';
import 'plans/plans_screen.dart';
import 'profile/profile_screen.dart';
import 'recommendations/recommendations_screen.dart';

/// Contenedor principal con la navegación inferior.
///
/// Las pestañas se construyen la primera vez que se visitan y después se
/// conservan (`IndexedStack`). Así, por ejemplo, Explorar no consulta Overpass
/// hasta que el usuario abre esa pestaña.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final Set<int> _visited = {NavigationProvider.home};

  static const List<NavigationDestination> _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: 'Inicio',
    ),
    NavigationDestination(
      icon: Icon(Icons.insights_outlined),
      selectedIcon: Icon(Icons.insights_rounded),
      label: 'Horarios',
      tooltip: 'Recomendaciones de horarios',
    ),
    NavigationDestination(
      icon: Icon(Icons.explore_outlined),
      selectedIcon: Icon(Icons.explore_rounded),
      label: 'Explorar',
    ),
    NavigationDestination(
      icon: Icon(Icons.event_note_outlined),
      selectedIcon: Icon(Icons.event_note_rounded),
      label: 'Mis planes',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
      label: 'Perfil',
    ),
  ];

  Widget _page(int index) {
    switch (index) {
      case NavigationProvider.home:
        return const HomeScreen();
      case NavigationProvider.recommendations:
        return const RecommendationsScreen();
      case NavigationProvider.explore:
        return const ExploreScreen();
      case NavigationProvider.plans:
        return const PlansScreen();
      default:
        return const ProfileScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = context.watch<NavigationProvider>().index;
    _visited.add(index);

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: [
          for (var i = 0; i < _destinations.length; i++)
            _visited.contains(i) ? _page(i) : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: context.read<NavigationProvider>().goTo,
        destinations: _destinations,
      ),
    );
  }
}
