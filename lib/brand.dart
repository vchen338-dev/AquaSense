import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'models.dart';
import 'theme.dart';

const kAppName = 'AmmoniaSense';
const kTagline = 'Smart water monitoring for your fish';

// ===========================================================================
// App logo: a water drop with a little fish inside
// ===========================================================================

class AppLogo extends StatelessWidget {
  final double size;
  final bool plate;
  const AppLogo({super.key, this.size = 96, this.plate = true});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LogoPainter(plate)),
    );
  }
}

class _LogoPainter extends CustomPainter {
  final bool plate;
  _LogoPainter(this.plate);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    if (plate) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(s * 0.24)),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(s, s),
            const [Color(0xFF38E0CF), Color(0xFF1F5FD6)],
          ),
      );
    }

    final c = Offset(s * 0.5, s * 0.60);
    final r = s * 0.25;
    final apex = Offset(s * 0.5, s * 0.17);
    final dist = (c - apex).distance;
    final cosA = r / dist;
    final sinA = sqrt(1 - cosA * cosA);
    final t1 = c + Offset(r * sinA, -r * cosA);
    final t2 = c + Offset(-r * sinA, -r * cosA);

    final tri = Path()
      ..moveTo(apex.dx, apex.dy)
      ..lineTo(t1.dx, t1.dy)
      ..lineTo(t2.dx, t2.dy)
      ..close();
    final circ = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    final drop = Path.combine(PathOperation.union, circ, tri);
    canvas.drawPath(
      drop,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, s * 0.17),
          Offset(0, s * 0.85),
          const [Colors.white, Color(0xFFCFF3FF)],
        ),
    );

    // fish
    const fish = Color(0xFF1E88D8);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(s * 0.53, s * 0.61), width: s * 0.25, height: s * 0.14),
      Paint()..color = fish,
    );
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.42, s * 0.61)
        ..lineTo(s * 0.33, s * 0.53)
        ..lineTo(s * 0.33, s * 0.69)
        ..close(),
      Paint()..color = fish,
    );
    canvas.drawCircle(
        Offset(s * 0.60, s * 0.595), s * 0.016, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(s * 0.57, s * 0.50), s * 0.016,
        Paint()..color = const Color(0xFF7FD8EE));
    canvas.drawCircle(Offset(s * 0.61, s * 0.455), s * 0.010,
        Paint()..color = const Color(0xFF7FD8EE));
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) => old.plate != plate;
}

// ===========================================================================
// Aqua - the friendly fish assistant
// ===========================================================================

enum AquaMood { happy, worried, alarmed }

AquaMood aquaMoodFor(Level l) {
  switch (l) {
    case Level.mid:
      return AquaMood.worried;
    case Level.high:
    case Level.fault:
      return AquaMood.alarmed;
    case Level.low:
    case Level.warmup:
      return AquaMood.happy;
  }
}

class AquaMascot extends StatefulWidget {
  final double size;
  final AquaMood mood;
  final bool animate;
  const AquaMascot({
    super.key,
    this.size = 80,
    this.mood = AquaMood.happy,
    this.animate = true,
  });

  @override
  State<AquaMascot> createState() => _AquaMascotState();
}

class _AquaMascotState extends State<AquaMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          painter: _MascotPainter(
            t: widget.animate ? _c.value : 0.1,
            mood: widget.mood,
          ),
        ),
      ),
    );
  }
}

class _MascotPainter extends CustomPainter {
  final double t;
  final AquaMood mood;
  _MascotPainter({required this.t, required this.mood});

  static const _ink = Color(0xFF0B1B2E);
  static const _blue = Color(0xFF2F7DE1);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    canvas.save();
    canvas.translate(0, sin(2 * pi * t) * s * 0.025);

    // tail
    canvas.save();
    canvas.translate(s * 0.20, s * 0.50);
    canvas.rotate(sin(2 * pi * t * 3) * 0.20);
    final tail = Path()
      ..moveTo(0, 0)
      ..cubicTo(-s * 0.10, -s * 0.24, -s * 0.26, -s * 0.22, -s * 0.20, 0)
      ..cubicTo(-s * 0.26, s * 0.22, -s * 0.10, s * 0.24, 0, 0);
    canvas.drawPath(tail, Paint()..color = _blue);
    canvas.restore();

    // top fin
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.40, s * 0.28)
        ..quadraticBezierTo(s * 0.52, s * 0.05, s * 0.68, s * 0.27)
        ..close(),
      Paint()..color = _blue,
    );

    // body
    final body = Rect.fromLTWH(s * 0.16, s * 0.22, s * 0.72, s * 0.58);
    canvas.drawOval(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
          body.topLeft,
          body.bottomRight,
          const [Color(0xFF7DF2E3), Color(0xFF3AA7E8), _blue],
          const [0.0, 0.55, 1.0],
        ),
    );
    canvas.drawOval(
      Rect.fromLTWH(s * 0.30, s * 0.55, s * 0.46, s * 0.19),
      Paint()..color = alpha(Colors.white, 0.22),
    );
    canvas.drawOval(
      Rect.fromLTWH(s * 0.28, s * 0.26, s * 0.30, s * 0.08),
      Paint()..color = alpha(Colors.white, 0.30),
    );

    // side fin
    canvas.save();
    canvas.translate(s * 0.46, s * 0.58);
    canvas.rotate(0.5 + sin(2 * pi * t * 3 + 1) * 0.2);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(-s * 0.05, 0), width: s * 0.17, height: s * 0.08),
      Paint()..color = alpha(_blue, 0.9),
    );
    canvas.restore();

    // cheek
    canvas.drawCircle(Offset(s * 0.60, s * 0.62), s * 0.04,
        Paint()..color = alpha(const Color(0xFFFF8FB8), 0.55));

    // eye
    final e = Offset(s * 0.67, s * 0.42);
    final er = s * 0.10;
    final blink = (t > 0.44 && t < 0.48) || (t > 0.82 && t < 0.85);
    if (blink) {
      canvas.drawLine(
        e.translate(-er * 0.8, 0),
        e.translate(er * 0.8, 0),
        Paint()
          ..color = _ink
          ..strokeWidth = s * 0.022
          ..strokeCap = StrokeCap.round,
      );
    } else {
      canvas.drawCircle(e, er, Paint()..color = Colors.white);
      final pr = mood == AquaMood.alarmed ? er * 0.40 : er * 0.58;
      canvas.drawCircle(e.translate(s * 0.015, s * 0.005), pr,
          Paint()..color = _ink);
      canvas.drawCircle(e.translate(s * 0.03, -s * 0.02), er * 0.22,
          Paint()..color = Colors.white);
    }

    // mood: mouth, brow, extras
    final m = Offset(s * 0.78, s * 0.585);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..color = _ink
      ..strokeWidth = s * 0.022
      ..strokeCap = StrokeCap.round;

    switch (mood) {
      case AquaMood.happy:
        canvas.drawArc(
          Rect.fromCenter(center: m, width: s * 0.13, height: s * 0.09),
          0.2,
          pi - 0.4,
          false,
          stroke,
        );
        // little bubbles
        for (var i = 0; i < 2; i++) {
          final p = (t * 2 + i * 0.5) % 1.0;
          canvas.drawCircle(
            Offset(s * 0.93 + sin(p * 6) * s * 0.01, s * 0.55 - p * s * 0.34),
            s * (0.018 + 0.008 * i),
            Paint()..color = alpha(Colors.white, 0.55 * (1 - p)),
          );
        }
        break;
      case AquaMood.worried:
        canvas.drawPath(
          Path()
            ..moveTo(m.dx - s * 0.05, m.dy + s * 0.015)
            ..quadraticBezierTo(
                m.dx, m.dy - s * 0.02, m.dx + s * 0.05, m.dy + s * 0.015),
          stroke,
        );
        canvas.drawLine(
          Offset(e.dx - er * 1.0, e.dy - er * 1.05),
          Offset(e.dx + er * 0.9, e.dy - er * 1.55),
          stroke,
        );
        break;
      case AquaMood.alarmed:
        canvas.drawOval(
          Rect.fromCenter(center: m, width: s * 0.065, height: s * 0.09),
          Paint()..color = _ink,
        );
        canvas.drawLine(
          Offset(e.dx - er * 1.0, e.dy - er * 1.1),
          Offset(e.dx + er * 0.9, e.dy - er * 1.6),
          stroke,
        );
        // sweat drop
        final dx = s * 0.80, dy = s * 0.20 + sin(2 * pi * t * 2) * s * 0.01;
        canvas.drawPath(
          Path()
            ..moveTo(dx, dy - s * 0.05)
            ..quadraticBezierTo(dx + s * 0.04, dy + s * 0.01, dx, dy + s * 0.035)
            ..quadraticBezierTo(dx - s * 0.04, dy + s * 0.01, dx, dy - s * 0.05),
          Paint()..color = const Color(0xFF9BE7F5),
        );
        break;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MascotPainter old) =>
      old.t != t || old.mood != mood;
}

// ===========================================================================
// Animated underwater background (connect screen)
// ===========================================================================

class WaveBackground extends StatefulWidget {
  final Widget child;
  const WaveBackground({super.key, required this.child});

  @override
  State<WaveBackground> createState() => _WaveBackgroundState();
}

class _WaveBackgroundState extends State<WaveBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) => CustomPaint(painter: _WavePainter(_c.value)),
          ),
        ),
        Positioned.fill(child: widget.child),
      ],
    );
  }
}

class _WavePainter extends CustomPainter {
  final double t;
  _WavePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, h),
          const [Color(0xFF0F3A5F), Color(0xFF0A1B30), Color(0xFF070F1D)],
          const [0.0, 0.6, 1.0],
        ),
    );

    // bubbles
    for (var i = 0; i < 12; i++) {
      final p = (t + i / 12) % 1.0;
      final x = w * ((i * 0.37 + 0.08) % 1.0) + sin(2 * pi * (t * 2 + i)) * 8;
      final y = h * (1.05 - 1.1 * p);
      final r = 2.0 + (i % 4) * 1.4;
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = alpha(Colors.white, 0.10 + 0.10 * (i % 3) / 2),
      );
    }

    // waves
    for (var i = 0; i < 3; i++) {
      final base = h * (0.80 + 0.045 * i);
      final amp = 9.0 + 4 * i;
      final dir = i.isEven ? 1 : -1;
      final path = Path()..moveTo(0, h);
      for (var x = 0.0; x <= w; x += 6) {
        final y = base +
            sin(x / w * 2 * pi * (1.2 + 0.4 * i) + 2 * pi * t * (i + 1) * dir) *
                amp;
        path.lineTo(x, y);
      }
      path
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = alpha(i == 0 ? kAccent : const Color(0xFF3A86FF),
              0.07 + 0.04 * i),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => old.t != t;
}
