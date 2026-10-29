import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../esp_service.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();

  Map<DateTime, List<Reading>> _byDay() {
    final m = <DateTime, List<Reading>>{};
    for (final r in esp.readings) {
      (m[dateOnly(r.time)] ??= []).add(r);
    }
    return m;
  }

  Level _worst(List<Reading> list) {
    var w = Level.low;
    for (final r in list) {
      if (r.level == Level.high) return Level.high;
      if (r.level == Level.mid) w = Level.mid;
      if (r.level == Level.fault && w == Level.low) w = Level.fault;
    }
    return w;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: esp,
        builder: (context, _) {
          final byDay = _byDay();
          final dayList = [...(byDay[dateOnly(_selected)] ?? <Reading>[])]
            ..sort((a, b) => a.epoch - b.epoch);
          final latest = esp.readings.isEmpty ? null : esp.readings.last;
          final high = esp.data?.high ?? 2200;
          final mid = esp.data?.mid ?? 1200;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Records',
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w800)),
                  ),
                  esp.syncing
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                              width: 22,
                              height: 22,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.5)),
                        )
                      : IconButton.filledTonal(
                          onPressed: esp.demo ? null : esp.syncHistory,
                          style:
                              IconButton.styleFrom(backgroundColor: kSurface2),
                          icon: const Icon(Icons.sync_rounded),
                          tooltip: 'Sync from device',
                        ),
                ],
              ),
              Text(
                'A reading is saved every 30 minutes'
                '${esp.lastSync != null ? ' · synced ${DateFormat('HH:mm').format(esp.lastSync!)}' : ''}',
                style: const TextStyle(color: kMuted, fontSize: 13),
              ),
              const SizedBox(height: 18),

              _LatestCard(latest: latest, mid: mid, high: high),
              const SizedBox(height: 16),

              // ---- calendar --------------------------------------------------
              AppCard(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
                child: TableCalendar<Reading>(
                  firstDay: DateTime(2024, 1, 1),
                  lastDay: DateTime.now().add(const Duration(days: 365)),
                  focusedDay: _focused,
                  selectedDayPredicate: (d) => isSameDay(d, _selected),
                  onDaySelected: (s, f) => setState(() {
                    _selected = s;
                    _focused = f;
                  }),
                  onPageChanged: (f) => _focused = f,
                  calendarFormat: CalendarFormat.month,
                  availableCalendarFormats: const {
                    CalendarFormat.month: 'Month'
                  },
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  eventLoader: (d) => byDay[dateOnly(d)] ?? const [],
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    leftChevronIcon:
                        Icon(Icons.chevron_left_rounded, color: kText),
                    rightChevronIcon:
                        Icon(Icons.chevron_right_rounded, color: kText),
                  ),
                  daysOfWeekStyle: const DaysOfWeekStyle(
                    weekdayStyle: TextStyle(color: kMuted, fontSize: 12),
                    weekendStyle: TextStyle(color: kMuted, fontSize: 12),
                  ),
                  calendarStyle: CalendarStyle(
                    defaultTextStyle: const TextStyle(color: kText),
                    weekendTextStyle: const TextStyle(color: kText),
                    outsideTextStyle:
                        TextStyle(color: alpha(kMuted, 0.4)),
                    todayDecoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: kAccent),
                    ),
                    todayTextStyle: const TextStyle(color: kText),
                    selectedDecoration: const BoxDecoration(
                      color: kAccent,
                      shape: BoxShape.circle,
                    ),
                    selectedTextStyle: const TextStyle(
                        color: Color(0xFF06101F), fontWeight: FontWeight.w800),
                    markersMaxCount: 1,
                  ),
                  calendarBuilders: CalendarBuilders<Reading>(
                    markerBuilder: (context, day, events) {
                      if (events.isEmpty) return null;
                      return Positioned(
                        bottom: 4,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: levelColor(_worst(events.cast<Reading>())),
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // ---- selected day ----------------------------------------------
              SectionTitle(
                DateFormat('EEEE, MMM d').format(_selected).toUpperCase(),
                trailing: Text('${dayList.length} records',
                    style: const TextStyle(color: kMuted, fontSize: 12)),
              ),
              if (dayList.isEmpty)
                AppCard(
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      children: [
                        const Icon(Icons.event_busy_rounded,
                            color: kMuted, size: 30),
                        const SizedBox(height: 8),
                        const Text('No records on this day',
                            style: TextStyle(color: kMuted)),
                      ],
                    ),
                  ),
                )
              else ...[
                AppCard(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 150,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _DayChartPainter(dayList, mid, high),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('00:00',
                              style: TextStyle(color: kMuted, fontSize: 11)),
                          Text('12:00',
                              style: TextStyle(color: kMuted, fontSize: 11)),
                          Text('24:00',
                              style: TextStyle(color: kMuted, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      for (final r in dayList.reversed)
                        _RecordRow(r: r, high: high),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(6, 10, 6, 0),
                  child: Text(
                    'Temperature shown is inside the sensor box, not the water.',
                    style: TextStyle(color: kMuted, fontSize: 12),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _LatestCard extends StatelessWidget {
  final Reading? latest;
  final int mid;
  final int high;
  const _LatestCard(
      {required this.latest, required this.mid, required this.high});

  @override
  Widget build(BuildContext context) {
    final d = esp.data;
    String next = '--:--';
    if (d != null && d.epoch > 0) {
      final rem = 1800 - (d.epoch % 1800);
      next =
          '${(rem ~/ 60).toString().padLeft(2, '0')}:${(rem % 60).toString().padLeft(2, '0')}';
    }
    final r = latest;
    final color = r == null ? kMuted : levelColor(r.level);
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('LATEST RECORD',
                    style: TextStyle(
                        color: kMuted,
                        fontSize: 11,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (r == null)
                  const Text('Nothing yet',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w800))
                else ...[
                  Row(
                    children: [
                      Text('${ammoniaIndex(r.raw, high: high)}',
                          style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: color)),
                      const SizedBox(width: 8),
                      StatusPill(text: levelLabel(r.level), color: color),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(DateFormat('EEE, MMM d · HH:mm').format(r.time),
                      style: const TextStyle(color: kMuted, fontSize: 12.5)),
                ],
              ],
            ),
          ),
          Container(
              width: 1, height: 64, color: alpha(Colors.white, 0.08)),
          const SizedBox(width: 18),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('NEXT IN',
                  style: TextStyle(
                      color: kMuted,
                      fontSize: 11,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(next,
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('min : sec',
                  style: TextStyle(color: kMuted, fontSize: 12.5)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  final Reading r;
  final int high;
  const _RecordRow({required this.r, required this.high});

  @override
  Widget build(BuildContext context) {
    final color = levelColor(r.level);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(DateFormat('HH:mm').format(r.time),
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 15)),
          ),
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              levelLabel(r.level),
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
          Text('NH₃ ${ammoniaIndex(r.raw, high: high)}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 14),
          SizedBox(
            width: 52,
            child: Text(
              r.temp == null ? '--' : '${r.temp!.toStringAsFixed(1)}°C',
              textAlign: TextAlign.right,
              style: const TextStyle(color: kMuted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayChartPainter extends CustomPainter {
  final List<Reading> list;
  final int mid;
  final int high;
  _DayChartPainter(this.list, this.mid, this.high);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    double yFor(int idx) => h - (idx / 100) * h;

    // grid
    final grid = Paint()
      ..color = alpha(Colors.white, 0.06)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = h * i / 4;
      canvas.drawLine(Offset(0, y), Offset(w, y), grid);
    }

    // threshold lines
    void dashed(double y, Color c) {
      final p = Paint()
        ..color = alpha(c, 0.6)
        ..strokeWidth = 1.2;
      for (var x = 0.0; x < w; x += 10) {
        canvas.drawLine(Offset(x, y), Offset(x + 5, y), p);
      }
    }

    dashed(yFor(ammoniaIndex(mid, high: high)), kWarn);
    dashed(yFor(ammoniaIndex(high, high: high)), kBad);

    if (list.isEmpty) return;
    final pts = <Offset>[];
    for (final r in list) {
      final t = r.time;
      final frac = (t.hour * 60 + t.minute) / 1440.0;
      pts.add(Offset(frac * w, yFor(ammoniaIndex(r.raw, high: high))));
    }

    if (pts.length > 1) {
      final line = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        line.lineTo(p.dx, p.dy);
      }
      final area = Path.from(line)
        ..lineTo(pts.last.dx, h)
        ..lineTo(pts.first.dx, h)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [alpha(kAccent, 0.30), alpha(kAccent, 0.0)],
          ).createShader(Offset.zero & size),
      );
      canvas.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round
          ..color = kAccent,
      );
    }
    for (var i = 0; i < pts.length; i++) {
      canvas.drawCircle(pts[i], 3.5, Paint()..color = levelColor(list[i].level));
    }
  }

  @override
  bool shouldRepaint(covariant _DayChartPainter old) => true;
}
