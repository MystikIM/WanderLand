import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_info.dart';
import '../controllers/settings_controller.dart';
import '../domain/buddy.dart';
import 'buddy_view.dart';

const _ink = Color(0xFF2B1B3D);

/// Text with a thick dark outline, cartoon-sticker style.
TextStyle _sticker(double size, {FontWeight weight = FontWeight.w700}) => TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: Colors.white,
      height: 1.2,
      shadows: [
        for (final o in const [Offset(-2, -2), Offset(2, -2), Offset(-2, 2), Offset(2, 2), Offset(0, 3)])
          Shadow(color: _ink, offset: o),
      ],
    );

/// The dedication: the family motto, who it's for, and the little crew.
/// Tap a friend and they cuddle (hearts) or hop.
class DedicationCard extends StatefulWidget {
  const DedicationCard({super.key});
  @override
  State<DedicationCard> createState() => _DedicationCardState();
}

class _DedicationCardState extends State<DedicationCard> {
  final _ticks = List<int>.filled(4, 0);

  Widget _friend(int i, String species, Color color) => GestureDetector(
        key: Key('dedication-friend-$i'),
        onTap: () => setState(() => _ticks[i]++),
        child: BuddyView(
          species: species,
          color: color,
          mood: BuddyMood.happy,
          size: 62,
          reaction: BuddyAction.cuddle,
          reactionTick: _ticks[i],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('dedication-card'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _ink, width: 4),
        boxShadow: const [BoxShadow(color: Color(0x66FF29B4), blurRadius: 24)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(children: [
          const Positioned.fill(child: CustomPaint(painter: _DedicationSky())),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(dedicationMotto1, textAlign: TextAlign.center, style: _sticker(26)),
                const SizedBox(height: 6),
                Text(dedicationMotto2, textAlign: TextAlign.center, style: _sticker(18, weight: FontWeight.w600)),
                const SizedBox(height: 14),
              ]),
            ),
            SizedBox(
              height: 128,
              child: Stack(children: [
                const Positioned.fill(child: CustomPaint(painter: _DedicationHill())),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _friend(0, 'cat', const Color(0xFFB57BFF)),
                        _friend(1, 'bunny', const Color(0xFFFF9AD5)),
                        const _FoxView(key: Key('dedication-fox')),
                        _friend(2, 'frog', const Color(0xFF6FE3A1)),
                        _friend(3, 'dog', const Color(0xFFFFB86B)),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              color: const Color(0xFF331C63),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(dedicationTo, textAlign: TextAlign.center, style: _sticker(15, weight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('$madeBy 💜', textAlign: TextAlign.center, style: _sticker(13)),
              ]),
            ),
          ]),
        ]),
      ),
    );
  }
}

/// About page: the dedication plus the usual app details.
class DedicationScreen extends StatelessWidget {
  const DedicationScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('About')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const DedicationCard(),
          const SizedBox(height: 20),
          Text(appName, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('$appDescriptor · $appTagline', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => showLicensePage(context: context, applicationName: appName),
              child: const Text('Open-source licenses'),
            ),
          ),
        ]),
      );
}

/// Shown once, right after setup (or the first time after this was added).
Future<void> showDedicationDialog(BuildContext context) async {
  final settings = context.read<SettingsController>();
  await showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const DedicationCard(),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('dedication-continue'),
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Let's go 💜"),
          ),
        ]),
      ),
    ),
  );
  await settings.setProfile(settings.profile.copyWith(dedicationSeen: true));
}

class _DedicationSky extends CustomPainter {
  const _DedicationSky();
  @override
  void paint(Canvas c, Size s) {
    final r = Offset.zero & s;
    c.drawRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A1260), Color(0xFF8A2BD2), Color(0xFFFF4DB0)],
        ).createShader(r),
    );
    final star = Paint();
    for (var i = 0; i < 30; i++) {
      final x = (sin(i * 12.9898) * 43758.5453).abs() % 1;
      final y = ((sin(i * 78.233) * 12345.678).abs() % 1) * .7;
      star.color = Colors.white.withValues(alpha: .45 + (i % 4) * .13);
      c.drawCircle(Offset(x * s.width, y * s.height), s.width * (i % 6 == 0 ? .007 : .004), star);
    }
    for (final (x, y, k) in const [(.12, .28, 1.0), (.88, .22, .8), (.80, .45, .6), (.18, .52, .7)]) {
      final o = Offset(s.width * x, s.height * y);
      final p = Path()
        ..moveTo(o.dx, o.dy + 8 * k)
        ..cubicTo(o.dx - 16 * k, o.dy - 2 * k, o.dx - 7 * k, o.dy - 14 * k, o.dx, o.dy - 5 * k)
        ..cubicTo(o.dx + 7 * k, o.dy - 14 * k, o.dx + 16 * k, o.dy - 2 * k, o.dx, o.dy + 8 * k);
      c.drawPath(p, Paint()..color = const Color(0xFFFFB3E6).withValues(alpha: .8));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _DedicationHill extends CustomPainter {
  const _DedicationHill();
  @override
  void paint(Canvas c, Size s) {
    final p = Path()..moveTo(0, s.height);
    p.lineTo(0, s.height * .62);
    for (var x = 0.0; x <= s.width; x += 4) {
      p.lineTo(x, s.height * .62 + sin(x / s.width * 2 * pi) * s.height * .06);
    }
    p
      ..lineTo(s.width, s.height)
      ..close();
    c.drawPath(p, Paint()..color = const Color(0xFF5B2A9E));
    c.drawPath(
      p,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// "Crazy Fox": a wild-tufted orange fox with mismatched eyes and a tongue out.
class _FoxView extends StatefulWidget {
  const _FoxView({super.key});
  @override
  State<_FoxView> createState() => _FoxViewState();
}

class _FoxViewState extends State<_FoxView> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100), value: 1);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => _ctl.forward(from: 0),
        child: AnimatedBuilder(
          animation: _ctl,
          builder: (_, _) {
            final t = _ctl.value;
            final live = t < 1;
            final hop = live ? sin(t * pi * 3).abs() * (1 - t) : 0.0;
            return Transform.translate(
              offset: Offset(0, -hop * 22),
              child: Transform.rotate(
                angle: live ? sin(t * pi * 6) * (1 - t) * .18 : 0,
                child: SizedBox(width: 86, height: 86, child: CustomPaint(painter: _FoxPainter(live ? t : 1))),
              ),
            );
          },
        ),
      );
}

class _FoxPainter extends CustomPainter {
  _FoxPainter(this.t);
  final double t; // 1 = resting; < 1 = going wild (eyes spin)

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height, cx = w / 2;
    final line = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * .04
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    Paint f(Color col) => Paint()..color = col;
    void shape(Path p, Color col) {
      c.drawPath(p, f(col));
      c.drawPath(p, line);
    }

    const orange = Color(0xFFFF8A3D);
    const cream = Color(0xFFFFF1DC);
    // wild forehead tuft (behind the head)
    shape(
      Path()
        ..moveTo(cx - w * .16, h * .30)
        ..lineTo(cx - w * .13, h * .04)
        ..lineTo(cx - w * .04, h * .22)
        ..lineTo(cx + w * .02, h * -.02)
        ..lineTo(cx + w * .08, h * .22)
        ..lineTo(cx + w * .17, h * .06)
        ..lineTo(cx + w * .16, h * .32)
        ..close(),
      orange,
    );
    for (final dx in [-1.0, 1.0]) {
      shape(
        Path()
          ..moveTo(cx + dx * w * .34, h * .42)
          ..lineTo(cx + dx * w * .40, h * .08)
          ..lineTo(cx + dx * w * .12, h * .28)
          ..close(),
        orange,
      );
      c.drawPath(
        Path()
          ..moveTo(cx + dx * w * .33, h * .36)
          ..lineTo(cx + dx * w * .36, h * .15)
          ..lineTo(cx + dx * w * .19, h * .29)
          ..close(),
        f(const Color(0xFFFF9DB8)),
      );
    }
    final head = Rect.fromLTWH(w * .06, h * .24, w * .88, h * .68);
    c.drawOval(head, f(orange));
    c.drawOval(head, line);
    // white cheek fluff + muzzle
    for (final dx in [-1.0, 1.0]) {
      c.drawOval(Rect.fromCenter(center: Offset(cx + dx * w * .27, h * .72), width: w * .34, height: h * .24), f(cream));
    }
    c.drawOval(Rect.fromCenter(center: Offset(cx, h * .74), width: w * .34, height: h * .22), f(cream));
    c.drawOval(Rect.fromCenter(center: Offset(cx, h * .64), width: w * .10, height: w * .07), f(_ink));
    // mismatched crazy eyes
    final spin = (1 - t) * pi * 6;
    for (final (dx, r) in [(-1.0, w * .11), (1.0, w * .075)]) {
      final e = Offset(cx + dx * w * .19, h * (dx < 0 ? .50 : .52));
      c.drawCircle(e, r, f(Colors.white));
      c.drawCircle(e, r, line..strokeWidth = w * .03);
      c.drawCircle(e.translate(cos(spin) * r * .35, sin(spin) * r * .35), r * .38, f(_ink));
    }
    line.strokeWidth = w * .04;
    // one raised, one dipped brow
    c.drawLine(Offset(cx - w * .30, h * .36), Offset(cx - w * .10, h * .40), line..strokeWidth = w * .035);
    c.drawLine(Offset(cx + w * .10, h * .42), Offset(cx + w * .28, h * .37), line);
    // big grin with the tongue out
    c.drawArc(Rect.fromCenter(center: Offset(cx, h * .76), width: w * .26, height: w * .16), 0, pi, false, line);
    c.drawOval(Rect.fromCenter(center: Offset(cx + w * .05, h * .86), width: w * .09, height: w * .10), f(const Color(0xFFFF6FA5)));
    c.drawOval(Rect.fromCenter(center: Offset(cx + w * .05, h * .86), width: w * .09, height: w * .10), line..strokeWidth = w * .02);
  }

  @override
  bool shouldRepaint(covariant _FoxPainter old) => old.t != t;
}
