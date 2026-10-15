import 'dart:math';
import 'package:flutter/material.dart';

const _ink = Color(0xFF2B1B3D);

/// Cartoony hand-inked pieces for the Inner World scene. They have little
/// faces and details so each one feels like a character, not clip-art.
/// [giggle] > 0 makes them squeeze their eyes happily (played when tapped).
class PiecePainter extends CustomPainter {
  PiecePainter(this.kind, this.tint, {this.giggle = 0});
  final String kind;
  final Color? tint;
  final double giggle;

  double _w = 0;
  int _seed = 0;
  late Paint _line;

  Color _c(Color fallback) => tint ?? fallback;
  Paint _p(Color c) => Paint()..color = c;
  Paint _stroke(double width, [Color color = _ink]) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  /// Make a clean shape slightly wobbly, like it was drawn by hand.
  Path _wob(Path src, double amp0, int seed) {
    final amp = amp0 * .6;
    final out = Path();
    for (final m in src.computeMetrics()) {
      if (m.length < 1) continue;
      final n = max(10, (m.length / (_w * .03)).ceil());
      for (var i = 0; i < n; i++) {
        final d = m.length * i / n;
        final tg = m.getTangentForOffset(d);
        if (tg == null) continue;
        final u = d / _w;
        final k = amp * (sin(u * 14 + seed) + .5 * sin(u * 37 + seed * 1.7));
        final pt = Offset(tg.position.dx - tg.vector.dy * k, tg.position.dy + tg.vector.dx * k);
        i == 0 ? out.moveTo(pt.dx, pt.dy) : out.lineTo(pt.dx, pt.dy);
      }
      if (m.isClosed) out.close();
    }
    return out;
  }

  /// Fill + hand-inked outline (with a thin shifted second line, like a print).
  void _o(Canvas c, Path p, Color fill, {double wobble = .007}) {
    final wp = _wob(p, _w * wobble, _seed++);
    c.drawPath(wp, _p(fill));
    c.drawPath(wp, _line);
    c.drawPath(wp.shift(Offset(_w * .007, _w * .005)), _stroke(_w * .012, const Color(0x552B1B3D)));
  }

  void _oval(Canvas c, Rect r, Color fill, {double wobble = .007}) =>
      _o(c, Path()..addOval(r), fill, wobble: wobble);
  void _rr(Canvas c, Rect r, double rad, Color fill, {double wobble = .008}) =>
      _o(c, Path()..addRRect(RRect.fromRectAndRadius(r, Radius.circular(rad))), fill, wobble: wobble);

  void _shine(Canvas c, Rect r) => c.drawOval(r, _p(const Color(0x88FFFFFF)));

  void _sparkle(Canvas c, Offset o, double r, [Color col = const Color(0xFFFFF59D)]) {
    final p = Path();
    for (var i = 0; i < 8; i++) {
      final a = -pi / 2 + i * pi / 4;
      final rad = i.isEven ? r : r * .3;
      final pt = Offset(o.dx + rad * cos(a), o.dy + rad * sin(a));
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    c.drawPath(p..close(), _p(col));
  }

  /// A little face: eyes, smile and blush. [o] is the point between the eyes.
  void _face(Canvas c, Offset o, double gap, {bool sleepy = false, double smile = .10}) {
    final w = _w;
    final thick = _stroke(w * .03);
    for (final dx in [-1.0, 1.0]) {
      final e = Offset(o.dx + dx * gap, o.dy);
      if (sleepy) {
        c.drawArc(Rect.fromCenter(center: e, width: gap * .9, height: gap * .7), 0, pi, false, thick);
      } else if (giggle > 0) {
        c.drawArc(Rect.fromCenter(center: e, width: gap * .9, height: gap * .9), pi, pi, false, thick);
      } else {
        c.drawOval(Rect.fromCenter(center: e, width: gap * .55, height: gap * .75), _p(_ink));
        c.drawCircle(e.translate(-gap * .08, -gap * .14), gap * .1, _p(const Color(0xFFFFFFFF)));
      }
      c.drawOval(Rect.fromCenter(center: Offset(o.dx + dx * gap * 1.75, o.dy + gap * .7), width: gap * .8, height: gap * .5),
          _p(const Color(0x88FF6FA5)));
    }
    c.drawArc(Rect.fromCenter(center: Offset(o.dx, o.dy + gap * .55), width: w * smile, height: w * smile * .7), 0, pi, false, thick);
  }

  @override
  void paint(Canvas c, Size s) {
    _w = s.width;
    final w = _w, h = s.height;
    _seed = kind.hashCode % 7;
    _line = _stroke(w * .045);
    switch (kind) {
      case 'tree':
        for (final x in [.22, .30, .70, .78]) {
          c.drawLine(Offset(w * x, h * .95), Offset(w * (x + (x < .5 ? -.03 : .03)), h * .88), _stroke(w * .025, const Color(0xFF2E7D32)));
        }
        _rr(c, Rect.fromLTWH(w * .42, h * .55, w * .15, h * .40), w * .05, const Color(0xFF9A6240));
        c.drawOval(Rect.fromCenter(center: Offset(w * .5, h * .80), width: w * .05, height: h * .08), _p(const Color(0x66000000)));
        var crown = Path()..addOval(Rect.fromCircle(center: Offset(w * .5, h * .32), radius: w * .26));
        for (final (o, r) in [(Offset(w * .29, h * .50), w * .20), (Offset(w * .72, h * .52), w * .20), (Offset(w * .34, h * .22), w * .15)]) {
          crown = Path.combine(PathOperation.union, crown, Path()..addOval(Rect.fromCircle(center: o, radius: r)));
        }
        _o(c, crown, _c(const Color(0xFF4CD964)), wobble: .005);
        _shine(c, Rect.fromLTWH(w * .26, h * .12, w * .18, h * .09));
        _face(c, Offset(w * .50, h * .38), w * .09);
        for (final o in [Offset(.27, .55), Offset(.74, .56)]) {
          c.drawCircle(Offset(w * o.dx, h * o.dy), w * .04, _p(const Color(0xFFFF4D4D)));
          c.drawCircle(Offset(w * o.dx, h * o.dy), w * .04, _stroke(w * .018));
          c.drawCircle(Offset(w * (o.dx - .012), h * (o.dy - .012)), w * .01, _p(const Color(0xAAFFFFFF)));
        }
      case 'lake':
        _oval(c, Rect.fromLTWH(w * .02, h * .38, w * .96, h * .54), _c(const Color(0xFF45C8FF)), wobble: .012);
        c.drawOval(Rect.fromLTWH(w * .12, h * .46, w * .76, h * .34), _p(const Color(0x33FFFFFF)));
        for (final (r, a) in [(Rect.fromLTWH(w * .52, h * .66, w * .26, h * .09), 0.0), (Rect.fromLTWH(w * .46, h * .70, w * .38, h * .12), 0.0)]) {
          c.drawArc(r, a, pi, false, _stroke(w * .02, const Color(0xCCFFFFFF)));
        }
        // lily pad with a lotus
        final pad = Path.combine(
          PathOperation.difference,
          Path()..addOval(Rect.fromCenter(center: Offset(w * .28, h * .62), width: w * .22, height: h * .13)),
          Path()
            ..moveTo(w * .28, h * .62)
            ..lineTo(w * .40, h * .56)
            ..lineTo(w * .40, h * .66)
            ..close(),
        );
        _o(c, pad, const Color(0xFF3DDC84));
        for (final dx in [-.035, 0.0, .035]) {
          c.drawOval(Rect.fromCenter(center: Offset(w * (.27 + dx), h * (.57 - (dx == 0 ? .02 : 0))), width: w * .045, height: w * .075), _p(const Color(0xFFFF8FD1)));
          c.drawOval(Rect.fromCenter(center: Offset(w * (.27 + dx), h * (.57 - (dx == 0 ? .02 : 0))), width: w * .045, height: w * .075), _stroke(w * .012));
        }
        // a shy something peeking out of the water
        _oval(c, Rect.fromLTWH(w * .58, h * .50, w * .20, h * .13), const Color(0xFF2E9FD6));
        for (final dx in [.64, .73]) {
          c.drawCircle(Offset(w * dx, h * .54), w * .038, _p(const Color(0xFFFFFFFF)));
          c.drawCircle(Offset(w * dx, h * .54), w * .038, _stroke(w * .014));
          c.drawCircle(Offset(w * (dx - .01), h * .545), w * .016, _p(_ink));
        }
        c.drawArc(Rect.fromCenter(center: Offset(w * .685, h * .59), width: w * .06, height: w * .04), 0, pi, false, _stroke(w * .014));
        // reeds
        for (final x in [.90, .94]) {
          c.drawLine(Offset(w * x, h * .62), Offset(w * (x - .02), h * .36), _stroke(w * .025, const Color(0xFF2E7D32)));
          c.drawOval(Rect.fromCenter(center: Offset(w * (x - .02), h * .34), width: w * .04, height: h * .10), _p(const Color(0xFF8D5A3B)));
        }
        _sparkle(c, Offset(w * .16, h * .46), w * .06);
      case 'house':
        // chimney + curly smoke first, behind the roof
        _rr(c, Rect.fromLTWH(w * .66, h * .16, w * .09, h * .20), w * .01, const Color(0xFFB0605A));
        c.drawPath(
          Path()
            ..moveTo(w * .70, h * .14)
            ..cubicTo(w * .62, h * .08, w * .78, h * .06, w * .72, h * .0),
          _stroke(w * .03, const Color(0xCCFFFFFF)),
        );
        _o(c, Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * .20, h * .44, w * .60, h * .47), Radius.circular(w * .04))),
            _c(const Color(0xFFFFB347)), wobble: .012);
        final roof = Path()
          ..moveTo(w * .08, h * .50)
          ..lineTo(w * .50, h * .10)
          ..lineTo(w * .93, h * .50)
          ..quadraticBezierTo(w * .80, h * .45, w * .70, h * .50)
          ..quadraticBezierTo(w * .60, h * .45, w * .50, h * .50)
          ..quadraticBezierTo(w * .40, h * .45, w * .30, h * .50)
          ..quadraticBezierTo(w * .18, h * .45, w * .08, h * .50)
          ..close();
        _o(c, roof, const Color(0xFFFF4D8D), wobble: .01);
        for (final x in [.38, .50, .62]) {
          c.drawArc(Rect.fromCenter(center: Offset(w * x, h * .34), width: w * .10, height: h * .08), 0, pi, false, _stroke(w * .018, const Color(0x772B1B3D)));
        }
        // round windows that look like friendly eyes
        for (final dx in [.34, .66]) {
          c.drawCircle(Offset(w * dx, h * .60), w * .085, _p(const Color(0xFFFFF3A6)));
          c.drawCircle(Offset(w * dx, h * .60), w * .085, _stroke(w * .03));
          c.drawLine(Offset(w * dx, h * .525), Offset(w * dx, h * .675), _stroke(w * .012));
          c.drawLine(Offset(w * (dx - .075), h * .60), Offset(w * (dx + .075), h * .60), _stroke(w * .012));
        }
        // arched door with a heart
        final door = Path()
          ..moveTo(w * .43, h * .91)
          ..lineTo(w * .43, h * .74)
          ..arcToPoint(Offset(w * .57, h * .74), radius: Radius.circular(w * .07))
          ..lineTo(w * .57, h * .91)
          ..close();
        _o(c, door, const Color(0xFF7E57C2));
        c.drawCircle(Offset(w * .50, h * .80), w * .016, _p(const Color(0xFFFF8FD1)));
        for (final x in [.24, .30, .70, .76]) {
          c.drawCircle(Offset(w * x, h * .93), w * .022, _p(const Color(0xFFFF8FD1)));
          c.drawCircle(Offset(w * x, h * .93), w * .022, _stroke(w * .01));
        }
      case 'mountain':
        final back = Path()
          ..moveTo(w * .46, h * .92)
          ..lineTo(w * .76, h * .34)
          ..lineTo(w * 1.0, h * .92)
          ..close();
        _o(c, back, const Color(0xFFB7A8FF), wobble: .01);
        final peak = Path()
          ..moveTo(w * .0, h * .92)
          ..lineTo(w * .42, h * .12)
          ..lineTo(w * .88, h * .92)
          ..close();
        _o(c, peak, _c(const Color(0xFF8E7CFF)), wobble: .012);
        c.drawPath(
          Path()
            ..moveTo(w * .42, h * .12)
            ..lineTo(w * .88, h * .92)
            ..lineTo(w * .58, h * .92)
            ..close(),
          _p(const Color(0x33000000)),
        );
        _o(
          c,
          Path()
            ..moveTo(w * .30, h * .36)
            ..lineTo(w * .42, h * .12)
            ..lineTo(w * .55, h * .36)
            ..lineTo(w * .48, h * .32)
            ..lineTo(w * .42, h * .40)
            ..lineTo(w * .36, h * .32)
            ..close(),
          const Color(0xFFFFFFFF),
        );
        // a tiny flag on top
        c.drawLine(Offset(w * .42, h * .12), Offset(w * .42, h * .01), _stroke(w * .02));
        c.drawPath(Path()..moveTo(w * .42, h * .01)..lineTo(w * .54, h * .045)..lineTo(w * .42, h * .08)..close(), _p(const Color(0xFFFF4D8D)));
        // sleepy face, snoring
        _face(c, Offset(w * .40, h * .60), w * .09, sleepy: true, smile: .05);
        c.drawOval(Rect.fromCenter(center: Offset(w * .40, h * .70), width: w * .045, height: w * .05), _p(_ink));
      case 'sun':
        final sun = _c(const Color(0xFFFFC93C));
        c.save();
        c.translate(w * .5, h * .5);
        c.rotate(giggle * pi / 8);
        c.translate(-w * .5, -h * .5);
        for (var i = 0; i < 12; i++) {
          final a = i * pi / 6;
          final long = i.isEven;
          final p0 = Offset(w * .5 + cos(a) * w * .30, h * .5 + sin(a) * h * .30);
          final p1 = Offset(w * .5 + cos(a) * w * (long ? .47 : .40), h * .5 + sin(a) * h * (long ? .47 : .40));
          c.drawLine(p0, p1, _stroke(w * (long ? .10 : .085)));
          c.drawLine(p0, p1, _stroke(w * (long ? .055 : .045), long ? sun : const Color(0xFFFFE066)));
        }
        c.restore();
        _oval(c, Rect.fromCircle(center: Offset(w * .5, h * .5), radius: w * .26), sun, wobble: .004);
        _shine(c, Rect.fromLTWH(w * .34, h * .31, w * .15, h * .08));
        _face(c, Offset(w * .5, h * .48), w * .095, smile: .13);
      case 'moon':
        final moon = Path.combine(
          PathOperation.difference,
          Path()..addOval(Rect.fromCircle(center: Offset(w * .5, h * .58), radius: w * .36)),
          Path()..addOval(Rect.fromCircle(center: Offset(w * .72, h * .50), radius: w * .27)),
        );
        _o(c, moon, _c(const Color(0xFFFFF176)), wobble: .006);
        c.drawCircle(Offset(w * .24, h * .74), w * .03, _p(const Color(0x33000000)));
        // sleepy face on the thick part of the crescent
        final eye = Offset(w * .31, h * .60);
        c.drawArc(Rect.fromCenter(center: eye, width: w * .09, height: w * .06), 0, pi, false, _stroke(w * .03));
        c.drawOval(Rect.fromCenter(center: eye.translate(-w * .005, h * .07), width: w * .08, height: w * .05), _p(const Color(0x99FF6FA5)));
        c.drawArc(Rect.fromCenter(center: Offset(w * .36, h * .70), width: w * .07, height: w * .05), 0, pi, false, _stroke(w * .026));
        // nightcap with a pompom
        final cap = Path()
          ..moveTo(w * .22, h * .40)
          ..quadraticBezierTo(w * .34, h * .08, w * .56, h * .20)
          ..quadraticBezierTo(w * .46, h * .24, w * .44, h * .33)
          ..quadraticBezierTo(w * .30, h * .30, w * .22, h * .40)
          ..close();
        _o(c, cap, const Color(0xFFFF4D8D), wobble: .006);
        c.drawCircle(Offset(w * .57, h * .20), w * .04, _p(const Color(0xFFFFFFFF)));
        c.drawCircle(Offset(w * .57, h * .20), w * .04, _stroke(w * .02));
        // floating z z z
        for (var i = 0; i < 3; i++) {
          final z = Offset(w * (.66 + i * .08), h * (.22 - i * .08));
          final zs = w * (.035 + i * .01);
          c.drawPath(
            Path()
              ..moveTo(z.dx - zs, z.dy - zs)
              ..lineTo(z.dx + zs, z.dy - zs)
              ..lineTo(z.dx - zs, z.dy + zs)
              ..lineTo(z.dx + zs, z.dy + zs),
            _stroke(w * .022, const Color(0xFFFFFFFF)),
          );
        }
        _sparkle(c, Offset(w * .84, h * .66), w * .05);
      case 'flower':
        c.drawLine(Offset(w * .5, h * .45), Offset(w * .5, h * .95), _stroke(w * .10));
        c.drawLine(Offset(w * .5, h * .45), Offset(w * .5, h * .95), _stroke(w * .05, const Color(0xFF3DDC84)));
        for (final dx in [-1.0, 1.0]) {
          final leaf = Path()
            ..moveTo(w * .5, h * (.82))
            ..quadraticBezierTo(w * (.5 + dx * .16), h * .62, w * (.5 + dx * .26), h * .72)
            ..quadraticBezierTo(w * (.5 + dx * .16), h * .86, w * .5, h * .82);
          _o(c, leaf, const Color(0xFF3DDC84), wobble: .006);
        }
        var petals = Path();
        for (var i = 0; i < 6; i++) {
          final a = -pi / 2 + i * 2 * pi / 6;
          petals = Path.combine(PathOperation.union, petals,
              Path()..addOval(Rect.fromCircle(center: Offset(w * .5 + cos(a) * w * .19, h * .30 + sin(a) * h * .19), radius: w * .13)));
        }
        _o(c, petals, _c(const Color(0xFFFF6FB5)), wobble: .01);
        _oval(c, Rect.fromCircle(center: Offset(w * .5, h * .30), radius: w * .13), const Color(0xFFFFE14D));
        _face(c, Offset(w * .5, h * .28), w * .05, smile: .07);
        // a bumblebee buzzing around
        final bee = Offset(w * (.82 - giggle * .06), h * .14);
        c.drawOval(Rect.fromCenter(center: bee.translate(-w * .02, -w * .04), width: w * .07, height: w * .05), _p(const Color(0xBBFFFFFF)));
        c.drawOval(Rect.fromCenter(center: bee.translate(w * .03, -w * .04), width: w * .07, height: w * .05), _p(const Color(0xBBFFFFFF)));
        _oval(c, Rect.fromCenter(center: bee, width: w * .12, height: w * .08), const Color(0xFFFFD93D), wobble: .004);
        for (final dx in [-.02, .02]) {
          c.drawLine(bee.translate(w * dx, -w * .03), bee.translate(w * dx, w * .03), _stroke(w * .015));
        }
        c.drawCircle(bee.translate(-w * .04, -w * .005), w * .008, _p(_ink));
      case 'door':
        _sparkle(c, Offset(w * .12, h * .30), w * .07);
        _sparkle(c, Offset(w * .90, h * .20), w * .06, const Color(0xFFFFB3E6));
        // warm light spilling out onto the ground
        c.drawOval(Rect.fromLTWH(w * .20, h * .88, w * .62, h * .09), _p(const Color(0x66FFE680)));
        final frame = Path()
          ..moveTo(w * .22, h * .93)
          ..lineTo(w * .22, h * .40)
          ..arcToPoint(Offset(w * .78, h * .40), radius: Radius.circular(w * .28))
          ..lineTo(w * .78, h * .93)
          ..close();
        _o(c, frame, _c(const Color(0xFF9B6BFF)), wobble: .01);
        final inner = Path()
          ..moveTo(w * .30, h * .93)
          ..lineTo(w * .30, h * .42)
          ..arcToPoint(Offset(w * .70, h * .42), radius: Radius.circular(w * .20))
          ..lineTo(w * .70, h * .93)
          ..close();
        final box = Rect.fromLTWH(w * .30, h * .2, w * .4, h * .73);
        c.drawPath(
          inner,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2B1B6D), Color(0xFFD64FA0), Color(0xFFFFE680)],
            ).createShader(box),
        );
        c.drawPath(inner, _stroke(w * .022));
        for (final o in [Offset(.42, .50), Offset(.58, .60), Offset(.50, .42), Offset(.62, .46)]) {
          _sparkle(c, Offset(w * o.dx, h * o.dy), w * .028, const Color(0xFFFFFFFF));
        }
        // the door itself, swung open a little
        final leaf = Path()
          ..moveTo(w * .30, h * .93)
          ..lineTo(w * .30, h * .42)
          ..lineTo(w * .43, h * .50)
          ..lineTo(w * .43, h * .88)
          ..close();
        _o(c, leaf, const Color(0xFF7E57C2), wobble: .004);
        c.drawCircle(Offset(w * .40, h * .70), w * .018, _p(const Color(0xFFFFE680)));
        _rr(c, Rect.fromLTWH(w * .26, h * .93, w * .48, h * .05), w * .01, const Color(0xFFFF4D8D), wobble: .004);
    }
  }

  @override
  bool shouldRepaint(covariant PiecePainter old) =>
      old.kind != kind || old.tint != tint || old.giggle != giggle;
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
    final star = Paint();
    for (var i = 0; i < 26; i++) {
      final x = (sin(i * 12.9898) * 43758.5453).abs() % 1;
      final y = ((sin(i * 78.233) * 12345.678).abs() % 1) * .55;
      star.color = const Color(0xFFFFFFFF).withValues(alpha: .5 + (i % 4) * .12);
      c.drawCircle(Offset(x * w, y * h), w * (i % 5 == 0 ? .007 : .004), star);
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
      return p
        ..lineTo(w, h)
        ..close();
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
