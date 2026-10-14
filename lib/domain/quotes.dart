import 'little.dart';

class QuotePrefs {
  const QuotePrefs({this.enabled = true, this.lastDay = '', this.lastIndex = -1});
  final bool enabled;
  final String lastDay;
  final int lastIndex;

  QuotePrefs copyWith({bool? enabled, String? lastDay, int? lastIndex}) => QuotePrefs(
        enabled: enabled ?? this.enabled,
        lastDay: lastDay ?? this.lastDay,
        lastIndex: lastIndex ?? this.lastIndex,
      );

  Map<String, dynamic> toJson() =>
      {'id': 'quotes', 'enabled': enabled, 'lastDay': lastDay, 'lastIndex': lastIndex};

  factory QuotePrefs.fromJson(Map<String, dynamic> j) => QuotePrefs(
        enabled: j['enabled'] as bool? ?? true,
        lastDay: j['lastDay'] as String? ?? '',
        lastIndex: j['lastIndex'] as int? ?? -1,
      );
}

/// Original, warm, plural-friendly notes. Written for this app; not attributed
/// to anyone. Bank sizes are not multiples of 7 so the daily step visits all.
const List<String> kQuotes = [
  'You are allowed to take up space exactly as you are.',
  'Every one of you belongs here.',
  'Rest is not a reward. It is part of the work.',
  'Being gentle with yourself counts as progress.',
  'You do not have to earn kindness.',
  'Small steps still move you forward.',
  'You made it to today, and that took strength.',
  'Everyone inside deserves to be heard.',
  'Your feelings make sense, even the confusing ones.',
  'You can be proud of how far you have come.',
  'It is okay to need help. Needing help is human.',
  'You are not too much, and you are not too little.',
  'Today you get to decide what kindness looks like.',
  'Taking a breath is a brave thing to do.',
  'You are not a problem to be solved.',
  'Healing does not have to be tidy.',
  'You are more than the hard things you have been through.',
  'Each of you matters, in your own way.',
  'A slow day is still a good day.',
  'You are worthy of care, today and always.',
  'Your story is yours to tell, or to keep.',
  'Be as patient with yourself as you are with the people you love.',
  'You deserve safe and gentle moments.',
  'It is okay to change. It is okay to stay the same.',
  'Showing up today was enough.',
  'You are doing better than you think.',
  'Your voice matters in this space, and so does your silence.',
  'There is room here for all of you.',
  'You are allowed to have good days without guilt.',
  'Your identity is yours, and it is valid.',
  'Love who you are, as many as you are.',
  'You get to define what feels like home.',
  'Even on hard days, you are not alone.',
  'Courage can be very quiet.',
  'You are learning how to take care of each other, and that is beautiful.',
  'It is okay to ask for what you need.',
  'Your pace is the right pace.',
  'You bring something special to this world.',
  'Be proud of surviving, and be gentle about healing.',
  'Today is a fresh page, and you hold the pen together.',
];

const List<String> kLittleQuotes = [
  'You are loved just the way you are! 💜',
  'You are brave and kind and special! 🌈',
  'It is okay to play today! 🎈',
  'You did a great job being you! ⭐',
  'Big hugs for you! 🤗',
  'You are safe here. 🏡',
  'It is okay to feel sad. It is okay to feel happy too! 🌤️',
  'You are a good friend! 🧸',
  'Your buddy is happy to see you! 🐾',
  'Every color is a good color! 🎨',
  'You are allowed to ask for help! 🤝',
  'Today is a good day for a snack and a cuddle! 🍪',
  'You are never in trouble for having feelings! 💛',
  'Your ideas are wonderful! 💡',
  'Being silly is the best! 🤪',
  'You are growing and learning every day! 🌱',
  'There is a place for you here! 🏠',
  'You can take your time! 🐢',
  'You are super special! 🦄',
  'Everybody gets to rest sometimes! 😴',
  'You are so, so loved! 💞',
  'Today we can be kind to each other! 🌸',
  'You can always try again! 🚀',
  'You are a star! ✨',
];

String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

int _dayNumber(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(2026)).inDays;

/// Pick today's note. Same result all day; a new day steps by 7 through the bank.
QuotePrefs chooseTodaysQuote(QuotePrefs p, DateTime now) {
  final today = dayKey(now);
  if (p.lastDay == today && p.lastIndex >= 0) return p;
  var idx = _dayNumber(now) * 7 + 3;
  if (idx == p.lastIndex) idx += 1;
  return p.copyWith(lastDay: today, lastIndex: idx);
}

QuotePrefs nextQuote(QuotePrefs p) => p.copyWith(lastIndex: p.lastIndex + 1);

String quoteText(LittleLevel level, int index) {
  final bank = level == LittleLevel.none ? kQuotes : kLittleQuotes;
  return bank[index % bank.length];
}
