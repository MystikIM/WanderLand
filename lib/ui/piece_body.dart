import 'dart:math';
import 'package:flutter/material.dart';
import 'art.dart';
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
              child: kPieceArt.contains(widget.kind)
                  ? _PieceArt(kind: widget.kind, tint: widget.tint, giggle: live)
                  : CustomPaint(painter: PiecePainter(widget.kind, widget.tint, giggle: live ? 1 : 0)),
            );
          },
        ),
      );
}

/// The real picture: calm normally, giggle while it bounces. Both stay loaded
/// so the swap never flickers. If a picture is missing the drawn one is used.
class _PieceArt extends StatelessWidget {
  const _PieceArt({required this.kind, required this.tint, required this.giggle});
  final String kind;
  final Color? tint;
  final bool giggle;

  @override
  Widget build(BuildContext context) {
    final fallback = CustomPaint(painter: PiecePainter(kind, tint, giggle: giggle ? 1 : 0));
    final t = tint == null ? null : softTint(tint!);
    Widget layer(String name, bool visible) => Visibility(
          visible: visible,
          maintainState: true,
          maintainSize: true,
          maintainAnimation: true,
          child: ArtImage(name, fit: BoxFit.contain, tint: t, fallback: visible ? fallback : const SizedBox.shrink()),
        );
    return Stack(fit: StackFit.expand, children: [
      layer('piece_$kind', !giggle),
      layer('piece_${kind}_giggle', giggle),
    ]);
  }
}
