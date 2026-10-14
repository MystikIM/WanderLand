import 'dart:math';
import 'package:flutter/material.dart';
import '../domain/buddy.dart';

class BuddyView extends StatelessWidget {
  const BuddyView({
    super.key,
    required this.species,
    required this.color,
    required this.mood,
    this.accessory = '',
    this.outfit = '',
    this.size = 120,
  });
  final String species;
  final Color color;
  final BuddyMood mood;
  final String accessory;
  final String outfit;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _BuddyPainter(species, color, mood, accessory, outfit)),
      );
}

class _BuddyPainter extends CustomPainter {
  _BuddyPainter(this.species, this.color, this.mood, this.accessory, this.outfit);
  final String species;
  final Color color;
  final BuddyMood mood;
  final String accessory;
  final String outfit;

  Path _star(Offset c, double r) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final a = -pi / 2 + i * pi / 5;
      final rad = i.isEven ? r : r * .45;
      final pt = Offset(c.dx + rad * cos(a), c.dy + rad * sin(a));
      if (i == 0) {
        p.moveTo(pt.dx, pt.dy);
      } else {
        p.lineTo(pt.dx, pt.dy);
      }
    }
    return p..close();
  }

  /// Ears, wings, shell and other parts that sit behind the body.
  void _behindBody(Canvas c, double w, double h, double cx) {
    final body = Paint()..color = color;
    final dark = Paint()..color = Color.lerp(color, const Color(0xFF000000), .25)!;
    final light = Paint()..color = Color.lerp(color, const Color(0xFFFFFFFF), .4)!;
    const sides = [-1.0, 1.0];
    if (outfit == 'cape') {
      c.drawPath(
        Path()
          ..moveTo(cx - w * .30, h * .50)
          ..lineTo(cx - w * .46, h * .98)
          ..lineTo(cx + w * .46, h * .98)
          ..lineTo(cx + w * .30, h * .50)
          ..close(),
        Paint()..color = const Color(0xFFD32F2F),
      );
    }
    switch (species) {
      case 'cat':
        for (final dx in sides) {
          c.drawPath(
            Path()
              ..moveTo(cx + dx * w * .32, h * .42)
              ..lineTo(cx + dx * w * .22, h * .10)
              ..lineTo(cx + dx * w * .06, h * .32)
              ..close(),
            body,
          );
        }
      case 'dog':
        for (final dx in sides) {
          c.drawOval(
              Rect.fromCenter(center: Offset(cx + dx * w * .38, h * .46), width: w * .20, height: h * .34),
              dark);
        }
      case 'bunny':
        for (final dx in sides) {
          c.drawOval(
              Rect.fromCenter(center: Offset(cx + dx * w * .16, h * .16), width: w * .14, height: h * .34),
              body);
        }
      case 'rabbit':
        for (final dx in sides) {
          c.drawOval(
              Rect.fromCenter(center: Offset(cx + dx * w * .38, h * .52), width: w * .13, height: h * .40),
              body);
        }
      case 'frog':
        for (final dx in sides) {
          c.drawCircle(Offset(cx + dx * w * .22, h * .30), w * .12, body);
        }
      case 'turtle':
        c.drawOval(Rect.fromLTWH(w * .02, h * .36, w * .96, h * .60), dark);
        for (final dx in sides) {
          c.drawCircle(Offset(cx + dx * w * .30, h * .93), w * .07, body);
        }
      case 'butterfly':
        for (final dx in sides) {
          c.drawOval(
              Rect.fromCenter(center: Offset(cx + dx * w * .38, h * .40), width: w * .34, height: h * .40),
              light);
          c.drawOval(
              Rect.fromCenter(center: Offset(cx + dx * w * .34, h * .72), width: w * .26, height: h * .30),
              light);
        }
      case 'fairy':
        final wing = Paint()..color = const Color(0x99FFFFFF);
        for (final dx in sides) {
          c.drawOval(
              Rect.fromCenter(center: Offset(cx + dx * w * .40, h * .42), width: w * .26, height: h * .44),
              wing);
        }
      case 'unicorn':
        for (final dx in sides) {
          c.drawPath(
            Path()
              ..moveTo(cx + dx * w * .24, h * .34)
              ..lineTo(cx + dx * w * .22, h * .14)
              ..lineTo(cx + dx * w * .10, h * .30)
              ..close(),
            body,
          );
        }
    }
  }

  /// Whiskers, noses, horns and other parts drawn on top of the face.
  void _frontOfFace(Canvas c, double w, double h, double cx, Paint ink, Paint fill) {
    const sides = [-1.0, 1.0];
    switch (species) {
      case 'cat':
        for (final dx in sides) {
          c.drawLine(Offset(cx + dx * w * .18, h * .64), Offset(cx + dx * w * .38, h * .60), ink);
          c.drawLine(Offset(cx + dx * w * .18, h * .67), Offset(cx + dx * w * .38, h * .69), ink);
        }
      case 'dog':
        c.drawOval(Rect.fromCenter(center: Offset(cx, h * .61), width: w * .10, height: w * .07), fill);
      case 'bunny':
      case 'rabbit':
        c.drawCircle(Offset(cx, h * .62), w * .02, Paint()..color = const Color(0xFFFF6FA5));
      case 'frog':
        c.drawArc(Rect.fromCenter(center: Offset(cx, h * .64), width: w * .36, height: w * .16),
            0, pi, false, ink);
      case 'butterfly':
        for (final dx in sides) {
          c.drawLine(Offset(cx + dx * w * .06, h * .28), Offset(cx + dx * w * .14, h * .10), ink);
          c.drawCircle(Offset(cx + dx * w * .14, h * .10), w * .02, fill);
        }
      case 'fairy':
        c.drawPath(_star(Offset(cx - w * .26, h * .20), w * .06), Paint()..color = const Color(0xFFFFE680));
      case 'unicorn':
        c.drawPath(
          Path()
            ..moveTo(cx - w * .06, h * .30)
            ..lineTo(cx, h * .02)
            ..lineTo(cx + w * .06, h * .30)
            ..close(),
          Paint()..color = const Color(0xFFFFC94D),
        );
        for (var i = 0; i < 3; i++) {
          c.drawCircle(Offset(cx - w * .32, h * .36 + i * h * .10), w * .06,
              Paint()..color = const Color(0xFFFF8CC6));
        }
    }
  }

  void _outfit(Canvas c, double w, double h, double cx) {
    RRect box(double l, double t, double ww, double hh, double r) =>
        RRect.fromRectAndRadius(Rect.fromLTWH(l, t, ww, hh), Radius.circular(r));
    switch (outfit) {
      case 'shirt':
        final p = Paint()..color = const Color(0xFF4DA3FF);
        c.drawRRect(box(w * .24, h * .74, w * .52, h * .18, h * .05), p);
        for (final dx in [-1.0, 1.0]) {
          c.drawOval(Rect.fromCenter(center: Offset(cx + dx * w * .28, h * .77), width: w * .14, height: h * .10), p);
        }
      case 'hoodie':
        c.drawRRect(box(w * .20, h * .72, w * .60, h * .22, h * .06), Paint()..color = const Color(0xFF7E57C2));
        c.drawRRect(box(w * .36, h * .82, w * .28, h * .08, h * .03), Paint()..color = const Color(0x33000000));
        final string = Paint()
          ..color = const Color(0xFFFFFFFF)
          ..strokeWidth = w * .02
          ..strokeCap = StrokeCap.round;
        for (final dx in [-1.0, 1.0]) {
          c.drawLine(Offset(cx + dx * w * .06, h * .72), Offset(cx + dx * w * .06, h * .80), string);
        }
      case 'dress':
        c.drawPath(
          Path()
            ..moveTo(cx - w * .14, h * .72)
            ..lineTo(cx + w * .14, h * .72)
            ..lineTo(cx + w * .30, h * .94)
            ..lineTo(cx - w * .30, h * .94)
            ..close(),
          Paint()..color = const Color(0xFFFF8CC6),
        );
      case 'pajamas':
        c.drawRRect(box(w * .22, h * .72, w * .56, h * .22, h * .05), Paint()..color = const Color(0xFF9FA8DA));
        final dot = Paint()..color = const Color(0xFFFFFFFF);
        for (var i = 0; i < 3; i++) {
          c.drawCircle(Offset(cx - w * .16 + i * w * .16, h * .83), w * .025, dot);
        }
    }
  }

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height, cx = w / 2;
    final body = Paint()..color = color;
    const inkColor = Color(0xFF2B2B3A);
    final ink = Paint()
      ..color = inkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.025
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = inkColor;
    final ey = h * .55;

    _behindBody(c, w, h, cx);
    c.drawOval(Rect.fromLTWH(w * .10, h * .26, w * .80, h * .68), body);
    final cheek = Paint()..color = const Color(0x55FF6FA5);
    c.drawCircle(Offset(cx - w * .24, h * .66), w * .06, cheek);
    c.drawCircle(Offset(cx + w * .24, h * .66), w * .06, cheek);

    for (final dx in [-1.0, 1.0]) {
      final p = Offset(cx + dx * w * .15, ey);
      switch (mood) {
        case BuddyMood.happy:
          c.drawArc(Rect.fromCenter(center: p, width: w * .12, height: w * .12), pi, pi, false, ink);
        case BuddyMood.content:
          c.drawCircle(p, w * .028, fill);
        case BuddyMood.sleepy:
          c.drawLine(p.translate(-w * .05, 0), p.translate(w * .05, 0), ink);
      }
    }
    c.drawArc(Rect.fromCenter(center: Offset(cx, h * .66), width: w * .14, height: w * .09), 0, pi, false, ink);
    _frontOfFace(c, w, h, cx, ink, fill);
    _outfit(c, w, h, cx);

    final gold = Paint()..color = const Color(0xFFFFC94D);
    switch (accessory) {
      case 'bow':
        final pink = Paint()..color = const Color(0xFFFF4D8D);
        for (final dx in [-1.0, 1.0]) {
          c.drawPath(
            Path()
              ..moveTo(cx + w * .22, h * .30)
              ..lineTo(cx + w * .22 + dx * w * .13, h * .22)
              ..lineTo(cx + w * .22 + dx * w * .13, h * .38)
              ..close(),
            pink,
          );
        }
      case 'crown':
        c.drawPath(
          Path()
            ..moveTo(cx - w * .16, h * .28)
            ..lineTo(cx - w * .16, h * .12)
            ..lineTo(cx - w * .08, h * .20)
            ..lineTo(cx, h * .08)
            ..lineTo(cx + w * .08, h * .20)
            ..lineTo(cx + w * .16, h * .12)
            ..lineTo(cx + w * .16, h * .28)
            ..close(),
          gold,
        );
      case 'scarf':
        c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(w * .18, h * .78, w * .64, h * .09), Radius.circular(h * .04)),
          Paint()..color = const Color(0xFF4DA3FF),
        );
      case 'glasses':
        for (final dx in [-1.0, 1.0]) {
          c.drawCircle(Offset(cx + dx * w * .15, ey), w * .10, ink);
        }
        c.drawLine(Offset(cx - w * .05, ey), Offset(cx + w * .05, ey), ink);
      case 'star':
        c.drawPath(_star(Offset(cx + w * .22, h * .22), w * .09), gold);
    }
  }

  @override
  bool shouldRepaint(covariant _BuddyPainter old) =>
      old.species != species ||
      old.color != color ||
      old.mood != mood ||
      old.accessory != accessory ||
      old.outfit != outfit;
}
