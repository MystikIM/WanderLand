import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../controllers/alter_controller.dart';
import '../controllers/front_controller.dart';
import '../domain/little.dart';

/// Little level of whoever is the primary front right now.
LittleLevel currentLittleLevel(BuildContext context) {
  final front = context.watch<FrontController>();
  final alters = context.watch<AlterController>();
  final id = front.primaryId;
  return littleLevelOf(id == null ? null : alters.byId(id));
}
