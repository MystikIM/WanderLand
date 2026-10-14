import 'little.dart';

enum BuddyAction { feed, snack, walk, play, cuddle, pet, wash }

const Map<BuddyAction, String> kBuddyActionLabels = {
  BuddyAction.feed: '🍎 Feed',
  BuddyAction.snack: '🍪 Snack',
  BuddyAction.walk: '🦮 Walk',
  BuddyAction.play: '🎈 Play',
  BuddyAction.cuddle: '💜 Cuddle',
  BuddyAction.pet: '🤚 Pet',
  BuddyAction.wash: '🛁 Wash',
};

enum BuddyMood { happy, content, sleepy }

const List<String> kBuddySpecies = [
  'blob', 'cat', 'dog', 'bunny', 'rabbit', 'frog', 'turtle', 'butterfly', 'fairy', 'unicorn',
];
const Duration kBuddyCooldown = Duration(minutes: 5);
const double kBuddyFloor = 30;
const Duration kClassicAway = Duration(days: 7);

class BuddyMemorial {
  const BuddyMemorial({required this.name, required this.species, required this.passedAt});
  final String name;
  final String species;
  final DateTime passedAt;

  Map<String, dynamic> toJson() =>
      {'name': name, 'species': species, 'passedAt': passedAt.toIso8601String()};

  factory BuddyMemorial.fromJson(Map<String, dynamic> j) => BuddyMemorial(
        name: j['name'] as String? ?? 'Buddy',
        species: j['species'] as String? ?? 'blob',
        passedAt: DateTime.parse(j['passedAt'] as String),
      );
}

class BuddyState {
  const BuddyState({
    this.name = 'Buddy',
    this.species = 'blob',
    this.accessory = '',
    this.enabled = true,
    this.joy = 70,
    this.tummy = 70,
    this.careCount = 0,
    this.lastCare = const {},
    this.updatedAt,
    this.classic = false,
    this.lastSeen,
    this.passedAt,
    this.generation = 1,
    this.memorial = const [],
    this.outfit = '',
  });

  final String outfit;
  final bool classic;
  final DateTime? lastSeen;
  final DateTime? passedAt;
  final int generation;
  final List<BuddyMemorial> memorial;
  bool get isPassed => passedAt != null;

  final String name;
  final String species;
  final String accessory;
  final bool enabled;
  final double joy;
  final double tummy;
  final int careCount;
  final Map<String, DateTime> lastCare;
  final DateTime? updatedAt;

  BuddyState copyWith({
    String? name,
    String? species,
    String? accessory,
    bool? enabled,
    double? joy,
    double? tummy,
    int? careCount,
    Map<String, DateTime>? lastCare,
    DateTime? updatedAt,
    bool? classic,
    DateTime? lastSeen,
    DateTime? passedAt,
    bool clearPassed = false,
    int? generation,
    List<BuddyMemorial>? memorial,
    String? outfit,
  }) =>
      BuddyState(
        outfit: outfit ?? this.outfit,
        name: name ?? this.name,
        species: species ?? this.species,
        accessory: accessory ?? this.accessory,
        enabled: enabled ?? this.enabled,
        joy: joy ?? this.joy,
        tummy: tummy ?? this.tummy,
        careCount: careCount ?? this.careCount,
        lastCare: lastCare ?? this.lastCare,
        updatedAt: updatedAt ?? this.updatedAt,
        classic: classic ?? this.classic,
        lastSeen: lastSeen ?? this.lastSeen,
        passedAt: clearPassed ? null : (passedAt ?? this.passedAt),
        generation: generation ?? this.generation,
        memorial: memorial ?? this.memorial,
      );

  static double _drift(double v, double drop, double floor) {
    if (v <= floor) return v;
    return (v - drop) < floor ? floor : v - drop;
  }

  /// Let time pass. Numbers only ever drift down to a gentle floor, never below
  /// (classic mode removes the floor).
  BuddyState settle(DateTime now) {
    final since = updatedAt;
    if (since == null) return copyWith(updatedAt: now);
    if (!now.isAfter(since)) return this;
    final hours = now.difference(since).inMinutes / 60.0;
    final floor = classic ? 0.0 : kBuddyFloor;
    return copyWith(
      joy: _drift(joy, hours, floor),
      tummy: _drift(tummy, hours * 2, floor),
      updatedAt: now,
    );
  }

  /// Call when the app opens or the buddy is cared for. In classic mode, being
  /// away for 7 days means the buddy has passed.
  BuddyState visit(DateTime now) {
    if (isPassed) return this;
    final seen = lastSeen;
    if (classic && seen != null && now.difference(seen) >= kClassicAway) {
      final when = seen.add(kClassicAway);
      return copyWith(
        passedAt: when,
        memorial: [...memorial, BuddyMemorial(name: name, species: species, passedAt: when)],
      );
    }
    return copyWith(lastSeen: now);
  }

  BuddyState hatchNew(DateTime now) => BuddyState(
        species: species,
        accessory: accessory,
        enabled: enabled,
        classic: classic,
        careCount: careCount,
        generation: generation + 1,
        memorial: memorial,
        outfit: outfit,
        lastSeen: now,
        updatedAt: now,
      );

  BuddyState withClassic(bool on, DateTime now) {
    if (on) return copyWith(classic: true, lastSeen: now);
    if (isPassed) {
      return copyWith(
        classic: false,
        clearPassed: true,
        joy: 60,
        tummy: 60,
        memorial: memorial.isEmpty ? memorial : memorial.sublist(0, memorial.length - 1),
        lastSeen: now,
        updatedAt: now,
      );
    }
    return copyWith(
      classic: false,
      joy: joy < kBuddyFloor ? kBuddyFloor : joy,
      tummy: tummy < kBuddyFloor ? kBuddyFloor : tummy,
    );
  }

  bool canCare(BuddyAction a, DateTime now) {
    if (isPassed) return false;
    final last = lastCare[a.name];
    if (last == null || now.isBefore(last)) return true;
    return now.difference(last) >= kBuddyCooldown;
  }

  BuddyState care(BuddyAction a, DateTime now) {
    if (!canCare(a, now)) return this;
    final s = settle(now);
    double cap(double v) => v > 100 ? 100 : v;
    double lower(double v) => v - 5 < kBuddyFloor ? kBuddyFloor : v - 5;
    var joy = s.joy;
    var tummy = s.tummy;
    switch (a) {
      case BuddyAction.feed:
        tummy = cap(tummy + 25);
        joy = cap(joy + 5);
      case BuddyAction.snack:
        tummy = cap(tummy + 10);
        joy = cap(joy + 8);
      case BuddyAction.walk:
        joy = cap(joy + 15);
        tummy = lower(tummy);
      case BuddyAction.play:
        joy = cap(joy + 20);
        tummy = lower(tummy);
      case BuddyAction.cuddle:
        joy = cap(joy + 12);
      case BuddyAction.pet:
        joy = cap(joy + 8);
      case BuddyAction.wash:
        joy = cap(joy + 10);
    }
    return s.copyWith(
      joy: joy,
      tummy: tummy,
      careCount: s.careCount + 1,
      lastCare: {...s.lastCare, a.name: now},
    );
  }

  BuddyMood moodAt(DateTime now) {
    final s = settle(now);
    final m = (s.joy + s.tummy) / 2;
    if (m >= 70) return BuddyMood.happy;
    if (m >= 45) return BuddyMood.content;
    return BuddyMood.sleepy;
  }

  Map<String, dynamic> toJson() => {
        'id': 'buddy',
        'name': name,
        'species': species,
        'accessory': accessory,
        'enabled': enabled,
        'joy': joy,
        'tummy': tummy,
        'careCount': careCount,
        'lastCare': {for (final e in lastCare.entries) e.key: e.value.toIso8601String()},
        'updatedAt': updatedAt?.toIso8601String(),
        'classic': classic,
        'lastSeen': lastSeen?.toIso8601String(),
        'passedAt': passedAt?.toIso8601String(),
        'generation': generation,
        'memorial': [for (final m in memorial) m.toJson()],
        'outfit': outfit,
      };

  factory BuddyState.fromJson(Map<String, dynamic> j) => BuddyState(
        name: j['name'] as String? ?? 'Buddy',
        species: j['species'] as String? ?? 'blob',
        accessory: j['accessory'] as String? ?? '',
        enabled: j['enabled'] as bool? ?? true,
        joy: (j['joy'] as num?)?.toDouble() ?? 70,
        tummy: (j['tummy'] as num?)?.toDouble() ?? 70,
        careCount: j['careCount'] as int? ?? 0,
        lastCare: {
          for (final e in (j['lastCare'] as Map? ?? const {}).entries)
            e.key as String: DateTime.parse(e.value as String),
        },
        updatedAt: j['updatedAt'] == null ? null : DateTime.parse(j['updatedAt'] as String),
        classic: j['classic'] as bool? ?? false,
        lastSeen: j['lastSeen'] == null ? null : DateTime.parse(j['lastSeen'] as String),
        passedAt: j['passedAt'] == null ? null : DateTime.parse(j['passedAt'] as String),
        generation: j['generation'] as int? ?? 1,
        outfit: j['outfit'] as String? ?? '',
        memorial: [
          for (final m in (j['memorial'] as List? ?? const []))
            BuddyMemorial.fromJson(Map<String, dynamic>.from(m as Map)),
        ],
      );
}

String buddyGreeting({
  String? alterName,
  required BuddyMood mood,
  LittleLevel level = LittleLevel.none,
}) {
  final who = (alterName == null || alterName.trim().isEmpty) ? null : alterName.trim();
  final sleepy = mood == BuddyMood.sleepy;
  if (who == null) return sleepy ? 'Yawn... hi there! 😴' : 'Hi there!';
  switch (level) {
    case LittleLevel.young:
      return 'Hiii $who!! 🧸';
    case LittleLevel.child:
      return sleepy ? 'Yawn... hi $who! 😴' : 'Hi $who! 🌈';
    case LittleLevel.none:
      return sleepy ? "Yawn... hi, $who! I'm glad you're here 😴" : 'Hi, $who! 💜';
  }
}
