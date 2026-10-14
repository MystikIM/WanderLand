import 'package:flutter/material.dart';
import '../domain/alter_links.dart';

class LinkedText extends StatelessWidget {
  const LinkedText({
    super.key,
    required this.text,
    required this.names,
    required this.onTap,
    this.style,
  });
  final String text;
  final List<NameRef> names;
  final void Function(List<String> alterIds) onTap;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final spans = AlterLinker.find(text, names);
    final base = style ?? DefaultTextStyle.of(context).style;
    final linkStyle = base.copyWith(
      color: Theme.of(context).colorScheme.secondary,
      decoration: TextDecoration.underline,
      fontWeight: FontWeight.w600,
    );
    final children = <InlineSpan>[];
    var i = 0;
    for (var k = 0; k < spans.length; k++) {
      final s = spans[k];
      if (s.start > i) children.add(TextSpan(text: text.substring(i, s.start)));
      children.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: InkWell(
          key: ValueKey('alter-link-$k'),
          onTap: () => onTap(s.alterIds),
          child: Text(s.text, style: linkStyle),
        ),
      ));
      i = s.end;
    }
    if (i < text.length) children.add(TextSpan(text: text.substring(i)));
    return Text.rich(TextSpan(style: base, children: children));
  }
}
