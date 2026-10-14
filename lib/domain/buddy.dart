import 'little.dart';

enum BuddyAction { feed, play, cuddle }

enum BuddyMood { happy, content, sleepy }

const List<String> kBuddySpecies = [
  'blob', 'cat', 'dog', 'bunny', 'rabbit', 'frog', 'turtle', 'butterfly', 'fairy', 'unicorn',
];
const Duration kBuddyCooldown = Duration(minutes: 5);
const double kBuddyFloor = 30;

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
  });

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
  }) =>
      BuddyState(
        name: name ?? this.name,
        species: species ?? this.species,
        accessory: accessory ?? this.accessory,
        enabled: enabled ?? this.enabled,
        joy: joy ?? this.joy,
        tummy: tummy ?? this.tummy,
        careCount: careCount ?? this.careCount,
        lastCare: lastCare ?? this.lastCare,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  static double _drift(double v, double drop) {
    if (v <= kBuddyFloor) return v;
    return (v - drop) < kBuddyFloor ? kBuddyFloor : v - drop;
  }

  /// Let time pass. Numbers only ever drift down to a gentle floor, never below.
  BuddyState settle(DateTime now) {
    final since = updatedAt;
    if (since == null) return copyWith(updatedAt: now);
    if (!now.isAfter(since)) return this;
    final hours = now.difference(since).inMinutes / 60.0;
    return copyWith(joy: _drift(joy, hours), tummy: _drift(tummy, hours * 2), updatedAt: now);
  }

  bool canCare(BuddyAction a, DateTime now) {
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
      case BuddyAction.play:
        joy = cap(joy + 20);
        tummy = lower(tummy);
      case BuddyAction.cuddle:
        joy = cap(joy + 12);
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
