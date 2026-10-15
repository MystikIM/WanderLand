import '../domain/models.dart';
import 'friend_models.dart';

/// What THIS friend may learn about who is out. Null = share nothing about front.
/// Only alters ticked for this friend are named; anyone else out becomes "someone".
TheirFront? frontShareFor(Friend f, List<Alter> out) {
  if (!f.shareFront) return null;
  final named = [
    for (final a in out)
      if (f.allowedAlterIds.contains(a.id)) TheirAlter(a.name, a.colorValue),
  ];
  return TheirFront(alters: named, someoneOut: out.length > named.length);
}

/// The "speaking as" label for a message to [f]; null means just the username.
TheirAlter? speakerFor(Friend f, Alter? speaker) {
  if (speaker == null || !f.allowedAlterIds.contains(speaker.id)) return null;
  return TheirAlter(speaker.name, speaker.colorValue);
}
