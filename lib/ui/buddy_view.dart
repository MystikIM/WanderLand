import 'dart:math';
import 'package:flutter/material.dart';
import '../domain/buddy.dart';
import 'art.dart';
import 'buddy_art.dart';

const _ink = Color(0xFF2B1B3D);

/// The buddy. Cartoony thick-outline style. When [reactionTick] changes and a
/// [reaction] is given, plays a short one-shot animation for that care action
/// (chewing, bubbles, blushing...). It never loops, so nothing is ever "running"
/// in the background.
class BuddyView extends StatefulWidget {
  const BuddyView({
    super.key,
    required this.species,
    required this.color,
    required this.mood,
    this.accessory = '',
    this.outfit = '',
    this.size = 120,
    this.reaction,
    this.reactionTick = 0,
  });
  final String species;
  final Color color;
  final BuddyMood mood;
  final String accessory;
  final String outfit;
  final double size;
  final BuddyAction? reaction;
  final int reactionTick;

  @override
  State<BuddyView> createState() => _BuddyViewState();
}

class _BuddyViewState extends State<BuddyView> with SingleTickerProviderStateMixin {
  // value: 1 means "resting" (no effect), so a fresh view never replays an old action.
  late final AnimationController _ctl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3200), value: 1);

  bool get _useArt =>
      buddyHasArt(widget.species) && widget.accessory.isEmpty && widget.outfit.isEmpty;

  static const _poses = [
    'idle_happy', 'idle_content', 'idle_sleepy', 'eating_open', 'eating_closed',
    'cuddle', 'jump', 'wash',
  ];
  static const _props = [
    'apple', 'cookie', 'crumbs', 'foam_puff', 'bubble_small', 'bubble_medium',
    'bubble_large', 'heart_float', 'balloon', 'sparkle_star', 'dust_puff', 'petting_hand',
  ];
  String? _warmedFor;

  /// Load every pose of this species up front so swapping poses never flickers.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_useArt || _warmedFor == widget.species) return;
    _warmedFor = widget.species;
    final sp = widget.species == 'rabbit' ? 'bunny' : widget.species;
    for (final p in _poses) {
      precacheImage(AssetImage(artPath('buddy_${sp}_$p')), context, onError: (_, _) {});
    }
    for (final p in _props) {
      precacheImage(AssetImage(artPath('buddy_prop_$p')), context, onError: (_, _) {});
    }
  }

  @override
  void didUpdateWidget(BuddyView old) {
    super.didUpdateWidget(old);
    if (old.species != widget.species) didChangeDependencies();
    if (widget.reactionTick != old.reactionTick && widget.reaction != null) {
      _ctl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _ctl,
          builder: (_, _) => _useArt
              ? ArtBuddy(
                  species: widget.species,
                  color: widget.color,
                  mood: widget.mood,
                  size: widget.size,
                  reaction: widget.reaction,
                  t: _ctl.value,
                )
              : CustomPaint(
                  painter: _BuddyPainter(
                    widget.species,
                    widget.color,
                    widget.mood,
                    widget.accessory,
                    widget.outfit,
                    widget.reaction,
                    _ctl.value,
                  ),
                ),
        ),
      );
}

enum _Eyes { mood, happy, squint }

class _Pose {
  double dx = 0, dy = 0, sx = 1, sy = 1, rot = 0, blush = 0, mouth = 0;
  _Eyes eyes = _Eyes.mood;
}

double _seg(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0).toDouble();

class _BuddyPainter extends CustomPainter {
  _BuddyPainter(this.species, this.color, this.mood, this.accessory, this.outfit, this.reaction, this.t);
  final String species;
  final Color color;
  final BuddyMood mood;
  final String accessory;
  final String outfit;
  final BuddyAction? reaction;
  final double t;

  double _w = 0, _h = 0, _cx = 0;
  Paint _line = Paint();

  // ---------- outlined shape helpers (the cartoony look) ----------
  void _oval(Canvas c, Rect r, Paint f) {
    c.drawOval(r, f);
    c.drawOval(r, _line);
  }

  void _path(Canvas c, Path p, Paint f) {
    c.drawPath(p, f);
    c.drawPath(p, _line);
  }

  void _circ(Canvas c, Offset o, double r, Paint f) {
    c.drawCircle(o, r, f);
    c.drawCircle(o, r, _line);
  }

  void _rrect(Canvas c, Rect r, double radius, Paint f) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
    c.drawRRect(rr, f);
    c.drawRRect(rr, _line);
  }

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

  Path _heart(Offset o, double s) => Path()
    ..moveTo(o.dx, o.dy + s * .9)
    ..cubicTo(o.dx - s * 2, o.dy - s * .2, o.dx - s * .9, o.dy - s * 1.4, o.dx, o.dy - s * .5)
    ..cubicTo(o.dx + s * .9, o.dy - s * 1.4, o.dx + s * 2, o.dy - s * .2, o.dx, o.dy + s * .9);

  // ---------- what the body does during a reaction ----------
  _Pose _pose() {
    final p = _Pose();
    final a = reaction;
    if (a == null || t >= 1) return p;
    switch (a) {
      case BuddyAction.feed:
      case BuddyAction.snack:
        if (t < .34) {
          p.mouth = .95 * _seg(t, .04, .2); // mouth opens for the food
        } else if (t < .88) {
          final o = (sin(_seg(t, .34, .88) * pi * 2 * 5) + 1) / 2; // chew, chew, chew
          p.mouth = o * .95;
          p.sx = 1 + .04 * o; // cheeks puff
          p.sy = 1 - .03 * o;
          p.eyes = _Eyes.happy;
        } else {
          p.eyes = _Eyes.happy;
        }
      case BuddyAction.walk:
        final s = sin(t * pi * 4);
        p.dx = s * .13;
        p.dy = -sin(t * pi * 8).abs() * .04;
        p.rot = s * .07;
      case BuddyAction.play:
        final hop = sin(t * pi * 4).abs();
        p.dy = -hop * .2;
        p.sy = 1 - .1 * (1 - hop); // squash when landing
        p.sx = 1 + .08 * (1 - hop);
        p.eyes = _Eyes.happy;
        p.mouth = .5;
      case BuddyAction.cuddle:
        p.blush = _seg(t, 0, .25) * (1 - _seg(t, .85, 1)); // cheeks go red and cozy
        p.eyes = _Eyes.happy;
        final pl = (sin(t * pi * 6) + 1) / 2;
        p.sx = 1 + .04 * pl;
        p.sy = 1 - .03 * pl;
        p.rot = sin(t * pi * 4) * .05;
      case BuddyAction.pet:
        p.eyes = _Eyes.happy;
        p.blush = .4 * (1 - _seg(t, .9, 1));
        p.rot = sin(t * pi * 8) * .03;
        p.sy = 1 - .025 * ((sin(t * pi * 6) + 1) / 2);
      case BuddyAction.wash:
        p.rot = (t > .1 && t < .7) ? sin(t * pi * 12) * .05 : 0;
        p.eyes = t < .8 ? _Eyes.squint : _Eyes.mood;
    }
    return p;
  }

  // ---------- parts behind the body ----------
  void _behindBody(Canvas c) {
    final w = _w, h = _h, cx = _cx;
    final body = Paint()..color = color;
    final dark = Paint()..color = Color.lerp(color, const Color(0xFF000000), .25)!;
    final light = Paint()..color = Color.lerp(color, const Color(0xFFFFFFFF), .4)!;
    const sides = [-1.0, 1.0];
    if (outfit == 'cape') {
      _path(
        c,
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
          _path(
            c,
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
          _oval(c, Rect.fromCenter(center: Offset(cx + dx * w * .38, h * .46), width: w * .20, height: h * .34), dark);
        }
      case 'bunny':
        for (final dx in sides) {
          _oval(c, Rect.fromCenter(center: Offset(cx + dx * w * .16, h * .16), width: w * .14, height: h * .34), body);
        }
      case 'rabbit':
        for (final dx in sides) {
          _oval(c, Rect.fromCenter(center: Offset(cx + dx * w * .38, h * .52), width: w * .13, height: h * .40), body);
        }
      case 'frog':
        for (final dx in sides) {
          _circ(c, Offset(cx + dx * w * .22, h * .30), w * .12, body);
        }
      case 'turtle':
        _oval(c, Rect.fromLTWH(w * .02, h * .36, w * .96, h * .60), dark);
        for (final dx in sides) {
          _circ(c, Offset(cx + dx * w * .30, h * .93), w * .07, body);
        }
      case 'butterfly':
        for (final dx in sides) {
          _oval(c, Rect.fromCenter(center: Offset(cx + dx * w * .38, h * .40), width: w * .34, height: h * .40), light);
          _oval(c, Rect.fromCenter(center: Offset(cx + dx * w * .34, h * .72), width: w * .26, height: h * .30), light);
        }
      case 'fairy':
        final wing = Paint()..color = const Color(0xCCFFFFFF);
        for (final dx in sides) {
          _oval(c, Rect.fromCenter(center: Offset(cx + dx * w * .40, h * .42), width: w * .26, height: h * .44), wing);
        }
      case 'unicorn':
        for (final dx in sides) {
          _path(
            c,
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

  // ---------- whiskers, noses, horns ----------
  void _frontOfFace(Canvas c, Paint ink, Paint fill) {
    final w = _w, h = _h, cx = _cx;
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
        c.drawCircle(Offset(cx, h * .62), w * .022, Paint()..color = const Color(0xFFFF6FA5));
      case 'frog':
        c.drawArc(Rect.fromCenter(center: Offset(cx, h * .64), width: w * .36, height: w * .16), 0, pi, false, ink);
      case 'butterfly':
        for (final dx in sides) {
          c.drawLine(Offset(cx + dx * w * .06, h * .28), Offset(cx + dx * w * .14, h * .10), ink);
          c.drawCircle(Offset(cx + dx * w * .14, h * .10), w * .025, fill);
        }
      case 'fairy':
        _path(c, _star(Offset(cx - w * .26, h * .20), w * .07), Paint()..color = const Color(0xFFFFE680));
      case 'unicorn':
        _path(
          c,
          Path()
            ..moveTo(cx - w * .06, h * .30)
            ..lineTo(cx, h * .02)
            ..lineTo(cx + w * .06, h * .30)
            ..close(),
          Paint()..color = const Color(0xFFFFC94D),
        );
        for (var i = 0; i < 3; i++) {
          c.drawCircle(Offset(cx - w * .32, h * .36 + i * h * .10), w * .06, Paint()..color = const Color(0xFFFF8CC6));
        }
    }
  }

  void _outfit(Canvas c) {
    final w = _w, h = _h, cx = _cx;
    Rect box(double l, double tt, double ww, double hh) => Rect.fromLTWH(l, tt, ww, hh);
    switch (outfit) {
      case 'shirt':
        final p = Paint()..color = const Color(0xFF4DA3FF);
        _rrect(c, box(w * .24, h * .74, w * .52, h * .18), h * .05, p);
        for (final dx in [-1.0, 1.0]) {
          _oval(c, Rect.fromCenter(center: Offset(cx + dx * w * .28, h * .77), width: w * .14, height: h * .10), p);
        }
      case 'hoodie':
        _rrect(c, box(w * .20, h * .72, w * .60, h * .22), h * .06, Paint()..color = const Color(0xFF7E57C2));
        c.drawRRect(
          RRect.fromRectAndRadius(box(w * .36, h * .82, w * .28, h * .08), Radius.circular(h * .03)),
          Paint()..color = const Color(0x33000000),
        );
        final string = Paint()
          ..color = const Color(0xFFFFFFFF)
          ..strokeWidth = w * .02
          ..strokeCap = StrokeCap.round;
        for (final dx in [-1.0, 1.0]) {
          c.drawLine(Offset(cx + dx * w * .06, h * .72), Offset(cx + dx * w * .06, h * .80), string);
        }
      case 'dress':
        _path(
          c,
          Path()
            ..moveTo(cx - w * .14, h * .72)
            ..lineTo(cx + w * .14, h * .72)
            ..lineTo(cx + w * .30, h * .94)
            ..lineTo(cx - w * .30, h * .94)
            ..close(),
          Paint()..color = const Color(0xFFFF8CC6),
        );
      case 'pajamas':
        _rrect(c, box(w * .22, h * .72, w * .56, h * .22), h * .05, Paint()..color = const Color(0xFF9FA8DA));
        final dot = Paint()..color = const Color(0xFFFFFFFF);
        for (var i = 0; i < 3; i++) {
          c.drawCircle(Offset(cx - w * .16 + i * w * .16, h * .83), w * .025, dot);
        }
    }
  }

  // ---------- the face ----------
  void _eyes(Canvas c, _Pose p, Paint ink, Paint fill) {
    final w = _w, h = _h, cx = _cx;
    final ey = h * .55;
    final eyes = p.eyes == _Eyes.mood
        ? switch (mood) {
            BuddyMood.happy => _Eyes.happy,
            BuddyMood.content => _Eyes.mood,
            BuddyMood.sleepy => _Eyes.squint,
          }
        : p.eyes;
    final thick = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * .03
      ..strokeCap = StrokeCap.round;
    for (final dx in [-1.0, 1.0]) {
      final o = Offset(cx + dx * w * .15, ey);
      if (p.eyes == _Eyes.squint) {
        // "> <" scrunched eyes (soap!)
        final path = Path()
          ..moveTo(o.dx - dx * w * .05, o.dy - w * .04)
          ..lineTo(o.dx + dx * w * .03, o.dy)
          ..lineTo(o.dx - dx * w * .05, o.dy + w * .04);
        c.drawPath(path, thick);
      } else if (eyes == _Eyes.happy) {
        c.drawArc(Rect.fromCenter(center: o, width: w * .13, height: w * .13), pi, pi, false, thick);
      } else if (mood == BuddyMood.sleepy && p.eyes == _Eyes.mood) {
        c.drawLine(o.translate(-w * .05, 0), o.translate(w * .05, 0), thick);
      } else {
        // big shiny cartoon eyes
        c.drawOval(Rect.fromCenter(center: o, width: w * .09, height: h * .13), fill);
        c.drawCircle(o.translate(-w * .014, -h * .03), w * .02, Paint()..color = const Color(0xFFFFFFFF));
        c.drawCircle(o.translate(w * .014, h * .025), w * .009, Paint()..color = const Color(0xFFFFFFFF));
      }
    }
  }

  void _mouth(Canvas c, _Pose p, Paint ink) {
    final w = _w, h = _h, cx = _cx;
    if (p.mouth > .05) {
      final r = Rect.fromCenter(center: Offset(cx, h * .67), width: w * .13, height: w * .02 + w * .12 * p.mouth);
      c.drawOval(r, Paint()..color = const Color(0xFF4A1230));
      if (p.mouth > .35) {
        c.drawOval(
          Rect.fromCenter(center: Offset(cx, r.bottom - r.height * .22), width: r.width * .6, height: r.height * .38),
          Paint()..color = const Color(0xFFFF7BA9),
        );
      }
      c.drawOval(r, ink);
    } else {
      c.drawArc(Rect.fromCenter(center: Offset(cx, h * .66), width: w * .14, height: w * .09), 0, pi, false, ink);
    }
  }

  void _cheeks(Canvas c, _Pose p) {
    final w = _w, h = _h, cx = _cx;
    final col = Color.lerp(const Color(0x77FF6FA5), const Color(0xF2FF2D55), p.blush)!;
    final cw = w * (.12 + .06 * p.blush), ch = w * (.08 + .04 * p.blush);
    for (final dx in [-1.0, 1.0]) {
      c.drawOval(Rect.fromCenter(center: Offset(cx + dx * w * .26, h * .66), width: cw, height: ch), Paint()..color = col);
    }
  }

  // ---------- effects drawn on top of everything ----------
  void _food(Canvas c, bool cookie) {
    final w = _w, h = _h, cx = _cx;
    final drop = Curves.easeIn.transform(_seg(t, 0, .30));
    final shrink = 1 - _seg(t, .30, .40); // pops into the mouth
    if (shrink <= 0) return;
    final r = w * .11 * shrink;
    final o = Offset(cx, h * -.02 + (h * .64) * drop);
    if (cookie) {
      _circ(c, o, r, Paint()..color = const Color(0xFFD9A066));
      final chip = Paint()..color = const Color(0xFF5A3418);
      for (final d in const [Offset(-.4, -.3), Offset(.3, -.4), Offset(.1, .3), Offset(-.35, .25), Offset(.45, .15)]) {
        c.drawCircle(o + d * r, r * .16, chip);
      }
    } else {
      _circ(c, o, r, Paint()..color = const Color(0xFFFF4D4D));
      c.drawLine(o.translate(0, -r * .9), o.translate(r * .2, -r * 1.35), _line);
      _oval(c, Rect.fromCenter(center: o.translate(r * .5, -r * 1.15), width: r * .7, height: r * .36),
          Paint()..color = const Color(0xFF58C957));
      c.drawCircle(o.translate(-r * .38, -r * .3), r * .18, Paint()..color = const Color(0x99FFFFFF));
    }
  }

  void _crumbs(Canvas c) {
    if (t < .36 || t > .88) return;
    final chew = _seg(t, .34, .88);
    final w = _w, h = _h, cx = _cx;
    for (var i = 0; i < 5; i++) {
      final ph = (chew * 5 + i * .2) % 1;
      c.drawCircle(
        Offset(cx + (i - 2) * w * .07 * (.6 + ph), h * .72 + ph * h * .12),
        w * .014,
        Paint()..color = const Color(0xFFD9A066).withValues(alpha: 1 - ph),
      );
    }
  }

  void _bubbles(Canvas c) {
    final w = _w, h = _h, cx = _cx;
    if (t < .04 || t > .95) return;
    final edge = Paint()
      ..color = const Color(0xFF7FD6FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * .014;
    for (var i = 0; i < 10; i++) {
      final ph = (t * 1.3 + i * .1) % 1;
      final r = w * (.035 + .02 * (i % 3));
      final o = Offset(cx + sin(i * 2.1) * w * .34 + sin(ph * 9 + i) * w * .02, h * (1.0 - ph * .95));
      c.drawCircle(o, r, Paint()..color = const Color(0x55FFFFFF));
      c.drawCircle(o, r, edge);
      c.drawCircle(o.translate(-r * .35, -r * .35), r * .22, Paint()..color = const Color(0xFFFFFFFF));
    }
    // foam on the head, rinsed away near the end
    final f = _seg(t, 0, .3) * (1 - _seg(t, .75, .95));
    if (f > 0) {
      final foam = Paint()..color = const Color(0xFFFFFFFF);
      final foamEdge = Paint()
        ..color = const Color(0xFF9ADCF5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * .016;
      for (final d in const [Offset(-.14, .22), Offset(0, .15), Offset(.14, .22), Offset(-.06, .27), Offset(.08, .28)]) {
        final o = Offset(cx + d.dx * w, h * d.dy);
        c.drawCircle(o, w * .085 * f, foam);
        c.drawCircle(o, w * .085 * f, foamEdge);
      }
    }
    final sp = _seg(t, .8, 1);
    if (sp > 0) {
      _path(c, _star(Offset(cx + w * .3, h * .2), w * .08 * sin(sp * pi)), Paint()..color = const Color(0xFFFFF59D));
    }
  }

  void _hearts(Canvas c) {
    if (t < .08 || t > .92) return;
    final w = _w, h = _h, cx = _cx;
    for (var i = 0; i < 5; i++) {
      final ph = (t * 1.3 + i * .2) % 1;
      final o = Offset(cx + (i - 2) * w * .17 + sin(ph * 6 + i) * w * .03, h * .34 - ph * h * .30);
      final hp = _heart(o, w * .085 * (1 - ph * .35));
      c.drawPath(hp, Paint()..color = const Color(0xFFFF4D8D).withValues(alpha: 1 - ph * .7));
      c.drawPath(hp, _line..color = _ink.withValues(alpha: 1 - ph * .7));
      _line.color = _ink;
    }
  }

  void _glow(Canvas c, _Pose p) {
    if (p.blush <= 0) return;
    final rect = Rect.fromCircle(center: Offset(_cx, _h * .6), radius: _w * .6);
    c.drawCircle(
      rect.center,
      rect.width / 2,
      Paint()
        ..shader = RadialGradient(colors: [
          const Color(0xFFFF8CC6).withValues(alpha: .55 * p.blush),
          const Color(0x00FF8CC6),
        ]).createShader(rect),
    );
  }

  void _hand(Canvas c) {
    final v = _seg(t, 0, .1) * (1 - _seg(t, .9, 1));
    if (v <= 0) return;
    final w = _w, h = _h, cx = _cx;
    final x = cx + sin(t * pi * 6) * w * .14;
    final y = h * .22 - (1 - v) * h * .25 + sin(t * pi * 12) * h * .012;
    final skin = Paint()..color = const Color(0xFFFFD9B8);
    _oval(c, Rect.fromCenter(center: Offset(x - w * .13, y + h * .03), width: w * .10, height: w * .15), skin);
    _rrect(c, Rect.fromCenter(center: Offset(x, y), width: w * .27, height: h * .15), h * .07, skin);
    final sp = Paint()..color = const Color(0xFFFFF59D);
    _path(c, _star(Offset(cx - w * .32, h * .2 + sin(t * 20) * 2), w * .05), sp);
    _path(c, _star(Offset(cx + w * .34, h * .26), w * .04), sp);
  }

  void _balloon(Canvas c) {
    final w = _w, h = _h, cx = _cx;
    final bob = sin(t * pi * 4) * h * .02;
    final o = Offset(cx + w * .36, h * .15 + bob);
    c.drawPath(
      Path()
        ..moveTo(o.dx, o.dy + w * .15)
        ..quadraticBezierTo(cx + w * .26, h * .45, cx + w * .2, h * .66),
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * .012,
    );
    _oval(c, Rect.fromCenter(center: o, width: w * .22, height: w * .27), Paint()..color = const Color(0xFFFF4DA6));
    _path(c, Path()
      ..moveTo(o.dx, o.dy + w * .13)
      ..lineTo(o.dx - w * .025, o.dy + w * .17)
      ..lineTo(o.dx + w * .025, o.dy + w * .17)
      ..close(), Paint()..color = const Color(0xFFFF4DA6));
    c.drawOval(Rect.fromCenter(center: o.translate(-w * .05, -w * .06), width: w * .05, height: w * .08),
        Paint()..color = const Color(0x99FFFFFF));
  }

  void _dust(Canvas c) {
    final w = _w, h = _h, cx = _cx;
    for (var i = 0; i < 3; i++) {
      final ph = (t * 2 + i / 3) % 1;
      c.drawCircle(Offset(cx + (i - 1) * w * .22, h * .96), w * .05 * ph,
          Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: (1 - ph) * .6));
    }
  }

  @override
  void paint(Canvas c, Size s) {
    _w = s.width;
    _h = s.height;
    _cx = _w / 2;
    final w = _w, h = _h, cx = _cx;
    _line = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * .035
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final body = Paint()..color = color;
    final ink = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * .025
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = _ink;
    final p = _pose();

    if (reaction == BuddyAction.walk && t < 1) _dust(c);
    _glow(c, p);

    c.save();
    c.translate(cx + p.dx * w, h * .94 + p.dy * h);
    c.rotate(p.rot);
    c.scale(p.sx, p.sy);
    c.translate(-cx, -h * .94);

    _behindBody(c);
    _oval(c, Rect.fromLTWH(w * .10, h * .26, w * .80, h * .68), body);
    // glossy shine
    c.drawOval(Rect.fromLTWH(w * .22, h * .33, w * .20, h * .09),
        Paint()..color = Color.lerp(color, const Color(0xFFFFFFFF), .65)!.withValues(alpha: .7));
    c.drawCircle(Offset(w * .46, h * .37), w * .018, Paint()..color = const Color(0x99FFFFFF));
    _cheeks(c, p);
    _eyes(c, p, ink, fill);
    _mouth(c, p, ink);
    _frontOfFace(c, ink, fill);
    _outfit(c);

    final gold = Paint()..color = const Color(0xFFFFC94D);
    switch (accessory) {
      case 'bow':
        final pink = Paint()..color = const Color(0xFFFF4D8D);
        for (final dx in [-1.0, 1.0]) {
          _path(
            c,
            Path()
              ..moveTo(cx + w * .22, h * .30)
              ..lineTo(cx + w * .22 + dx * w * .13, h * .22)
              ..lineTo(cx + w * .22 + dx * w * .13, h * .38)
              ..close(),
            pink,
          );
        }
        _circ(c, Offset(cx + w * .22, h * .30), w * .03, pink);
      case 'crown':
        _path(
          c,
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
        _rrect(c, Rect.fromLTWH(w * .18, h * .78, w * .64, h * .09), h * .04, Paint()..color = const Color(0xFF4DA3FF));
      case 'glasses':
        for (final dx in [-1.0, 1.0]) {
          c.drawCircle(Offset(cx + dx * w * .15, h * .55), w * .10, ink);
        }
        c.drawLine(Offset(cx - w * .05, h * .55), Offset(cx + w * .05, h * .55), ink);
      case 'star':
        _path(c, _star(Offset(cx + w * .22, h * .22), w * .10), gold);
    }
    c.restore();

    // effects on top, in the buddy's own box
    if (reaction != null && t < 1) {
      switch (reaction!) {
        case BuddyAction.feed:
          _food(c, false);
          _crumbs(c);
        case BuddyAction.snack:
          _food(c, true);
          _crumbs(c);
        case BuddyAction.walk:
          break;
        case BuddyAction.play:
          _balloon(c);
        case BuddyAction.cuddle:
          _hearts(c);
        case BuddyAction.pet:
          _hand(c);
        case BuddyAction.wash:
          _bubbles(c);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BuddyPainter old) =>
      old.species != species ||
      old.color != color ||
      old.mood != mood ||
      old.accessory != accessory ||
      old.outfit != outfit ||
      old.reaction != reaction ||
      old.t != t;
}
