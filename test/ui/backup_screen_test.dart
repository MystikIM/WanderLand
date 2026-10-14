import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/controllers/alter_controller.dart';
import 'package:plural_app/controllers/front_controller.dart';
import 'package:plural_app/controllers/settings_controller.dart';
import 'package:plural_app/data/backup_service.dart';
import 'package:plural_app/data/doc_store.dart';
import 'package:plural_app/platform/device_backup_io.dart';
import 'package:plural_app/ui/backup_screen.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import '../helpers/harness.dart';

class FakeApi implements BackupApi {
  int restored = 0;
  Uint8List? lastBytes;
  bool refuse = false;
  @override
  Future<File> exportToFile(Directory dir) async => File('${dir.path}/wanderland-backup-test.zip');
  @override
  Future<RestoreResult> restoreZip(Uint8List bytes) async {
    if (refuse) throw BackupException('That does not look like a WanderLand InnerWorlds backup file.');
    restored++;
    lastBytes = bytes;
    return const RestoreResult(docs: 12, files: 3);
  }
}

class FakeIo implements BackupIo {
  File? shared;
  Uint8List? toPick = Uint8List.fromList([1, 2, 3]);
  @override
  Future<Directory> exportDirectory() async => Directory.systemTemp;
  @override
  Future<void> shareFile(File f) async => shared = f;
  @override
  Future<Uint8List?> pickBackup() async => toPick;
}

void main() {
  late FakeApi api;
  late FakeIo io;
  late AlterController alters;
  late FrontController front;
  late SettingsController settings;
  var reloads = 0;

  Future<List<SingleChildWidget>> env() async {
    final store = MemoryDocStore();
    settings = SettingsController(store);
    await settings.load();
    alters = AlterController(store);
    await alters.load();
    front = FrontController(store, clock: () => DateTime(2026, 10, 14, 9));
    await front.load();
    api = FakeApi();
    io = FakeIo();
    reloads = 0;
    return <SingleChildWidget>[
      ChangeNotifierProvider.value(value: settings),
      ChangeNotifierProvider.value(value: alters),
      ChangeNotifierProvider.value(value: front),
      Provider<BackupApi>.value(value: api),
      Provider<BackupIo>.value(value: io),
      Provider<ReloadAll>.value(value: () async => reloads++),
    ];
  }

  testWidgets('the screen warns that the file holds the whole system', (tester) async {
    await pumpScreen(tester, const BackupScreen(), providers: await env());
    expect(find.textContaining('whole system'), findsOneWidget);
    expect(find.textContaining('private'), findsWidgets);
  });

  testWidgets('export makes the file and hands it to the share sheet', (tester) async {
    await pumpScreen(tester, const BackupScreen(), providers: await env());
    await tester.tap(find.byKey(const Key('backup-export')));
    await tester.pumpAndSettle();
    expect(io.shared, isNotNull);
    expect(io.shared!.path, endsWith('wanderland-backup-test.zip'));
    expect(find.textContaining('Backup ready'), findsOneWidget);
  });

  testWidgets('restore asks first, then replaces, reloads the app, and says what came back', (tester) async {
    await pumpScreen(tester, const BackupScreen(), providers: await env());
    await tester.tap(find.byKey(const Key('backup-restore')));
    await tester.pumpAndSettle();
    expect(find.textContaining('replace everything'), findsOneWidget);
    await tester.tap(find.byKey(const Key('restore-confirm')));
    await tester.pumpAndSettle();
    expect(api.restored, 1);
    expect(reloads, 1);
    expect(find.textContaining('Restored 12'), findsOneWidget);
  });

  testWidgets('cancelling the question changes nothing', (tester) async {
    await pumpScreen(tester, const BackupScreen(), providers: await env());
    await tester.tap(find.byKey(const Key('backup-restore')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(api.restored, 0);
    expect(reloads, 0);
  });

  testWidgets('not picking a file does nothing; a bad file shows the reason and nothing is reloaded', (tester) async {
    await pumpScreen(tester, const BackupScreen(), providers: await env());
    io.toPick = null;
    await tester.tap(find.byKey(const Key('backup-restore')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('restore-confirm')), findsNothing);

    io.toPick = Uint8List.fromList([9]);
    api.refuse = true;
    await tester.tap(find.byKey(const Key('backup-restore')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('restore-confirm')));
    await tester.pumpAndSettle();
    expect(find.textContaining('does not look like'), findsOneWidget);
    expect(reloads, 0);
  });

  testWidgets('little guard: restore is locked while a little is out; export still works', (tester) async {
    final p = await env();
    final pip = await alters.create(name: 'Pip');
    await alters.save(pip.copyWith(ageYears: 6));
    await front.set(primary: pip.id);
    await pumpScreen(tester, const BackupScreen(), providers: p);
    final restore = tester.widget<FilledButton>(find.byKey(const Key('backup-restore')));
    expect(restore.onPressed, isNull);
    expect(find.textContaining('grown-up'), findsWidgets);
    final export = tester.widget<FilledButton>(find.byKey(const Key('backup-export')));
    expect(export.onPressed, isNotNull);
  });
}
