import 'package:flutter/foundation.dart';

class DeepLinks {
  /// Increment to ask the app to open the "who's out?" sheet
  /// (notification tap, home-screen widget tap, app shortcut).
  static final ValueNotifier<int> switchRequests = ValueNotifier<int>(0);
}
