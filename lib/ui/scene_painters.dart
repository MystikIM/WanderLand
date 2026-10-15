import 'dart:math';
import 'package:flutter/material.dart';

const _ink = Color(0xFF2B1B3D);

/// Cartoony thick-outline pieces for the Inner World scene.
class PiecePainter extends CustomPainter {
  PiecePainter(this.kind, this.tint);
  final String kind;
  final Color? tint;

  Color _c(Color fallback) => tint ?? fallback;
  Paint _p(Color c) => Paint()..color = c;

  late Paint _line;

  void _o(Canvas c, Path p, Color fill) {
    c.drawPath(p, _p(fill));
    c.drawPath(p, _line);
  }

  void _oval(Canvas c, Rect r, Color fill) => _o(c, Path()..addOval(r), fill);
  void _rr(Canvas c, Rect r, double rad, Color fill) =>
      _o(c, Path()..addRRect(RRect.fromRectAndRadius(r, Radius.circular(rad))), fill);

  void _shine(Canvas c, Rect r) => c.drawOval(r, _p(const Color(0x88FFFFFF)));

  void _sparkle(Canvas c, Offset o, double r) {
    final p = Path();
    for (var i = 0; i < 8; i++) {
      final a = -pi / 2 + i * pi / 4;
      final rad = i.isEven ? r : r * .3;
      final pt = Offset(o.dx + rad * cos(a), o.dy + rad * sin(a));
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    c.drawPath(p..close(), _p(const Color(0xFFFFF59D)));
  }

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    _line = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * .045
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    switch (kind) {
      case 'tree':
        _rr(c, Rect.fromLTWH(w * .43, h * .52, w * .14, h * .42), w * .04, const Color(0xFF8D5A3B));
        c.drawLine(Offset(w * .5, h * .70), Offset(w * .5, h * .86), Paint()
          ..color = const Color(0x55000000)
          ..strokeWidth = w * .02
          ..strokeCap = StrokeCap.round);
        var crown = Path()..addOval(Rect.fromCircle(center: Offset(w * .5, h * .32), radius: w * .27));
        for (final o in [Offset(w * .30, h * .50), Offset(w * .70, h * .50)]) {
          crown = Path.combine(PathOperation.union, crown, Path()..addOval(Rect.fromCircle(center: o, radius: w * .21)));
        }
        _o(c, crown, _c(const Color(0xFF4CD964)));
        _shine(c, Rect.fromLTWH(w * .30, h * .15, w * .20, h * .11));
        for (final o in [Offset(.42, .40), Offset(.62, .30), Offset(.34, .52)]) {
          c.drawCircle(Offset(w * o.dx, h * o.dy), w * .02, _p(const Color(0x33000000)));
        }
      case 'lake':
        final pond = Rect.fromLTWH(w * .02, h * .38, w * .96, h * .54);
        _oval(c, pond, _c(const Color(0xFF45C8FF)));
        c.drawOval(Rect.fromLTWH(w * .12, h * .46, w * .76, h * .34), _p(const Color(0x33FFFFFF)));
        final wave = Paint()
          ..color = const Color(0xCCFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * .03
          ..strokeCap = StrokeCap.round;
        c.drawArc(Rect.fromLTWH(w * .20, h * .52, w * .26, h * .14), 0, pi, false, wave);
        c.drawArc(Rect.fromLTWH(w * .54, h * .64, w * .22, h * .11), 0, pi, false, wave);
        _sparkle(c, Offset(w * .74, h * .52), w * .07);
      case 'house':
        _rr(c, Rect.fromLTWH(w * .20, h * .45, w * .60, h * .46), w * .03, _c(const Color(0xFFFFB347)));
        _o(
          c,
          Path()
            ..moveTo(w * .10, h * .49)
            ..lineTo(w * .50, h * .12)
            ..lineTo(w * .90, h * .49)
            ..close(),
          const Color(0xFFFF4D8D),
        );
        _rr(c, Rect.fromLTWH(w * .42, h * .62, w * .16, h * .29), w * .08, const Color(0xFF7E57C2));
        c.drawCircle(Offset(w * .54, h * .78), w * .016, _p(const Color(0xFFFFE680)));
        _rr(c, Rect.fromLTWH(w * .25, h * .54, w * .13, h * .13), w * .02, const Color(0xFFFFF3A6));
        _rr(c, Rect.fromLTWH(w * .62, h * .54, w * .13, h * .13), w * .02, const Color(0xFFFFF3A6));
        _rr(c, Rect.fromLTWH(w * .66, h * .17, w * .07, h * .14), w * .01, const Color(0xFF8D5A3B));
      case 'mountain':
        final peak = Path()
          ..moveTo(w * .02, h * .92)
          ..lineTo(w * .50, h * .10)
          ..lineTo(w * .98, h * .92)
          ..close();
        _o(c, peak, _c(const Color(0xFF8E7CFF)));
        c.drawPath(
          Path()
            ..moveTo(w * .50, h * .10)
            ..lineTo(w * .98, h * .92)
            ..lineTo(w * .62, h * .92)
            ..close(),
          _p(const Color(0x33000000)),
        );
        _o(
          c,
          Path()
            ..moveTo(w * .37, h * .34)
            ..lineTo(w * .50, h * .10)
            ..lineTo(w * .63, h * .34)
            ..lineTo(w * .55, h * .30)
            ..lineTo(w * .50, h * .36)
            ..lineTo(w * .44, h * .30)
            ..close(),
          const Color(0xFFFFFFFF),
        );
      case 'sun':
        final sun = _c(const Color(0xFFFFC93C));
        for (var i = 0; i < 8; i++) {
          final a = i * pi / 4;
          final p0 = Offset(w * .5 + cos(a) * w * .30, h * .5 + sin(a) * h * .30);
          final p1 = Offset(w * .5 + cos(a) * w * .46, h * .5 + sin(a) * h * .46);
          c.drawLine(p0, p1, Paint()
            ..color = _ink
            ..strokeWidth = w * .10
            ..strokeCap = StrokeCap.round);
          c.drawLine(p0, p1, Paint()
            ..color = sun
            ..strokeWidth = w * .055
            ..strokeCap = StrokeCap.round);
        }
        _oval(c, Rect.fromCircle(center: Offset(w * .5, h * .5), radius: w * .25), sun);
        _shine(c, Rect.fromLTWH(w * .36, h * .33, w * .14, h * .08));
        for (final dx in [-1.0, 1.0]) {
          c.drawArc(Rect.fromCenter(center: Offset(w * (.5 + dx * .09), h * .49), width: w * .08, height: w * .08), pi, pi, false,
              Paint()
                ..color = _ink
                ..style = PaintingStyle.stroke
                ..strokeWidth = w * .02
                ..strokeCap = StrokeCap.round);
          c.drawOval(Rect.fromCenter(center: Offset(w * (.5 + dx * .15), h * .58), width: w * .07, height: w * .045),
              _p(const Color(0x88FF6FA5)));
        }
        c.drawArc(Rect.fromCenter(center: Offset(w * .5, h * .57), width: w * .10, height: w * .06), 0, pi, false,
            Paint()
              ..color = _ink
              ..style = PaintingStyle.stroke
              ..strokeWidth = w * .02
              ..strokeCap = StrokeCap.round);
      case 'moon':
        final moon = Path.combine(
          PathOperation.difference,
          Path()..addOval(Rect.fromCircle(center: Offset(w * .5, h * .5), radius: w * .36)),
          Path()..addOval(Rect.fromCircle(center: Offset(w * .67, h * .42), radius: w * .31)),
        );
        _o(c, moon, _c(const Color(0xFFFFF176)));
        c.drawCircle(Offset(w * .30, h * .56), w * .03, _p(const Color(0x33000000)));
        c.drawCircle(Offset(w * .38, h * .70), w * .02, _p(const Color(0x33000000)));
        _sparkle(c, Offset(w * .78, h * .24), w * .09);
        _sparkle(c, Offset(w * .84, h * .62), w * .05);
      case 'flower':
        c.drawLine(Offset(w * .5, h * .45), Offset(w * .5, h * .95), Paint()
          ..color = _ink
          ..strokeWidth = w * .10
          ..strokeCap = StrokeCap.round);
        c.drawLine(Offset(w * .5, h * .45), Offset(w * .5, h * .95), Paint()
          ..color = const Color(0xFF3DDC84)
          ..strokeWidth = w * .05
          ..strokeCap = StrokeCap.round);
        _oval(c, Rect.fromCenter(center: Offset(w * .66, h * .75), width: w * .22, height: w * .11), const Color(0xFF3DDC84));
        var petals = Path();
        for (var i = 0; i < 5; i++) {
          final a = -pi / 2 + i * 2 * pi / 5;
          petals = Path.combine(PathOperation.union, petals,
              Path()..addOval(Rect.fromCircle(center: Offset(w * .5 + cos(a) * w * .17, h * .30 + sin(a) * h * .17), radius: w * .13)));
        }
        _o(c, petals, _c(const Color(0xFFFF6FB5)));
        _oval(c, Rect.fromCircle(center: Offset(w * .5, h * .30), radius: w * .095), const Color(0xFFFFE14D));
        c.drawCircle(Offset(w * .47, h * .27), w * .02, _p(const Color(0xAAFFFFFF)));
      case 'door':
        _sparkle(c, Offset(w * .14, h * .30), w * .07);
        _sparkle(c, Offset(w * .88, h * .22), w * .06);
        final door = Path()
          ..moveTo(w * .26, h * .93)
          ..lineTo(w * .26, h * .40)
          ..arcToPoint(Offset(w * .74, h * .40), radius: Radius.circular(w * .24), clockwise: true)
          ..lineTo(w * .74, h * .93)
          ..close();
        _o(c, door, _c(const Color(0xFF9B6BFF)));
        final inner = Path()
          ..moveTo(w * .34, h * .93)
          ..lineTo(w * .34, h * .42)
          ..arcToPoint(Offset(w * .66, h * .42), radius: Radius.circular(w * .16), clockwise: true)
          ..lineTo(w * .66, h * .93)
          ..close();
        c.drawPath(inner, _p(const Color(0xFFFF8FD1)));
        c.drawPath(inner, Paint()
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * .02);
        c.drawCircle(Offset(w * .58, h * .66), w * .03, _p(const Color(0xFFFFE680)));
        c.drawCircle(Offset(w * .58, h * .66), w * .03, Paint()
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * .012);
    }
  }

  @override
  bool shouldRepaint(covariant PiecePainter old) => old.kind != kind || old.tint != tint;
}

/// The default Inner World backdrop: a dusk sky, twinkly stars and soft hills.
class SceneBackdropPainter extends CustomPainter {
  const SceneBackdropPainter();

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final rect = Rect.fromLTWH(0, 0, w, h);
    c.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B1040), Color(0xFF5B2A86), Color(0xFFD64FA0)],
        ).createShader(rect),
    );
    // stars (fixed positions, so the picture is steady)
    final star = Paint()..color = const Color(0xFFFFFFFF);
    for (var i = 0; i < 26; i++) {
      final x = (sin(i * 12.9898) * 43758.5453).abs() % 1;
      final y = ((sin(i * 78.233) * 12345.678).abs() % 1) * .55;
      c.drawCircle(Offset(x * w, y * h), w * (i % 5 == 0 ? .007 : .004), star..color = Color(0xFFFFFFFF).withValues(alpha: .5 + (i % 4) * .12));
    }
    final line = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * .008
      ..strokeJoin = StrokeJoin.round;
    Path hill(double y0, double amp, double phase) {
      final p = Path()..moveTo(0, h);
      p.lineTo(0, y0);
      for (var x = 0.0; x <= w; x += 4) {
        p.lineTo(x, y0 + sin(x / w * 2 * pi + phase) * amp);
      }
      return p..lineTo(w, h)..close();
    }

    for (final (y0, amp, ph, col) in [
      (h * .70, h * .04, 0.0, const Color(0xFF6C3FA8)),
      (h * .80, h * .035, 2.0, const Color(0xFF4A2A86)),
      (h * .90, h * .025, 4.0, const Color(0xFF331C63)),
    ]) {
      final p = hill(y0, amp, ph);
      c.drawPath(p, Paint()..color = col);
      c.drawPath(p, line);
    }
  }

  @override
  bool shouldRepaint(covariant SceneBackdropPainter old) => false;
}
