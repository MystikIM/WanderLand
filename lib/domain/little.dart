import '../theme/theme_config.dart';
import 'models.dart';

enum LittleLevel { none, young, child }

LittleLevel littleLevelOf(Alter? a) {
  if (a == null) return LittleLevel.none;
  switch (a.littleMode) {
    case 'off':
      return LittleLevel.none;
    case 'on':
      return (a.ageYears != null && a.ageYears! < 6) ? LittleLevel.young : LittleLevel.child;
    default: // 'auto' and anything unknown
      final age = a.ageYears;
      if (age == null) return LittleLevel.none;
      if (age < 6) return LittleLevel.young;
      if (age < 13) return LittleLevel.child;
      return LittleLevel.none;
  }
}

class LittleCopy {
  const LittleCopy(this.level);
  final LittleLevel level;

  static const _normal = {
    'whosOut': "Who's out?",
    'done': 'Save',
    'journal': 'Journal',
    'addFirst': 'Add your first one with the button below.',
    'guardMessage': 'A grown-up alter needs to do this one.',
  };
  static const _child = {
    'whosOut': "Hi! 🌈 Who's out right now?",
    'done': 'Save it! ✨',
    'journal': 'My Diary 📖',
    'addFirst': 'Tap the big button to add your first friend!',
    'guardMessage': 'Ask a grown-up alter to help with this one 💜',
  };
  static const _young = {
    'whosOut': 'Hi hi! 🧸 Who is here?',
    'done': 'Done! ⭐',
    'journal': 'My Drawing Book 🎨',
    'addFirst': 'Push the big button to add a friend! 🎈',
    'guardMessage': 'Get a big helper! 💜',
  };

  String call(String key) {
    final table = switch (level) {
      LittleLevel.none => _normal,
      LittleLevel.child => _child,
      LittleLevel.young => _young,
    };
    return table[key] ?? key;
  }
}

ThemeConfig littleAdjust(ThemeConfig c, LittleLevel level) {
  double up(double v, double floor) => v < floor ? floor : v;
  switch (level) {
    case LittleLevel.none:
      return c;
    case LittleLevel.child:
      return c.copyWith(fontScale: up(c.fontScale, 1.15), cornerRadius: up(c.cornerRadius, 24));
    case LittleLevel.young:
      return c.copyWith(fontScale: up(c.fontScale, 1.3), cornerRadius: up(c.cornerRadius, 28));
  }
}

bool riskyActionsAllowed(LittleLevel level, {required bool guardOn}) =>
    !(guardOn && level != LittleLevel.none);
