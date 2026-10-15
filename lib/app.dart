import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_info.dart';
import 'app_links.dart';
import 'platform/front_notification_sync.dart';
import 'platform/quick_access_ports.dart';
import 'platform/quick_access_sync.dart';
import 'platform/local_notifier_port.dart';
import 'controllers/alter_controller.dart';
import 'controllers/buddy_controller.dart';
import 'controllers/chat_controller.dart';
import 'controllers/journal_controller.dart';
import 'controllers/world_controller.dart';
import 'data/backup_service.dart';
import 'domain/alter_links.dart';
import 'platform/device_backup_io.dart';
import 'theme/font_service.dart';
import 'domain/pin_lock.dart';
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

class _PluralAppState extends State<PluralApp> with WidgetsBindingObserver {
  late final AlterController alters = AlterController(widget.store)..load();
  late final ImageStore images = ImageStore(widget.docsDir);
  late final FrontController front = FrontController(widget.store)..load();
  late final BuddyController buddy = BuddyController(widget.store)..load();
  late final JournalController journal = JournalController(widget.store)..load();
  late final ChatController chat = ChatController(widget.store)..load();
  late final WorldController world = WorldController(
    widget.store,
    names: () => [for (final a in alters.all) NameRef(a.id, a.name)],
  )..load();
  late final PinLock pinLock = PinLock(widget.store);
  late final BackupService backup = BackupService(widget.store, widget.docsDir);

  Future<void> reloadAll() async {
    await widget.settings.load();
    await alters.load();
    await front.load();
    await journal.load();
    await chat.load();
    await world.load();
    await buddy.load();
    await FontService(widget.store, widget.docsDir).loadSaved();
  }

  late final QuickAccessSync quickAccess = QuickAccessSync(
    shortcuts: QuickActionsPort(),
    widget: HomeWidgetPort(),
    alters: alters,
    front: front,
    onOpenSwitch: () => DeepLinks.switchRequests.value++,
  );
  late final NotifierPort notifier = LocalNotifierPort();
  late final FrontNotificationSync notifySync = FrontNotificationSync(
    port: notifier,
    settings: widget.settings,
    alters: alters,
    front: front,
    onOpenSwitch: () => DeepLinks.switchRequests.value++,
  );
  // PROVIDERS: later tasks create their controllers here.

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    alters.addListener(_syncBuddy);
    front.addListener(_syncBuddy);
    notifySync.start(); // fire and forget; must not block startup
    quickAccess.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) buddy.visit();
  }

  void _syncBuddy() =>
      buddy.refresh(alterCount: alters.all.length, history: front.history);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    notifySync.dispose();
    quickAccess.dispose();
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
        ChangeNotifierProvider.value(value: journal),
        ChangeNotifierProvider.value(value: chat),
        ChangeNotifierProvider.value(value: world),
        Provider<PinLock>.value(value: pinLock),
        Provider<BackupApi>.value(value: backup),
        Provider<BackupIo>.value(value: DeviceBackupIo()),
        Provider<ReloadAll>.value(value: reloadAll),
        Provider<NotifierPort>.value(value: notifier),
        Provider<ImageStore>.value(value: images),
        Provider<DocStore>.value(value: widget.store),
        Provider<Directory>.value(value: widget.docsDir),
        // PROVIDERS-LIST
      ],
      child: Consumer3<SettingsController, FrontController, AlterController>(
        builder: (context, s, f, a, _) {
          final id = f.primaryId;
          final alter = id == null ? null : a.byId(id);
          final cfg = littleAdjust(withAlterLook(s.theme, alter?.colorValue), littleLevelOf(alter));
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
            home: s.profile.onboarded ? const HomeShell(showDedication: true) : const OnboardingScreen(),
          );
        },
      ),
    );
  }
}
