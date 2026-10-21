import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'wire_background.dart';

/// "You're in." success screen with an animated ring + check mark.
class WelcomeScreen extends StatefulWidget {
  final User user;
  final VoidCallback onDone;
  const WelcomeScreen({super.key, required this.user, required this.onDone});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..forward();
  Timer? timer;
  bool done = false;

  void _finish() {
    if (done) return;
    done = true;
    widget.onDone();
  }

  @override
  void initState() {
    super.initState();
    timer = Timer(const Duration(milliseconds: 2600), _finish);
  }

  @override
  void dispose() {
    timer?.cancel();
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final who = widget.user.email ?? widget.user.phoneNumber ?? '';
    return Scaffold(
      body: Stack(children: [
        const Positioned.fill(child: WireBackground()),
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedBuilder(
              animation: ctrl,
              builder: (_, __) => CustomPaint(
                  size: const Size(110, 110), painter: _RingPainter(ctrl.value)),
            ),
            const SizedBox(height: 28),
            ShaderMask(
              shaderCallback: (r) => const LinearGradient(
                      colors: [Color(0xFFFF5CA8), Color(0xFF7C5CFF)])
                  .createShader(r),
              child: const Text("You're in.",
                  style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ),
            const SizedBox(height: 8),
            Text('Welcome to ONYX — signed in as $who',
                style: const TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _finish, child: const Text('Get started  →')),
          ]),
        ),
      ]),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double t;
  _RingPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 6;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF00E0FF);
    final p = Curves.easeOut.transform((t / 0.6).clamp(0.0, 1.0));
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -pi / 2, 2 * pi * p,
        false, ring);

    final ct = ((t - 0.55) / 0.45).clamp(0.0, 1.0);
    if (ct > 0) {
      final w = size.width, h = size.height;
      final path = Path()
        ..moveTo(w * .30, h * .52)
        ..lineTo(w * .45, h * .66)
        ..lineTo(w * .72, h * .38);
      for (final m in path.computeMetrics()) {
        canvas.drawPath(m.extractPath(0, m.length * ct), ring);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.t != t;
}
