import 'package:flutter/foundation.dart';
import '../data/doc_store.dart';
import '../theme/terminology.dart';
import '../theme/theme_config.dart';

class SystemProfile {
  const SystemProfile({
    this.systemName = '',
    this.greeting = '',
    this.onboarded = false,
    this.littleGuard = true,
  });
  final String systemName;
  final String greeting;
  final bool onboarded;
  final bool littleGuard;

  SystemProfile copyWith({
    String? systemName,
    String? greeting,
    bool? onboarded,
    bool? littleGuard,
  }) =>
      SystemProfile(
        systemName: systemName ?? this.systemName,
        greeting: greeting ?? this.greeting,
        onboarded: onboarded ?? this.onboarded,
        littleGuard: littleGuard ?? this.littleGuard,
      );

  Map<String, dynamic> toJson() => {
        'id': 'profile',
        'systemName': systemName,
        'greeting': greeting,
        'onboarded': onboarded,
        'littleGuard': littleGuard,
      };

  factory SystemProfile.fromJson(Map<String, dynamic> j) => SystemProfile(
        systemName: j['systemName'] as String? ?? '',
        greeting: j['greeting'] as String? ?? '',
        onboarded: j['onboarded'] as bool? ?? false,
        littleGuard: j['littleGuard'] as bool? ?? true,
      );
}

class SettingsController extends ChangeNotifier {
  SettingsController(this._store);
  static const collection = 'settings';
  final DocStore _store;

  ThemeConfig theme = const ThemeConfig();
  Terminology terminology = Terminology.standard();
  SystemProfile profile = const SystemProfile();

  Future<void> load() async {
    final t = await _store.get(collection, 'theme');
    final w = await _store.get(collection, 'terminology');
    final p = await _store.get(collection, 'profile');
    if (t != null) theme = ThemeConfig.fromJson(t);
    if (w != null) terminology = Terminology.fromJson(w);
    if (p != null) profile = SystemProfile.fromJson(p);
    notifyListeners();
  }

  Future<void> setTheme(ThemeConfig c) async {
    theme = c;
    await _store.put(collection, c.toJson());
    notifyListeners();
  }

  Future<void> setTerminology(Terminology t) async {
    terminology = t;
    await _store.put(collection, t.toJson());
    notifyListeners();
  }

  Future<void> setProfile(SystemProfile p) async {
    profile = p;
    await _store.put(collection, p.toJson());
    notifyListeners();
  }
}
