import 'package:flutter/foundation.dart';
import '../data/doc_store.dart';
import '../domain/buddy.dart';
import '../domain/ids.dart';
import '../domain/models.dart';
import '../domain/rewards.dart';

class BuddyController extends ChangeNotifier {
  BuddyController(this._store, {Clock? clock}) : clock = clock ?? DateTime.now;
  static const collection = 'buddy';
  final DocStore _store;
  final Clock clock;

  BuddyState state = const BuddyState();
  Map<String, DateTime> earned = {};
  final List<RewardBadge> celebrations = [];

  /// The last care action done and a counter that goes up each time, so the
  /// buddy can play a one-shot animation (chewing, bubbles, cuddles...).
  BuddyAction? lastAction;
  int actionTick = 0;
  int _alterCount = 0;
  int _days = 0;

  Set<String> get unlocked => accessoriesUnlockedBy(earned.keys);
  Set<String> get unlockedOutfits => outfitsUnlockedBy(earned.keys);

  Future<void> setOutfit(String o) async {
    if (o.isNotEmpty && !unlockedOutfits.contains(o)) return;
    state = state.copyWith(outfit: o);
    await _saveState();
    notifyListeners();
  }

  Future<void> load() async {
    final b = await _store.get(collection, 'buddy');
    if (b != null) state = BuddyState.fromJson(b);
    final now = clock();
    state = state.settle(now);
    final visited = state.visit(now);
    final changed = visited.passedAt != state.passedAt || visited.lastSeen != state.lastSeen;
    state = visited;
    if (changed && b != null) await _saveState();
    final r = await _store.get(collection, 'rewards');
    if (r != null) {
      earned = {
        for (final e in (r['earned'] as Map? ?? const {}).entries)
          e.key as String: DateTime.parse(e.value as String),
      };
    }
    notifyListeners();
  }

  Future<void> _saveState() => _store.put(collection, state.toJson());

  Future<void> _saveRewards() => _store.put(collection, {
        'id': 'rewards',
        'earned': {for (final e in earned.entries) e.key: e.value.toIso8601String()},
      });

  Future<void> refresh({required int alterCount, required List<FrontEntry> history}) async {
    _alterCount = alterCount;
    _days = checkInDays(history);
    await _evaluate();
    notifyListeners();
  }

  Future<bool> care(BuddyAction a) async {
    final now = clock();
    final visited = state.visit(now);
    if (!visited.canCare(a, now)) {
      if (visited.isPassed && !state.isPassed) {
        state = visited;
        await _saveState();
        notifyListeners();
      }
      return false;
    }
    state = visited.care(a, now);
    lastAction = a; // the screen plays a little animation for this
    actionTick++;
    await _saveState();
    await _evaluate();
    notifyListeners();
    return true;
  }

  /// Called when the app comes back to the foreground.
  Future<void> visit() async {
    final before = state;
    state = state.settle(clock()).visit(clock());
    if (state.passedAt != before.passedAt || state.lastSeen != before.lastSeen) {
      await _saveState();
    }
    notifyListeners();
  }

  Future<void> setClassic(bool on) async {
    state = state.withClassic(on, clock());
    await _saveState();
    notifyListeners();
  }

  Future<void> hatchNew() async {
    state = state.hatchNew(clock());
    await _saveState();
    notifyListeners();
  }

  Future<void> _evaluate() async {
    final now = clock();
    final got = earnedBadges(
        alterCount: _alterCount, checkInDays: _days, careCount: state.careCount);
    var changed = false;
    for (final b in kBadges) {
      if (got.contains(b.id) && !earned.containsKey(b.id)) {
        earned[b.id] = now;
        if (state.enabled) celebrations.add(b);
        changed = true;
      }
    }
    if (changed) await _saveRewards();
  }

  void dismissCelebrations() {
    celebrations.clear();
    notifyListeners();
  }

  Future<void> rename(String name) async {
    final n = name.trim();
    if (n.isEmpty) return;
    state = state.copyWith(name: n);
    await _saveState();
    notifyListeners();
  }

  Future<void> setSpecies(String s) async {
    if (!kBuddySpecies.contains(s)) return;
    state = state.copyWith(species: s);
    await _saveState();
    notifyListeners();
  }

  Future<void> setAccessory(String a) async {
    if (a.isNotEmpty && !unlocked.contains(a)) return;
    state = state.copyWith(accessory: a);
    await _saveState();
    notifyListeners();
  }

  Future<void> setEnabled(bool v) async {
    state = state.copyWith(enabled: v);
    await _saveState();
    notifyListeners();
  }
}
