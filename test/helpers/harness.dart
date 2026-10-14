import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

Future<void> pumpScreen(
  WidgetTester tester,
  Widget child, {
  required List<SingleChildWidget> providers,
}) async {
  // A tall phone-sized surface so long lists are fully built and tappable.
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiProvider(providers: providers, child: MaterialApp(home: child)),
  );
  await tester.pumpAndSettle();
}
