import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_info.dart';
import 'controllers/alter_controller.dart';
import 'controllers/settings_controller.dart';
import 'data/doc_store.dart';
import 'data/image_store.dart';
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
  // PROVIDERS: later tasks create their controllers here.

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.settings),
        ChangeNotifierProvider.value(value: alters),
        Provider<ImageStore>.value(value: images),
        Provider<DocStore>.value(value: widget.store),
        Provider<Directory>.value(value: widget.docsDir),
        // PROVIDERS-LIST
      ],
      child: Consumer<SettingsController>(
        builder: (context, s, _) => MaterialApp(
          title: appName,
          debugShowCheckedModeBanner: false,
          themeMode: themeModeOf(s.theme),
          theme: buildTheme(s.theme, Brightness.light),
          darkTheme: buildTheme(s.theme, Brightness.dark),
          builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.linear(s.theme.fontScale)),
            child: child!,
          ),
          home: s.profile.onboarded ? const HomeShell() : const OnboardingScreen(),
        ),
      ),
    );
  }
}
