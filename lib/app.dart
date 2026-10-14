import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_info.dart';
import 'controllers/alter_controller.dart';
import 'controllers/buddy_controller.dart';
import 'controllers/front_controller.dart';
import 'controllers/settings_controller.dart';
import 'data/doc_store.dart';
import 'data/image_store.dart';
import 'domain/little.dart';
import 'theme/theme_config.dart';
import 'ui/home_shell.dart';
import 'ui/onboarding_screen.dart';

class PluralApp extends StatefulWidget {
  const PluralApp({super.key, required this.store, required this.docsDir, required this.settings});
  final DocStore store;
  final Directory docsDir;
  final SettingsController settings;
  @override
  State<PluralApp> createState() => _PluralAppState();
}

class _PluralAppState extends State<PluralApp> {
  late final AlterController alters = AlterController(widget.store)..load();
  late final ImageStore images = ImageStore(widget.docsDir);
  late final FrontController front = FrontController(widget.store)..load();
  late final BuddyController buddy = BuddyController(widget.store)..load();
  // PROVIDERS: later tasks create their controllers here.

  @override
  void initState() {
    super.initState();
    alters.addListener(_syncBuddy);
    front.addListener(_syncBuddy);
  }

  void _syncBuddy() =>
      buddy.refresh(alterCount: alters.all.length, history: front.history);

  @override
  void dispose() {
    alters.removeListener(_syncBuddy);
    front.removeListener(_syncBuddy);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.settings),
        ChangeNotifierProvider.value(value: alters),
        ChangeNotifierProvider.value(value: front),
        ChangeNotifierProvider.value(value: buddy),
        Provider<ImageStore>.value(value: images),
        Provider<DocStore>.value(value: widget.store),
        Provider<Directory>.value(value: widget.docsDir),
        // PROVIDERS-LIST
      ],
      child: Consumer3<SettingsController, FrontController, AlterController>(
        builder: (context, s, f, a, _) {
          final id = f.primaryId;
          final cfg = littleAdjust(s.theme, littleLevelOf(id == null ? null : a.byId(id)));
          return MaterialApp(
            title: appName,
            debugShowCheckedModeBanner: false,
            themeMode: themeModeOf(cfg),
            theme: buildTheme(cfg, Brightness.light),
            darkTheme: buildTheme(cfg, Brightness.dark),
            builder: (ctx, child) => MediaQuery(
              data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.linear(cfg.fontScale)),
              child: child!,
            ),
            home: s.profile.onboarded ? const HomeShell() : const OnboardingScreen(),
          );
        },
      ),
    );
  }
}
