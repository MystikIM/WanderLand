import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/settings_controller.dart';
import '../theme/terminology.dart';
import '../theme/theme_config.dart';

const List<int> kSwatches = [
  0xFF9B30FF, 0xFFFF29B4, 0xFFE40303, 0xFFFF8C00, 0xFFFFED00, 0xFF008026,
  0xFF24A8A0, 0xFF004DFF, 0xFF750787, 0xFFFF8CC6, 0xFF5BCEFA, 0xFF8A5A44,
  0xFF1F1F2E, 0xFFF5F5F5,
];

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key, required this.onImportFont, this.extraFonts = const []});
  /// Opens the file picker and imports a font (wired in More screen).
  final Future<void> Function() onImportFont;
  final List<String> extraFonts;

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  final _ctrls = <String, TextEditingController>{};
  late final TextEditingController _name;
  late final TextEditingController _greeting;

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsController>();
    for (final k in Terminology.defaults.keys) {
      _ctrls[k] = TextEditingController(text: s.terminology(k));
    }
    _name = TextEditingController(text: s.profile.systemName);
    _greeting = TextEditingController(text: s.profile.greeting);
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    _name.dispose();
    _greeting.dispose();
    super.dispose();
  }

  Widget _swatches(int current, void Function(int) pick) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in kSwatches)
            GestureDetector(
              onTap: () => pick(c),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: Border.all(width: c == current ? 3 : 1, color: Colors.white70),
                ),
              ),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    final t = s.theme;
    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Main color', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _swatches(t.seedColor, (c) => s.setTheme(t.copyWith(seedColor: c))),
        const SizedBox(height: 16),
        Text('Accent color', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _swatches(t.accentColor, (c) => s.setTheme(t.copyWith(accentColor: c))),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'dark', label: Text('Dark')),
            ButtonSegment(value: 'light', label: Text('Light')),
            ButtonSegment(value: 'system', label: Text('Auto')),
          ],
          selected: {t.mode},
          onSelectionChanged: (v) => s.setTheme(t.copyWith(mode: v.first)),
        ),
        const SizedBox(height: 16),
        Text('Font', style: Theme.of(context).textTheme.titleMedium),
        Wrap(spacing: 8, children: [
          for (final f in [...kBundledFonts, ...widget.extraFonts])
            ChoiceChip(
              label: Text(f.startsWith('custom:') ? f.substring(7) : f, style: TextStyle(fontFamily: f)),
              selected: t.fontFamily == f,
              onSelected: (_) => s.setTheme(t.copyWith(fontFamily: f)),
            ),
          ActionChip(
            avatar: const Icon(Icons.upload_file, size: 18),
            label: const Text('Use my own font file'),
            onPressed: widget.onImportFont,
          ),
        ]),
        const SizedBox(height: 16),
        Text('Text size  ${t.fontScale.toStringAsFixed(1)}x'),
        Slider(
          min: 0.8, max: 1.8, divisions: 10, value: t.fontScale,
          onChanged: (v) => s.setTheme(t.copyWith(fontScale: v)),
        ),
        Text('Roundness  ${t.cornerRadius.round()}'),
        Slider(
          min: 0, max: 32, divisions: 16, value: t.cornerRadius,
          onChanged: (v) => s.setTheme(t.copyWith(cornerRadius: v)),
        ),
        const Divider(height: 32),
        Text('Your words', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Our name')),
        const SizedBox(height: 8),
        TextField(controller: _greeting, decoration: const InputDecoration(labelText: 'Greeting')),
        for (final k in Terminology.defaults.keys) ...[
          const SizedBox(height: 8),
          TextField(
            key: Key('word-$k'),
            controller: _ctrls[k],
            decoration: InputDecoration(labelText: 'What we call "$k"'),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('save-words'),
          onPressed: () async {
            await s.setTerminology(Terminology({for (final e in _ctrls.entries) e.key: e.value.text}));
            await s.setProfile(SystemProfile(
              systemName: _name.text.trim(),
              greeting: _greeting.text.trim(),
              onboarded: s.profile.onboarded,
            ));
          },
          child: const Text('Save my words'),
        ),
      ]),
    );
  }
}
