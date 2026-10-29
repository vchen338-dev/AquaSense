import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'theme.dart';

enum FishType { betta, goldfish, guppy, neon, tilapia, shrimp, crayfish }

enum TankType { aquarium, pond }

extension TankInfo on TankType {
  String get label => this == TankType.pond ? 'Pond' : 'Aquarium';
  String get defaultName => this == TankType.pond ? 'My Pond' : 'My Aquarium';
}

extension FishInfo on FishType {
  String get label {
    switch (this) {
      case FishType.betta:
        return 'Betta';
      case FishType.goldfish:
        return 'Goldfish';
      case FishType.guppy:
        return 'Guppy';
      case FishType.neon:
        return 'Neon tetra';
      case FishType.tilapia:
        return 'Tilapia';
      case FishType.shrimp:
        return 'Shrimp';
      case FishType.crayfish:
        return 'Crayfish';
    }
  }

  double get minTemp {
    switch (this) {
      case FishType.betta:
        return 24;
      case FishType.goldfish:
        return 18;
      case FishType.guppy:
        return 22;
      case FishType.neon:
        return 22;
      case FishType.tilapia:
        return 26;
      case FishType.shrimp:
        return 24;
      case FishType.crayfish:
        return 18;
    }
  }

  double get maxTemp {
    switch (this) {
      case FishType.betta:
        return 28;
      case FishType.goldfish:
        return 23;
      case FishType.guppy:
        return 28;
      case FishType.neon:
        return 26;
      case FishType.tilapia:
        return 30;
      case FishType.shrimp:
        return 30;
      case FishType.crayfish:
        return 26;
    }
  }

  /// Word used in "How many ...".
  String get plural => switch (this) {
        FishType.shrimp => 'shrimp',
        FishType.crayfish => 'crayfish',
        _ => 'fish',
      };

  String get tempRange => '${minTemp.round()}-${maxTemp.round()} °C';

  List<Color> get palette {
    switch (this) {
      case FishType.betta:
        return const [
          Color(0xFFE63946),
          Color(0xFF3A86FF),
          Color(0xFF9B5DE5),
          Color(0xFF06D6A0),
          Color(0xFFFF8C42),
        ];
      case FishType.goldfish:
        return const [
          Color(0xFFFF8F1F),
          Color(0xFFE5383B),
          Color(0xFFF1F1F1),
          Color(0xFFFFC300),
          Color(0xFF3D405B),
        ];
      case FishType.guppy:
        return const [
          Color(0xFFFF5D8F),
          Color(0xFF4CC9F0),
          Color(0xFFF9C74F),
          Color(0xFF90BE6D),
          Color(0xFFB5179E),
        ];
      case FishType.neon:
        return const [
          Color(0xFF5AA9E6),
          Color(0xFF7BDFF2),
          Color(0xFFB8C0FF),
          Color(0xFFA0E7E5),
          Color(0xFFC3F0CA),
        ];
      case FishType.tilapia:
        return const [
          Color(0xFF9AA7B0),
          Color(0xFFE86A5A),
          Color(0xFFE0B24A),
          Color(0xFF8A9A5B),
          Color(0xFF4F5D63),
        ];
      case FishType.shrimp:
        return const [
          Color(0xFFE5533D),
          Color(0xFF5B8DEF),
          Color(0xFFE9C46A),
          Color(0xFF8AB17D),
          Color(0xFFB8B8C0),
        ];
      case FishType.crayfish:
        return const [
          Color(0xFFD1432F),
          Color(0xFF3D6FD8),
          Color(0xFF8B5E3C),
          Color(0xFF4F8F5B),
          Color(0xFFE08A2E),
        ];
    }
  }
}

/// User-customisable tank (saved on the phone).
class TankSettings extends ChangeNotifier {
  TankType type = TankType.aquarium;
  String tankName = 'My Aquarium';
  String fishName = 'Bubbles';
  FishType fish = FishType.betta;
  int colorIndex = 0;
  int count = 1;

  Color get color => fish.palette[colorIndex.clamp(0, 4)];

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final t = (p.getInt('tankType') ?? 0).clamp(0, TankType.values.length - 1);
      type = TankType.values[t];
      tankName = p.getString('tankName') ?? type.defaultName;
      fishName = p.getString('fishName') ?? fishName;
      final f = p.getInt('fish') ?? 0;
      fish = FishType.values[f.clamp(0, FishType.values.length - 1)];
      colorIndex = (p.getInt('colorIndex') ?? 0).clamp(0, 4);
      count = (p.getInt('count') ?? 1).clamp(1, kMaxCount);
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt('tankType', type.index);
      await p.setString('tankName', tankName);
      await p.setString('fishName', fishName);
      await p.setInt('fish', fish.index);
      await p.setInt('colorIndex', colorIndex);
      await p.setInt('count', count);
    } catch (_) {}
  }

  void update({
    TankType? type,
    String? tankName,
    String? fishName,
    FishType? fish,
    int? colorIndex,
    int? count,
  }) {
    if (type != null && type != this.type) {
      final wasDefault = this.tankName == this.type.defaultName;
      this.type = type;
      if (wasDefault) this.tankName = type.defaultName;
    }
    if (tankName != null) this.tankName = tankName;
    if (fishName != null) this.fishName = fishName;
    if (fish != null && fish != this.fish) {
      this.fish = fish;
      this.colorIndex = 0;
      if (fish == FishType.neon && this.count < 4) this.count = 5;
      if (fish == FishType.shrimp && this.count < 3) this.count = 3;
    }
    if (colorIndex != null) this.colorIndex = colorIndex;
    if (count != null) this.count = count.clamp(1, kMaxCount);
    notifyListeners();
    _save();
  }
}

final TankSettings tank = TankSettings();

/// Most animals the user can enter (any number up to this is allowed).
const int kMaxCount = 9999;

/// Only this many are drawn and animated so the app stays smooth.
const int kMaxDrawn = 16;

// ===========================================================================
// Animated aquarium
// ===========================================================================

class AquariumView extends StatefulWidget {
  final Level level;
  const AquariumView({super.key, required this.level});

  @override
  State<AquariumView> createState() => _AquariumViewState();
}

class _AquariumViewState extends State<AquariumView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tank,
      builder: (_, __) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          painter: AquariumPainter(
            t: _c.value,
            level: widget.level,
            type: tank.fish,
            color: tank.color,
            count: min(tank.count, kMaxDrawn),
            pond: tank.type == TankType.pond,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class AquariumPainter extends CustomPainter {
  final double t; // 0..1, loops every 24 s
  final Level level;
  final FishType type;
  final Color color;
  final int count;
  final bool pond;

  AquariumPainter({
    required this.t,
    required this.level,
    required this.type,
    required this.color,
    required this.count,
    required this.pond,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;

    // ---- water -----------------------------------------------------------
    Color top, bottom;
    if (pond) {
      switch (level) {
        case Level.high:
          top = const Color(0xFF8A7A3A);
          bottom = const Color(0xFF3A2E14);
          break;
        case Level.mid:
          top = const Color(0xFF5E8F3F);
          bottom = const Color(0xFF22371A);
          break;
        default:
          top = const Color(0xFF2F7C6A);
          bottom = const Color(0xFF0E2B24);
      }
    } else {
      switch (level) {
        case Level.high:
          top = const Color(0xFF8A8A3A);
          bottom = const Color(0xFF3A3A1C);
          break;
        case Level.mid:
          top = const Color(0xFF3F8A78);
          bottom = const Color(0xFF173B36);
          break;
        default:
          top = const Color(0xFF1E6F95);
          bottom = const Color(0xFF08243D);
      }
    }
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          Offset(0, h),
          [top, bottom],
        ),
    );

    // ---- light rays ------------------------------------------------------
    for (var i = 0; i < 4; i++) {
      final sway = sin(2 * pi * (t * 1 + i * 0.25)) * 14;
      final x = w * (0.12 + i * 0.26) + sway;
      final p = Path()
        ..moveTo(x, 0)
        ..lineTo(x + 46, 0)
        ..lineTo(x + 46 - 70, h)
        ..lineTo(x - 70, h)
        ..close();
      canvas.drawPath(
        p,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(x, 0),
            Offset(x - 40, h),
            [alpha(Colors.white, 0.10), alpha(Colors.white, 0.0)],
          ),
      );
    }

    // ---- plants / reeds (back) --------------------------------------------
    if (pond) {
      _plant(canvas, w * 0.06, h, h * 0.62, const Color(0xFF3F8F52), 0.0);
      _plant(canvas, w * 0.13, h, h * 0.40, const Color(0xFF4FA463), 0.3);
      _plant(canvas, w * 0.93, h, h * 0.58, const Color(0xFF3F8F52), 0.6);
    } else {
      _plant(canvas, w * 0.10, h, h * 0.42, const Color(0xFF2FA37A), 0.0);
      _plant(canvas, w * 0.17, h, h * 0.30, const Color(0xFF3CC08F), 0.3);
      _plant(canvas, w * 0.90, h, h * 0.38, const Color(0xFF2FA37A), 0.6);
    }

    // ---- swimmers --------------------------------------------------------
    for (var i = 0; i < count; i++) {
      final phase = i / count;
      if (type == FishType.crayfish) {
        final ang = 2 * pi * (t * 0.7 + phase);
        final x = w * 0.5 + w * 0.34 * sin(ang);
        final y = h * 0.84 + (i % 3) * h * 0.025;
        final right = cos(ang) >= 0;
        final s = w * 0.24 * (1 - 0.05 * (i % 4));
        final c = i > 0 ? Color.lerp(color, Colors.white, 0.05 * (i % 4))! : color;
        _crayfish(canvas, Offset(x, y), s, right, 2 * pi * t * 30 + i, c);
        continue;
      }
      if (type == FishType.shrimp) {
        final ang = 2 * pi * (t + phase);
        final x = w * 0.5 + w * 0.34 * sin(ang);
        final y = h * 0.835 + (i % 2) * h * 0.03 + sin(ang * 6).abs() * 2.0;
        final right = cos(ang) >= 0;
        final s = w * 0.17 * (1 - 0.06 * (i % 4));
        final c = i > 0 ? Color.lerp(color, Colors.white, 0.06 * (i % 4))! : color;
        _shrimp(canvas, Offset(x, y), s, right, 2 * pi * t * 40 + i, c);
        continue;
      }
      final speed = type == FishType.neon ? 2 : 1;
      final ang = 2 * pi * (t * speed + phase);
      final amp = w * (type == FishType.neon ? 0.30 : 0.34);
      final lane = 0.30 + 0.13 * (i % 4);
      final x = w * 0.5 + amp * sin(ang);
      final y = h * lane + sin(ang * 2) * 7;
      final right = cos(ang) >= 0;
      final base = switch (type) {
        FishType.betta => 0.30,
        FishType.goldfish => 0.27,
        FishType.guppy => 0.19,
        FishType.neon => 0.13,
        FishType.tilapia => 0.32,
        FishType.shrimp => 0.17,
        FishType.crayfish => 0.24,
      };
      final s = w * base * (1 - 0.055 * (i % 6));
      final wag = sin(2 * pi * t * 36 + i);
      final c = count > 1 && type != FishType.neon && i > 0
          ? Color.lerp(color, Colors.white, 0.07 * (i % 5))!
          : color;
      _fish(canvas, Offset(x, y), s, right, wag, c);
    }

    // ---- bottom: sand (aquarium) or mud + rocks (pond) ------------------------
    final floor = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.90);
    for (var x = 0.0; x <= w; x += 8) {
      floor.lineTo(x, h * 0.90 + sin(x / 38) * 4);
    }
    floor
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(
      floor,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, h * 0.88),
          Offset(0, h),
          pond
              ? [const Color(0xFF7A6644), const Color(0xFF3F3322)]
              : [const Color(0xFFC9B58C), const Color(0xFF8E7B57)],
        ),
    );
    if (pond) {
      _rock(canvas, w * 0.30, h * 0.93, 15, const Color(0xFF7D8590));
      _rock(canvas, w * 0.37, h * 0.95, 10, const Color(0xFF9199A3));
      _rock(canvas, w * 0.74, h * 0.94, 18, const Color(0xFF6C747E));
      _rock(canvas, w * 0.83, h * 0.96, 11, const Color(0xFF8A929C));
    } else {
      _plant(canvas, w * 0.80, h * 0.93, h * 0.22, const Color(0xFF4FD6A0), 0.9);
      _plant(canvas, w * 0.27, h * 0.93, h * 0.18, const Color(0xFF4FD6A0), 0.5);
    }

    // ---- bubbles ---------------------------------------------------------
    for (var i = 0; i < 8; i++) {
      final p = (t * 3 + i / 8) % 1.0;
      final bx = w * (0.08 + 0.84 * ((i * 0.37) % 1.0)) +
          sin(2 * pi * (t * 6 + i)) * 5;
      final by = h * 0.88 - (h * 0.82) * p;
      final r = 2.0 + (i % 3) * 1.6;
      canvas.drawCircle(
        Offset(bx, by),
        r,
        Paint()..color = alpha(Colors.white, 0.35 * (1 - p * 0.6)),
      );
      canvas.drawCircle(
        Offset(bx, by),
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = alpha(Colors.white, 0.5 * (1 - p * 0.6)),
      );
    }

    // ---- surface shimmer -------------------------------------------------
    final shimmer = Path()..moveTo(0, 0);
    for (var x = 0.0; x <= w; x += 6) {
      shimmer.lineTo(x, 6 + sin(x / 22 + 2 * pi * t * 2) * 2.5);
    }
    shimmer
      ..lineTo(w, 0)
      ..close();
    canvas.drawPath(shimmer, Paint()..color = alpha(Colors.white, 0.10));

    // ---- lily pads (pond) ------------------------------------------------
    if (pond) {
      for (var j = 0; j < 4; j++) {
        final px = w * (0.16 + 0.23 * j) + sin(2 * pi * (t + j * 0.25)) * 6;
        canvas.drawOval(
          Rect.fromCenter(center: Offset(px, 8), width: 58, height: 10),
          Paint()..color = const Color(0xFF3E9B4F),
        );
        canvas.drawOval(
          Rect.fromCenter(center: Offset(px - 4, 6.5), width: 34, height: 4),
          Paint()..color = alpha(Colors.white, 0.18),
        );
        if (j == 1) {
          canvas.drawCircle(
              Offset(px + 6, 4), 5.5, Paint()..color = const Color(0xFFFF8FB8));
          canvas.drawCircle(
              Offset(px + 6, 4), 2.2, Paint()..color = const Color(0xFFFFE066));
        }
      }
    }
  }

  void _rock(Canvas canvas, double x, double y, double r, Color c) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, y), width: r * 2.2, height: r * 1.4),
      Paint()..color = c,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(x - r * 0.3, y - r * 0.25),
          width: r * 1.0,
          height: r * 0.5),
      Paint()..color = alpha(Colors.white, 0.14),
    );
  }

  void _plant(Canvas canvas, double x, double baseY, double len, Color c,
      double phase) {
    for (var k = 0; k < 3; k++) {
      final off = (k - 1) * 9.0;
      final sway = sin(2 * pi * (t * 2 + phase + k * 0.2)) * 12;
      final p = Path()
        ..moveTo(x + off, baseY)
        ..quadraticBezierTo(
          x + off + sway,
          baseY - len * 0.55,
          x + off + sway * 1.6,
          baseY - len * (0.85 + 0.08 * k),
        );
      canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = (6 - k).toDouble()
          ..color = alpha(Color.lerp(c, Colors.black, 0.12 * k)!, 0.95),
      );
    }
  }

  // --------------------------------------------------------------- shrimp
  void _shrimp(Canvas canvas, Offset pos, double s, bool right, double phase,
      Color c) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    if (!right) canvas.scale(-1, 1);

    final light = Color.lerp(c, Colors.white, 0.30)!;
    final dark = Color.lerp(c, Colors.black, 0.35)!;

    final p0 = Offset(s * 0.38, 0);
    final p1 = Offset(-s * 0.02, -s * 0.62);
    final p2 = Offset(-s * 0.40, s * 0.08);

    Offset bez(double u) {
      final a = (1 - u) * (1 - u), b = 2 * (1 - u) * u, d = u * u;
      return Offset(
        a * p0.dx + b * p1.dx + d * p2.dx,
        a * p0.dy + b * p1.dy + d * p2.dy,
      );
    }

    // legs (behind body)
    for (var k = 0; k < 5; k++) {
      final q = bez(0.22 + k * 0.12);
      canvas.drawLine(
        q.translate(0, s * 0.06),
        q.translate(sin(phase + k * 1.3) * s * 0.035, s * 0.15),
        Paint()
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..color = alpha(dark, 0.9),
      );
    }

    // tail fan
    final tdir = atan2(p2.dy - p1.dy, p2.dx - p1.dx);
    canvas.save();
    canvas.translate(p2.dx, p2.dy);
    for (var k = -1; k <= 1; k++) {
      canvas.save();
      canvas.rotate(tdir + k * 0.55 + sin(phase * 0.5) * 0.08);
      canvas.drawOval(
        Rect.fromLTWH(0, -s * 0.045, s * 0.20, s * 0.09),
        Paint()..color = alpha(light, 0.9),
      );
      canvas.restore();
    }
    canvas.restore();

    // body
    final body = Path()
      ..moveTo(p0.dx, p0.dy)
      ..quadraticBezierTo(p1.dx, p1.dy, p2.dx, p2.dy);
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = s * 0.20
        ..color = c,
    );
    canvas.drawPath(
      body.shift(Offset(0, -s * 0.045)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = s * 0.07
        ..color = alpha(light, 0.55),
    );

    // segment lines
    for (var u = 0.18; u < 0.9; u += 0.14) {
      final q = bez(u);
      final a = bez(u - 0.01), b = bez(u + 0.01);
      final tx = b.dx - a.dx, ty = b.dy - a.dy;
      final len = sqrt(tx * tx + ty * ty);
      if (len == 0) continue;
      final nx = -ty / len, ny = tx / len;
      canvas.drawLine(
        q.translate(nx * s * 0.10, ny * s * 0.10),
        q.translate(-nx * s * 0.10, -ny * s * 0.10),
        Paint()
          ..strokeWidth = 1.6
          ..color = alpha(dark, 0.55),
      );
    }

    // head
    canvas.drawCircle(p0, s * 0.12, Paint()..color = light);
    final rostrum = Path()
      ..moveTo(p0.dx + s * 0.07, p0.dy - s * 0.07)
      ..lineTo(p0.dx + s * 0.22, p0.dy - s * 0.13)
      ..lineTo(p0.dx + s * 0.10, p0.dy - s * 0.01)
      ..close();
    canvas.drawPath(rostrum, Paint()..color = alpha(c, 0.9));

    // antennae
    for (var k = 0; k < 2; k++) {
      final wave = sin(phase * 0.15 + k) * s * 0.04;
      final a = Path()
        ..moveTo(p0.dx + s * 0.05, p0.dy - s * 0.05)
        ..quadraticBezierTo(
          p0.dx + s * 0.35,
          p0.dy - s * (0.30 + 0.10 * k) + wave,
          p0.dx + s * (0.60 - 0.10 * k),
          p0.dy - s * (0.20 + 0.14 * k) - wave,
        );
      canvas.drawPath(
        a,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round
          ..color = alpha(light, 0.85),
      );
    }

    // eye
    final ec = p0.translate(s * 0.05, -s * 0.04);
    canvas.drawCircle(ec, s * 0.04, Paint()..color = const Color(0xFF101820));
    canvas.drawCircle(ec.translate(s * 0.012, -s * 0.012), s * 0.012,
        Paint()..color = Colors.white);

    canvas.restore();
  }

  // ------------------------------------------------------------- crayfish
  void _oval(Canvas canvas, Offset c, double w, double h, double rot, Paint p) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rot);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: w, height: h), p);
    canvas.restore();
  }

  void _claw(Canvas canvas, double s, Offset shoulder, Offset elbow, Color c,
      Color dark, double open) {
    // arm
    canvas.drawLine(
      shoulder,
      elbow,
      Paint()
        ..strokeWidth = s * 0.07
        ..strokeCap = StrokeCap.round
        ..color = dark,
    );
    // palm
    final palm = elbow.translate(s * 0.09, -s * 0.03);
    _oval(canvas, palm, s * 0.20, s * 0.12, -0.35, Paint()..color = c);
    // two fingers that open and close
    final tip = palm.translate(s * 0.12, -s * 0.045);
    _oval(canvas, tip.translate(0, -s * 0.012), s * 0.16, s * 0.045,
        -0.45 - open, Paint()..color = c);
    _oval(canvas, tip.translate(0, s * 0.020), s * 0.16, s * 0.045,
        -0.05 + open, Paint()..color = Color.lerp(c, Colors.black, 0.12)!);
  }

  void _crayfish(Canvas canvas, Offset pos, double s, bool right, double phase,
      Color c) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    if (!right) canvas.scale(-1, 1);

    final light = Color.lerp(c, Colors.white, 0.28)!;
    final dark = Color.lerp(c, Colors.black, 0.32)!;
    final open = 0.14 + 0.12 * sin(phase * 0.12);

    // far claw (behind the body)
    _claw(canvas, s, Offset(s * 0.20, s * 0.05), Offset(s * 0.34, s * 0.0),
        Color.lerp(c, Colors.black, 0.18)!, dark, open * 0.8);

    // walking legs
    for (var k = 0; k < 4; k++) {
      final x = s * (0.18 - k * 0.09);
      canvas.drawLine(
        Offset(x, s * 0.07),
        Offset(x + sin(phase + k * 1.4) * s * 0.05, s * 0.21),
        Paint()
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round
          ..color = alpha(dark, 0.95),
      );
    }

    // tail fan
    for (var k = -1; k <= 1; k++) {
      _oval(canvas, Offset(-s * 0.52, k * s * 0.045 + s * 0.02), s * 0.17,
          s * 0.07, k * 0.45 + sin(phase * 0.2) * 0.05, Paint()..color = light);
    }

    // abdomen segments
    for (var k = 0; k < 5; k++) {
      final x = -s * 0.14 - k * s * 0.075;
      _oval(canvas, Offset(x, s * 0.01), s * 0.11, s * (0.21 - 0.022 * k), 0,
          Paint()..color = k.isEven ? c : Color.lerp(c, Colors.black, 0.10)!);
    }

    // carapace
    _oval(canvas, Offset(s * 0.10, -s * 0.01), s * 0.48, s * 0.27, 0,
        Paint()..color = c);
    _oval(canvas, Offset(s * 0.07, -s * 0.07), s * 0.30, s * 0.08, 0,
        Paint()..color = alpha(light, 0.6));

    // rostrum
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.30, -s * 0.07)
        ..lineTo(s * 0.43, -s * 0.02)
        ..lineTo(s * 0.30, s * 0.03)
        ..close(),
      Paint()..color = dark,
    );

    // antennae
    for (var k = 0; k < 2; k++) {
      final wave = sin(phase * 0.1 + k * 1.7) * s * 0.04;
      final a = Path()
        ..moveTo(s * 0.32, -s * 0.06)
        ..quadraticBezierTo(
          s * (0.50 + 0.08 * k),
          -s * (0.26 + 0.06 * k) + wave,
          s * (0.72 - 0.08 * k),
          -s * (0.30 - 0.12 * k) - wave,
        );
      canvas.drawPath(
        a,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round
          ..color = alpha(light, 0.9),
      );
    }

    // near claw (in front)
    _claw(canvas, s, Offset(s * 0.22, s * 0.03), Offset(s * 0.38, -s * 0.06), c,
        dark, open);

    // eye
    final ec = Offset(s * 0.29, -s * 0.11);
    canvas.drawCircle(ec, s * 0.032, Paint()..color = const Color(0xFF101820));
    canvas.drawCircle(ec.translate(s * 0.010, -s * 0.010), s * 0.010,
        Paint()..color = Colors.white);

    canvas.restore();
  }

  // ----------------------------------------------------------------- fish
  void _fish(Canvas canvas, Offset pos, double s, bool right, double wag,
      Color c) {
    late double bh, tailL, tailH, dorsal, belly;
    switch (type) {
      case FishType.betta:
        bh = 0.36;
        tailL = 0.78;
        tailH = 0.62;
        dorsal = 0.32;
        belly = 0.40;
        break;
      case FishType.goldfish:
        bh = 0.62;
        tailL = 0.55;
        tailH = 0.50;
        dorsal = 0.22;
        belly = 0.16;
        break;
      case FishType.guppy:
        bh = 0.32;
        tailL = 0.62;
        tailH = 0.48;
        dorsal = 0.20;
        belly = 0.10;
        break;
      case FishType.neon:
        bh = 0.26;
        tailL = 0.36;
        tailH = 0.26;
        dorsal = 0.12;
        belly = 0.08;
        break;
      case FishType.tilapia:
      case FishType.shrimp:
      case FishType.crayfish:
        bh = 0.50;
        tailL = 0.46;
        tailH = 0.46;
        dorsal = 0.26;
        belly = 0.14;
        break;
    }

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    if (!right) canvas.scale(-1, 1);

    final light = Color.lerp(c, Colors.white, 0.28)!;
    final dark = Color.lerp(c, Colors.black, 0.30)!;
    final bodyRect = Rect.fromCenter(
      center: Offset.zero,
      width: s,
      height: s * bh,
    );

    // tail (behind body)
    final ax = -s * 0.42;
    final tl = s * tailL, th = s * tailH;
    final tail = Path()
      ..moveTo(0, 0)
      ..cubicTo(-tl * 0.35, -th * 0.95, -tl * 1.05, -th * 0.75, -tl * 0.95, 0)
      ..cubicTo(-tl * 1.05, th * 0.75, -tl * 0.35, th * 0.95, 0, 0);
    canvas.save();
    canvas.translate(ax, 0);
    canvas.rotate(wag * 0.30);
    canvas.drawPath(
      tail,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(-tl, 0),
          [alpha(c, 0.95), alpha(light, 0.55)],
        ),
    );
    canvas.restore();

    // dorsal + belly fins
    final dorsalSpan = type == FishType.tilapia ? 0.30 : 0.18;
    final dorsalFin = Path()
      ..moveTo(-s * dorsalSpan, -s * bh * 0.42)
      ..quadraticBezierTo(
        -s * 0.02,
        -s * (bh * 0.5 + dorsal) * 1.1,
        s * (dorsalSpan * 0.9),
        -s * bh * 0.42,
      )
      ..close();
    canvas.drawPath(dorsalFin, Paint()..color = alpha(dark, 0.9));
    final bellyFin = Path()
      ..moveTo(-s * 0.02, s * bh * 0.42)
      ..quadraticBezierTo(
        -s * 0.24,
        s * (bh * 0.5 + belly) * 1.1,
        -s * 0.34,
        s * bh * 0.36,
      )
      ..close();
    canvas.drawPath(bellyFin, Paint()..color = alpha(dark, 0.85));

    // body
    final bodyPath = Path()..addOval(bodyRect);
    canvas.drawPath(
      bodyPath,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, -s * bh / 2),
          Offset(0, s * bh / 2),
          [light, c, dark],
          [0.0, 0.5, 1.0],
        ),
    );

    // species details
    if (type == FishType.neon) {
      canvas.save();
      canvas.clipPath(bodyPath);
      canvas.drawRect(
        Rect.fromLTRB(-s * 0.52, s * 0.01, -s * 0.02, s * bh),
        Paint()..color = const Color(0xFFE53935),
      );
      canvas.drawRect(
        Rect.fromLTRB(-s * 0.40, -s * 0.045, s * 0.42, s * 0.015),
        Paint()..color = const Color(0xFF3FE8FF),
      );
      canvas.restore();
    } else if (type == FishType.goldfish) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(-s * 0.02, -s * bh * 0.22),
          width: s * 0.55,
          height: s * bh * 0.28,
        ),
        Paint()..color = alpha(Colors.white, 0.18),
      );
    } else if (type == FishType.tilapia) {
      canvas.save();
      canvas.clipPath(bodyPath);
      for (var k = 0; k < 4; k++) {
        canvas.drawRect(
          Rect.fromLTRB(-s * (0.30 - k * 0.12), -s * bh,
              -s * (0.26 - k * 0.12), s * bh),
          Paint()..color = alpha(Colors.black, 0.14),
        );
      }
      canvas.restore();
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, -s * bh * 0.2),
          width: s * 0.6,
          height: s * bh * 0.18,
        ),
        Paint()..color = alpha(Colors.white, 0.16),
      );
    } else {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, -s * bh * 0.2),
          width: s * 0.6,
          height: s * bh * 0.2,
        ),
        Paint()..color = alpha(Colors.white, 0.16),
      );
    }

    // pectoral fin
    canvas.save();
    canvas.translate(s * 0.10, s * bh * 0.10);
    canvas.rotate(-0.5 + wag * 0.25);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(-s * 0.07, 0), width: s * 0.2, height: s * 0.09),
      Paint()..color = alpha(light, 0.8),
    );
    canvas.restore();

    // eye
    final er = s * (type == FishType.neon ? 0.065 : 0.055);
    final ec = Offset(s * 0.30, -s * bh * 0.10);
    canvas.drawCircle(ec, er, Paint()..color = Colors.white);
    canvas.drawCircle(ec.translate(er * 0.2, 0), er * 0.58,
        Paint()..color = const Color(0xFF101820));
    canvas.drawCircle(ec.translate(er * 0.35, -er * 0.3), er * 0.2,
        Paint()..color = Colors.white);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant AquariumPainter old) => true;
}

// ===========================================================================
// Customiser (used on Home bottom-sheet and in Settings)
// ===========================================================================

class FishCustomizer extends StatefulWidget {
  const FishCustomizer({super.key});

  @override
  State<FishCustomizer> createState() => _FishCustomizerState();
}

class _FishCustomizerState extends State<FishCustomizer> {
  late final TextEditingController _tank =
      TextEditingController(text: tank.tankName);
  late final TextEditingController _fish =
      TextEditingController(text: tank.fishName);

  late final TextEditingController _count =
      TextEditingController(text: '${tank.count}');
  final FocusNode _countFocus = FocusNode();

  @override
  void dispose() {
    _tank.dispose();
    _fish.dispose();
    _count.dispose();
    _countFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tank,
      builder: (context, _) {
        if (!_countFocus.hasFocus && _count.text != '${tank.count}') {
          _count.text = '${tank.count}';
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Type',
                style: TextStyle(color: kMuted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<TankType>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                      value: TankType.aquarium,
                      icon: Icon(Icons.crop_square_rounded),
                      label: Text('Aquarium')),
                  ButtonSegment(
                      value: TankType.pond,
                      icon: Icon(Icons.water_rounded),
                      label: Text('Pond')),
                ],
                selected: {tank.type},
                onSelectionChanged: (v) {
                  tank.update(type: v.first);
                  _tank.text = tank.tankName;
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tank,
                    decoration: InputDecoration(labelText: '${tank.type.label} name'),
                    onChanged: (v) => tank.update(
                        tankName: v.trim().isEmpty ? tank.type.defaultName : v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _fish,
                    decoration: const InputDecoration(labelText: 'Fish name'),
                    onChanged: (v) =>
                        tank.update(fishName: v.trim().isEmpty ? 'Fish' : v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text('Species',
                style: TextStyle(color: kMuted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in FishType.values)
                  ChoiceChip(
                    label: Text(f.label),
                    selected: tank.fish == f,
                    onSelected: (_) => tank.update(fish: f),
                    selectedColor: alpha(kAccent, 0.25),
                    backgroundColor: kSurface2,
                    side: BorderSide.none,
                  ),
              ],
            ),
            const SizedBox(height: 18),
            const Text('Colour',
                style: TextStyle(color: kMuted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(
              children: [
                for (var i = 0; i < 5; i++)
                  GestureDetector(
                    onTap: () => tank.update(colorIndex: i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 12),
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: tank.fish.palette[i],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: tank.colorIndex == i
                              ? Colors.white
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Text('How many ${tank.fish.plural}',
                    style: const TextStyle(
                        color: kMuted, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton.filledTonal(
                  onPressed: tank.count > 1
                      ? () => tank.update(count: tank.count - 1)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                SizedBox(
                  width: 78,
                  child: TextField(
                    controller: _count,
                    focusNode: _countFocus,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                    ),
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null && n > 0) tank.update(count: n);
                    },
                    onSubmitted: (_) => _count.text = '${tank.count}',
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: tank.count < kMaxCount
                      ? () => tank.update(count: tank.count + 1)
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final n in const [10, 50, 100, 500])
                  ActionChip(
                    label: Text('+$n'),
                    onPressed: () {
                      _countFocus.unfocus();
                      tank.update(count: tank.count + n);
                    },
                    backgroundColor: kSurface2,
                    side: BorderSide.none,
                  ),
                ActionChip(
                  label: const Text('Reset to 1'),
                  onPressed: () {
                    _countFocus.unfocus();
                    tank.update(count: 1);
                  },
                  backgroundColor: kSurface2,
                  side: BorderSide.none,
                ),
              ],
            ),
            if (tank.count > kMaxDrawn) ...[
              const SizedBox(height: 8),
              Text(
                'You can keep up to $kMaxCount. The picture shows $kMaxDrawn '
                'so it stays smooth, the app remembers all ${tank.count}.',
                style: const TextStyle(
                    color: kMuted, fontSize: 12.5, height: 1.4),
              ),
            ],
          ],
        );
      },
    );
  }
}
