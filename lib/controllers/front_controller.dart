import 'package:flutter/foundation.dart';
import '../data/doc_store.dart';
import '../domain/front_service.dart';
import '../domain/ids.dart';
import '../domain/models.dart';

class FrontController extends ChangeNotifier {
  FrontController(DocStore store, {Clock? clock})
      : clock = clock ?? DateTime.now,
        _service = FrontService(store, clock: clock);

  final Clock clock;
  final FrontService _service;
  List<FrontEntry> current = const [];
  List<FrontEntry> history = const [];

  String? get primaryId => current
      .where((e) => e.tier == FrontTier.primary)
      .map((e) => e.alterId)
      .firstOrNull;

  Future<void> load() async {
    history = await _service.history();
    current = history.where((e) => e.end == null).toList();
    notifyListeners();
  }

  Future<void> set({
    required String primary,
    List<String> coFront = const [],
    List<String> coCon = const [],
    String note = '',
  }) async {
    await _service.setFront(primary: primary, coFront: coFront, coCon: coCon, note: note);
    await load();
  }

  Future<void> clear() async {
    await _service.clearFront();
    await load();
  }
}
