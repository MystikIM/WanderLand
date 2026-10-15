import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_info.dart';
import '../controllers/settings_controller.dart';
import '../theme/terminology.dart';
import '../theme/theme_config.dart';
import 'appearance_screen.dart' show kSwatches;

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController();
  final _alterWord = TextEditingController();
  final _greeting = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _alterWord.dispose();
    _greeting.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    final t = s.theme;
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Text(appName, style: Theme.of(context).textTheme.headlineMedium),
          Text('$appDescriptor · $appTagline'),
          const SizedBox(height: 24),
          Text('Let\'s make this yours.', style: Theme.of(context).textTheme.titleLarge),
          const Text('Nothing here is required, and you can change all of it later.'),
          const SizedBox(height: 16),
          TextField(
            key: const Key('onb-name'),
            controller: _name,
            decoration: const InputDecoration(labelText: 'What should we call your system?'),
          ),
          const SizedBox(height: 16),
          Text('Pick your colors', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in kSwatches)
              GestureDetector(
                onTap: () => s.setTheme(t.copyWith(seedColor: c)),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Color(c), shape: BoxShape.circle,
                    border: Border.all(width: c == t.seedColor ? 3 : 1, color: Colors.white70),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 16),
          Text('Pick a font', style: Theme.of(context).textTheme.titleMedium),
          Wrap(spacing: 8, children: [
            for (final f in kBundledFonts)
              ChoiceChip(
                label: Text(f, style: TextStyle(fontFamily: f)),
                selected: t.fontFamily == f,
                onSelected: (_) => s.setTheme(t.copyWith(fontFamily: f)),
              ),
          ]),
          const SizedBox(height: 16),
          TextField(
            key: const Key('onb-alter-word'),
            controller: _alterWord,
            decoration: const InputDecoration(
              labelText: 'What do you call the people in your system?',
              hintText: 'alter, headmate, part, ...',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('onb-greeting'),
            controller: _greeting,
            decoration: const InputDecoration(labelText: 'A greeting for the home screen'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('onb-finish'),
            onPressed: () async {
              final word = _alterWord.text.trim();
              await s.setTerminology(Terminology({
                if (word.isNotEmpty) 'alter': word,
                if (word.isNotEmpty) 'alters': word.endsWith('s') ? word : '${word}s',
              }));
              await s.setProfile(SystemProfile(
                systemName: _name.text.trim(),
                greeting: _greeting.text.trim(),
                onboarded: true,
              ));
            },
            child: const Text('Start'),
          ),
        ]),
      ),
    );
  }
}
