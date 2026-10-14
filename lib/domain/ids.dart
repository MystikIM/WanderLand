typedef Clock = DateTime Function();

class IdGen {
  static int _n = 0;
  static String next(DateTime now) =>
      '${now.microsecondsSinceEpoch.toRadixString(36)}-${(_n++).toRadixString(36)}';
}
