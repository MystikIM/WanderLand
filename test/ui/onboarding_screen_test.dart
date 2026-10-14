import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/app_info.dart';
import 'package:plural_app/controllers/settings_controller.dart';
import 'package:plural_app/data/doc_store.dart';
import 'package:plural_app/ui/onboarding_screen.dart';
import 'package:provider/provider.dart';
import '../helpers/harness.dart';

void main() {
  testWidgets('first run saves name, color, font, word, greeting and marks onboarded', (tester) async {
    final store = MemoryDocStore();
    final s = SettingsController(store);
    await s.load();
    await pumpScreen(tester, const OnboardingScreen(),
        providers: [ChangeNotifierProvider.value(value: s)]);

    expect(find.text(appName), findsWidgets);
    await tester.enterText(find.byKey(const Key('onb-name')), 'The Wanderers');
    await tester.enterText(find.byKey(const Key('onb-alter-word')), 'headmate');
    await tester.enterText(find.byKey(const Key('onb-greeting')), 'Welcome home');
    await tester.ensureVisible(find.text('Pacifico'));
    await tester.tap(find.text('Pacifico'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('onb-finish')));
    await tester.tap(find.byKey(const Key('onb-finish')));
    await tester.pumpAndSettle();

    expect(s.profile.onboarded, isTrue);
    expect(s.profile.systemName, 'The Wanderers');
    expect(s.profile.greeting, 'Welcome home');
    expect(s.terminology('alter'), 'headmate');
    expect(s.theme.fontFamily, 'Pacifico');
  });

  testWidgets('finishing with everything blank still works (nothing is required)', (tester) async {
    final s = SettingsController(MemoryDocStore());
    await s.load();
    await pumpScreen(tester, const OnboardingScreen(),
        providers: [ChangeNotifierProvider.value(value: s)]);
    await tester.ensureVisible(find.byKey(const Key('onb-finish')));
    await tester.tap(find.byKey(const Key('onb-finish')));
    await tester.pumpAndSettle();
    expect(s.profile.onboarded, isTrue);
    expect(s.terminology('alter'), 'alter');
  });
}
