import 'dart:math';
import 'package:flutter/material.dart';

const _ink = Color(0xFF2B1B3D);

/// Cartoony frame art around an alter's avatar, for non-human alters: ears,
/// horns, wings, a witch hat and so on. [behind] draws what sits behind the
/// round picture (ears, wings); the rest draws on top (horns, hats, fangs).
class AlterFramePainter extends CustomPainter {
  AlterFramePainter(this.kind, {required this.behind});
  final String kind;
  final bool behind;

  late Canvas _c;
  late double _r;
  late Offset _o;
  late Paint _line;

  Paint _f(Color c) => Paint()..color = c;

  void _shape(Path p, Color fill) {
    _c.drawPath(p, _f(fill));
    _c.drawPath(p, _line);
  }

  Offset _pt(double x, double y) => Offset(_o.dx + x * _r, _o.dy + y * _r);

  Path _poly(List<(double, double)> pts) {
    final p = Path();
    for (var i = 0; i < pts.length; i++) {
      final q = _pt(pts[i].$1, pts[i].$2);
      i == 0 ? p.moveTo(q.dx, q.dy) : p.lineTo(q.dx, q.dy);
    }
    return p..close();
  }

  void _ears(Color outer, {Color? inner}) {
    for (final s in [-1.0, 1.0]) {
      _shape(_poly([(s * .95, -.25), (s * .78, -1.45), (s * .12, -.9)]), outer);
      if (inner != null) {
        _c.drawPath(_poly([(s * .80, -.45), (s * .72, -1.12), (s * .34, -.84)]), _f(inner));
      }
    }
  }

  void _roundEars(Color col) {
    for (final s in [-1.0, 1.0]) {
      final o = _pt(s * .78, -.78);
      _c.drawCircle(o, _r * .34, _f(col));
      _c.drawCircle(o, _r * .34, _line);
      _c.drawCircle(o, _r * .17, _f(const Color(0x55FFFFFF)));
    }
  }

  void _star(Offset o, double r, Color col) {
    final p = Path();
    for (var i = 0; i < 8; i++) {
      final a = -pi / 2 + i * pi / 4;
      final rad = i.isEven ? r : r * .3;
      final pt = Offset(o.dx + rad * cos(a), o.dy + rad * sin(a));
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    _c.drawPath(p..close(), _f(col));
  }

  @override
  void paint(Canvas c, Size s) {
    _c = c;
    _o = s.center(Offset.zero);
    _r = min(s.width, s.height) / 2;
    _line = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.2, _r * .09)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    switch (kind) {
      case 'fox':
        if (behind) _ears(const Color(0xFFFF8A3D), inner: const Color(0xFFFFE0C2));
      case 'wolf':
        if (behind) _ears(const Color(0xFF9AA3B5), inner: const Color(0xFFD9DEE8));
      case 'cat':
        if (behind) _ears(const Color(0xFFFFB3D9), inner: const Color(0xFFFF8CC6));
      case 'dog':
        if (behind) {
          for (final sd in [-1.0, 1.0]) {
            _c.save();
            _c.translate(_pt(sd * .95, -.2).dx, _pt(sd * .95, -.2).dy);
            _c.rotate(sd * .35);
            final rect = Rect.fromCenter(center: Offset.zero, width: _r * .55, height: _r * 1.1);
            _c.drawOval(rect, _f(const Color(0xFFB07A4A)));
            _c.drawOval(rect, _line);
            _c.restore();
          }
        }
      case 'bunny':
        if (behind) {
          for (final sd in [-1.0, 1.0]) {
            final rect = Rect.fromCenter(center: _pt(sd * .42, -1.3), width: _r * .5, height: _r * 1.3);
            _c.drawOval(rect, _f(const Color(0xFFFFE3F1)));
            _c.drawOval(rect, _line);
            _c.drawOval(Rect.fromCenter(center: _pt(sd * .42, -1.25), width: _r * .22, height: _r * .8), _f(const Color(0xFFFF9AD5)));
          }
        }
      case 'bear':
        if (behind) _roundEars(const Color(0xFF9A6240));
      case 'bird':
        if (!behind) {
          for (final (dx, tip, col) in const [(-.25, -1.35, 0xFF4DA3FF), (0.0, -1.55, 0xFFFF4D8D), (.25, -1.35, 0xFFFFC93C)]) {
            _shape(_poly([(dx - .16, -.88), (dx, tip), (dx + .16, -.88)]), Color(col));
          }
          _shape(_poly([(-.18, .35), (.18, .35), (0, .72)]), const Color(0xFFFFB347));
        }
      case 'dragon':
        if (!behind) {
          for (final sd in [-1.0, 1.0]) {
            _shape(_poly([(sd * .62, -.72), (sd * .78, -1.45), (sd * .30, -.92)]), const Color(0xFFFFF1DC));
          }
          for (final dx in [-.28, 0.0, .28]) {
            _shape(_poly([(dx - .13, -.96 + dx.abs() * .1), (dx, -1.22 + dx.abs() * .25), (dx + .13, -.96 + dx.abs() * .1)]), const Color(0xFF3DDC84));
          }
        }
      case 'demon':
        if (!behind) {
          for (final sd in [-1.0, 1.0]) {
            final p = Path()
              ..moveTo(_pt(sd * .50, -.82).dx, _pt(sd * .50, -.82).dy)
              ..quadraticBezierTo(_pt(sd * 1.15, -1.0).dx, _pt(sd * 1.15, -1.0).dy, _pt(sd * .85, -1.6).dx, _pt(sd * .85, -1.6).dy)
              ..quadraticBezierTo(_pt(sd * .62, -1.1).dx, _pt(sd * .62, -1.1).dy, _pt(sd * .30, -.92).dx, _pt(sd * .30, -.92).dy)
              ..close();
            _shape(p, const Color(0xFFD7263D));
          }
        }
      case 'witch':
        if (!behind) {
          _c.save();
          _c.translate(_pt(0, -.8).dx, _pt(0, -.8).dy);
          _c.rotate(-.18);
          _c.translate(-_pt(0, -.8).dx, -_pt(0, -.8).dy);
          _shape(_poly([(-.95, -.7), (.95, -.7), (.2, -.85), (.32, -1.75), (-.28, -.95)]), const Color(0xFF6A2FB8));
          _shape(_poly([(-1.1, -.62), (1.1, -.62), (.9, -.8), (-.9, -.8)]), const Color(0xFF8A4DE0));
          _c.drawRect(Rect.fromLTRB(_pt(-.32, -.86).dx, _pt(0, -.86).dy, _pt(.32, -.86).dx, _pt(0, -.7).dy), _f(const Color(0xFFFFC93C)));
          _star(_pt(.05, -1.3), _r * .22, const Color(0xFFFFF59D));
          _c.restore();
        }
      case 'vampire':
        if (!behind) {
          for (final sd in [-1.0, 1.0]) {
            _shape(_poly([(sd * .30 - .13, .55), (sd * .30 + .13, .55), (sd * .30, 1.0)]), Colors.white);
          }
          _c.drawCircle(_pt(.30, 1.12), _r * .08, _f(const Color(0xFFD7263D)));
        }
      case 'fae':
        if (behind) {
          for (final sd in [-1.0, 1.0]) {
            final w1 = Rect.fromCenter(center: _pt(sd * 1.1, -.3), width: _r * .95, height: _r * 1.45);
            _c.save();
            _c.translate(w1.center.dx, w1.center.dy);
            _c.rotate(sd * .5);
            _c.translate(-w1.center.dx, -w1.center.dy);
            _c.drawOval(w1, _f(const Color(0xAAC7F0FF)));
            _c.drawOval(w1, _line);
            _c.restore();
          }
        } else {
          _star(_pt(.95, -.95), _r * .26, const Color(0xFFFFF59D));
          _star(_pt(-1.0, .5), _r * .18, const Color(0xFFFFB3E6));
        }
      case 'ghost':
        if (behind) {
          final p = Path()..moveTo(_pt(-.95, 0).dx, _pt(0, 0).dy);
          p.lineTo(_pt(-.95, 1.2).dx, _pt(0, 1.2).dy);
          for (var i = 0; i < 4; i++) {
            final x0 = -.95 + i * .475, x1 = x0 + .475;
            p.quadraticBezierTo(_pt((x0 + x1) / 2, i.isEven ? 1.6 : .85).dx, _pt(0, i.isEven ? 1.6 : .85).dy, _pt(x1, 1.2).dx, _pt(0, 1.2).dy);
          }
          p.lineTo(_pt(.95, 0).dx, _pt(0, 0).dy);
          p.close();
          _shape(p, const Color(0xFFF2F0FF));
        }
      case 'unicorn':
        if (!behind) {
          _shape(_poly([(-.16, -.9), (0, -1.75), (.16, -.9)]), const Color(0xFFFFC93C));
          _c.drawLine(_pt(-.1, -1.15), _pt(.1, -1.2), _line..strokeWidth = _r * .05);
          _line.strokeWidth = max(1.2, _r * .09);
          for (final (dx, col) in const [(-.55, 0xFFFF8CC6), (.55, 0xFF9B6BFF), (-.82, 0xFF6FE3A1)]) {
            _c.drawCircle(_pt(dx, -.78 + dx.abs() * .15), _r * .16, _f(Color(col)));
            _c.drawCircle(_pt(dx, -.78 + dx.abs() * .15), _r * .16, _line);
          }
        }
      case 'angel':
        if (behind) {
          for (final sd in [-1.0, 1.0]) {
            final w1 = Rect.fromCenter(center: _pt(sd * 1.15, .1), width: _r * .8, height: _r * 1.5);
            _c.save();
            _c.translate(w1.center.dx, w1.center.dy);
            _c.rotate(sd * .35);
            _c.translate(-w1.center.dx, -w1.center.dy);
            _c.drawOval(w1, _f(Colors.white));
            _c.drawOval(w1, _line);
            _c.restore();
          }
        } else {
          final halo = Rect.fromCenter(center: _pt(0, -1.2), width: _r * 1.2, height: _r * .38);
          _c.drawOval(halo, _line..strokeWidth = _r * .2..color = _ink);
          _c.drawOval(halo, _line..strokeWidth = _r * .1..color = const Color(0xFFFFE066));
          _line
            ..color = _ink
            ..strokeWidth = max(1.2, _r * .09);
        }
      case 'robot':
        if (!behind) {
          _c.drawLine(_pt(0, -.95), _pt(0, -1.35), _line);
          _c.drawCircle(_pt(0, -1.45), _r * .16, _f(const Color(0xFFFF4D8D)));
          _c.drawCircle(_pt(0, -1.45), _r * .16, _line);
          for (final sd in [-1.0, 1.0]) {
            _c.drawCircle(_pt(sd * 1.0, .1), _r * .13, _f(const Color(0xFFB8C0CC)));
            _c.drawCircle(_pt(sd * 1.0, .1), _r * .13, _line);
          }
        }
      case 'plant':
        if (!behind) {
          _c.drawLine(_pt(0, -.95), _pt(0, -1.25), _line);
          for (final sd in [-1.0, 1.0]) {
            final leaf = Path()
              ..moveTo(_pt(0, -1.25).dx, _pt(0, -1.25).dy)
              ..quadraticBezierTo(_pt(sd * .7, -1.75).dx, _pt(sd * .7, -1.75).dy, _pt(sd * .85, -1.2).dx, _pt(sd * .85, -1.2).dy)
              ..quadraticBezierTo(_pt(sd * .4, -1.0).dx, _pt(sd * .4, -1.0).dy, _pt(0, -1.25).dx, _pt(0, -1.25).dy);
            _shape(leaf, const Color(0xFF3DDC84));
          }
        }
    }
  }

  @override
  bool shouldRepaint(covariant AlterFramePainter old) => old.kind != kind || old.behind != behind;
}
