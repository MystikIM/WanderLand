import 'package:flutter/material.dart';

class ComingSoon extends StatelessWidget {
  const ComingSoon(this.name, {super.key});
  final String name;
  @override
  Widget build(BuildContext context) =>
      Center(child: Text('$name is coming soon', textAlign: TextAlign.center));
}
