import 'dart:math';
import 'package:flutter/material.dart';

class PiecePainter extends CustomPainter {
  PiecePainter(this.kind, this.tint);
  final String kind;
  final Color? tint;

  Color _c(Color fallback) => tint ?? fallback;
  Paint _p(Color c) => Paint()..color = c;

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    switch (kind) {
      case 'tree':
        c.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(w * .44, h * .55, w * .12, h * .40), Radius.circular(w * .03)),
          _p(const Color(0xFF6D4C41)),
        );
        final leaf = _p(_c(const Color(0xFF43A047)));
        c.drawCircle(Offset(w * .5, h * .34), w * .26, leaf);
        c.drawCircle(Offset(w * .32, h * .50), w * .20, leaf);
        c.drawCircle(Offset(w * .68, h * .50), w * .20, leaf);
      case 'lake':
        c.drawOval(Rect.fromLTWH(0, h * .40, w, h * .52), _p(_c(const Color(0xFF4FC3F7))));
        final wave = Paint()
          ..color = const Color(0x66FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * .02
          ..strokeCap = StrokeCap.round;
        c.drawArc(Rect.fromLTWH(w * .2, h * .55, w * .25, h * .12), 0, pi, false, wave);
        c.drawArc(Rect.fromLTWH(w * .55, h * .65, w * .22, h * .10), 0, pi, false, wave);
      case 'house':
        c.drawRect(Rect.fromLTWH(w * .2, h * .45, w * .6, h * .45), _p(_c(const Color(0xFFFFB74D))));
        c.drawPath(
          Path()
            ..moveTo(w * .12, h * .47)
            ..lineTo(w * .5, h * .14)
            ..lineTo(w * .88, h * .47)
            ..close(),
          _p(const Color(0xFFD84315)),
        );
        c.drawRect(Rect.fromLTWH(w * .43, h * .62, w * .14, h * .28), _p(const Color(0xFF6D4C41)));
        c.drawRect(Rect.fromLTWH(w * .26, h * .55, w * .12, h * .12), _p(const Color(0xFFB3E5FC)));
        c.drawRect(Rect.fromLTWH(w * .62, h * .55, w * .12, h * .12), _p(const Color(0xFFB3E5FC)));
      case 'mountain':
        c.drawPath(
          Path()
            ..moveTo(0, h * .92)
            ..lineTo(w * .5, h * .12)
            ..lineTo(w, h * .92)
            ..close(),
          _p(_c(const Color(0xFF78909C))),
        );
        c.drawPath(
          Path()
            ..moveTo(w * .38, h * .32)
            ..lineTo(w * .5, h * .12)
            ..lineTo(w * .62, h * .32)
            ..lineTo(w * .5, h * .28)
            ..close(),
          _p(const Color(0xFFFFFFFF)),
        );
      case 'sun':
        final sun = _c(const Color(0xFFFFC107));
        final ray = Paint()
          ..color = sun
          ..strokeWidth = w * .04
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 8; i++) {
          final a = i * pi / 4;
          c.drawLine(
            Offset(w * .5 + cos(a) * w * .32, h * .5 + sin(a) * h * .32),
            Offset(w * .5 + cos(a) * w * .46, h * .5 + sin(a) * h * .46),
            ray,
          );
        }
        c.drawCircle(Offset(w * .5, h * .5), w * .24, _p(sun));
      case 'moon':
        final moon = Path.combine(
          PathOperation.difference,
          Path()..addOval(Rect.fromCircle(center: Offset(w * .5, h * .5), radius: w * .36)),
          Path()..addOval(Rect.fromCircle(center: Offset(w * .66, h * .42), radius: w * .32)),
        );
        c.drawPath(moon, _p(_c(const Color(0xFFFFF59D))));
      case 'flower':
        c.drawLine(
          Offset(w * .5, h * .45),
          Offset(w * .5, h * .95),
          Paint()
            ..color = const Color(0xFF2E7D32)
            ..strokeWidth = w * .05
            ..strokeCap = StrokeCap.round,
        );
        final petal = _p(_c(const Color(0xFFF06292)));
        for (var i = 0; i < 5; i++) {
          final a = -pi / 2 + i * 2 * pi / 5;
          c.drawCircle(Offset(w * .5 + cos(a) * w * .17, h * .30 + sin(a) * h * .17), w * .12, petal);
        }
        c.drawCircle(Offset(w * .5, h * .30), w * .09, _p(const Color(0xFFFFEB3B)));
      case 'door':
        final door = Path()
          ..moveTo(w * .28, h * .92)
          ..lineTo(w * .28, h * .40)
          ..arcToPoint(Offset(w * .72, h * .40), radius: Radius.circular(w * .22), clockwise: true)
          ..lineTo(w * .72, h * .92)
          ..close();
        c.drawPath(door, _p(_c(const Color(0xFF7E57C2))));
        c.drawCircle(Offset(w * .64, h * .64), w * .03, _p(const Color(0xFFFFEB3B)));
    }
  }

  @override
  bool shouldRepaint(covariant PiecePainter old) => old.kind != kind || old.tint != tint;
}
