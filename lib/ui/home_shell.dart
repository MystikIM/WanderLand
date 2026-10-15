import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/settings_controller.dart';
import '../app_links.dart';
import 'activity_screen.dart';
import 'alters_screen.dart';
import 'chat_home.dart';
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
    () => const ChatHome(),
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

  /// The biggest label size (up to the normal 12) at which the widest label
  /// fits inside one of the six tabs, in the app's current font and text scale.
  double _fitLabelSize(BuildContext context, List<String> labels) {
    const normal = 12.0, smallest = 8.5;
    final tab = MediaQuery.sizeOf(context).width / labels.length - 8; // a little breathing room
    final family = Theme.of(context).textTheme.labelMedium?.fontFamily;
    final scaler = MediaQuery.textScalerOf(context);
    var widest = 0.0;
    for (final l in labels) {
      final tp = TextPainter(
        text: TextSpan(text: l, style: TextStyle(fontFamily: family, fontSize: normal, letterSpacing: -0.2)),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      if (tp.width > widest) widest = tp.width;
    }
    if (widest <= tab) return normal;
    return (normal * tab / widest).clamp(smallest, normal);
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
      // Six tabs on a narrow phone: size the labels so the longest one ("Inner
      // World", "Activity"...) stays on one line in whatever font is chosen.
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarTheme.of(context).copyWith(
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(fontSize: _fitLabelSize(context, labels), letterSpacing: -0.2, height: 1.1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _i,
          onDestinationSelected: (i) => setState(() => _i = i),
          destinations: [
            for (var k = 0; k < 6; k++)
              NavigationDestination(icon: Icon(icons[k]), label: labels[k]),
          ],
        ),
      ),
    );
  }
}
