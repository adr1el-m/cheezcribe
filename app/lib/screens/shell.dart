import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import 'home_screen.dart';
import 'sessions_screen.dart';
import 'settings_screen.dart';

class StudioShell extends StatefulWidget {
  const StudioShell({super.key, required this.state});
  final AppState state;
  @override
  State<StudioShell> createState() => _StudioShellState();
}

class _StudioShellState extends State<StudioShell> {
  int index = 0;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.state,
        builder: (context, _) => Scaffold(
          body: IndexedStack(index: index, children: [
            HomeScreen(
                state: widget.state,
                openSessions: () => setState(() => index = 1),
                openSettings: () => setState(() => index = 2)),
            SessionsScreen(state: widget.state),
            SettingsScreen(state: widget.state),
          ]),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: line))),
            child: NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (value) => setState(() => index = value),
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.grid_view_outlined),
                    selectedIcon: Icon(Icons.grid_view_rounded, color: mint),
                    label: 'Studio'),
                NavigationDestination(
                    icon: Icon(Icons.layers_outlined),
                    selectedIcon: Icon(Icons.layers_rounded, color: mint),
                    label: 'Sessions'),
                NavigationDestination(
                    icon: Icon(Icons.tune_rounded),
                    selectedIcon: Icon(Icons.tune_rounded, color: mint),
                    label: 'Setup'),
              ],
            ),
          ),
        ),
      );
}
