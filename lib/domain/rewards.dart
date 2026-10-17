import 'models.dart';

class RewardBadge {
  const RewardBadge(this.id, this.title, this.emoji, this.how);
  final String id;
  final String title;
  final String emoji;
  final String how;
}

const List<RewardBadge> kBadges = [
  RewardBadge('first-alter', 'First friend', '🌱', 'Add your first alter'),
  RewardBadge('alters-5', 'Growing system', '🌳', 'Have 5 alters'),
  RewardBadge('alters-10', 'Big family', '🏡', 'Have 10 alters'),
  RewardBadge('first-checkin', 'Hello!', '👋', 'Check in for the first time'),
  RewardBadge('checkin-3', 'Getting into it', '⭐', 'Check in on 3 different days'),
  RewardBadge('checkin-7', 'A week of care', '🌈', 'Check in on 7 different days'),
  RewardBadge('checkin-14', 'Two weeks strong', '🌻', 'Check in on 14 different days'),
  RewardBadge('checkin-30', 'Cozy habit', '🏅', 'Check in on 30 different days'),
  RewardBadge('care-10', 'Buddy buddy', '🧸', 'Care for your buddy 10 times'),
  RewardBadge('care-50', 'Best friends', '💞', 'Care for your buddy 50 times'),
];

/// Different calendar days with at least one check-in. Gaps never matter.
int checkInDays(List<FrontEntry> history) =>
    {for (final e in history) (e.start.year, e.start.month, e.start.day)}.length;

Set<String> earnedBadges({
  required int alterCount,
  required int checkInDays,
  required int careCount,
}) =>
    {
      if (alterCount >= 1) 'first-alter',
      if (alterCount >= 5) 'alters-5',
      if (alterCount >= 10) 'alters-10',
      if (checkInDays >= 1) 'first-checkin',
      if (checkInDays >= 3) 'checkin-3',
      if (checkInDays >= 7) 'checkin-7',
      if (checkInDays >= 14) 'checkin-14',
      if (checkInDays >= 30) 'checkin-30',
      if (careCount >= 10) 'care-10',
      if (careCount >= 50) 'care-50',
    };
