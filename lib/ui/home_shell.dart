import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/settings_controller.dart';
import '../app_links.dart';
import 'activity_screen.dart';
import 'alters_screen.dart';
import 'chat_screen.dart';
import 'dedication.dart';
import 'front_screen.dart';
import 'more_screen.dart';
import 'switch_sheet.dart';
import 'world_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialTab = 0, this.showDedication = false});
  final int initialTab;

  /// The real app turns this on: the dedication shows once, then never again.
  final bool showDedication;

  /// Tab bodies in bottom-bar order. Tabs built in later tasks replace ComingSoon.
  static List<Widget Function()> tabs = [
    () => const FrontScreen(),
    () => const ActivityScreen(),
    () => const AltersScreen(),
    () => const WorldScreen(),
    () => const ChatScreen(),
    () => const MoreScreen(),
  ];

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _i = widget.initialTab;

  @override
  void initState() {
    super.initState();
    DeepLinks.switchRequests.addListener(_onSwitchRequest);
    if (widget.showDedication) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final s = context.read<SettingsController>();
        if (s.profile.onboarded && !s.profile.dedicationSeen) showDedicationDialog(context);
      });
    }
  }

  @override
  void dispose() {
    DeepLinks.switchRequests.removeListener(_onSwitchRequest);
    super.dispose();
  }

  void _onSwitchRequest() {
    if (!mounted) return;
    setState(() => _i = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showSwitchSheet(context);
    });
  }

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
