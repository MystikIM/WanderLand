import 'models.dart';

class Activity {
  static DateTime weekStart(DateTime d) =>
      DateTime(d.year, d.month, d.day - (d.weekday - 1));

  static List<Map<String, Duration>> weekDays(
    List<FrontEntry> entries,
    DateTime weekStart,
    DateTime now,
  ) {
    return List.generate(7, (i) {
      final from = DateTime(weekStart.year, weekStart.month, weekStart.day + i);
      final to = DateTime(weekStart.year, weekStart.month, weekStart.day + i + 1);
      final totals = <String, Duration>{};
      for (final e in entries) {
        final overlap = _overlap(e, from, to, now);
        if (overlap > Duration.zero) {
          totals[e.alterId] = (totals[e.alterId] ?? Duration.zero) + overlap;
        }
      }
      return totals;
    });
  }

  static Map<String, Duration> weekTotals(List<Map<String, Duration>> days) {
    final out = <String, Duration>{};
    for (final d in days) {
      d.forEach((k, v) => out[k] = (out[k] ?? Duration.zero) + v);
    }
    return out;
  }

  static Duration _overlap(FrontEntry e, DateTime from, DateTime to, DateTime now) {
    final s = e.start.isAfter(from) ? e.start : from;
    final endRaw = e.end ?? now;
    final f = endRaw.isBefore(to) ? endRaw : to;
    return f.isAfter(s) ? f.difference(s) : Duration.zero;
  }

  static bool _weekend(DateTime d) => d.weekday >= 6;

  /// Who has usually been the primary front at this hour on this kind of day
  /// (weekday vs weekend)? Null unless there is enough history and a clear winner.
  static String? usualFronter({
    required List<FrontEntry> entries,
    required DateTime now,
    int lookbackDays = 56,
    int minDays = 4,
    int minTopDays = 3,
    double minShare = 0.5,
  }) {
    final wins = <String, int>{};
    var days = 0;
    for (var d = 1; d <= lookbackDays; d++) {
      final day = DateTime(now.year, now.month, now.day - d);
      if (_weekend(day) != _weekend(now)) continue;
      final from = DateTime(day.year, day.month, day.day, now.hour);
      final to = from.add(const Duration(hours: 1));
      final byAlter = <String, Duration>{};
      for (final e in entries) {
        if (e.tier != FrontTier.primary) continue;
        final o = _overlap(e, from, to, now);
        if (o > Duration.zero) {
          byAlter[e.alterId] = (byAlter[e.alterId] ?? Duration.zero) + o;
        }
      }
      if (byAlter.isEmpty) continue;
      days++;
      final winner =
          byAlter.entries.reduce((a, b) => b.value > a.value ? b : a).key;
      wins[winner] = (wins[winner] ?? 0) + 1;
    }
    if (days < minDays || wins.isEmpty) return null;
    final top = wins.entries.reduce((a, b) => b.value > a.value ? b : a);
    if (top.value < minTopDays || top.value / days < minShare) return null;
    return top.key;
  }

  static String? headsUp({
    required List<FrontEntry> entries,
    required String pickedAlterId,
    required DateTime now,
  }) {
    final usual = usualFronter(entries: entries, now: now);
    return (usual != null && usual != pickedAlterId) ? usual : null;
  }

  static List<String> recentAlterIds(List<FrontEntry> history, {int limit = 4}) {
    final primaries = history.where((e) => e.tier == FrontTier.primary).toList()
      ..sort((a, b) => b.start.compareTo(a.start));
    final out = <String>[];
    for (final e in primaries) {
      if (!out.contains(e.alterId)) out.add(e.alterId);
      if (out.length == limit) break;
    }
    return out;
  }
}
