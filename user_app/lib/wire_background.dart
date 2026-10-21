import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Animated dark gradient with floating 3D wireframe shapes (cube, octahedron, ring).
class WireBackground extends StatefulWidget {
  const WireBackground({super.key});
  @override
  State<WireBackground> createState() => _WireBackgroundState();
}

class _WireBackgroundState extends State<WireBackground>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final time = ValueNotifier<double>(0);
  final shapes = _makeShapes();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) => time.value = d.inMicroseconds / 1e6)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF05050F), Color(0xFF120A2B)],
        ),
      ),
      child: CustomPaint(
        painter: _WirePainter(shapes, time),
        size: Size.infinite,
      ),
    );
  }
}

class _Shape {
  final List<List<double>> v;
  final List<List<int>> e;
  final double x, y, z, rx, ry, rz, sx, sy, sz, size, alpha;
  final Color c;
  _Shape(this.v, this.e, this.x, this.y, this.z, this.rx, this.ry, this.rz,
      this.sx, this.sy, this.sz, this.size, this.alpha, this.c);
}

List<_Shape> _makeShapes() {
  final r = Random(7);
  const palette = [
    Color(0xFF7C5CFF),
    Color(0xFF00E0FF),
    Color(0xFFFF5CA8),
    Color(0xFF5CFFB1),
    Color(0xFFFFD166),
  ];
  final cube = <List<double>>[
    for (var i = 0; i < 8; i++)
      [(i & 1) == 0 ? -1.0 : 1.0, (i & 2) == 0 ? -1.0 : 1.0, (i & 4) == 0 ? -1.0 : 1.0]
  ];
  final cubeE = <List<int>>[
    for (var i = 0; i < 8; i++)
      for (var j = i + 1; j < 8; j++)
        if ([1, 2, 4].contains(i ^ j)) [i, j]
  ];
  final octa = <List<double>>[
    [1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]
  ];
  final octaE = <List<int>>[
    for (var i = 0; i < 6; i++)
      for (var j = i + 1; j < 6; j++)
        if ((i >> 1) != (j >> 1)) [i, j]
  ];
  const n = 20;
  final ring = <List<double>>[
    for (var i = 0; i < n; i++) [cos(i / n * 2 * pi), sin(i / n * 2 * pi), 0]
  ];
  final ringE = <List<int>>[
    for (var i = 0; i < n; i++) [i, (i + 1) % n]
  ];
  final kinds = [(cube, cubeE), (octa, octaE), (ring, ringE)];

  double rnd(double a) => (r.nextDouble() - .5) * a;
  return List.generate(18, (i) {
    final k = kinds[i % 3];
    return _Shape(k.$1, k.$2, rnd(2), rnd(2), r.nextDouble() * 900 + 100,
        r.nextDouble() * pi, r.nextDouble() * pi, r.nextDouble() * pi,
        rnd(.6), rnd(.6), rnd(.6), r.nextDouble() * 34 + 16,
        r.nextDouble() * .5 + .3, palette[i % 5]);
  });
}

class _WirePainter extends CustomPainter {
  final List<_Shape> shapes;
  final ValueNotifier<double> time;
  _WirePainter(this.shapes, this.time) : super(repaint: time);

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final cx = size.width / 2, cy = size.height / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (var i = 0; i < shapes.length; i++) {
      final s = shapes[i];
      final ax = s.rx + s.sx * t, ay = s.ry + s.sy * t, az = s.rz + s.sz * t;
      final pts = <Offset>[];
      for (final p in s.v) {
        var x = p[0], y = p[1], z = p[2];
        var y1 = y * cos(ax) - z * sin(ax);
        var z1 = y * sin(ax) + z * cos(ax);
        y = y1; z = z1;
        var x1 = x * cos(ay) + z * sin(ay);
        z1 = -x * sin(ay) + z * cos(ay);
        x = x1; z = z1;
        x1 = x * cos(az) - y * sin(az);
        y1 = x * sin(az) + y * cos(az);
        x = x1; y = y1;

        final persp = 600 / (600 + s.z + z * s.size);
        final wx = s.x * size.width * 0.6 + x * s.size * 2.2;
        final wy = s.y * size.height * 0.5 + y * s.size * 2.2 +
            sin(t * .3 + i) * 20;
        pts.add(Offset(cx + wx * persp * 1.6, cy + wy * persp * 1.6));
      }
      final depthFade = (600 / (600 + s.z)).clamp(0.2, 1.0);
      paint.color = s.c.withOpacity((s.alpha * depthFade * 1.4).clamp(0.0, 1.0));
      for (final e in s.e) {
        canvas.drawLine(pts[e[0]], pts[e[1]], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WirePainter old) => false;
}
