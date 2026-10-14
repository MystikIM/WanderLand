import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/settings_controller.dart';
import 'alters_screen.dart';
import 'coming_soon.dart';
import 'more_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialTab = 0});
  final int initialTab;

  /// Tab bodies in bottom-bar order. Tabs built in later tasks replace ComingSoon.
  static List<Widget Function()> tabs = [
    () => const ComingSoon('Front'),
    () => const ComingSoon('Activity'),
    () => const AltersScreen(),
    () => const ComingSoon('Inner World'),
    () => const ComingSoon('Chat'),
    () => const MoreScreen(),
  ];

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _i = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<SettingsController>().terminology;
    final icons = [
      Icons.bolt, Icons.calendar_view_week, Icons.people,
      Icons.cloud, Icons.chat_bubble, Icons.more_horiz,
    ];
    final labels = ['Front', 'Activity', t.cap('alters'), 'Inner World', 'Chat', 'More'];
    return Scaffold(
      body: SafeArea(child: HomeShell.tabs[_i]()),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (i) => setState(() => _i = i),
        destinations: [
          for (var k = 0; k < 6; k++)
            NavigationDestination(icon: Icon(icons[k]), label: labels[k]),
        ],
      ),
    );
  }
}
