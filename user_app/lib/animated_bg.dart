import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Animated background that changes with the selected navigation tab.
class AnimatedTabBackground extends StatefulWidget {
  final int index;
  final Widget child;
  const AnimatedTabBackground({super.key, required this.index, required this.child});
  @override
  State<AnimatedTabBackground> createState() => _AnimatedTabBackgroundState();
}

class _AnimatedTabBackgroundState extends State<AnimatedTabBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(vsync: this, duration: const Duration(seconds: 24))
      ..repeat();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(children: [
      Positioned.fill(
        child: RepaintBoundary(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            child: CustomPaint(
              key: ValueKey(widget.index),
              size: Size.infinite,
              painter: _BgPainter(widget.index, _ctl, cs),
            ),
          ),
        ),
      ),
      widget.child,
    ]);
  }
}

class _BgPainter extends CustomPainter {
  final int index;
  final Animation<double> anim;
  final ColorScheme cs;
  _BgPainter(this.index, this.anim, this.cs) : super(repaint: anim);

  static const _tau = math.pi * 2;
  double _frac(double v) => v - v.floorToDouble();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final t = anim.value;
    final rect = Offset.zero & size;
    // base gradient
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(cs.primary.withOpacity(.10), cs.surface),
            cs.surface,
          ],
        ).createShader(rect),
    );
    switch (index) {
      case 0:
        _aurora(canvas, w, h, t);
        break;
      case 1:
        _bubbles(canvas, w, h, t);
        break;
      case 2:
        _rings(canvas, w, h, t);
        break;
      case 3:
        _network(canvas, w, h, t);
        break;
      case 4:
        _stars(canvas, w, h, t);
        break;
      default:
        _waves(canvas, w, h, t);
    }
  }

  void _blob(Canvas c, Offset o, double r, Color col) {
    c.drawCircle(
      o,
      r,
      Paint()
        ..shader = RadialGradient(colors: [col, col.withOpacity(0)])
            .createShader(Rect.fromCircle(center: o, radius: r)),
    );
  }

  void _aurora(Canvas c, double w, double h, double t) {
    _blob(c, Offset(w * (.5 + .35 * math.sin(_tau * t)), h * (.25 + .12 * math.cos(_tau * t))),
        w * .7, cs.primary.withOpacity(.35));
    _blob(c, Offset(w * (.5 + .4 * math.cos(_tau * t + 2)), h * (.55 + .15 * math.sin(_tau * t + 1))),
        w * .65, cs.tertiary.withOpacity(.28));
    _blob(c, Offset(w * (.5 + .3 * math.sin(_tau * 2 * t + 4)), h * (.85 + .08 * math.cos(_tau * t))),
        w * .6, cs.secondary.withOpacity(.25));
  }

  void _bubbles(Canvas c, double w, double h, double t) {
    final fill = Paint()..color = cs.primary.withOpacity(.10);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = cs.primary.withOpacity(.30);
    for (var i = 0; i < 16; i++) {
      final speed = 1 + i % 3;
      final p = _frac(t * speed + i * .137);
      final x = w * _frac(i * .37 + .1) + 14 * math.sin(_tau * 2 * t + i);
      final y = h * (1.05 - p * 1.15);
      final r = 8.0 + (i * 7 % 22);
      c.drawCircle(Offset(x, y), r, fill);
      c.drawCircle(Offset(x, y), r, line);
    }
  }

  void _rings(Canvas c, double w, double h, double t) {
    final o = Offset(w / 2, h * .38);
    _blob(c, o, w * .55, cs.primary.withOpacity(.22 + .08 * math.sin(_tau * 6 * t)));
    for (var i = 0; i < 5; i++) {
      final p = _frac(t * 3 + i / 5);
      c.drawCircle(
        o,
        p * math.max(w, h) * .7,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = cs.primary.withOpacity((1 - p) * .35),
      );
    }
  }

  void _network(Canvas c, double w, double h, double t) {
    final pts = <Offset>[];
    for (var i = 0; i < 18; i++) {
      pts.add(Offset(
        w * (.5 + .42 * math.sin(_tau * (t + i * .173))),
        h * (.5 + .42 * math.cos(_tau * (t + i * .291))),
      ));
    }
    final lp = Paint()..strokeWidth = 1;
    for (var a = 0; a < pts.length; a++) {
      for (var b = a + 1; b < pts.length; b++) {
        final d = (pts[a] - pts[b]).distance;
        if (d < 130) {
          lp.color = cs.tertiary.withOpacity((1 - d / 130) * .35);
          c.drawLine(pts[a], pts[b], lp);
        }
      }
    }
    final dp = Paint()..color = cs.primary.withOpacity(.55);
    for (final p in pts) {
      c.drawCircle(p, 3, dp);
    }
  }

  void _stars(Canvas c, double w, double h, double t) {
    _blob(c, Offset(w * .5, h * .12), w * .8, cs.secondary.withOpacity(.22));
    for (var i = 0; i < 46; i++) {
      final x = w * _frac(i * .6180339);
      final y = h * _frac(i * .4142135 + .05 * math.sin(_tau * t + i));
      final a = .5 + .5 * math.sin(_tau * 3 * t + i * 1.7);
      c.drawCircle(Offset(x, y), 1 + (i % 3) * .8,
          Paint()..color = Colors.white.withOpacity(a * .6));
    }
  }

  void _waves(Canvas c, double w, double h, double t) {
    final colors = [cs.primary, cs.tertiary, cs.secondary, cs.primary];
    for (var i = 0; i < 4; i++) {
      final path = Path()..moveTo(0, h);
      for (double x = 0; x <= w; x += 6) {
        final y = h * (.5 + .1 * i) + 22 * math.sin(_tau * (x / w * 1.5 + t + i * .25));
        path.lineTo(x, y);
      }
      path
        ..lineTo(w, h)
        ..close();
      c.drawPath(path, Paint()..color = colors[i].withOpacity(.10 + .02 * i));
    }
  }

  @override
  bool shouldRepaint(covariant _BgPainter old) => old.index != index || old.cs != cs;
}
