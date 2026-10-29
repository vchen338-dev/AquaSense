import 'dart:math';

enum Level { warmup, low, mid, high, fault }

Level levelFrom(String? s) {
  switch (s) {
    case 'low':
      return Level.low;
    case 'mid':
      return Level.mid;
    case 'high':
      return Level.high;
    case 'fault':
      return Level.fault;
    default:
      return Level.warmup;
  }
}

String levelToken(Level l) => l.name;

/// How the cooling fan is controlled.
enum FanMode { auto, on, off }

FanMode fanModeFrom(String? s) {
  switch (s) {
    case 'on':
      return FanMode.on;
    case 'off':
      return FanMode.off;
    default:
      return FanMode.auto;
  }
}

Level levelForRaw(int raw, int mid, int high) {
  if (raw >= high) return Level.high;
  if (raw >= mid) return Level.mid;
  return Level.low;
}

/// 0..100 gauge value derived from the raw ADC reading.
int ammoniaIndex(int raw, {int high = 2200}) =>
    (raw / (high * 1.2) * 100).round().clamp(0, 100);

/// The ESP stores the RTC as "local time written as unix seconds".
DateTime fromDeviceEpoch(int epoch) {
  final u = DateTime.fromMillisecondsSinceEpoch(epoch * 1000, isUtc: true);
  return DateTime(u.year, u.month, u.day, u.hour, u.minute, u.second);
}

int toDeviceEpoch(DateTime local) =>
    DateTime.utc(local.year, local.month, local.day, local.hour, local.minute,
            local.second)
        .millisecondsSinceEpoch ~/
    1000;

class LiveData {
  final int raw;
  final bool doAlarm;
  final Level level;
  final double? temp;
  final double? hum;
  final bool mqOk, dhtOk, rtcOk, lcdOk;
  final bool fan, buzzer;
  final int mid, high;
  final FanMode fanMode;
  final double fanOnC, fanOffC;
  final int epoch;
  final int uptime;

  const LiveData({
    required this.raw,
    required this.doAlarm,
    required this.level,
    required this.temp,
    required this.hum,
    required this.mqOk,
    required this.dhtOk,
    required this.rtcOk,
    required this.lcdOk,
    required this.fan,
    required this.buzzer,
    required this.mid,
    required this.high,
    this.fanMode = FanMode.auto,
    this.fanOnC = 32,
    this.fanOffC = 30,
    required this.epoch,
    required this.uptime,
  });

  factory LiveData.fromJson(Map<String, dynamic> j) => LiveData(
        raw: (j['raw'] as num?)?.toInt() ?? 0,
        doAlarm: j['do'] == true,
        level: levelFrom(j['level'] as String?),
        temp: (j['temp'] as num?)?.toDouble(),
        hum: (j['hum'] as num?)?.toDouble(),
        mqOk: j['mqOk'] != false,
        dhtOk: j['dhtOk'] != false,
        rtcOk: j['rtcOk'] != false,
        lcdOk: j['lcdOk'] != false,
        fan: j['fan'] == true,
        buzzer: j['buzzer'] == true,
        mid: (j['mid'] as num?)?.toInt() ?? 1200,
        high: (j['high'] as num?)?.toInt() ?? 2200,
        fanMode: fanModeFrom(j['fanMode'] as String?),
        fanOnC: (j['fanOnC'] as num?)?.toDouble() ?? 32,
        fanOffC: (j['fanOffC'] as num?)?.toDouble() ?? 30,
        epoch: (j['epoch'] as num?)?.toInt() ?? 0,
        uptime: (j['uptime'] as num?)?.toInt() ?? 0,
      );

  int get index => ammoniaIndex(raw, high: high);

  DateTime? get deviceTime => epoch > 0 ? fromDeviceEpoch(epoch) : null;

  /// Names of the parts that report a fault.
  List<String> get failingSensors => [
        if (!mqOk) 'MQ-137',
        if (!dhtOk) 'DHT22',
        if (!rtcOk) 'RTC clock',
        if (!lcdOk) 'LCD',
      ];
}

class Reading {
  final int epoch;
  final int raw;
  final Level level;
  final double? temp;
  final double? hum;

  const Reading({
    required this.epoch,
    required this.raw,
    required this.level,
    this.temp,
    this.hum,
  });

  DateTime get time => fromDeviceEpoch(epoch);

  String toCsv() =>
      '$epoch,$raw,${levelToken(level)},${temp?.toStringAsFixed(1) ?? ''},${hum?.toStringAsFixed(1) ?? ''}';

  static Reading? tryParse(String line) {
    final p = line.trim().split(',');
    if (p.length < 3) return null;
    final e = int.tryParse(p[0]);
    final r = int.tryParse(p[1]);
    if (e == null || r == null) return null;
    return Reading(
      epoch: e,
      raw: r,
      level: levelFrom(p[2]),
      temp: p.length > 3 ? double.tryParse(p[3]) : null,
      hum: p.length > 4 ? double.tryParse(p[4]) : null,
    );
  }
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Small deterministic helper for the demo data.
double demoWave(double x, [double phase = 0]) => sin(x + phase);
