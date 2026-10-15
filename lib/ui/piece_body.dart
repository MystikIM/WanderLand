import 'dart:math';
import 'package:flutter/material.dart';
import 'scene_painters.dart';

/// One piece in the Inner World. Tap it and it giggles and bounces (one short
/// animation, never a loop). Drag and long-press are passed through.
class PieceBody extends StatefulWidget {
  const PieceBody({
    super.key,
    required this.kind,
    required this.tint,
    this.onPanUpdate,
    this.onPanEnd,
    this.onLongPress,
  });
  final String kind;
  final Color? tint;
  final GestureDragUpdateCallback? onPanUpdate;
  final GestureDragEndCallback? onPanEnd;
  final VoidCallback? onLongPress;

  @override
  State<PieceBody> createState() => _PieceBodyState();
}

class _PieceBodyState extends State<PieceBody> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900), value: 1);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => _ctl.forward(from: 0),
        onPanUpdate: widget.onPanUpdate,
        onPanEnd: widget.onPanEnd,
        onLongPress: widget.onLongPress,
        child: AnimatedBuilder(
          animation: _ctl,
          builder: (_, _) {
            final t = _ctl.value;
            final live = t < 1;
            final fade = 1 - t;
            final bounce = live ? sin(t * pi * 3) * fade : 0.0;
            return Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.identity()
                ..rotateZ(live ? sin(t * pi * 4) * fade * .14 : 0)
                ..scaleByDouble(1 + .07 * bounce, 1 - .07 * bounce, 1, 1),
              child: CustomPaint(painter: PiecePainter(widget.kind, widget.tint, giggle: live ? 1 : 0)),
            );
          },
        ),
      );
}
